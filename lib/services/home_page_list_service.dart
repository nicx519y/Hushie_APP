import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
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

  // 单例模式
  static final HomePageListService _instance = HomePageListService._internal();
  factory HomePageListService() => _instance;
  HomePageListService._internal();

  // 本地存储实例
  SharedPreferences? _prefs;

  // 内存中的数据缓存
  final Map<String, List<AudioItem>> _tabDataCache = {};

  // 是否已初始化
  bool _isInitialized = false;

  /// 初始化服务
  Future<void> initialize() async {
    if (_isInitialized) return;

    try {
      _prefs = await SharedPreferences.getInstance();

      // 清除之前的缓存数据
      debugPrint('清除之前的缓存数据');
      _tabDataCache.clear();

      // 清除本地存储
      await _prefs?.remove(_storageKey);

      _isInitialized = true;
      debugPrint('HomePageListService 初始化完成，缓存已清除');
    } catch (error) {
      debugPrint('HomePageListService 初始化失败: $error');
      rethrow;
    }
  }

  /// 获取指定tab的数据列表（不使用缓存）
  List<AudioItem> getTabData(String tabId) {
    _ensureInitialized();
    // 不使用缓存，返回空列表
    return [];
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
        // 不使用缓存，每次都返回新数据
        debugPrint('Tab $tabId 获取数据成功: ${newItems.length} 条，lastCid: ${newItems.last.id}');
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
        debugPrint('Tab $tabId 获取数据成功: ${newItems.length} 条，lastCid: ${newItems.last.id}');
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
  Future<void> preloadTabData(String tabId) async {
    _ensureInitialized();

    // 不使用缓存，每次都获取新数据
    debugPrint('预加载 Tab $tabId 的数据');
    await fetchNextPageData(tabId);
  }

  /// 获取所有tab的缓存状态信息
  Map<String, Map<String, dynamic>> getAllTabsStatus() {
    _ensureInitialized();

    // 由于不使用缓存，返回空状态
    return {};
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
