import 'package:flutter/material.dart';
import '../models/audio_item.dart';
import '../models/tab_item.dart';
import '../components/custom_tab_bar.dart';
import '../components/user_header.dart';
import '../components/premium_access_card.dart';
import '../components/likes_list.dart';
import '../components/audio_history_list.dart';
import '../services/auth_manager.dart';
import '../utils/custom_icons.dart';
import 'login_page.dart';
import '../router/navigation_utils.dart';
import 'dart:async';
import 'package:hushie_app/services/audio_manager.dart';
import '../services/audio_service.dart';

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

  // 当前播放音频ID
  String currentAudioId = '';

  // 认证状态订阅
  StreamSubscription<AuthStatusChangeEvent>? _authSubscription;
  // 音频流订阅
  StreamSubscription<AudioPlayerState>? _audioSubscription;

  @override
  void initState() {
    super.initState();

    _tabItems = [
      const TabItemModel(id: 'history', label: 'History', items: []),
      const TabItemModel(id: 'like', label: 'Like', items: []),
    ];
    _tabController = TabController(length: _tabItems.length, vsync: this);
    _tabController.addListener(() {
      if (_tabController.indexIsChanging) {
        setState(() {
          currentTabIndex = _tabController.index;
        });
      }
    });

    // 先初始化登录状态渲染，再监听登录状态变化，否则可能会产生状态冲突
    _initializeAuthState().then((_) {
      // 订阅登录状态变化事件
      _subscribeToAuthChanges();
      // 订阅音频流变化事件
      _subscribeToAudioChanges();
    });
  }

  /// 订阅认证状态变化事件
  Future<void> _subscribeToAuthChanges() async {
    _authSubscription?.cancel(); // 取消之前的订阅

    _authSubscription = AuthManager.instance.authStatusChanges.listen((
      event,
    ) async {
      debugPrint('👤 [PROFILE] 收到认证状态变化事件: ${event.status}');

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

    debugPrint('👤 [PROFILE] 已订阅认证状态变化事件');
  }

  /// 订阅音频流变化事件
  void _subscribeToAudioChanges() {
    _audioSubscription?.cancel(); // 取消之前的订阅

    _audioSubscription = AudioManager.instance.audioStateStream.listen((
      audioState,
    ) {
      if (mounted) {
        final newAudioId = audioState.currentAudio?.id ?? '';
        // 只有当音频ID真正发生变化时才更新状态
        if (currentAudioId != newAudioId) {
          setState(() {
            currentAudioId = newAudioId;
          });
        }
      }
    });

    debugPrint('🎵 [PROFILE] 已订阅音频流变化事件');
  }

  /// 登录后加载数据
  Future<void> _loadDataAfterLogin() async {
    // 历史数据和点赞数据都由各自的管理器自动处理登录状态变化
    // AudioHistoryManager 和 LikesList 组件会自动监听认证状态并刷新数据
  }

  /// 登出后清空页面数据
  Future<void> _clearDataAfterLogout() async {
    debugPrint('👤 [PROFILE] 用户已登出，清空页面数据');

    if (mounted) {
      setState(() {
        userName = '';
      });
    }
  }

  /// 异步初始化认证状态
  Future<void> _initializeAuthState() async {
    try {
      // 先检查认证状态
      final signedIn = await AuthManager.instance.isSignedIn();

      if (mounted) {
        setState(() {
          isLoggedIn = signedIn;
        });
      }

      if (signedIn) {
        // 获取用户信息
        final user = await AuthManager.instance.getCurrentUser();
        final displayName = user?.displayName ?? user?.email ?? '';

        if (mounted) {
          setState(() {
            userName = displayName;
          });
        }

        // 登录状态下加载数据
        await _loadDataAfterLogin();
      } else {
        // 未登录状态，清空数据
        if (mounted) {
          setState(() {
            userName = '';
          });
        }
      }
    } catch (e) {
      debugPrint('初始化认证状态失败: $e');
      // 发生错误时，确保状态一致
      if (mounted) {
        setState(() {
          isLoggedIn = false;
          userName = '';
        });
      }
    }
  }

  @override
  void dispose() {
    // 取消认证状态订阅
    _authSubscription?.cancel();
    _authSubscription = null;

    // 取消音频流订阅
    _audioSubscription?.cancel();
    _audioSubscription = null;

    _tabController.dispose();
    super.dispose();
  }

  /// 刷新认证状态
  Future<void> _refreshAuthState() async {
    try {
      final newLoginState = await AuthManager.instance.isSignedIn();

      if (mounted) {
        setState(() {
          isLoggedIn = newLoginState;
        });

        // 如果登录状态发生变化，重新获取用户信息
        if (newLoginState) {
          await _refreshUserInfo();
        } else {
          // 如果登录状态变为false，清空用户信息和数据
          setState(() {
            userName = '';
          });
        }
      }
    } catch (e) {
      debugPrint('刷新认证状态失败: $e');
      // 发生错误时，采用保守策略
      if (mounted) {
        setState(() {
          isLoggedIn = false;
          userName = '';
        });
      }
    }
  }

  /// 刷新用户信息
  Future<void> _refreshUserInfo() async {
    try {
      final user = await AuthManager.instance.getCurrentUser();
      final displayName = user?.displayName ?? user?.email ?? '';

      debugPrint('👤 [PROFILE] 刷新用户信息: $displayName');

      if (mounted) {
        setState(() {
          userName = displayName;
        });
      }
    } catch (e) {
      debugPrint('刷新用户信息失败: $e');
      // 刷新失败时，尝试保持当前状态或设置默认值
      if (mounted && userName.isEmpty) {
        setState(() {
          userName = 'User';
        });
      }
    }
  }

  void _onAudioListItemTap(AudioItem audio) async {
    AudioManager.instance.playAudio(audio);
    NavigationUtils.navigateToAudioPlayer(context, initialAudio: audio);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: SafeArea(
        child: Column(
          children: [
            // 设置按钮
            const SizedBox(height: 10),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Row(
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
            ),

            const SizedBox(height: 10),

            // 用户头部组件
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: UserHeader(
                isLoggedIn: isLoggedIn,
                userName: userName,
                onLoginTap: () {
                  LoginPage.show(context);
                },
              ),
            ),

            const SizedBox(height: 25),

            // Premium Access 卡片
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: PremiumAccessCard(),
            ),

            const SizedBox(height: 16),
            // 内容区域
            Expanded(
              child: isLoggedIn
                  ? _buildLoggedInContent()
                  : _buildLoggedOutContent(),
            ),
          ],
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
                  labelStyle: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w500,
                  ),
                  unselectedLabelStyle: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w500,
                  ),
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
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: TabBarView(
                controller: _tabController,
                children: [
                  // History 标签页 - 使用封装的 AudioHistoryList 组件
                  _KeepAliveWrapper(
                    child: AudioHistoryList(
                      key: const PageStorageKey('history_list'),
                      onItemTap: _onAudioListItemTap,
                      padding: const EdgeInsets.only(bottom: 120),
                    ),
                  ),
                  // Like 标签页 - 使用封装的 LikesList 组件
                  _KeepAliveWrapper(
                    child: LikesList(
                      key: const PageStorageKey('likes_list'),
                      onItemTap: _onAudioListItemTap,
                      padding: const EdgeInsets.only(bottom: 120),
                    ),
                  ),
                ],
              ),
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
            labelStyle: TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
            unselectedLabelStyle: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w500,
            ),
            onTabChanged: (index) {
              setState(() {
                currentTabIndex = index;
              });
            },
          ),

          // 未登录状态的内容
          Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Text(
                      'Log in / Sign up to access data.',
                      style: TextStyle(
                        fontSize: 14,
                        color: Color(0xFF999999),
                        fontWeight: FontWeight.w400,
                        height: 1,
                      ),
                    ),
                    const SizedBox(height: 20),
                    TextButton(
                      style: TextButton.styleFrom(
                        foregroundColor: Color(0xFF999999),
                        padding: EdgeInsets.symmetric(
                          horizontal: 20,
                          vertical: 12,
                        ),
                        side: BorderSide(color: Color(0xFF999999)),
                      ),
                      onPressed: () {
                        NavigationUtils.navigateToLogin(context);
                      },
                      child: const Text(
                        'Log in / Sign up',
                        style: TextStyle(
                          fontSize: 14,
                          color: Color(0xFF333333),
                          fontWeight: FontWeight.w400,
                        ),
                      ),
                    ),

                    const SizedBox(height: 180),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// KeepAlive 包装器，用于保持 TabBarView 中页面的状态
class _KeepAliveWrapper extends StatefulWidget {
  final Widget child;

  const _KeepAliveWrapper({required this.child});

  @override
  State<_KeepAliveWrapper> createState() => _KeepAliveWrapperState();
}

class _KeepAliveWrapperState extends State<_KeepAliveWrapper>
    with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;

  @override
  Widget build(BuildContext context) {
    super.build(context); // 必须调用 super.build(context)
    return widget.child;
  }
}
