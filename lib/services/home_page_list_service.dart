import 'dart:convert';
import 'dart:async';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter/services.dart' show rootBundle; // 读取预埋资产文件
import '../models/audio_item.dart';
import 'api/audio_list_service.dart';
import 'package:flutter/foundation.dart';
import 'performance_service.dart';
import 'package:firebase_performance/firebase_performance.dart';

/// 首页列表数据管理服务
///
/// 功能特性：
/// - 每次请求都从服务器获取最新数据，不使用缓存
/// - 提供fetchNextPageData方法，自动管理分页和lastCid
/// - 服务初始化时清除所有缓存数据
/// - 支持实时数据获取，确保数据新鲜度
class HomePageListService {
  static const String _storageKey = 'home_page_list_data';
  static const int _maxItemsPerTab = 20;
  static const String _defaultTabId = 'for_you';
  static const String _defaultAssetsPath = 'assets/configs/default_audio_list.json';

  // 单例模式
  static final HomePageListService _instance = HomePageListService._internal();
  factory HomePageListService() => _instance;
  HomePageListService._internal();

  // 本地存储实例
  SharedPreferences? _prefs;

  // 内存中的数据缓存
  final Map<String, List<AudioItem>> _tabDataCache = {};
  // 标记哪些tab使用了预埋默认数据（首次渲染用，不参与服务端分页cid）
  final Set<String> _defaultSeededTabs = {};
  // 记录各 tab 的预加载进行中任务，避免重复触发
  final Map<String, Future<void>> _preloadingTabs = {};

  // 是否已初始化
  bool _isInitialized = false;

  /// 初始化服务
  Future<void> initialize() async {
    if (_isInitialized) return;

    try {
      _prefs = await SharedPreferences.getInstance();

      // 尝试从本地存储加载缓存
      final stored = _prefs?.getString(_storageKey);
      if (stored != null && stored.isNotEmpty) {
        _loadDataFromStorage(stored);
        debugPrint('HomePageListService 初始化完成：已加载本地缓存');
      } else {
        // 本地存储为空：加载预埋的默认数据到 for_you，并作为首次渲染数据
        try {
          final seedItems = await _loadDefaultSeedItems();
          _tabDataCache[_defaultTabId] = seedItems;
          _defaultSeededTabs.add(_defaultTabId);
          debugPrint('HomePageListService 初始化完成：已加载预埋默认数据(${seedItems.length}条)');
        } catch (e) {
          debugPrint('HomePageListService 预埋数据加载失败: $e');
          _tabDataCache[_defaultTabId] = [];
        }
      }

      _isInitialized = true;
    } catch (error) {
      debugPrint('HomePageListService 初始化失败: $error');
      rethrow;
    }
  }

  /// 获取指定tab的数据列表（不使用缓存）
  List<AudioItem> getTabData(String tabId) {
    _ensureInitialized();
    return _tabDataCache[tabId] ?? [];
  }

  /// 获取指定tab的lastCid
  /// 从当前正在使用的数据中获取最后一个item的id
  String? getTabLastCid(String tabId, {List<AudioItem>? currentData}) {
    _ensureInitialized();
    // 优先使用传入的当前数据
    if (currentData != null && currentData.isNotEmpty) {
      return currentData.last.id;
    }
    
    // 其次使用缓存数据
    final tabData = _tabDataCache[tabId];
    if (tabData != null && tabData.isNotEmpty) {
      return tabData.last.id;
    }
    
    // 如果都没有数据，返回null（首次请求）
    return null;
  }

  /// 获取下一页数据
  ///
  /// [tabId] tab标识
  /// [forceRefresh] 是否强制刷新（忽略缓存）
  /// 返回获取到的数据列表
  Future<List<AudioItem>> fetchNextPageData(
    String tabId, {
    bool forceRefresh = false,
  }) async {
    _ensureInitialized();
    Trace? trace;
    final startMs = DateTime.now().millisecondsSinceEpoch;
    try {
      trace = await PerformanceService().startTrace('home_list_load');
      // 获取当前tab的lastCid
      final lastCid = getTabLastCid(tabId);
      trace?.putAttribute('tab_id', tabId);
      if (lastCid != null) trace?.putAttribute('last_cid', lastCid);
      trace?.putAttribute('count', '$_maxItemsPerTab');
      trace?.putAttribute('force_refresh', forceRefresh ? 'true' : 'false');

      // 调用API获取数据
      final newItems = await AudioListService.getAudioList(
        tag: tabId == 'for_you' ? null : tabId,
        cid: lastCid,
        count: _maxItemsPerTab,
      );

      if (newItems.isNotEmpty) {
        // 更新缓存：若之前是预埋默认数据，首次请求用新数据替换；否则追加并去重
        final existing = _tabDataCache[tabId] ?? [];
        List<AudioItem> merged;
        if (_defaultSeededTabs.contains(tabId) || forceRefresh) {
          merged = newItems;
          _defaultSeededTabs.remove(tabId);
        } else {
          final ids = existing.map((e) => e.id).toSet();
          merged = [...existing];
          for (final item in newItems) {
            if (!ids.contains(item.id)) {
              merged.add(item);
              ids.add(item.id);
            }
          }
        }
        _tabDataCache[tabId] = merged;
        await _saveDataToStorage();

        debugPrint('Tab $tabId 获取数据成功: ${newItems.length} 条，合并后共 ${merged.length} 条');
        final elapsed = DateTime.now().millisecondsSinceEpoch - startMs;
        trace?.setMetric('elapsed_ms', elapsed);
        trace?.setMetric('item_count', newItems.length);
        return newItems;
      } else {
        debugPrint('Tab $tabId 没有更多数据');
        final elapsed = DateTime.now().millisecondsSinceEpoch - startMs;
        trace?.setMetric('elapsed_ms', elapsed);
        trace?.setMetric('item_count', 0);
        return [];
      }
    } catch (error) {
      debugPrint('Tab $tabId 获取数据失败: $error');
      rethrow;
    } finally {
      await PerformanceService().stopTrace(trace);
    }
  }

  /// 获取下一页数据（传递当前数据）
  ///
  /// [tabId] tab标识
  /// [currentData] 当前已有的数据列表
  /// 返回获取到的数据列表
  Future<List<AudioItem>> fetchNextPageDataWithCurrentData(
    String tabId,
    List<AudioItem> currentData,
  ) async {
    _ensureInitialized();
    Trace? trace;
    final startMs = DateTime.now().millisecondsSinceEpoch;
    try {
      trace = await PerformanceService().startTrace('home_list_load');
      trace?.putAttribute('tab_id', tabId);
      trace?.putAttribute('has_current_data', currentData.isNotEmpty ? 'true' : 'false');
      trace?.putAttribute('current_data_count', '${currentData.length}');
      // 获取当前tab的lastCid，传递当前数据
      final lastCid = getTabLastCid(tabId, currentData: currentData);
      if (lastCid != null) trace?.putAttribute('last_cid', lastCid);
      trace?.putAttribute('count', '$_maxItemsPerTab');

      // 调用API获取数据
      final newItems = await AudioListService.getAudioList(
        tag: tabId == 'for_you' ? null : tabId,
        cid: lastCid,
        count: _maxItemsPerTab,
      );

      if (newItems.isNotEmpty) {
        // 同步缓存
        final existing = _tabDataCache[tabId] ?? [];
        List<AudioItem> merged;
        if (_defaultSeededTabs.contains(tabId)) {
          merged = newItems;
          _defaultSeededTabs.remove(tabId);
        } else {
          final ids = existing.map((e) => e.id).toSet();
          merged = [...existing];
          for (final item in newItems) {
            if (!ids.contains(item.id)) {
              merged.add(item);
              ids.add(item.id);
            }
          }
        }
        _tabDataCache[tabId] = merged;
        await _saveDataToStorage();

        debugPrint('Tab $tabId 获取数据成功: ${newItems.length} 条，合并后共 ${merged.length} 条');
        final elapsed = DateTime.now().millisecondsSinceEpoch - startMs;
        trace?.setMetric('elapsed_ms', elapsed);
        trace?.setMetric('item_count', newItems.length);
        return newItems;
      } else {
        debugPrint('Tab $tabId 没有更多数据');
        final elapsed = DateTime.now().millisecondsSinceEpoch - startMs;
        trace?.setMetric('elapsed_ms', elapsed);
        trace?.setMetric('item_count', 0);
        return [];
      }
    } catch (error) {
      debugPrint('Tab $tabId 获取数据失败: $error');
      rethrow;
    } finally {
      await PerformanceService().stopTrace(trace);
    }
  }

  /// 刷新指定tab的数据（清空缓存，重新获取）
  Future<List<AudioItem>> refreshTabData(String tabId) async {
    _ensureInitialized();

    // 清空当前tab的缓存
    _tabDataCache[tabId] = [];

    // 重新获取数据
    return await fetchNextPageData(tabId, forceRefresh: true);
  }

  /// 清空指定tab的数据
  void clearTabData(String tabId) {
    _ensureInitialized();
    _tabDataCache[tabId] = [];
    _saveDataToStorage();
  }

  /// 清空所有tab的数据
  void clearAllTabData() {
    _ensureInitialized();
    _tabDataCache.clear();
    _saveDataToStorage();
  }

  /// 预加载指定tab的数据（如果缓存为空）
  /// 增加状态限制：当该 tab 的预加载已在进行中，等待其完成后返回，不重复发起
  Future<void> preloadTabData(String tabId) async {
    _ensureInitialized();

    // 若已有进行中的预加载任务，直接等待其完成
    final existingTask = _preloadingTabs[tabId];
    if (existingTask != null) {
      debugPrint('Tab $tabId 预加载进行中，等待现有任务完成');
      await existingTask;
      return;
    }

    // 创建并注册新任务，确保并发调用只执行一次真正的预加载逻辑
    final completer = Completer<void>();
    _preloadingTabs[tabId] = completer.future;
    try {
      // 若本地是空且为默认tab，确保预埋数据已加载
      if ((_tabDataCache[tabId] == null || _tabDataCache[tabId]!.isEmpty) && tabId == _defaultTabId) {
        try {
          final seedItems = await _loadDefaultSeedItems();
          _tabDataCache[_defaultTabId] = seedItems;
          _defaultSeededTabs.add(_defaultTabId);
          debugPrint('预加载默认Tab($tabId)：写入预埋数据 ${seedItems.length} 条');
        } catch (e) {
          debugPrint('预加载默认Tab预埋数据失败: $e');
        }
      }
      // 之后拉取服务器数据
      await fetchNextPageData(tabId);
      completer.complete();
    } catch (e, st) {
      // 将错误传播给所有等待者
      if (!completer.isCompleted) {
        completer.completeError(e, st);
      }
      rethrow;
    } finally {
      // 清理进行中标记
      _preloadingTabs.remove(tabId);
    }
  }

  /// 获取所有tab的缓存状态信息
  Map<String, Map<String, dynamic>> getAllTabsStatus() {
    _ensureInitialized();
    final status = <String, Map<String, dynamic>>{};
    _tabDataCache.forEach((tabId, items) {
      status[tabId] = {
        'items': items.length,
        'default_seeded': _defaultSeededTabs.contains(tabId),
      };
    });
    return status;
  }

  /// 保存数据到本地存储
  Future<void> _saveDataToStorage() async {
    try {
      // 转换数据为可序列化的格式
      final tabDataMap = <String, List<Map<String, dynamic>>>{};
      _tabDataCache.forEach((tabId, items) {
        tabDataMap[tabId] = items.map((item) => item.toMap()).toList();
      });

      final data = {
        'tabData': tabDataMap,
        'timestamp': DateTime.now().millisecondsSinceEpoch,
      };

      final dataJson = json.encode(data);
      await _prefs?.setString(_storageKey, dataJson);

      debugPrint('数据已保存到本地存储');
    } catch (error) {
      debugPrint('保存数据到本地存储失败: $error');
    }
  }

  /// 从本地存储字符串加载数据到内存缓存
  void _loadDataFromStorage(String stored) {
    try {
      final decoded = json.decode(stored) as Map<String, dynamic>;
      final tabData = decoded['tabData'] as Map<String, dynamic>?;
      _tabDataCache.clear();
      if (tabData != null) {
        tabData.forEach((tabId, list) {
          final items = (list as List<dynamic>)
              .map((e) => AudioItem.fromMap(e as Map<String, dynamic>))
              .toList();
          _tabDataCache[tabId] = items;
        });
      }
      // 从本地加载的数据不属于预埋默认数据
      _defaultSeededTabs.clear();
    } catch (e) {
      debugPrint('解析本地存储数据失败: $e');
    }
  }

  /// 加载预埋默认数据（assets/configs/default_audio_list.json）
  Future<List<AudioItem>> _loadDefaultSeedItems() async {
    final jsonStr = await rootBundle.loadString(_defaultAssetsPath);
    final list = json.decode(jsonStr) as List<dynamic>;
    return list
        .map((e) => AudioItem.fromMap(e as Map<String, dynamic>))
        .toList();
  }

  /// 确保服务已初始化
  void _ensureInitialized() {
    if (!_isInitialized) {
      throw StateError('HomePageListService 尚未初始化，请先调用 initialize() 方法');
    }
  }

  /// 获取服务状态信息
  Map<String, dynamic> getServiceStatus() {
    return {
      'isInitialized': _isInitialized,
      'tabsCount': 0, // 不使用缓存，所以tab数量为0
      'totalItems': 0, // 不使用缓存，所以总项目数为0
      'storageKey': _storageKey,
      'maxItemsPerTab': _maxItemsPerTab,
      'cacheEnabled': false, // 标记缓存已禁用
    };
  }
}

/// 使用示例：
/// 
/// ```dart
/// // 1. 在应用启动时初始化服务
/// void main() async {
///   WidgetsFlutterBinding.ensureInitialized();
///   await HomePageListService().initialize();
///   runApp(MyApp());
/// }
/// 
/// // 2. 在HomePage中使用服务
/// class HomePage extends StatefulWidget {
///   @override
///   State<HomePage> createState() => _HomePageState();
/// }
/// 
/// class _HomePageState extends State<HomePage> {
///   final _listService = HomePageListService();
///   
///   @override
///   void initState() {
///     super.initState();
///     _initializeData();
///   }
///   
///   Future<void> _initializeData() async {
///     // 预加载当前tab的数据（每次都是新数据）
///     await _listService.preloadTabData('for_you');
///   }
///   
///   // 获取下一页数据（每次都是新数据）
///   Future<List<AudioItem>> _fetchNextPage(String tabId) async {
///     return await _listService.fetchNextPageData(tabId);
///   }
///   
///   // 刷新数据（每次都是新数据）
///   Future<List<AudioItem>> _refreshData(String tabId) async {
///     return await _listService.refreshTabData(tabId);
///   }
///   
///   // 获取缓存数据（现在总是返回空列表）
///   List<AudioItem> _getCachedData(String tabId) {
///     return _listService.getTabData(tabId);
///   }
/// }
/// 
/// // 3. 在PagedAudioGrid中使用
/// PagedAudioGrid(
///   tag: 'music',
///   initDataFetcher: (tag) => _listService.fetchNextPageData(tag ?? 'for_you'),
///   refreshDataFetcher: (tag) => _listService.refreshTabData(tag ?? 'for_you'),
///   loadMoreDataFetcher: (tag, pageKey, count) => 
///       _listService.fetchNextPageData(tag ?? 'for_you'),
/// )
/// ```
