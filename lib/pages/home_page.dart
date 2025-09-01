import 'package:flutter/material.dart';
import '../components/custom_app_bar.dart';
import '../components/custom_tab_bar.dart';
import '../components/paged_audio_grid.dart';
import '../models/audio_item.dart';
import '../models/tab_item.dart';
import '../services/audio_manager.dart';
import '../services/tab_manager.dart';
import 'search_page.dart';
import 'audio_player_page.dart';

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

  @override
  void initState() {
    super.initState();
    _initTabs();
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

  void _initDefaultTabs() {
    setState(() {
      _tabItems = [
        const TabItemModel(id: 'for_you', label: '为你推荐'),
        const TabItemModel(id: 'mf', label: 'M/F'),
        const TabItemModel(id: 'fm', label: 'F/M'),
        const TabItemModel(id: 'asmr', label: 'ASMR'),
        const TabItemModel(id: 'nsfw', label: 'NSFW'),
      ];
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

    // 延迟重置标志，确保动画完成后再允许新的调用
    Future.delayed(const Duration(milliseconds: 350), () {
      _isUpdatingFromTab = false;
    });
  }

  // 注意：不再需要_onTabChanged方法
  // Tab点击现在直接由TabController处理

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
  }

  void _onSearchTap() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const SearchPage()),
    );
  }

  void _onAudioTap(AudioItem item) {
    // 先开始播放音频，然后跳转到播放页面
    _playAudioById(item.id);

    // 使用播放器页面的标准打开方式（包含上滑动画）
    AudioPlayerPage.show(context);
  }

  Future<void> _playAudioById(String audioId) async {
    try {
      // 通过音频管理器播放指定 ID 的音频
      final success = await AudioManager.instance.playAudioById(audioId);

      if (!success) {
        // 播放失败，显示错误提示
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('播放失败：音频不存在或加载错误'),
              duration: Duration(seconds: 2),
            ),
          );
        }
      }
    } catch (e) {
      print('播放音频失败: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('播放失败：发生未知错误'),
            duration: Duration(seconds: 2),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Column(
        children: [
          // 自定义顶部栏
          CustomAppBar(onSearchTap: _onSearchTap),
          // Tab 栏
          if (_tabItems.isNotEmpty)
            CustomTabBar(
              tabItems: _tabItems,
              controller: _tabController,
              onTabChanged: _syncPageViewToTab,
              // 移除onTabChanged回调，让TabController自己处理点击
            ),
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
