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

  // Tabs更新通知（供UI订阅）
  final StreamController<List<TabItemModel>> _tabsStreamController =
      StreamController<List<TabItemModel>>.broadcast();
  Stream<List<TabItemModel>> get tabsStream => _tabsStreamController.stream;

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
      
      // 启动策略：
      // 1) 若本地缓存为空，先用第一个 for_you tab 和预埋数据渲染，再后台拉取服务器tabs并合并（仅填充空tab数据）
      // 2) 若本地缓存存在，直接返回缓存，再后台拉取服务器tabs并合并（仅填充空tab数据）
      if (_cachedTabs.isEmpty) {
        debugPrint('🏠 [DATA_PROVIDER] 没有缓存数据，先使用 for_you 预埋数据渲染');
        // 从列表服务获取预埋数据
        var seedItems = _listService.getTabData('for_you');
        if (seedItems.isEmpty) {
          // 兜底确保预埋数据写入
          await _listService.preloadTabData('for_you');
          seedItems = _listService.getTabData('for_you');
        }
        // 设置一个仅包含 for_you 的临时tabs用于首屏渲染
        _cachedTabs = [
          const TabItemModel(id: 'for_you', label: 'For You', items: []),
        ];
        _cachedTabLists['for_you'] = seedItems;
        debugPrint('🏠 [DATA_PROVIDER] 首屏渲染使用预埋数据: ${seedItems.length} 条');

        // 先写入本地缓存，确保预埋数据被持久化
        await _cacheTabsData(_cachedTabs);
        await _cacheTabListData('for_you', seedItems);

        // 通知UI：首屏tabs更新
        _tabsStreamController.add(List.from(_cachedTabs));

        // 后台拉取并合并服务器tabs
        _updateTabsInBackground();
      } else {
        debugPrint('🏠 [DATA_PROVIDER] 使用缓存数据，后台更新');
        // 通知UI：使用缓存的tabs
        _tabsStreamController.add(List.from(_cachedTabs));
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
      
      // 如果API返回了items数据，仅填充“空的tab数据”，不覆盖已有缓存
      for (final tab in tabs) {
        final existing = _cachedTabLists[tab.id] ?? [];
        if (existing.isNotEmpty) {
          debugPrint('🏠 [DATA_PROVIDER] 保留已有tab ${tab.id} 的${existing.length}条数据，不覆盖');
          continue;
        }
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
      
      // 合并规则：替换tabs；每个tab下如果已有数据（非空），不覆盖；仅覆盖空的tab数据
      final Map<String, List<AudioItem>> mergedLists = {};
      for (final newTab in latestTabs) {
        final existing = _cachedTabLists[newTab.id] ?? [];
        if (existing.isNotEmpty) {
          mergedLists[newTab.id] = existing;
        } else if (newTab.items.isNotEmpty) {
          mergedLists[newTab.id] = newTab.items;
          await _cacheTabListData(newTab.id, newTab.items);
        } else {
          mergedLists[newTab.id] = [];
        }
      }

      // 替换tabs并更新列表缓存
      _cachedTabs = latestTabs;
      _cachedTabLists
        ..clear()
        ..addAll(mergedLists);
      
      // 只缓存tabs数据（根据需求4）
      await _cacheTabsData(latestTabs);
      
      debugPrint('🏠 [DATA_PROVIDER] 后台更新tabs完成');

      // 通知UI：后台更新后的tabs
      _tabsStreamController.add(List.from(_cachedTabs));
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
      
      // 将新数据追加到现有内存缓存中（用于返回给UI）
      final existingData = getTabListData(tabId);
      final combinedData = [...existingData, ...newData];
      _cachedTabLists[tabId] = combinedData;
      
      // 本地存储只保留最新数据，抛弃旧数据
      await _cacheTabListData(tabId, newData);
      
      debugPrint('🏠 [DATA_PROVIDER] 内存缓存已更新为${combinedData.length}条数据，本地存储只保留最新${newData.length}条数据');
      
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
    await _tabsStreamController.close();
    debugPrint('🏠 [DATA_PROVIDER] HomeTabListDataProvider已清理');
  }
}