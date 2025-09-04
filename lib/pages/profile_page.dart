import 'package:flutter/material.dart';
import 'package:hushie_app/services/api/user_likes_service.dart';
import '../models/audio_item.dart';
import '../models/tab_item.dart';
import '../components/custom_tab_bar.dart';
import '../components/audio_list.dart';
import '../components/user_header.dart';
import '../components/premium_access_card.dart';
import '../services/audio_history_manager.dart';
import '../services/auth_service.dart';
import '../utils/custom_icons.dart';
import '../layouts/main_layout.dart'; // 导入以使用全局RouteObserver
import 'login_page.dart';
import 'setting_page.dart';

class ProfilePage extends StatefulWidget {
  const ProfilePage({super.key});

  @override
  State<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage>
    with TickerProviderStateMixin, RouteAware {
  // 模拟登录状态
  bool isLoggedIn = false;
  String userName = '';

  // 标签页状态
  late List<TabItemModel> _tabItems;
  late TabController _tabController;
  int currentTabIndex = 0;

  // 音频数据
  List<AudioItem> historyAudios = [];
  List<AudioItem> likedAudios = [];
  bool _isLoadingHistory = false;
  bool _isLoadingLiked = false;
  bool _isRefreshingAuth = false;

  @override
  void initState() {
    super.initState();

    _tabItems = [
      const TabItemModel(id: 'history', label: 'History'),
      const TabItemModel(id: 'like', label: 'Like'),
    ];
    _tabController = TabController(length: _tabItems.length, vsync: this);
    _tabController.addListener(() {
      if (_tabController.indexIsChanging) {
        setState(() {
          currentTabIndex = _tabController.index;
        });
      }
    });

    // 异步初始化登录状态
    _initializeAuthState();
  }

  /// 异步初始化认证状态
  Future<void> _initializeAuthState() async {
    try {
      isLoggedIn = await AuthService.isSignedIn();
      if (isLoggedIn) {
        final user = await AuthService.getCurrentUser();
        if (mounted) {
          setState(() {
            userName = user?.displayName ?? '';
          });
        }
      }
    } catch (e) {
      print('初始化认证状态失败: $e');
    }
  }

  @override
  void dispose() {
    // 取消路由观察者订阅
    final route = ModalRoute.of(context);
    if (route != null) {
      globalRouteObserver.unsubscribe(this);
    }

    _tabController.dispose();
    super.dispose();
  }

  // 注册路由观察者 用于监听登录状态
  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // 注册路由观察者
    final route = ModalRoute.of(context);
    if (route != null) {
      globalRouteObserver.subscribe(this, route);
    }
  }

  // 当从其他页面返回时，重新检查登录状态
  @override
  void didPopNext() {
    super.didPopNext();
    _refreshAuthState();
  }

  @override
  void didPushNext() {
    super.didPushNext();
  }

  /// 刷新认证状态
  Future<void> _refreshAuthState() async {
    // 防抖逻辑：避免频繁调用
    if (_isRefreshingAuth) {
      return;
    }

    _isRefreshingAuth = true;

    try {
      final newLoginState = await AuthService.isSignedIn();
      final oldLoginState = isLoggedIn; // 保存旧状态用于比较

      if (mounted) {
        setState(() {
          isLoggedIn = newLoginState;
        });

        // 如果登录状态发生变化，重新获取用户信息
        if (newLoginState && !oldLoginState) {
          await _refreshUserInfo();
        }

        // 如果登录状态变为false，清空用户信息
        if (!newLoginState && oldLoginState) {
          setState(() {
            userName = '';
          });
        }
      }
    } catch (e) {
      print('刷新认证状态失败: $e');
    } finally {
      _isRefreshingAuth = false;
    }
  }

  /// 刷新用户信息
  Future<void> _refreshUserInfo() async {
    try {
      final user = await AuthService.getCurrentUser();
      if (mounted) {
        setState(() {
          userName = user?.displayName ?? '';
        });
      }
    } catch (e) {
      print('刷新用户信息失败: $e');
    }
  }

  // 加载历史数据
  Future<void> _loadHistoryData() async {
    if (_isLoadingHistory) return;

    setState(() {
      _isLoadingHistory = true;
    });

    try {
      // 从 AudioHistoryManager 获取最近的历史记录
      final historyList = await AudioHistoryManager.instance.getAudioHistory();

      setState(() {
        historyAudios = historyList;
      });
    } catch (e) {
      print('加载历史数据失败: $e');
    } finally {
      setState(() {
        _isLoadingHistory = false;
      });
    }
  }

  Future<void> _loadMoreLikedAudios() async {
    if (_isLoadingLiked) return;

    setState(() {
      _isLoadingLiked = true;
    });

    try {
      final response = await UserLikesService.getUserLikedAudios();
      setState(() {
        likedAudios.addAll(response);
      });
    } catch (e) {
      print('加载更多喜欢数据失败: $e');
    } finally {
      setState(() {
        _isLoadingLiked = false;
      });
    }
  }

  Future<void> _refreshLikedAudios() async {
    if (_isLoadingHistory) return;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: SafeArea(
        child: Container(
          padding: const EdgeInsets.only(
            left: 16,
            right: 16,
            top: 0,
            bottom: 0,
          ),
          child: Column(
            children: [
              // 设置按钮
              const SizedBox(height: 10),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  IconButton(
                    padding: EdgeInsets.zero,
                    style: IconButton.styleFrom(
                      minimumSize: const Size(40, 40),
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    ),
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => const SettingPage(),
                        ),
                      );
                    },
                    icon: Icon(CustomIcons.setup, size: 20),
                  ),
                ],
              ),

              const SizedBox(height: 10),

              // 用户头部组件
              UserHeader(
                isLoggedIn: isLoggedIn,
                userName: userName,
                onLoginTap: () {
                  Navigator.of(context).push(
                    MaterialPageRoute(builder: (context) => const LoginPage()),
                  );
                },
              ),

              const SizedBox(height: 25),

              // Premium Access 卡片
              PremiumAccessCard(
                onSubscribe: () {
                  // 订阅逻辑
                },
              ),

              const SizedBox(height: 30),
              // 内容区域
              Expanded(
                child: isLoggedIn
                    ? _buildLoggedInContent()
                    : _buildLoggedOutContent(),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildLoggedInContent() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 0),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        children: [
          // 统一的标签页头部
          Row(
            children: [
              Expanded(
                child: CustomTabBar(
                  controller: _tabController,
                  tabItems: _tabItems,
                  onTabChanged: (index) {
                    setState(() {
                      currentTabIndex = index;
                    });
                  },
                ),
              ),
            ],
          ),

          const SizedBox(height: 20),

          // 内容区域
          Expanded(
            child: IndexedStack(
              index: currentTabIndex,
              children: [
                // History 标签页
                _isLoadingHistory
                    ? _buildLoadingWidget()
                    : historyAudios.isEmpty
                    ? _buildEmptyWidget('No history')
                    : AudioList(
                        padding: const EdgeInsets.only(bottom: 120),
                        audios: historyAudios,
                        emptyWidget: _buildEmptyWidget('No history'),
                        onRefresh: _loadHistoryData,
                        hasMoreData: false,
                      ),
                // Like 标签页
                _isLoadingLiked && likedAudios.isEmpty
                    ? _buildLoadingWidget()
                    : likedAudios.isEmpty
                    ? _buildEmptyWidget('No liked content')
                    : AudioList(
                        audios: likedAudios,
                        padding: const EdgeInsets.only(bottom: 120),
                        emptyWidget: _buildEmptyWidget('No liked content'),
                        onRefresh: _refreshLikedAudios,
                        hasMoreData: true,
                        onLoadMore: _loadMoreLikedAudios,
                      ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLoggedOutContent() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 0),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        children: [
          // 统一的标签页头部（未登录状态）
          CustomTabBar(
            controller: _tabController,
            tabItems: _tabItems,
            onTabChanged: (index) {
              setState(() {
                currentTabIndex = index;
              });
            },
          ),

          // 未登录状态的内容
          Expanded(
            child: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Text(
                    'Log in / Sign up to access data.',
                    style: TextStyle(
                      fontSize: 16,
                      color: Color(0xFF999999),
                      height: 1,
                    ),
                  ),
                  const SizedBox(height: 20),
                  ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.white,
                      foregroundColor: Color(0xFF333333),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(25),
                      ),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 20,
                        vertical: 12,
                      ),
                      side: const BorderSide(color: Color(0xFF333333)),
                    ),
                    onPressed: () {
                      Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (context) => const LoginPage(),
                        ),
                      );
                    },
                    child: const Text(
                      'Log in / Sign up',
                      style: TextStyle(fontSize: 16, color: Color(0xFF333333)),
                    ),
                  ),

                  const SizedBox(height: 180),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyWidget(String text) {
    return Column(
      children: [
        Expanded(
          child: Center(
            child: Text(
              text,
              style: TextStyle(color: Colors.grey, fontSize: 14),
            ),
          ),
        ),
        const SizedBox(height: 180),
      ],
    );
  }

  Widget _buildLoadingWidget() {
    return Column(
      children: [
        Expanded(child: Center(child: CircularProgressIndicator())),
        const SizedBox(height: 180),
      ],
    );
  }
}
