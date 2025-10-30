import 'dart:convert';
import 'dart:async';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/audio_item.dart';
import '../models/tab_item.dart';
import 'api/audio_list_service.dart';
import 'api/home_tabs_service.dart';
import 'package:flutter/foundation.dart';
import 'performance_service.dart';
import 'package:firebase_performance/firebase_performance.dart';

/// 首页列表数据管理服务
/// 
/// 职责：
/// - 管理首页 Tabs 数据的缓存和获取
/// - 管理每个 Tab 下音频列表的缓存和分页
/// - 提供统一的数据访问接口
/// - 处理本地缓存逻辑
class HomePageListService {
  // 缓存键名
  static const String _tabsCacheKey = 'home_tabs_cache';
  static const String _tabListCachePrefix = 'home_tab_list_';
  static const int _maxItemsPerTab = 20;

  // 单例模式
  static final HomePageListService _instance = HomePageListService._internal();
  factory HomePageListService() => _instance;
  HomePageListService._internal();

  // 本地存储实例
  SharedPreferences? _prefs;

  // 内存缓存
  List<TabItemModel> _cachedTabs = [];
  final Map<String, List<AudioItem>> _tabDataCache = {};

  // 初始化状态
  bool _isInitialized = false;

  // Tabs更新通知流
  final StreamController<List<TabItemModel>> _tabsStreamController =
      StreamController<List<TabItemModel>>.broadcast();
  Stream<List<TabItemModel>> get tabsStream => _tabsStreamController.stream;

  /// 初始化服务
  Future<void> initialize() async {
    if (_isInitialized) return;

    try {
      debugPrint('🏠 [HOME_SERVICE] 开始初始化 HomePageListService');
      
      // 初始化 SharedPreferences
      _prefs = await SharedPreferences.getInstance();
      
      // 加载缓存的 Tabs 数据
      await _loadCachedTabs();
      
      // 如果没有缓存，从服务器获取
      if (_cachedTabs.isEmpty) {
        debugPrint('🏠 [HOME_SERVICE] 没有缓存数据，从服务器获取 Tabs');
        await _fetchAndCacheTabs();
      } else {
        debugPrint('🏠 [HOME_SERVICE] 使用缓存的 Tabs 数据: ${_cachedTabs.length} 个');
        // 后台更新 Tabs
        _updateTabsInBackground();
      }
      
      // 加载每个 Tab 的音频列表缓存
      await _loadCachedTabLists();
      
      // 通知 UI
      _tabsStreamController.add(List.from(_cachedTabs));
      
      _isInitialized = true;
      debugPrint('🏠 [HOME_SERVICE] HomePageListService 初始化完成');
    } catch (e) {
      debugPrint('🏠 [HOME_SERVICE] 初始化失败: $e');
      rethrow;
    }
  }

  /// 获取 Tabs 列表
  List<TabItemModel> getTabs() {
    _ensureInitialized();
    return List.from(_cachedTabs);
  }

  /// 获取指定 Tab 的音频列表
  List<AudioItem> getTabData(String tabId) {
    _ensureInitialized();
    return List.from(_tabDataCache[tabId] ?? []);
  }

  /// 初始化指定 Tab 的音频数据
  Future<List<AudioItem>> initTabAudioData(String tabId) async {
    _ensureInitialized();
    
    try {
      debugPrint('🏠 [HOME_SERVICE] 初始化 Tab $tabId 的音频数据');
      
      // 检查缓存
      final cachedData = _tabDataCache[tabId];
      if (cachedData != null && cachedData.isNotEmpty) {
        debugPrint('🏠 [HOME_SERVICE] 使用缓存数据: ${cachedData.length} 条');
        return cachedData;
      }
      
      // 从服务器获取数据
      final newData = await _fetchTabAudioData(tabId);
      
      // 更新缓存
      _tabDataCache[tabId] = newData;
      await _cacheTabListData(tabId, newData);
      
      return newData;
    } catch (e) {
      debugPrint('🏠 [HOME_SERVICE] 初始化 Tab $tabId 数据失败: $e');
      rethrow;
    }
  }

  /// 刷新指定 Tab 的音频数据
  Future<List<AudioItem>> refreshTabAudioData(String tabId) async {
    // _ensureInitialized();
    
    // try {
    //   debugPrint('🏠 [HOME_SERVICE] 刷新 Tab $tabId 的音频数据');
      
    //   // 清空缓存，重新获取
    //   _tabDataCache[tabId] = [];
    //   final newData = await _fetchTabAudioData(tabId);
      
    //   // 更新缓存
    //   _tabDataCache[tabId] = newData;
    //   await _cacheTabListData(tabId, newData);
      
    //   return newData;
    // } catch (e) {
    //   debugPrint('🏠 [HOME_SERVICE] 刷新 Tab $tabId 数据失败: $e');
    //   rethrow;
    // }
    return loadMoreTabAudioData(tabId);
  }

  /// 加载更多音频数据
  Future<List<AudioItem>> loadMoreTabAudioData(String tabId) async {
    _ensureInitialized();
    
    try {
      debugPrint('🏠 [HOME_SERVICE] 加载更多 Tab $tabId 的音频数据');
      
      final currentData = _tabDataCache[tabId] ?? [];
      final lastCid = currentData.isNotEmpty ? currentData.last.id : null;
      
      // 获取下一页数据
      final newData = await _fetchTabAudioData(tabId, lastCid: lastCid);
      
      if (newData.isNotEmpty) {
        // 合并数据（不做去重，按请求返回直接追加）
        final combinedData = [...currentData, ...newData];
        _tabDataCache[tabId] = combinedData;
        
        // 本地存储只保留最新数据
        await _cacheTabListData(tabId, newData);
        
        debugPrint('🏠 [HOME_SERVICE] 加载了 ${newData.length} 条新数据，总计 ${combinedData.length} 条');
        return newData;
      }
      
      return [];
    } catch (e) {
      debugPrint('🏠 [HOME_SERVICE] 加载更多 Tab $tabId 数据失败: $e');
      rethrow;
    }
  }

  /// 从本地存储加载缓存的 Tabs
  Future<void> _loadCachedTabs() async {
    try {
      final tabsJson = _prefs?.getString(_tabsCacheKey);
      if (tabsJson != null) {
        final List<dynamic> tabsData = json.decode(tabsJson);
        _cachedTabs = tabsData
            .map((tab) => TabItemModel.fromMap(tab as Map<String, dynamic>))
            .toList();
        debugPrint('🏠 [HOME_SERVICE] 加载了 ${_cachedTabs.length} 个缓存 Tabs');
      }
    } catch (e) {
      debugPrint('🏠 [HOME_SERVICE] 加载缓存 Tabs 失败: $e');
      _cachedTabs.clear();
    }
  }

  /// 从本地存储加载缓存的 Tab 列表数据
  Future<void> _loadCachedTabLists() async {
    try {
      for (final tab in _cachedTabs) {
        final listJson = _prefs?.getString('$_tabListCachePrefix${tab.id}');
        if (listJson != null) {
          final List<dynamic> listData = json.decode(listJson);
          _tabDataCache[tab.id] = listData
              .map((item) => AudioItem.fromMap(item as Map<String, dynamic>))
              .toList();
          debugPrint('🏠 [HOME_SERVICE] 加载了 Tab ${tab.id} 的 ${_tabDataCache[tab.id]!.length} 条缓存数据');
        }
      }
    } catch (e) {
      debugPrint('🏠 [HOME_SERVICE] 加载缓存 Tab 列表失败: $e');
      _tabDataCache.clear();
    }
  }

  /// 从服务器获取并缓存 Tabs
  Future<void> _fetchAndCacheTabs() async {
    try {
      final tabs = await HomeTabsService.getHomeTabs();
      _cachedTabs = tabs;
      await _cacheTabsData(tabs);
      debugPrint('🏠 [HOME_SERVICE] 获取并缓存了 ${tabs.length} 个 Tabs');

      // 同步写入每个 Tab 的 items（若非空）到列表缓存与内存缓存，
      // 以便首次切换 Tab 不发请求即可有首屏数据。
      for (final tab in tabs) {
        final List<AudioItem> items = tab.items;
        if (items.isNotEmpty) {
          // 轻量化：限制写入的条目数，避免过大的首屏缓存
          final List<AudioItem> trimmed =
              items.length > _maxItemsPerTab ? items.sublist(0, _maxItemsPerTab) : items;

          // 写入内存缓存
          _tabDataCache[tab.id] = trimmed;

          // 写入本地缓存
          await _cacheTabListData(tab.id, trimmed);

          debugPrint(
              '🏠 [HOME_SERVICE] 预填充 Tab ${tab.id} 的 items 至缓存，数量: ${trimmed.length}');
        }
      }
    } catch (e) {
      debugPrint('🏠 [HOME_SERVICE] 获取 Tabs 失败: $e');
      rethrow;
    }
  }

  /// 后台更新 Tabs
  Future<void> _updateTabsInBackground() async {
    try {
      final latestTabs = await HomeTabsService.getHomeTabs();
      _cachedTabs = latestTabs;
      await _cacheTabsData(latestTabs);
      
      // 通知 UI 更新
      _tabsStreamController.add(List.from(_cachedTabs));
      
      debugPrint('🏠 [HOME_SERVICE] 后台更新 Tabs 完成');
    } catch (e) {
      debugPrint('🏠 [HOME_SERVICE] 后台更新 Tabs 失败: $e');
    }
  }

  /// 获取指定 Tab 的音频数据
  Future<List<AudioItem>> _fetchTabAudioData(String tabId, {String? lastCid}) async {
    Trace? trace;
    final startMs = DateTime.now().millisecondsSinceEpoch;
    
    try {
      trace = await PerformanceService().startTrace('home_tab_audio_load');
      trace?.putAttribute('tab_id', tabId);
      if (lastCid != null) trace?.putAttribute('last_cid', lastCid);
      trace?.putAttribute('count', '$_maxItemsPerTab');

      final newItems = await AudioListService.getAudioList(
        tag: tabId == 'for_you' ? null : tabId,
        cid: lastCid,
        count: _maxItemsPerTab,
      );

      final elapsed = DateTime.now().millisecondsSinceEpoch - startMs;
      trace?.setMetric('elapsed_ms', elapsed);
      trace?.setMetric('item_count', newItems.length);
      
      debugPrint('🏠 [HOME_SERVICE] Tab $tabId 获取了 ${newItems.length} 条音频数据');
      return newItems;
    } catch (e) {
      debugPrint('🏠 [HOME_SERVICE] 获取 Tab $tabId 音频数据失败: $e');
      rethrow;
    } finally {
      await PerformanceService().stopTrace(trace);
    }
  }

  /// 缓存 Tabs 数据
  Future<void> _cacheTabsData(List<TabItemModel> tabs) async {
    try {
      final tabsJson = json.encode(tabs.map((tab) => tab.toMap()).toList());
      await _prefs?.setString(_tabsCacheKey, tabsJson);
      debugPrint('🏠 [HOME_SERVICE] Tabs 数据已缓存');
    } catch (e) {
      debugPrint('🏠 [HOME_SERVICE] 缓存 Tabs 数据失败: $e');
    }
  }

  /// 缓存指定 Tab 的列表数据
  Future<void> _cacheTabListData(String tabId, List<AudioItem> items) async {
    try {
      final listJson = json.encode(items.map((item) => item.toMap()).toList());
      await _prefs?.setString('$_tabListCachePrefix$tabId', listJson);
      debugPrint('🏠 [HOME_SERVICE] Tab $tabId 的列表数据已缓存，共 ${items.length} 条');
    } catch (e) {
      debugPrint('🏠 [HOME_SERVICE] 缓存 Tab $tabId 列表数据失败: $e');
    }
  }

  /// 确保服务已初始化
  void _ensureInitialized() {
    if (!_isInitialized) {
      throw StateError('HomePageListService failure.');
    }
  }

  /// 获取服务状态信息
  Map<String, dynamic> getServiceStatus() {
    return {
      'isInitialized': _isInitialized,
      'tabsCount': _cachedTabs.length,
      'tabDataCacheCount': _tabDataCache.length,
      'totalCachedItems': _tabDataCache.values.fold(0, (sum, list) => sum + list.length),
    };
  }

  /// 清理资源
  Future<void> dispose() async {
    _cachedTabs.clear();
    _tabDataCache.clear();
    _isInitialized = false;
    await _tabsStreamController.close();
    debugPrint('🏠 [HOME_SERVICE] HomePageListService 已清理');
  }
}
