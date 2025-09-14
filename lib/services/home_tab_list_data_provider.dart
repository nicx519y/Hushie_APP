import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/audio_item.dart';
import '../models/tab_item.dart';
import 'api/home_tabs_service.dart';
import 'home_page_list_service.dart';

/// 首页Tab列表数据提供者
/// 负责管理首页tabs和对应的音频列表数据，包括本地缓存策略
class HomeTabListDataProvider {
  static HomeTabListDataProvider? _instance;
  static HomeTabListDataProvider get instance {
    _instance ??= HomeTabListDataProvider._internal();
    return _instance!;
  }

  HomeTabListDataProvider._internal();

  // 缓存键名
  static const String _tabsCacheKey = 'home_tabs_cache';
  static const String _tabListCachePrefix = 'home_tab_list_';

  // 本地存储实例
  SharedPreferences? _prefs;
  
  // 内存缓存
  List<TabItemModel> _cachedTabs = [];
  final Map<String, List<AudioItem>> _cachedTabLists = {};
  
  // 首页列表数据管理服务
  final HomePageListService _listService = HomePageListService();
  
  // 初始化状态
  bool _isInitialized = false;
  bool _isInitializing = false;

  /// 初始化数据提供者
  Future<void> initialize() async {
    if (_isInitialized || _isInitializing) return;
    
    _isInitializing = true;
    
    try {
      debugPrint('🏠 [DATA_PROVIDER] 开始初始化HomeTabListDataProvider');
      
      // 初始化SharedPreferences
      _prefs = await SharedPreferences.getInstance();
      
      // 初始化列表服务
      await _listService.initialize();
      
      // 尝试从本地存储加载缓存数据
      await _loadCachedData();
      
      // 如果没有缓存数据，从API获取
      if (_cachedTabs.isEmpty) {
        debugPrint('🏠 [DATA_PROVIDER] 没有缓存数据，从API获取');
        await _fetchAndCacheInitialData();
      } else {
        debugPrint('🏠 [DATA_PROVIDER] 使用缓存数据，后台更新');
        // 有缓存数据时，后台更新tabs数据
        _updateTabsInBackground();
      }
      
      _isInitialized = true;
      debugPrint('🏠 [DATA_PROVIDER] HomeTabListDataProvider初始化完成');
    } catch (e) {
      debugPrint('🏠 [DATA_PROVIDER] 初始化失败: $e');
      rethrow;
    } finally {
      _isInitializing = false;
    }
  }

  /// 从本地存储加载缓存数据
  Future<void> _loadCachedData() async {
    try {
      // 加载tabs缓存
      final tabsJson = _prefs?.getString(_tabsCacheKey);
      if (tabsJson != null) {
        final List<dynamic> tabsData = json.decode(tabsJson);
        _cachedTabs = tabsData
            .map((tab) => TabItemModel.fromMap(tab as Map<String, dynamic>))
            .toList();
        debugPrint('🏠 [DATA_PROVIDER] 加载了${_cachedTabs.length}个缓存tabs');
        
        // 加载每个tab的列表数据缓存
        for (final tab in _cachedTabs) {
          final listJson = _prefs?.getString('$_tabListCachePrefix${tab.id}');
          if (listJson != null) {
            final List<dynamic> listData = json.decode(listJson);
            _cachedTabLists[tab.id] = listData
                .map((item) => AudioItem.fromMap(item as Map<String, dynamic>))
                .toList();

            
            debugPrint('🏠 [DATA_PROVIDER] 加载了tab ${tab.id} 的${_cachedTabLists[tab.id]!.length}条缓存数据, 第一条item tags: ${_cachedTabLists[tab.id]!.first.tags}');
          }
        }
      }
    } catch (e) {
      debugPrint('🏠 [DATA_PROVIDER] 加载缓存数据失败: $e');
      // 清空可能损坏的缓存
      _cachedTabs.clear();
      _cachedTabLists.clear();
    }
  }

  /// 获取初始数据并缓存
  Future<void> _fetchAndCacheInitialData() async {
    try {
      final tabs = await HomeTabsService.getHomeTabs();
      _cachedTabs = tabs;
      
      // 缓存tabs数据
      await _cacheTabsData(tabs);
      
      // 如果API返回了items数据，也进行缓存
      for (final tab in tabs) {
        if (tab.items.isNotEmpty) {
          _cachedTabLists[tab.id] = tab.items;
          await _cacheTabListData(tab.id, tab.items);
        }
      }
      
      debugPrint('🏠 [DATA_PROVIDER] 初始数据获取并缓存完成');
    } catch (e) {
      debugPrint('🏠 [DATA_PROVIDER] 获取初始数据失败: $e');
      rethrow;
    }
  }

  /// 后台更新tabs数据
  Future<void> _updateTabsInBackground() async {
    try {
      final latestTabs = await HomeTabsService.getHomeTabs();
      
      // 对比新旧tabs，保留已有数据的tab列表
      final Map<String, List<AudioItem>> preservedLists = {};
      
      for (final newTab in latestTabs) {
        // 如果新tab在旧tabs中存在且有缓存数据，保留缓存数据
        if (_cachedTabLists.containsKey(newTab.id)) {
          preservedLists[newTab.id] = _cachedTabLists[newTab.id]!;
        } else if (newTab.items.isNotEmpty) {
          // 全新的tab，使用API返回的数据
          preservedLists[newTab.id] = newTab.items;
          await _cacheTabListData(newTab.id, newTab.items);
        }
      }
      
      // 更新内存缓存
      _cachedTabs = latestTabs;
      _cachedTabLists.clear();
      _cachedTabLists.addAll(preservedLists);
      
      // 只缓存tabs数据（根据需求4）
      await _cacheTabsData(latestTabs);
      
      debugPrint('🏠 [DATA_PROVIDER] 后台更新tabs完成');
    } catch (e) {
      debugPrint('🏠 [DATA_PROVIDER] 后台更新tabs失败: $e');
    }
  }

  /// 缓存tabs数据到本地存储
  Future<void> _cacheTabsData(List<TabItemModel> tabs) async {
    try {
      final tabsJson = json.encode(tabs.map((tab) => tab.toMap()).toList());
      await _prefs?.setString(_tabsCacheKey, tabsJson);
      debugPrint('🏠 [DATA_PROVIDER] tabs数据已缓存');
    } catch (e) {
      debugPrint('🏠 [DATA_PROVIDER] 缓存tabs数据失败: $e');
    }
  }

  /// 缓存指定tab的列表数据到本地存储
  Future<void> _cacheTabListData(String tabId, List<AudioItem> items) async {
    try {
      final listJson = json.encode(items.map((item) => item.toMap()).toList());
      await _prefs?.setString('$_tabListCachePrefix$tabId', listJson);
      debugPrint('🏠 [DATA_PROVIDER] tab $tabId 的列表数据已缓存，共${items.length}条, 第一条item tags: ${items.first.tags}');
    } catch (e) {
      debugPrint('🏠 [DATA_PROVIDER] 缓存tab $tabId 列表数据失败: $e');
    }
  }

  /// 获取tabs列表
  List<TabItemModel> getTabs() {
    return List.from(_cachedTabs);
  }

  /// 获取指定tab的列表数据
  List<AudioItem> getTabListData(String tabId) {
    return List.from(_cachedTabLists[tabId] ?? []);
  }

  /// 初始化音频数据
  Future<List<AudioItem>> initAudioData({String? tag}) async {
    try {
      debugPrint('🏠 [DATA_PROVIDER] 初始化音频数据: tag=$tag');
      
      final tabId = tag ?? 'for_you';
      
      // 检查缓存数据
      final cachedData = getTabListData(tabId);
      if (cachedData.isNotEmpty) {
        debugPrint('🏠 [DATA_PROVIDER] 使用缓存数据: ${cachedData.length} 条');
        return cachedData;
      }
      
      // 如果没有缓存数据，通过列表服务获取
      debugPrint('🏠 [DATA_PROVIDER] 缓存为空，通过列表服务获取新数据');
      final newData = await _listService.fetchNextPageData(tabId);
      
      // 更新缓存
      await _updateTabListCache(tabId, newData);
      
      return newData;
    } catch (error) {
      debugPrint('🏠 [DATA_PROVIDER] 初始化数据失败: $error');
      rethrow;
    }
  }

  /// 刷新音频数据
  Future<List<AudioItem>> refreshAudioData({String? tag}) async {
    try {
      debugPrint('🏠 [DATA_PROVIDER] 刷新音频数据: tag=$tag');
      
      final tabId = tag ?? 'for_you';
      
      // 获取当前缓存的数据，用于传递给getTabLastCid
      final currentData = getTabListData(tabId);
      
      // 调用列表服务获取更多数据，传递当前数据
      final newData = await _listService.fetchNextPageDataWithCurrentData(tabId, currentData);
      
      // 更新缓存（刷新时替换所有数据）
      await _updateTabListCache(tabId, newData);
      
      return newData;
    } catch (error) {
      debugPrint('🏠 [DATA_PROVIDER] 刷新数据失败: $error');
      rethrow;
    }
  }

  /// 加载更多音频数据
  Future<List<AudioItem>> loadMoreAudioData({
    String? tag,
    String? pageKey,
    int? count,
  }) async {
    try {
      debugPrint('🏠 [DATA_PROVIDER] 加载更多音频数据: tag=$tag, pageKey=$pageKey, count=$count');
      
      final tabId = tag ?? 'for_you';
      
      // 获取当前缓存的数据，用于传递给getTabLastCid
      final currentData = getTabListData(tabId);
      
      // 调用列表服务获取更多数据，传递当前数据
      final newData = await _listService.fetchNextPageDataWithCurrentData(tabId, currentData);
      
      // 将新数据追加到现有缓存中
      final existingData = getTabListData(tabId);
      final combinedData = [...existingData, ...newData];
      await _updateTabListCache(tabId, combinedData);
      
      return newData;
    } catch (error) {
      debugPrint('🏠 [DATA_PROVIDER] 加载更多数据失败: $error');
      rethrow;
    }
  }

  /// 更新指定tab的列表缓存
  Future<void> _updateTabListCache(String tabId, List<AudioItem> newData) async {
    // 清空当前tab的缓存
    _cachedTabLists[tabId] = newData;
    
    // 缓存到本地存储
    await _cacheTabListData(tabId, newData);
    
    debugPrint('🏠 [DATA_PROVIDER] 已更新tab $tabId 的缓存数据，共${newData.length}条');
  }

  /// 预加载指定tab的数据
  Future<void> preloadTabData(String tabId) async {
    try {
      // 检查是否已有缓存数据
      if (_cachedTabLists.containsKey(tabId) && _cachedTabLists[tabId]!.isNotEmpty) {
        debugPrint('🏠 [DATA_PROVIDER] tab $tabId 已有缓存数据，跳过预加载');
        return;
      }
      
      debugPrint('🏠 [DATA_PROVIDER] 预加载tab $tabId 数据');
      await _listService.preloadTabData(tabId);
    } catch (e) {
      debugPrint('🏠 [DATA_PROVIDER] 预加载tab $tabId 数据失败: $e');
    }
  }

  /// 获取服务状态信息（用于调试）
  Map<String, dynamic> getServiceStatus() {
    return {
      'isInitialized': _isInitialized,
      'isInitializing': _isInitializing,
      'cachedTabsCount': _cachedTabs.length,
      'cachedTabListsCount': _cachedTabLists.length,
      'listServiceStatus': _listService.getServiceStatus(),
    };
  }

  /// 获取所有tabs的缓存状态
  Map<String, Map<String, dynamic>> getAllTabsStatus() {
    final Map<String, Map<String, dynamic>> status = {};
    
    for (final tab in _cachedTabs) {
      status[tab.id] = {
        'label': tab.label,
        'cachedItemsCount': _cachedTabLists[tab.id]?.length ?? 0,
        'listServiceStatus': _listService.getAllTabsStatus()[tab.id],
      };
    }
    
    return status;
  }

  /// 清理资源
  Future<void> dispose() async {
    _cachedTabs.clear();
    _cachedTabLists.clear();
    _isInitialized = false;
    _isInitializing = false;
    debugPrint('🏠 [DATA_PROVIDER] HomeTabListDataProvider已清理');
  }
}