import 'package:flutter/material.dart';
import 'dart:async';
import '../components/custom_app_bar.dart';
import '../components/custom_tab_bar.dart';
import '../components/paged_audio_grid.dart';
import '../models/audio_item.dart';
import '../models/tab_item.dart';
import '../services/audio_manager.dart';
import '../services/home_tab_list_data_provider.dart';
import '../services/analytics_service.dart';

import '../router/navigation_utils.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> with TickerProviderStateMixin {
  // Tab 相关
  List<TabItemModel> _tabItems = [];
  late TabController _tabController;
  late PageController _pageController;
  int _currentTabIndex = 0;
  bool _isUpdatingFromTab = false; // 防止循环调用的标志

  // 首页Tab列表数据提供者
  final HomeTabListDataProvider _dataProvider = HomeTabListDataProvider.instance;
  StreamSubscription<List<TabItemModel>>? _tabsSubscription;

  @override
  void initState() {
    debugPrint('🏠 [HOME_PAGE] HomePage initState开始');
    super.initState();
    debugPrint('🏠 [HOME_PAGE] 开始初始化tabs');
    _initTabs();
    debugPrint('🏠 [HOME_PAGE] 开始初始化列表服务');
    _initListService();
    debugPrint('🏠 [HOME_PAGE] HomePage initState完成');
  }

  @override
  void dispose() {
    _tabsSubscription?.cancel();
    _tabController.dispose();
    _pageController.dispose();
    super.dispose();
  }

  void _initTabs() async {
    try {
      // 初始化数据提供者
      await _dataProvider.initialize();
      
      // 获取tabs数据
      final tabs = _dataProvider.getTabs();
      setState(() {
        _tabItems = tabs;
      });
      _setupControllers();
      // 订阅tabs更新（后台拉取完成后通知UI刷新）
      _tabsSubscription = _dataProvider.tabsStream.listen((updatedTabs) {
        if (!mounted) return;
        bool needRebuild = updatedTabs.length != _tabItems.length;
        if (!needRebuild) {
          for (int i = 0; i < updatedTabs.length; i++) {
            if (updatedTabs[i].id != _tabItems[i].id) {
              needRebuild = true;
              break;
            }
          }
        }

        setState(() {
          _tabItems = updatedTabs;
        });

        if (needRebuild) {
          try { _tabController.dispose(); } catch (_) {}
          try { _pageController.dispose(); } catch (_) {}
          _setupControllers();
        }
      });
    } catch (e) {
      debugPrint('初始化tabs失败: $e');
      _initDefaultTabs();
    }
  }

  // 初始化列表服务（现在由数据提供者统一管理）
  Future<void> _initListService() async {
    try {
      // 数据提供者已在_initTabs中初始化
      debugPrint('数据提供者初始化完成');

      // 预加载当前tab的数据
      if (_tabItems.isNotEmpty) {
        await _dataProvider.preloadTabData(_tabItems[0].id);
      }

    } catch (error) {
      debugPrint('数据提供者初始化失败: $error');
    }
  }

  void _initDefaultTabs() {
    setState(() {
      _tabItems = [const TabItemModel(id: 'for_you', label: 'For You', items: [])];
    });
    _setupControllers();
  }

  void _setupControllers() {
    _tabController = TabController(length: _tabItems.length, vsync: this);
    _pageController = PageController(initialPage: 0);
  }

  // 同步PageView到指定的Tab索引
  void _syncPageViewToTab(int tabIndex) {
    if (_isUpdatingFromTab) return; // 防止循环调用

    debugPrint('Syncing PageView to tab: $tabIndex'); // 调试信息

    // 记录 Tab 点击事件
    if (tabIndex >= 0 && tabIndex < _tabItems.length) {
      final tabName = _tabItems[tabIndex].label;
      AnalyticsService().logCustomEvent(
        eventName: 'tab_tap',
        parameters: {
          'tab_name': tabName,
        },
      );
    }

    _isUpdatingFromTab = true;

    setState(() {
      _currentTabIndex = tabIndex;
    });

    // 同步PageView到当前tab
    if (_pageController.hasClients &&
        _pageController.page?.round() != tabIndex) {
      _pageController.animateToPage(
        tabIndex,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
    }

    // 移除预加载逻辑，让 _onPageChanged 统一处理
    // _preloadTabData(tabIndex);

    // 延迟重置标志，确保动画完成后再允许新的调用
    Future.delayed(const Duration(milliseconds: 350), () {
      _isUpdatingFromTab = false;
    });
  }

  // 预加载指定tab的数据
  void _preloadTabData(int tabIndex) {
    if (tabIndex < _tabItems.length) {
      final tabId = _tabItems[tabIndex].id;
      _dataProvider.preloadTabData(tabId).catchError((error) {
        debugPrint('预加载Tab $tabId 数据失败: $error');
      });
    }
  }

  void _onPageChanged(int pageIndex) {
    if (_isUpdatingFromTab) return; // 如果是从Tab点击触发的，不处理PageView变化

    debugPrint('Page changed: $pageIndex, current: $_currentTabIndex'); // 调试信息

    setState(() {
      _currentTabIndex = pageIndex;
    });

    // 同步TabController到当前页面（仅在手动滑动PageView时）
    if (_tabController.index != pageIndex) {
      _tabController.animateTo(pageIndex);
    }

    // 预加载新页面的数据（统一的数据加载入口）
    _preloadTabData(pageIndex);
  }

  void _onSearchTap() {
    NavigationUtils.navigateToSearch(context);
  }

  void _onAudioTap(AudioItem item) {
    // 先开始播放音频，然后跳转到播放页面
    debugPrint('点击音频: ${item.title} ${item.id}');
  
    // 记录首页音频点击事件
    final currentTabName = (_currentTabIndex >= 0 && _currentTabIndex < _tabItems.length)
        ? _tabItems[_currentTabIndex].label
        : 'for_you';
    AnalyticsService().logCustomEvent(
      eventName: 'homepage_audio_tap',
      parameters: {
        'current_tab_name': currentTabName,
        'audio_id': item.id,
      },
    );
    
    _playAudio(item);

    // 使用播放器页面的标准打开方式（包含上滑动画）
    NavigationUtils.navigateToAudioPlayer(context, initialAudio: item);
  }

  Future<void> _playAudio(AudioItem item) async {
  try {
      // 通过音频管理器播放指定 ID 的音频
      await AudioManager.instance.playAudio(item);
    } catch (e) {
      debugPrint('播放音频失败: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Column(
        children: [
          // 自定义顶部栏
          CustomAppBar(onSearchTap: _onSearchTap, hintText: 'Search Creation'),
          
          if (_tabItems.isNotEmpty)
            CustomTabBar(
              tabItems: _tabItems,
              controller: _tabController,
              onTabChanged: _syncPageViewToTab,
              // 移除onTabChanged回调，让TabController自己处理点击
            ),
          const SizedBox(height: 10),
          // 主内容区域
          Expanded(
            child: _tabItems.isEmpty
                ? const Center(child: CircularProgressIndicator())
                : PageView.builder(
                    controller: _pageController,
                    onPageChanged: _onPageChanged,
                    itemCount: _tabItems.length,
                    itemBuilder: (context, index) {
                      final tabItem = _tabItems[index];
                      final tag = tabItem.id != 'for_you' ? tabItem.id : null;

                      return RepaintBoundary(
                        child: PagedAudioGrid(
                          key: ValueKey('tab_$index'),
                          tag: tag,
                          initDataFetcher: _dataProvider.initAudioData,
                          refreshDataFetcher: _dataProvider.refreshAudioData,
                          loadMoreDataFetcher: _dataProvider.loadMoreAudioData,
                          onItemTap: _onAudioTap,
                        ),
                      );
                    },
                  ),
          ),
          const SizedBox(height: 55),
        ],
      ),
    );
  }
}
