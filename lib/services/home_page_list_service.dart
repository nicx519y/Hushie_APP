import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/audio_item.dart';
import 'api_service.dart';

/// 首页列表数据管理服务
///
/// 功能特性：
/// - 针对tabs以及每个tab的列表，本地存储每个tab的最新获取的200条数据
/// - 提供fetchNextPageData方法，自动管理分页和lastCid
/// - 服务初始化时从本地存储恢复数据状态
/// - 支持数据缓存和离线访问
class HomePageListService {
  static const String _storageKey = 'home_page_list_data';
  static const int _maxItemsPerTab = 50;

  // 单例模式
  static final HomePageListService _instance = HomePageListService._internal();
  factory HomePageListService() => _instance;
  HomePageListService._internal();

  // 本地存储实例
  SharedPreferences? _prefs;

  // 内存中的数据缓存
  final Map<String, List<AudioItem>> _tabDataCache = {};
  final Map<String, String?> _tabLastCidCache = {};

  // 是否已初始化
  bool _isInitialized = false;

  /// 初始化服务
  Future<void> initialize() async {
    if (_isInitialized) return;

    try {
      _prefs = await SharedPreferences.getInstance();
      await _loadDataFromStorage();
      _isInitialized = true;
      print('HomePageListService 初始化完成');
    } catch (error) {
      print('HomePageListService 初始化失败: $error');
      rethrow;
    }
  }

  /// 获取指定tab的数据列表
  List<AudioItem> getTabData(String tabId) {
    _ensureInitialized();
    return _tabDataCache[tabId] ?? [];
  }

  /// 获取指定tab的lastCid
  String? getTabLastCid(String tabId) {
    _ensureInitialized();
    return _tabLastCidCache[tabId];
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

    try {
      // 获取当前tab的lastCid
      final lastCid = _tabLastCidCache[tabId];

      // 调用API获取数据
      final response = await ApiService.getAudioList(
        tag: tabId == 'for_you' ? null : tabId,
        cid: lastCid,
        count: _maxItemsPerTab,
      );

      if (response.errNo == 0 && response.data != null) {
        final newItems = response.data!.items;

        if (newItems.isNotEmpty) {
          // 更新lastCid为最新数据的最后一个item的id
          final newLastCid = newItems.last.id;
          _tabLastCidCache[tabId] = newLastCid;

          // 更新数据缓存
          if (forceRefresh || _tabDataCache[tabId] == null) {
            // 强制刷新或首次加载，直接替换
            _tabDataCache[tabId] = List.from(newItems);
          } else {
            // 追加新数据，保持最大数量限制
            final currentData = _tabDataCache[tabId]!;
            final combinedData = [...currentData, ...newItems];

            // 只保留最新的50条数据
            if (combinedData.length > _maxItemsPerTab) {
              _tabDataCache[tabId] = combinedData.sublist(
                combinedData.length - _maxItemsPerTab,
              );
            } else {
              _tabDataCache[tabId] = combinedData;
            }
          }

          // 保存到本地存储
          await _saveDataToStorage();

          print('Tab $tabId 获取数据成功: ${newItems.length} 条，lastCid: $newLastCid');
          return _tabDataCache[tabId]!;
        } else {
          print('Tab $tabId 没有更多数据');
          return _tabDataCache[tabId] ?? [];
        }
      } else {
        throw Exception('获取数据失败: 错误码 ${response.errNo}');
      }
    } catch (error) {
      print('Tab $tabId 获取数据失败: $error');
      rethrow;
    }
  }

  /// 刷新指定tab的数据（清空缓存，重新获取）
  Future<List<AudioItem>> refreshTabData(String tabId) async {
    _ensureInitialized();

    // 清空当前tab的缓存
    _tabDataCache[tabId] = [];
    _tabLastCidCache[tabId] = null;

    // 重新获取数据
    return await fetchNextPageData(tabId, forceRefresh: true);
  }

  /// 清空指定tab的数据
  void clearTabData(String tabId) {
    _ensureInitialized();
    _tabDataCache[tabId] = [];
    _tabLastCidCache[tabId] = null;
    _saveDataToStorage();
  }

  /// 清空所有tab的数据
  void clearAllTabData() {
    _ensureInitialized();
    _tabDataCache.clear();
    _tabLastCidCache.clear();
    _saveDataToStorage();
  }

  /// 预加载指定tab的数据（如果缓存为空）
  Future<void> preloadTabData(String tabId) async {
    _ensureInitialized();

    if (_tabDataCache[tabId]?.isEmpty ?? true) {
      print('预加载 Tab $tabId 的数据');
      await fetchNextPageData(tabId);
    }
  }

  /// 获取所有tab的缓存状态信息
  Map<String, Map<String, dynamic>> getAllTabsStatus() {
    _ensureInitialized();

    final status = <String, Map<String, dynamic>>{};
    _tabDataCache.forEach((tabId, data) {
      status[tabId] = {
        'itemCount': data.length,
        'lastCid': _tabLastCidCache[tabId],
        'hasData': data.isNotEmpty,
      };
    });

    return status;
  }

  /// 从本地存储加载数据
  Future<void> _loadDataFromStorage() async {
    try {
      final dataJson = _prefs?.getString(_storageKey);
      if (dataJson != null) {
        final data = json.decode(dataJson) as Map<String, dynamic>;

        // 恢复tab数据缓存
        final tabDataMap = data['tabData'] as Map<String, dynamic>? ?? {};
        tabDataMap.forEach((tabId, itemsJson) {
          final items = (itemsJson as List)
              .map((item) => AudioItem.fromMap(item))
              .toList();
          _tabDataCache[tabId] = items;
        });

        // 恢复lastCid缓存
        final lastCidMap = data['lastCid'] as Map<String, dynamic>? ?? {};
        lastCidMap.forEach((tabId, lastCid) {
          _tabLastCidCache[tabId] = lastCid as String?;
        });

        print('从本地存储恢复数据: ${_tabDataCache.length} 个tab');
      }
    } catch (error) {
      print('从本地存储恢复数据失败: $error');
      // 恢复失败时清空缓存
      _tabDataCache.clear();
      _tabLastCidCache.clear();
    }
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
        'lastCid': _tabLastCidCache,
        'timestamp': DateTime.now().millisecondsSinceEpoch,
      };

      final dataJson = json.encode(data);
      await _prefs?.setString(_storageKey, dataJson);

      print('数据已保存到本地存储');
    } catch (error) {
      print('保存数据到本地存储失败: $error');
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
      'tabsCount': _tabDataCache.length,
      'totalItems': _tabDataCache.values.fold(
        0,
        (sum, items) => sum + items.length,
      ),
      'storageKey': _storageKey,
      'maxItemsPerTab': _maxItemsPerTab,
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
///     // 预加载当前tab的数据
///     await _listService.preloadTabData('for_you');
///   }
///   
///   // 获取下一页数据
///   Future<List<AudioItem>> _fetchNextPage(String tabId) async {
///     return await _listService.fetchNextPageData(tabId);
///   }
///   
///   // 刷新数据
///   Future<List<AudioItem>> _refreshData(String tabId) async {
///     return await _listService.refreshTabData(tabId);
///   }
///   
///   // 获取缓存数据
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
