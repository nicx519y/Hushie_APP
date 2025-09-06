import 'package:flutter/material.dart';
import '../components/custom_app_bar.dart';
import '../components/custom_tab_bar.dart';
import '../components/paged_audio_grid.dart';
import '../models/audio_item.dart';
import '../models/tab_item.dart';
import '../services/audio_manager.dart';
import '../services/tab_manager.dart';
import '../services/home_page_list_service.dart';

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

  // 首页列表数据管理服务
  final HomePageListService _listService = HomePageListService();

  @override
  void initState() {
    print('🏠 [HOME_PAGE] HomePage initState开始');
    super.initState();
    print('🏠 [HOME_PAGE] 开始初始化tabs');
    _initTabs();
    print('🏠 [HOME_PAGE] 开始初始化列表服务');
    _initListService();
    print('🏠 [HOME_PAGE] HomePage initState完成');
  }

  @override
  void dispose() {
    _tabController.dispose();
    _pageController.dispose();
    super.dispose();
  }

  void _initTabs() async {
    try {
      final tabs = await TabManager().getAllTabs();
      setState(() {
        _tabItems = tabs;
      });
      _setupControllers();
    } catch (e) {
      print('初始化tabs失败: $e');
      _initDefaultTabs();
    }
  }

  // 初始化列表服务
  Future<void> _initListService() async {
    try {
      await _listService.initialize();
      print('HomePageListService 初始化成功');

      // 预加载当前tab的数据
      if (_tabItems.isNotEmpty) {
        await _listService.preloadTabData(_tabItems[0].id);
      }

      // 打印初始状态
      _printServiceStatus();
    } catch (error) {
      print('HomePageListService 初始化失败: $error');
    }
  }

  void _initDefaultTabs() {
    setState(() {
      _tabItems = [const TabItemModel(id: 'for_you', label: 'For You')];
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

    print('Syncing PageView to tab: $tabIndex'); // 调试信息

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
      _listService.preloadTabData(tabId).catchError((error) {
        print('预加载Tab $tabId 数据失败: $error');
      });
    }
  }

  // 注意：不再需要_onTabChanged方法
  // Tab点击现在直接由TabController处理

  // 初始化数据获取方法
  Future<List<AudioItem>> _initAudioData({String? tag}) async {
    try {
      print('初始化音频数据: tag=$tag');

      // 使用HomePageListService获取数据
      final tabId = tag ?? 'for_you';

      // 检查缓存数据
      final cachedData = _listService.getTabData(tabId);
      if (cachedData.isNotEmpty) {
        print('使用缓存数据: ${cachedData.length} 条');
        return cachedData;
      }

      // 如果没有缓存数据，则获取新数据
      print('缓存为空，获取新数据');
      return await _listService.fetchNextPageData(tabId);
    } catch (error) {
      print('初始化数据失败: $error');
      rethrow;
    }
  }

  // 刷新数据获取方法（上拉刷新）
  Future<List<AudioItem>> _refreshAudioData({String? tag}) async {
    try {
      print('刷新音频数据: tag=$tag');

      // 使用HomePageListService刷新数据
      final tabId = tag ?? 'for_you';
      return await _listService.fetchNextPageData(tabId);
    } catch (error) {
      print('刷新数据失败: $error');
      rethrow;
    }
  }

  // 加载更多数据获取方法（下滑加载）
  Future<List<AudioItem>> _loadMoreAudioData({
    String? tag,
    String? pageKey,
    int? count,
  }) async {
    try {
      print('加载更多音频数据: tag=$tag, pageKey=$pageKey, count=$count');

      // 使用HomePageListService获取下一页数据
      final tabId = tag ?? 'for_you';
      return await _listService.fetchNextPageData(tabId);
    } catch (error) {
      print('加载更多数据失败: $error');
      rethrow;
    }
  }

  void _onPageChanged(int pageIndex) {
    if (_isUpdatingFromTab) return; // 如果是从Tab点击触发的，不处理PageView变化

    print('Page changed: $pageIndex, current: $_currentTabIndex'); // 调试信息

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

  // 获取服务状态信息（用于调试）
  Map<String, dynamic> _getServiceStatus() {
    return _listService.getServiceStatus();
  }

  // 获取所有tabs的缓存状态
  Map<String, Map<String, dynamic>> _getAllTabsStatus() {
    return _listService.getAllTabsStatus();
  }

  // 打印服务状态信息（用于调试）
  void _printServiceStatus() {
    final status = _getServiceStatus();
    final tabsStatus = _getAllTabsStatus();

    print('=== HomePageListService 状态 ===');
    print('服务状态: $status');
    print('Tabs状态: $tabsStatus');
    print('===============================');
  }

  void _onAudioTap(AudioItem item) {
    // 先开始播放音频，然后跳转到播放页面
    _playAudio(item);

    // 使用播放器页面的标准打开方式（包含上滑动画）
    NavigationUtils.navigateToAudioPlayer(context);
  }

  Future<void> _playAudio(AudioItem item) async {
    try {
      // 通过音频管理器播放指定 ID 的音频
      await AudioManager.instance.playAudio(item);
    } catch (e) {
      print('播放音频失败: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Column(
        children: [
          // 自定义顶部栏
          CustomAppBar(onSearchTap: _onSearchTap),
          // IconButton(
          //   onPressed: () {
          //     _initTabs();
          //   },
          //   icon: const Icon(Icons.refresh),
          // ),
          // Tab 栏
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

                      return PagedAudioGrid(
                        key: ValueKey('tab_$index'),
                        tag: tag,
                        initDataFetcher: _initAudioData,
                        refreshDataFetcher: _refreshAudioData,
                        loadMoreDataFetcher: _loadMoreAudioData,
                        onItemTap: _onAudioTap,
                      );
                    },
                  ),
          ),
          const SizedBox(height: 80),
        ],
      ),
    );
  }
}
