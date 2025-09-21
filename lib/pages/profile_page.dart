import 'package:flutter/material.dart';
import 'package:hushie_app/components/subscribe_dialog.dart';
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

  // 音频数据
  List<AudioItem> likedAudios = [];
  bool _isLoadingLiked = false;
  bool _isRefreshingAuth = false;

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

    // 订阅登录状态变化事件
    _subscribeToAuthChanges();

    // 订阅音频流变化事件
    _subscribeToAudioChanges();

    // 异步初始化登录状态
    _initializeAuthState();
  }

  /// 订阅认证状态变化事件
  Future<void> _subscribeToAuthChanges() async {
    _authSubscription?.cancel(); // 取消之前的订阅

    _authSubscription = AuthService.authStatusChanges.listen((event) async {
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
    // 并行加载历史和喜欢数据
    await Future.wait([
      _loadLikedAudios(),
      // AudioHistoryManager.instance.refreshHistory(),
    ]);
  }

  /// 登出后清空页面数据
  Future<void> _clearDataAfterLogout() async {
    debugPrint('👤 [PROFILE] 用户已登出，清空页面数据');

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
      // 先检查认证状态
      final signedIn = await AuthService.isSignedIn();
      
      if (mounted) {
        setState(() {
          isLoggedIn = signedIn;
        });
      }

      if (signedIn) {
        // 获取用户信息
        final user = await AuthService.getCurrentUser();
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
            likedAudios.clear();
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
          likedAudios.clear();
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
      final newLoginState = await AuthService.isSignedIn();

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
            likedAudios.clear();
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
          likedAudios.clear();
        });
      }
    } 
  }

  /// 刷新用户信息
  Future<void> _refreshUserInfo() async {
    try {
      final user = await AuthService.getCurrentUser();
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

  // 加载喜欢数据
  Future<void> _loadLikedAudios() async {
    debugPrint(
      '👤 [PROFILE] 加载喜欢数据, _isLoadingLiked: ${_isLoadingLiked}, isLoggedIn: ${isLoggedIn}',
    );
    
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
        debugPrint('👤 [PROFILE] 成功加载 ${likesList.length} 个喜欢的音频');
      }
    } catch (e) {
      debugPrint('加载喜欢数据失败: $e');
      // 加载失败时，确保UI状态正确
      if (mounted) {
        setState(() {
          likedAudios = [];
        });
      }
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
      debugPrint('刷新喜欢数据失败: $e');
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
      debugPrint('加载更多喜欢数据失败: $e');
    } finally {
      if (mounted) {
        setState(() {
          _isLoadingLiked = false;
        });
      }
    }
  }

  void _onAudioListItemTap(AudioItem audio) async {
    AudioManager.instance.playAudio(audio);
    NavigationUtils.navigateToAudioPlayer(context, initialAudio: audio);
  }

  // 订阅按钮点击
  void _onSubscribeTap() {
    showSubscribeDialog(context);
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
              child: PremiumAccessCard(onSubscribe: _onSubscribeTap),
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
                    fontWeight: FontWeight.w400,
                  ),
                  unselectedLabelStyle: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w400,
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
                  // History 标签页 - 从AudioHistoryManager获取数据并监听事件流
                  _HistoryTabContent(
                    currentAudioId: currentAudioId,
                    onItemTap: _onAudioListItemTap,
                  ),
                  // Like 标签页
                  _isLoadingLiked && likedAudios.isEmpty
                      ? _buildLoadingWidget()
                      : likedAudios.isEmpty
                      ? _buildEmptyWidget('No liked content')
                      : AudioList(
                          audios: likedAudios,
                          activeId: currentAudioId,
                          padding: const EdgeInsets.only(bottom: 120),
                          emptyWidget: _buildEmptyWidget('No liked content'),
                          onRefresh: _refreshLikedAudios, // 改为刷新方法
                          onLoadMore: _loadMoreLikedAudios,
                          hasMoreData: true,
                          isLoadingMore: _isLoadingLiked, // 添加加载状态
                          onItemTap: _onAudioListItemTap,
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

/// 历史记录标签页内容组件
class _HistoryTabContent extends StatefulWidget {
  final String currentAudioId;
  final void Function(AudioItem) onItemTap;

  const _HistoryTabContent({
    required this.currentAudioId,
    required this.onItemTap,
  });

  @override
  State<_HistoryTabContent> createState() => _HistoryTabContentState();
}

class _HistoryTabContentState extends State<_HistoryTabContent> {
  List<AudioItem> _historyList = [];
  StreamSubscription<List<AudioItem>>? _historyStreamSubscription;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _initializeHistory();
  }

  /// 初始化历史记录数据
  Future<void> _initializeHistory() async {
    try {
      // 获取初始历史记录数据
      final historyList = await AudioHistoryManager.instance.getAudioHistory();
      if (mounted) {
        setState(() {
          _historyList = historyList;
          _isLoading = false;
        });
      }

      // 监听历史记录变更事件流
      _historyStreamSubscription = AudioHistoryManager.instance.historyStream
          .listen((updatedHistory) {
            if (mounted) {
              setState(() {
                _historyList = updatedHistory;
              });
            }
          });
    } catch (e) {
      debugPrint('初始化历史记录失败: $e');
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _refreshHistory() async {
    try {
      await AudioHistoryManager.instance.refreshHistory();
    } catch (e) {
      debugPrint('刷新历史记录失败: $e');
    }
  }

  @override
  void dispose() {
    _historyStreamSubscription?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Column(
        children: [
          Expanded(child: Center(child: CircularProgressIndicator())),
          const SizedBox(height: 180),
        ],
      );
    }

    if (_historyList.isEmpty) {
      return Column(
        children: [
          Expanded(
            child: Center(
              child: Text(
                'No history',
                style: TextStyle(color: Colors.grey, fontSize: 14),
              ),
            ),
          ),
          const SizedBox(height: 180),
        ],
      );
    }

    return AudioList(
      padding: const EdgeInsets.only(bottom: 120),
      audios: _historyList,
      activeId: widget.currentAudioId,
      emptyWidget: Column(
        children: [
          Expanded(
            child: Center(
              child: Text(
                'No history',
                style: TextStyle(color: Colors.grey, fontSize: 14),
              ),
            ),
          ),
          const SizedBox(height: 180),
        ],
      ),
      onRefresh: _refreshHistory,
      hasMoreData: false,
      onItemTap: widget.onItemTap,
    );
  }
}
