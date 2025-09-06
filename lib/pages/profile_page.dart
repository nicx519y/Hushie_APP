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
import 'login_page.dart';
import '../layouts/main_layout.dart'; // 导入以使用全局RouteObserver
import '../router/navigation_utils.dart';
import 'dart:async';
import 'package:hushie_app/services/api/user_history_service.dart';
import 'audio_player_page.dart';
import 'package:hushie_app/services/audio_manager.dart';

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
  List<AudioItem> likedAudios = [];
  bool _isLoadingLiked = false;
  bool _isRefreshingAuth = false;

  // 认证状态订阅
  StreamSubscription<AuthStatusChangeEvent>? _authSubscription;

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

    // 订阅认证状态变化事件
    _subscribeToAuthChanges();

    // 初始化 AudioHistoryManager
    AudioHistoryManager.instance.initialize();

    // 异步初始化登录状态
    _initializeAuthState();
  }

  /// 订阅认证状态变化事件
  Future<void> _subscribeToAuthChanges() async {
    _authSubscription?.cancel(); // 取消之前的订阅

    _authSubscription = AuthService.authStatusChanges.listen((event) async {
      print('👤 [PROFILE] 收到认证状态变化事件: ${event.status}');
      
      // 根据状态变化刷新数据
      switch (event.status) {
        case AuthStatus.authenticated:
          // 用户登录，重新加载数据
          await _refreshAuthState();
          await _loadDataAfterLogin();
          break;
        case AuthStatus.unauthenticated:
          // 用户登出，清空页面数据
          await _refreshAuthState();
          await _clearDataAfterLogout();
          break;
        case AuthStatus.unknown:
          // 状态未知，暂不处理
          break;
      }
    });

    print('👤 [PROFILE] 已订阅认证状态变化事件');
  }

  /// 登录后加载数据
  Future<void> _loadDataAfterLogin() async {
    print('👤 [PROFILE] 用户已登录，重新加载页面数据');

    // 检查认证状态
    final token = await AuthService.getAccessToken();
    print('👤 [PROFILE] 当前访问令牌: ${token != null ? "存在(${token.length}字符)" : "不存在"}');
    
    final isSignedIn = await AuthService.isSignedIn();
    print('👤 [PROFILE] 登录状态检查: $isSignedIn');

    // 并行加载历史和喜欢数据
    await Future.wait([
      _loadLikedAudios(),
      // AudioHistoryManager.instance.refreshHistory(),
      () async {
        try {
          print('🎵 [HISTORY] 开始调用 UserHistoryService.getUserHistoryList()');
          final value = await UserHistoryService.getUserHistoryList();
          print('🎵 [HISTORY] 刷新用户播放历史成功: $value');
        } catch (error) {
          print('🎵 [HISTORY] 获取用户播放历史失败: $error');
          print('🎵 [HISTORY] 错误类型: ${error.runtimeType}');
          if (error is Exception) {
            print('🎵 [HISTORY] 异常详情: ${error.toString()}');
          }
        }
      }()
    ]);
  }

  /// 登出后清空页面数据
  Future<void> _clearDataAfterLogout() async {
    print('👤 [PROFILE] 用户已登出，清空页面数据');

    if (mounted) {
      setState(() {
        likedAudios.clear();
        userName = '';
      });
    }
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

        // 登录状态下加载数据
        await _loadDataAfterLogin();
      }
    } catch (e) {
      print('初始化认证状态失败: $e');
    }
  }

  @override
  void dispose() {
    // 取消认证状态订阅
    _authSubscription?.cancel();
    _authSubscription = null;

    // 取消路由观察者订阅
    final route = ModalRoute.of(context);
    if (route != null) {
      globalRouteObserver.unsubscribe(this);
    }

    _tabController.dispose();
    super.dispose();
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

      if (mounted) {
        setState(() {
          isLoggedIn = newLoginState;
        });

        // 如果登录状态发生变化，重新获取用户信息
        if (newLoginState) {
          await _refreshUserInfo();
        }

        // 如果登录状态变为false，清空用户信息
        if (!newLoginState) {
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
      print('👤 [PROFILE] 刷新用户信息: ${user?.displayName}');
      if (mounted) {
        setState(() {
          userName = user?.displayName ?? '';
        });
      }
    } catch (e) {
      print('刷新用户信息失败: $e');
    }
  }

  // 刷新历史数据（用于下拉刷新）
  Future<void> _refreshHistoryData() async {
    if (!isLoggedIn) return;
    try {
      await AudioHistoryManager.instance.refreshHistory();
    } catch (e) {
      print('刷新历史数据失败: $e');
    }
  }

  // 加载喜欢数据
  Future<void> _loadLikedAudios() async {
    print('👤 [PROFILE] 加载喜欢数据, _isLoadingLiked: ${_isLoadingLiked}, isLoggedIn: ${isLoggedIn}');
    if (_isLoadingLiked || !isLoggedIn) return;

    setState(() {
      _isLoadingLiked = true;
    });

    try {
      // 使用 UserLikesManager 获取喜欢列表
      final likesList = await UserLikesService.getUserLikedAudios();

      if (mounted) {
        setState(() {
          likedAudios = likesList;
        });
      }
    } catch (e) {
      print('加载喜欢数据失败: $e');
    } finally {
      if (mounted) {
        setState(() {
          _isLoadingLiked = false;
        });
      }
    }
  }

  // 1. 修复下拉刷新 - 应该重新加载第一页
  Future<void> _refreshLikedAudios() async {
    if (_isLoadingLiked || !isLoggedIn) return;

    setState(() {
      _isLoadingLiked = true;
    });

    try {
      // 重新获取第一页数据
      final refreshedAudios = await UserLikesService.getUserLikedAudios(
        count: 20, // 不传cid，获取第一页
      );

      if (mounted) {
        setState(() {
          likedAudios = refreshedAudios; // 替换整个列表
        });
      }
    } catch (e) {
      print('刷新喜欢数据失败: $e');
    } finally {
      if (mounted) {
        setState(() {
          _isLoadingLiked = false;
        });
      }
    }
  }

  // 2. 修复上拉加载更多
  Future<void> _loadMoreLikedAudios() async {
    if (_isLoadingLiked || !isLoggedIn) return;

    // 检查是否有数据用于分页
    if (likedAudios.isEmpty) return;

    setState(() {
      _isLoadingLiked = true;
    });

    try {
      final moreLikedAudios = await UserLikesService.getUserLikedAudios(
        cid: likedAudios.last.id, // 移除 ?? ''，因为上面已经检查了
        count: 20,
      );

      if (moreLikedAudios.isNotEmpty) {
        setState(() {
          likedAudios.addAll(moreLikedAudios); // 追加数据
        });
      }
    } catch (e) {
      print('加载更多喜欢数据失败: $e');
    } finally {
      if (mounted) {
        setState(() {
          _isLoadingLiked = false;
        });
      }
    }
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
                      NavigationUtils.navigateToSettings(context);
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
                  LoginPage.show(context);
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
                ValueListenableBuilder<List<AudioItem>>(
                  valueListenable: AudioHistoryManager.instance.historyNotifier,
                  builder: (context, historyList, child) {
                    if (historyList.isEmpty) {
                      return _buildEmptyWidget('No history');
                    }
                    return AudioList(
                      padding: const EdgeInsets.only(bottom: 120),
                      audios: historyList,
                      emptyWidget: _buildEmptyWidget('No history'),
                      onRefresh: _refreshHistoryData,
                      hasMoreData: false,
                    );
                  },
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
                        onRefresh: _refreshLikedAudios, // 改为刷新方法
                        onLoadMore: _loadMoreLikedAudios,
                        hasMoreData: true,
                        isLoadingMore: _isLoadingLiked, // 添加加载状态
                        onItemTap: (audio) {
                          AudioManager.instance.playAudio(audio);
                          NavigationUtils.navigateToAudioPlayer(context);
                        },
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
                      LoginPage.show(context);
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
