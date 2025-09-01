import 'package:flutter/material.dart';
import '../components/custom_app_bar.dart';
import '../components/custom_tab_bar.dart';
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
  List<TabItemModel> _tabItems = [];
  late TabController _tabController;
  int _currentTabIndex = 0;
  bool _isLoading = false;
  bool _isRefreshing = false;
  List<AudioItem> _audioItems = [];
  bool _hasMoreData = true;
  String? _lastAudioId;
  int _currentPage = 1;

  @override
  void initState() {
    super.initState();
    _initTabs();
    _loadAudioData();
  }

  void _initTabs() async {
    try {
      final tabs = await TabManager().getAllTabs();
      setState(() {
        _tabItems = tabs;
      });
      _tabController = TabController(length: _tabItems.length, vsync: this);
      _tabController.addListener(() {
        if (_tabController.indexIsChanging) {
          _onTabChanged(_tabController.index);
        }
      });
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
    _tabController.addListener(() {
      if (_tabController.indexIsChanging) {
        _onTabChanged(_tabController.index);
      }
    });
  }

  void _onTabChanged(int tabIndex) {
    setState(() {
      _currentTabIndex = tabIndex;
    });
    // 切换到新 tab 时加载数据
    _loadTabData(tabIndex);
  }

  void _loadTabData(int tabIndex) async {
    if (tabIndex < 0 || tabIndex >= _tabItems.length) {
      return;
    }

    final tabItem = _tabItems[tabIndex];

    // 如果指定了标签，使用标签过滤
    if (tabItem.id != 'for_you') {
      await _loadAudioDataByTag(tabItem.id);
    } else {
      // 否则加载推荐数据
      await _loadAudioData();
    }
  }

  Future<void> _loadAudioDataByTag(String tag) async {
    try {
      setState(() {
        _isLoading = true;
      });

      final response = await ApiService.getAudioList(tag: tag, count: 20);

      if (response.errNo == 0 && response.data != null) {
        setState(() {
          _audioItems = response.data!.items;
          _hasMoreData = response.data!.items.length >= 20;
          if (_audioItems.isNotEmpty) {
            _lastAudioId = _audioItems.last.id;
          }
        });
      } else {
        print('加载音频数据失败: 错误码 ${response.errNo}');
      }
    } catch (e) {
      print('加载音频数据异常: $e');
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
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
