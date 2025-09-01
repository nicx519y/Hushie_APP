import 'package:flutter/material.dart';
import '../components/custom_app_bar.dart';
import '../components/custom_tab_bar.dart';
import '../components/audio_grid.dart';
import '../models/audio_item.dart';
import '../models/tab_item.dart';
import '../services/api_service.dart';
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
  @override
  void dispose() {
    _tabController.dispose();
    _pageController.dispose();
    super.dispose();
  }

  final String _searchQuery = '';
  final int _pageSize = 10;

  // Tab 相关
  List<TabItemModel> _tabItems = [];
  late TabController _tabController;
  late PageController _pageController;
  int _currentTabIndex = 0;
  bool _isLoading = false;
  bool _isRefreshing = false;
  List<AudioItem> _audioItems = [];
  bool _hasMoreData = true;
  String? _lastAudioId;
  int _currentPage = 1;

  // 每个Tab的数据状态
  final Map<int, List<AudioItem>> _tabData = {};
  final Map<int, bool> _tabLoading = {};
  final Map<int, String?> _tabErrors = {};
  final Map<int, int> _tabPages = {};
  final Map<int, bool> _tabHasMore = {};

  @override
  void initState() {
    super.initState();
    _initTabs();
  }

  void _initTabs() async {
    try {
      final tabs = await TabManager().getAllTabs();
      setState(() {
        _tabItems = tabs;
      });
      _tabController = TabController(length: _tabItems.length, vsync: this);
      _pageController = PageController(initialPage: 0);

      _tabController.addListener(() {
        if (_tabController.indexIsChanging) {
          _onTabChanged(_tabController.index);
        }
      });

      // 初始化所有Tab的状态
      for (int i = 0; i < _tabItems.length; i++) {
        _tabData[i] = [];
        _tabLoading[i] = false;
        _tabErrors[i] = null;
        _tabPages[i] = 1;
        _tabHasMore[i] = true;
      }

      // 加载第一个Tab的数据
      if (_tabItems.isNotEmpty) {
        _loadTabData(0);
      }
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
    _tabController = TabController(length: _tabItems.length, vsync: this);
    _pageController = PageController(initialPage: 0);

    _tabController.addListener(() {
      if (_tabController.indexIsChanging) {
        _onTabChanged(_tabController.index);
      }
    });

    // 初始化所有Tab的状态
    for (int i = 0; i < _tabItems.length; i++) {
      _tabData[i] = [];
      _tabLoading[i] = false;
      _tabErrors[i] = null;
      _tabPages[i] = 1;
      _tabHasMore[i] = true;
    }

    // 加载第一个Tab的数据
    if (_tabItems.isNotEmpty) {
      _loadTabData(0);
    }
  }

  void _onTabChanged(int tabIndex) {
    setState(() {
      _currentTabIndex = tabIndex;
    });

    // 同步PageView到当前tab
    if (_pageController.hasClients) {
      _pageController.animateToPage(
        tabIndex,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
    }

    // 同步当前Tab的数据到主列表
    if (_tabData[tabIndex] != null) {
      setState(() {
        _audioItems = _tabData[tabIndex]!;
      });
    }

    // 如果当前Tab没有数据，则加载数据
    if (_tabData[tabIndex] == null || _tabData[tabIndex]!.isEmpty) {
      _loadTabData(tabIndex);
    }
  }

  void _onPageChanged(int pageIndex) {
    setState(() {
      _currentTabIndex = pageIndex;
    });

    // 同步TabController到当前页面
    if (_tabController.index != pageIndex) {
      _tabController.animateTo(pageIndex);
    }

    // 同步当前Tab的数据到主列表
    if (_tabData[pageIndex] != null) {
      setState(() {
        _audioItems = _tabData[pageIndex]!;
      });
    }

    // 如果当前Tab没有数据，则加载数据
    if (_tabData[pageIndex] == null || _tabData[pageIndex]!.isEmpty) {
      _loadTabData(pageIndex);
    }
  }

  Future<void> _loadTabData(int tabIndex, {bool refresh = false}) async {
    if (tabIndex < 0 || tabIndex >= _tabItems.length) {
      return;
    }

    final tabItem = _tabItems[tabIndex];

    // 设置loading状态
    setState(() {
      _tabLoading[tabIndex] = true;
      if (refresh) {
        _tabData[tabIndex] = [];
        _tabPages[tabIndex] = 1;
        _tabHasMore[tabIndex] = true;
        _tabErrors[tabIndex] = null;
      }
    });

    try {
      // 如果指定了标签，使用标签过滤
      String? tag = tabItem.id != 'for_you' ? tabItem.id : null;
      final response = await ApiService.getAudioList(tag: tag, count: 20);

      if (response.errNo == 0 && response.data != null) {
        setState(() {
          if (refresh || _tabData[tabIndex] == null) {
            _tabData[tabIndex] = response.data!.items;
          } else {
            _tabData[tabIndex]!.addAll(response.data!.items);
          }
          _tabHasMore[tabIndex] = response.data!.items.length >= 20;
          _tabErrors[tabIndex] = null;
        });

        // 同时更新主列表（为了保持兼容性）
        if (tabIndex == _currentTabIndex) {
          setState(() {
            _audioItems = _tabData[tabIndex]!;
          });
        }
      } else {
        setState(() {
          _tabErrors[tabIndex] = '加载数据失败: 错误码 ${response.errNo}';
        });
      }
    } catch (e) {
      setState(() {
        _tabErrors[tabIndex] = '加载数据异常: $e';
      });
    } finally {
      setState(() {
        _tabLoading[tabIndex] = false;
      });
    }
  }

  // 获取用于显示的数据列表（转换为 Map 格式以兼容现有组件）
  List<Map<String, dynamic>> get _filteredDataList {
    return _audioItems.map((item) => item.toMap()).toList();
  }

  void _onSearchTap() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const SearchPage()),
    );
  }

  void _onAudioTap(Map<String, dynamic> item) {
    // 先开始播放音频，然后跳转到播放页面
    _playAudioById(item['id']);

    // 使用播放器页面的标准打开方式（包含上滑动画）
    AudioPlayerPage.show(context);
  }

  void _onPlayTap(Map<String, dynamic> item) {
    print('播放音频: ${item['title']}');
    // 只播放音频，不跳转页面
    _playAudioById(item['id']);
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
          SnackBar(
            content: Text('播放失败: $e'),
            duration: const Duration(seconds: 2),
          ),
        );
      }
    }
  }

  void _onLikeTap(Map<String, dynamic> item) {
    print('点赞音频: ${item['title']}');
    // 这里可以实现点赞逻辑
  }

  void _toggleApiMode() {
    final currentMode = ApiService.currentMode;
    final newMode = currentMode == ApiMode.mock ? ApiMode.real : ApiMode.mock;

    ApiService.setApiMode(newMode);

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          '已切换到 ${newMode == ApiMode.mock ? 'Mock 数据' : '真实接口'} 模式',
        ),
        duration: const Duration(seconds: 2),
      ),
    );

    // 重新加载数据
    _loadTabData(_currentTabIndex, refresh: true);
  }

  // 刷新 tabs
  Future<void> _refreshTabs() async {
    try {
      final tabs = await TabManager().refreshTabs();

      setState(() {
        _tabItems = tabs;
      });

      // 重新初始化 Tab 控制器
      _tabController.dispose();
      _tabController = TabController(length: _tabItems.length, vsync: this);
      _tabController.addListener(() {
        if (_tabController.indexIsChanging) {
          setState(() {
            _currentTabIndex = _tabController.index;
          });
          _loadTabData(_currentTabIndex);
        }
      });

      // 重新初始化 Page 控制器
      _pageController.dispose();
      _pageController = PageController(initialPage: 0);

      // 重新初始化数据状态
      for (int i = 0; i < _tabItems.length; i++) {
        _tabData[i] = [];
        _tabLoading[i] = false;
        _tabErrors[i] = null;
        _tabPages[i] = 1;
        _tabHasMore[i] = true;
      }

      // 加载第一个 tab 的数据
      _loadTabData(0);

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Tabs 已刷新'),
          duration: Duration(seconds: 2),
        ),
      );
    } catch (e) {
      print('刷新 tabs 失败: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('刷新 tabs 失败: $e'),
          duration: const Duration(seconds: 2),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // 自定义头部
        CustomAppBar(hintText: 'Search audio', onSearchTap: _onSearchTap),

        // Tab 栏
        Container(
          color: Colors.white,
          child: Column(
            children: [
              CustomTabBar(
                controller: _tabController,
                tabItems: _tabItems,
                onTabChanged: (index) {
                  // Tab 点击时的处理逻辑
                },
              ),
              const SizedBox(height: 6),
              // 开发工具按钮区域
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 8,
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      '当前模式: ${ApiService.currentMode == ApiMode.mock ? 'Mock 数据' : '真实接口'}',
                      style: const TextStyle(fontSize: 12, color: Colors.grey),
                    ),
                    Row(
                      children: [
                        TextButton(
                          onPressed: _refreshTabs,
                          child: const Text('刷新 Tabs'),
                        ),
                        TextButton(
                          onPressed: _toggleApiMode,
                          child: const Text('切换模式'),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),

        // 内容区域 - 使用PageView实现滑动切换
        Expanded(
          child: PageView.builder(
            controller: _pageController,
            onPageChanged: _onPageChanged,
            itemCount: _tabItems.length,
            itemBuilder: (context, index) {
              final tabData = _tabData[index] ?? [];
              final filteredData = tabData.map((item) => item.toMap()).toList();

              return _tabErrors[index] != null
                  ? _buildErrorWidget()
                  : AudioGrid(
                      dataList: filteredData,
                      isLoading: _tabLoading[index] ?? false,
                      onRefresh: () => _loadTabData(index, refresh: true),
                      onItemTap: _onAudioTap,
                      onPlayTap: _onPlayTap,
                      onLikeTap: _onLikeTap,
                    );
            },
          ),
        ),
        const SizedBox(height: 80),
      ],
    );
  }

  Widget _buildErrorWidget() {
    final errorMessage = _tabErrors[_currentTabIndex];
    if (errorMessage == null) return const SizedBox.shrink();

    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.error_outline, size: 64, color: Colors.grey[400]),
          const SizedBox(height: 16),
          Text(
            errorMessage,
            style: const TextStyle(color: Colors.grey, fontSize: 16),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 16),
          ElevatedButton(
            onPressed: () => _loadTabData(_currentTabIndex, refresh: true),
            child: const Text('重试'),
          ),
        ],
      ),
    );
  }
}
