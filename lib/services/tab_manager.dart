import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/tab_item.dart';
import 'api_service.dart';

class TabManager {
  static TabManager? _instance;
  static TabManager get instance => _instance ??= TabManager._internal();

  TabManager._internal();

  // 本地存储的 key
  static const String _storageKey = 'home_tabs';
  static const String _lastUpdateKey = 'home_tabs_last_update';

  // 缓存过期时间（24小时）
  static const Duration _cacheExpiry = Duration(hours: 24);

  // 默认的 "For You" tab
  static const TabItem _defaultForYouTab = TabItem(
    id: 'for_you',
    title: 'For You',
    tag: null,
    isDefault: true,
    order: 0,
    isEnabled: true,
  );

  // 获取所有 tabs（包括固定的 "For You" 和动态获取的）
  Future<List<TabItem>> getAllTabs() async {
    try {
      // 首先尝试从本地存储获取
      final cachedTabs = await _getCachedTabs();

      // 如果有缓存且未过期，直接返回
      if (cachedTabs.isNotEmpty && !(await _isCacheExpired())) {
        print('使用缓存的 tabs: ${cachedTabs.length} 个');
        return _combineWithDefaultTab(cachedTabs);
      }

      // 缓存过期或为空，从服务器获取
      print('缓存过期或为空，从服务器获取 tabs');
      final serverTabs = await _fetchTabsFromServer();

      if (serverTabs.isNotEmpty) {
        // 保存到本地存储
        await _saveTabsToCache(serverTabs);
        return _combineWithDefaultTab(serverTabs);
      } else {
        // 服务器获取失败，尝试使用缓存（即使过期）
        if (cachedTabs.isNotEmpty) {
          print('服务器获取失败，使用过期缓存');
          return _combineWithDefaultTab(cachedTabs);
        }

        // 都没有，返回默认 tabs
        print('使用默认 tabs');
        return _getDefaultTabs();
      }
    } catch (e) {
      print('获取 tabs 失败: $e');
      // 出错时返回默认 tabs
      return _getDefaultTabs();
    }
  }

  // 强制刷新 tabs（忽略缓存）
  Future<List<TabItem>> refreshTabs() async {
    try {
      print('强制刷新 tabs');
      final serverTabs = await _fetchTabsFromServer();

      if (serverTabs.isNotEmpty) {
        await _saveTabsToCache(serverTabs);
        return _combineWithDefaultTab(serverTabs);
      } else {
        // 刷新失败，返回当前缓存的 tabs
        final cachedTabs = await _getCachedTabs();
        return _combineWithDefaultTab(cachedTabs);
      }
    } catch (e) {
      print('刷新 tabs 失败: $e');
      final cachedTabs = await _getCachedTabs();
      return _combineWithDefaultTab(cachedTabs);
    }
  }

  // 从服务器获取 tabs
  Future<List<TabItem>> _fetchTabsFromServer() async {
    try {
      final response = await ApiService.getHomeTabs();

      if (response.success && response.data != null) {
        return response.data!;
      } else {
        print('服务器返回错误: ${response.message}');
        return [];
      }
    } catch (e) {
      print('网络请求失败: $e');
      return [];
    }
  }

  // 从本地存储获取缓存的 tabs
  Future<List<TabItem>> _getCachedTabs() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final tabsJson = prefs.getString(_storageKey);

      if (tabsJson != null) {
        final List<dynamic> tabsList = json.decode(tabsJson);
        return tabsList.map((item) => TabItem.fromMap(item)).toList();
      }

      return [];
    } catch (e) {
      print('读取缓存 tabs 失败: $e');
      return [];
    }
  }

  // 保存 tabs 到本地存储
  Future<void> _saveTabsToCache(List<TabItem> tabs) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final tabsJson = json.encode(tabs.map((tab) => tab.toMap()).toList());

      await prefs.setString(_storageKey, tabsJson);
      await prefs.setString(_lastUpdateKey, DateTime.now().toIso8601String());

      print('已保存 ${tabs.length} 个 tabs 到本地存储');
    } catch (e) {
      print('保存 tabs 到缓存失败: $e');
    }
  }

  // 检查缓存是否过期
  Future<bool> _isCacheExpired() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final lastUpdateStr = prefs.getString(_lastUpdateKey);

      if (lastUpdateStr == null) return true;

      final lastUpdate = DateTime.parse(lastUpdateStr);
      final now = DateTime.now();

      return now.difference(lastUpdate) > _cacheExpiry;
    } catch (e) {
      print('检查缓存过期时间失败: $e');
      return true; // 出错时认为过期
    }
  }

  // 将动态 tabs 与默认的 "For You" tab 合并
  List<TabItem> _combineWithDefaultTab(List<TabItem> dynamicTabs) {
    final allTabs = <TabItem>[_defaultForYouTab];

    // 添加动态 tabs，按 order 排序
    final sortedDynamicTabs = List<TabItem>.from(dynamicTabs)
      ..sort((a, b) => a.order.compareTo(b.order));

    allTabs.addAll(sortedDynamicTabs);

    return allTabs;
  }

  // 获取默认 tabs（当所有方法都失败时的兜底方案）
  List<TabItem> _getDefaultTabs() {
    return [
      _defaultForYouTab,
      const TabItem(id: 'mf', title: 'M/F', tag: 'M/F', order: 1),
      const TabItem(id: 'fm', title: 'F/M', tag: 'F/M', order: 2),
      const TabItem(id: 'asmr', title: 'ASMR', tag: 'ASMR', order: 3),
      const TabItem(id: 'nsfw', title: 'NSFW', tag: 'NSFW', order: 4),
    ];
  }

  // 根据 tab 获取对应的标签（用于 API 请求）
  String? getTagForTab(String tabId) {
    if (tabId == 'for_you') return null;

    // 这里可以根据 tabId 返回对应的标签
    // 或者从缓存的 tabs 中查找
    switch (tabId) {
      case 'mf':
        return 'M/F';
      case 'fm':
        return 'F/M';
      case 'asmr':
        return 'ASMR';
      case 'nsfw':
        return 'NSFW';
      default:
        return null;
    }
  }

  // 清除本地缓存
  Future<void> clearCache() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_storageKey);
      await prefs.remove(_lastUpdateKey);
      print('已清除 tabs 缓存');
    } catch (e) {
      print('清除缓存失败: $e');
    }
  }
}
