import 'package:flutter/material.dart';
import '../components/custom_app_bar.dart';
import '../components/audio_grid.dart';
import '../models/audio_item.dart';
import '../models/tab_item.dart';
import '../services/api_service.dart';
import '../services/audio_manager.dart';
import '../services/audio_data_pool.dart';
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
    super.dispose();
  }

  final String _searchQuery = '';
  final int _pageSize = 10;

  // Tab 相关
  late TabController _tabController;
  int _currentTabIndex = 0;

  // 不同 tab 的数据
  List<TabItem> _tabItems = [];
  final Map<int, List<AudioItem>> _tabData = {};
  final Map<int, bool> _tabLoading = {};
  final Map<int, String?> _tabErrors = {};
  final Map<int, int> _tabPages = {};
  final Map<int, bool> _tabHasMore = {};

  @override
  void initState() {
    super.initState();

    // 先加载 tabs，然后初始化其他内容
    _initializeTabs();
  }

  Future<void> _initializeTabs() async {
    try {
      // 从 TabManager 获取 tabs
      final tabs = await TabManager.instance.getAllTabs();

      setState(() {
        _tabItems = tabs;
      });

      // 初始化 Tab 控制器
      _tabController = TabController(length: _tabItems.length, vsync: this);
      _tabController.addListener(() {
        if (_tabController.indexIsChanging) {
          setState(() {
            _currentTabIndex = _tabController.index;
          });
          // 切换到新 tab 时加载数据
          _loadTabData(_currentTabIndex);
        }
      });

      // 初始化各个 tab 的数据状态
      for (int i = 0; i < _tabItems.length; i++) {
        _tabData[i] = [];
        _tabLoading[i] = false;
        _tabErrors[i] = null;
        _tabPages[i] = 1;
        _tabHasMore[i] = true;
      }

      // 加载第一个 tab 的数据
      _loadTabData(0);
    } catch (e) {
      print('初始化 tabs 失败: $e');
      // 如果失败，使用默认 tabs
      _useDefaultTabs();
    }
  }

  void _useDefaultTabs() {
    setState(() {
      _tabItems = [
        const TabItem(
          id: 'for_you',
          title: 'For You',
          tag: null,
          isDefault: true,
          order: 0,
        ),
        const TabItem(id: 'mf', title: 'M/F', tag: 'M/F', order: 1),
        const TabItem(id: 'fm', title: 'F/M', tag: 'F/M', order: 2),
        const TabItem(id: 'asmr', title: 'ASMR', tag: 'ASMR', order: 3),
        const TabItem(id: 'nsfw', title: 'NSFW', tag: 'NSFW', order: 4),
      ];
    });

    // 初始化 Tab 控制器
    _tabController = TabController(length: _tabItems.length, vsync: this);
    _tabController.addListener(() {
      if (_tabController.indexIsChanging) {
        setState(() {
          _currentTabIndex = _tabController.index;
        });
        // 切换到新 tab 时加载数据
        _loadTabData(_currentTabIndex);
      }
    });

    // 初始化各个 tab 的数据状态
    for (int i = 0; i < _tabItems.length; i++) {
      _tabData[i] = [];
      _tabLoading[i] = false;
      _tabErrors[i] = null;
      _tabPages[i] = 1;
      _tabHasMore[i] = true;
    }

    // 加载第一个 tab 的数据
    _loadTabData(0);
  }

  Future<void> _loadTabData(int tabIndex, {bool refresh = false}) async {
    if (refresh) {
      setState(() {
        _tabLoading[tabIndex] = true;
        _tabPages[tabIndex] = 1;
        _tabData[tabIndex]!.clear();
        _tabErrors[tabIndex] = null;
        _tabHasMore[tabIndex] = true;
      });
    }

    try {
      // 根据不同的 tab 调用不同的 API 方法
      final response = await _getApiResponseForTab(
        tabIndex,
        _tabPages[tabIndex]!,
      );

      if (mounted) {
        setState(() {
          _tabLoading[tabIndex] = false;

          if (response.success && response.data != null) {
            if (refresh || _tabPages[tabIndex] == 1) {
              _tabData[tabIndex] = response.data!.items;
            } else {
              _tabData[tabIndex]!.addAll(response.data!.items);
            }
            _tabHasMore[tabIndex] = response.data!.hasNextPage;
            _tabErrors[tabIndex] = null;

            // 将新加载的音频数据缓存到数据池
            AudioDataPool.instance.addAudioList(response.data!.items);
            print('Tab $tabIndex 已缓存 ${response.data!.items.length} 个音频到数据池');
          } else {
            _tabErrors[tabIndex] = response.message;
          }
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _tabLoading[tabIndex] = false;
          _tabErrors[tabIndex] = '加载失败: $e';
        });
      }
    }
  }

  Future<dynamic> _getApiResponseForTab(int tabIndex, int page) async {
    // 确保 tabIndex 在有效范围内
    if (tabIndex < 0 || tabIndex >= _tabItems.length) {
      return await ApiService.getHomeAudioList(
        page: page,
        pageSize: _pageSize,
        searchQuery: _searchQuery.isNotEmpty ? _searchQuery : null,
      );
    }

    final tabItem = _tabItems[tabIndex];

    // 根据 tab 的 tag 来请求数据
    if (tabItem.tag != null) {
      return await ApiService.getHomeAudioList(
        page: page,
        pageSize: _pageSize,
        tags: [tabItem.tag!],
        searchQuery: _searchQuery.isNotEmpty ? _searchQuery : null,
      );
    } else {
      // 没有 tag 的 tab（如 "For You"）返回推荐数据
      return await ApiService.getHomeAudioList(
        page: page,
        pageSize: _pageSize,
        searchQuery: _searchQuery.isNotEmpty ? _searchQuery : null,
      );
    }
  }

  Future<void> _loadAudioData({bool refresh = false}) async {
    // 保持原有方法以兼容，现在调用当前 tab 的数据加载
    await _loadTabData(_currentTabIndex, refresh: refresh);
  }

  // 获取用于显示的数据列表（转换为 Map 格式以兼容现有组件）
  List<Map<String, dynamic>> get _filteredDataList {
    return _tabData[_currentTabIndex]?.map((item) => item.toMap()).toList() ??
        [];
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
    _loadAudioData(refresh: true);
  }

  // 刷新 tabs
  Future<void> _refreshTabs() async {
    try {
      final tabs = await TabManager.instance.refreshTabs();

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
              Container(
                child: TabBar(
                  controller: _tabController,
                  tabAlignment: TabAlignment.start,
                  tabs: _tabItems.map((tab) => Tab(text: tab.title)).toList(),
                  labelColor: const Color(0xFF333333),
                  unselectedLabelColor: const Color(0xFF787878),
                  indicator: UnderlineTabIndicator(
                    insets: const EdgeInsets.only(bottom: 5), // 底部间距
                    borderRadius: BorderRadius.circular(2),
                    borderSide: BorderSide(
                      color: const Color(0xFFF359AA),
                      width: 4,
                      style: BorderStyle.solid,
                    ),
                  ),
                  // indicatorColor: const Color(0xFFF359AA),
                  // indicatorWeight: 3,
                  indicatorSize: TabBarIndicatorSize.label,
                  labelStyle: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                  ),
                  // unselectedLabelStyle: const TextStyle(fontSize: 14),
                  isScrollable: true,
                  dividerColor: Colors.transparent, // 去掉底部灰线
                ),
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

        // 内容区域
        Expanded(
          child: _tabErrors[_currentTabIndex] != null
              ? _buildErrorWidget()
              : AudioGrid(
                  dataList: _filteredDataList,
                  isLoading: _tabLoading[_currentTabIndex] ?? false,
                  onRefresh: () =>
                      _loadTabData(_currentTabIndex, refresh: true),
                  onItemTap: _onAudioTap,
                  onPlayTap: _onPlayTap,
                  onLikeTap: _onLikeTap,
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
