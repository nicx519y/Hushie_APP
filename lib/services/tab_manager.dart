import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/tab_item.dart';
import '../models/api_response.dart';
import 'api_service.dart';

/// Tab管理器
class TabManager {
  static const String _cacheKey = 'home_tabs_cache';
  static const Duration _cacheExpiry = Duration(hours: 1);

  // 默认的"为你推荐"tab
  static const TabItemModel _defaultForYouTab = TabItemModel(
    id: 'for_you',
    label: '为你推荐',
  );

  /// 获取所有tabs
  Future<List<TabItemModel>> getAllTabs() async {
    try {
      // 1. 尝试从缓存获取
      final cachedTabs = await _getCachedTabs();
      if (cachedTabs.isNotEmpty) {
        return cachedTabs;
      }

      // 2. 从服务器获取
      final serverTabs = await _fetchTabsFromServer();
      if (serverTabs.isNotEmpty) {
        // 保存到缓存
        await _saveTabsToCache(serverTabs);
        return serverTabs;
      }

      // 3. 使用默认tabs
      return _getDefaultTabs();
    } catch (e) {
      print('获取tabs失败: $e');
      return _getDefaultTabs();
    }
  }

  /// 刷新tabs
  Future<List<TabItemModel>> refreshTabs() async {
    try {
      // 清除缓存
      await _clearCache();

      // 从服务器获取最新数据
      final serverTabs = await _fetchTabsFromServer();
      if (serverTabs.isNotEmpty) {
        // 保存到缓存
        await _saveTabsToCache(serverTabs);
        return serverTabs;
      }

      // 如果服务器没有数据，使用默认tabs
      return _getDefaultTabs();
    } catch (e) {
      print('刷新tabs失败: $e');
      return _getDefaultTabs();
    }
  }

  /// 从服务器获取tabs
  Future<List<TabItemModel>> _fetchTabsFromServer() async {
    try {
      final response = await ApiService.getHomeTabs();
      if (response.errNo == 0 && response.data != null) {
        return response.data!;
      }
      return [];
    } catch (e) {
      print('从服务器获取tabs失败: $e');
      return [];
    }
  }

  /// 从缓存获取tabs
  Future<List<TabItemModel>> _getCachedTabs() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final cacheData = prefs.getString(_cacheKey);
      if (cacheData == null) return [];

      final Map<String, dynamic> cache = json.decode(cacheData);
      final timestamp = cache['timestamp'] as int?;
      final tabsList = cache['tabs'] as List<dynamic>?;

      if (timestamp == null || tabsList == null) return [];

      // 检查缓存是否过期
      final cacheTime = DateTime.fromMillisecondsSinceEpoch(timestamp);
      if (DateTime.now().difference(cacheTime) > _cacheExpiry) {
        return [];
      }

      return tabsList.map((item) => TabItemModel.fromMap(item)).toList();
    } catch (e) {
      print('从缓存获取tabs失败: $e');
      return [];
    }
  }

  /// 保存tabs到缓存
  Future<void> _saveTabsToCache(List<TabItemModel> tabs) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final cacheData = {
        'timestamp': DateTime.now().millisecondsSinceEpoch,
        'tabs': tabs.map((tab) => tab.toMap()).toList(),
      };

      await prefs.setString(_cacheKey, json.encode(cacheData));
    } catch (e) {
      print('保存tabs到缓存失败: $e');
    }
  }

  /// 清除缓存
  Future<void> _clearCache() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_cacheKey);
    } catch (e) {
      print('清除缓存失败: $e');
    }
  }

  /// 合并默认tab和动态tabs
  List<TabItemModel> _combineWithDefaultTab(List<TabItemModel> dynamicTabs) {
    final allTabs = <TabItemModel>[_defaultForYouTab];

    // 添加动态tabs
    allTabs.addAll(dynamicTabs);
    return allTabs;
  }

  /// 获取默认tabs
  List<TabItemModel> _getDefaultTabs() {
    return [
      const TabItemModel(id: 'mf', label: 'M/F'),
      const TabItemModel(id: 'fm', label: 'F/M'),
      const TabItemModel(id: 'asmr', label: 'ASMR'),
      const TabItemModel(id: 'nsfw', label: 'NSFW'),
    ];
  }
}
