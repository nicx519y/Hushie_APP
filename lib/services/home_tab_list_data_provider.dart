import 'dart:async';
import 'package:flutter/material.dart';
import '../models/audio_item.dart';
import '../models/tab_item.dart';
import 'home_page_list_service.dart';

/// 首页Tab列表数据提供者
/// 
/// 职责：
/// - 提供统一的数据访问接口
/// - 将具体的业务逻辑委托给 HomePageListService
/// - 为 UI 层提供简洁的数据访问方式
class HomeTabListDataProvider {
  static HomeTabListDataProvider? _instance;
  static HomeTabListDataProvider get instance {
    _instance ??= HomeTabListDataProvider._internal();
    return _instance!;
  }

  HomeTabListDataProvider._internal();

  // 主要业务逻辑服务
  final HomePageListService _listService = HomePageListService();

  // 初始化状态
  bool _isInitialized = false;

  /// 初始化数据提供者
  Future<void> initialize() async {
    if (_isInitialized) return;
    
    try {
      debugPrint('🏠 [DATA_PROVIDER] 开始初始化 HomeTabListDataProvider');
      
      // 初始化底层服务
      await _listService.initialize();
      
      _isInitialized = true;
      debugPrint('🏠 [DATA_PROVIDER] HomeTabListDataProvider 初始化完成');
    } catch (e) {
      debugPrint('🏠 [DATA_PROVIDER] 初始化失败: $e');
      rethrow;
    }
  }

  /// 获取 Tabs 流（用于 UI 订阅）
  Stream<List<TabItemModel>> get tabsStream => _listService.tabsStream;

  /// 获取 Tabs 列表
  List<TabItemModel> getTabs() {
    _ensureInitialized();
    return _listService.getTabs();
  }

  /// 获取指定 Tab 的列表数据
  List<AudioItem> getTabListData(String tabId) {
    _ensureInitialized();
    return _listService.getTabData(tabId);
  }

  /// 初始化音频数据
  Future<List<AudioItem>> initAudioData({String? tag}) async {
    _ensureInitialized();
    
    try {
      final tabId = tag ?? 'for_you';
      debugPrint('🏠 [DATA_PROVIDER] 初始化音频数据: tag=$tag');
      
      return await _listService.initTabAudioData(tabId);
    } catch (error) {
      debugPrint('🏠 [DATA_PROVIDER] 初始化数据失败: $error');
      rethrow;
    }
  }

  /// 刷新音频数据
  Future<List<AudioItem>> refreshAudioData({String? tag}) async {
    _ensureInitialized();
    
    try {
      final tabId = tag ?? 'for_you';
      debugPrint('🏠 [DATA_PROVIDER] 刷新音频数据: tag=$tag');
      
      return await _listService.refreshTabAudioData(tabId);
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
    _ensureInitialized();
    
    try {
      final tabId = tag ?? 'for_you';
      debugPrint('🏠 [DATA_PROVIDER] 加载更多音频数据: tag=$tag, pageKey=$pageKey, count=$count');
      
      return await _listService.loadMoreTabAudioData(tabId);
    } catch (error) {
      debugPrint('🏠 [DATA_PROVIDER] 加载更多数据失败: $error');
      rethrow;
    }
  }

  /// 预加载指定 Tab 的数据
  Future<void> preloadTabData(String tabId) async {
    _ensureInitialized();
    
    try {
      debugPrint('🏠 [DATA_PROVIDER] 预加载 Tab $tabId 数据');
      
      // 检查是否已有缓存数据
      final cachedData = _listService.getTabData(tabId);
      if (cachedData.isNotEmpty) {
        debugPrint('🏠 [DATA_PROVIDER] Tab $tabId 已有缓存数据，跳过预加载');
        return;
      }
      
      // 初始化数据
      await _listService.initTabAudioData(tabId);
    } catch (e) {
      debugPrint('🏠 [DATA_PROVIDER] 预加载 Tab $tabId 数据失败: $e');
    }
  }

  /// 获取服务状态信息（用于调试）
  Map<String, dynamic> getServiceStatus() {
    return {
      'isInitialized': _isInitialized,
      'listServiceStatus': _listService.getServiceStatus(),
    };
  }

  /// 获取所有 Tabs 的缓存状态
  Map<String, Map<String, dynamic>> getAllTabsStatus() {
    _ensureInitialized();
    
    final Map<String, Map<String, dynamic>> status = {};
    final tabs = _listService.getTabs();
    
    for (final tab in tabs) {
      final cachedData = _listService.getTabData(tab.id);
      status[tab.id] = {
        'label': tab.label,
        'cachedItemsCount': cachedData.length,
      };
    }
    
    return status;
  }

  /// 确保服务已初始化
  void _ensureInitialized() {
    if (!_isInitialized) {
      throw StateError('HomeTabListDataProvider failure.');
    }
  }

  /// 清理资源
  Future<void> dispose() async {
    _isInitialized = false;
    await _listService.dispose();
    debugPrint('🏠 [DATA_PROVIDER] HomeTabListDataProvider 已清理');
  }
}