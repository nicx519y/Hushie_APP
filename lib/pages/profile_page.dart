import 'package:flutter/material.dart';
import '../models/audio_item.dart';
import '../models/tab_item.dart';
import '../components/custom_tab_bar.dart';
import '../components/audio_list.dart';
import '../components/user_header.dart';
import '../components/premium_access_card.dart';
import '../services/audio_history_manager.dart';
import '../services/api_service.dart';
import '../services/auth_service.dart';
import '../utils/custom_icons.dart';
import 'login_page.dart';

class ProfilePage extends StatefulWidget {
  const ProfilePage({super.key});

  @override
  State<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage>
    with TickerProviderStateMixin {
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
  int _likedPage = 1;
  bool _hasMoreLiked = true;
  String? _lastLikedId; // 用于存储最后一个喜欢的音频ID，以便进行分页

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
    _tabController.dispose();
    super.dispose();
  }

  // 加载历史数据
  Future<void> _loadHistoryData() async {
    setState(() {
      _isLoadingHistory = true;
    });

    try {
      // 从 AudioHistoryManager 获取最近的历史记录
      final historyList = await AudioHistoryManager.instance.getRecentHistory(
        limit: 20,
      );

      setState(() {
        historyAudios = historyList;
        _isLoadingHistory = false;
      });
    } catch (e) {
      print('加载历史数据失败: $e');
      setState(() {
        _isLoadingHistory = false;
      });
    }
  }

  // 加载喜欢的音频数据
  Future<void> _loadLikedAudios({bool refresh = false}) async {
    if (refresh) {
      setState(() {
        _likedPage = 1;
        likedAudios.clear();
        _hasMoreLiked = true;
        _lastLikedId = null; // 刷新时重置最后一个ID
      });
    }

    if (!_hasMoreLiked || _isLoadingLiked) return;

    setState(() {
      _isLoadingLiked = true;
    });

    try {
      final response = await ApiService.getUserLikedAudios(
        cid: _likedPage == 1 ? null : _lastLikedId,
        count: 20,
      );

      if (mounted) {
        setState(() {
          _isLoadingLiked = false;

          if (response.errNo == 0 && response.data != null) {
            if (refresh || _likedPage == 1) {
              likedAudios = response.data!.items;
            } else {
              likedAudios.addAll(response.data!.items);
            }

            // 更新分页信息
            if (response.data!.items.isNotEmpty) {
              _lastLikedId = response.data!.items.last.id;
              _hasMoreLiked = response.data!.items.length >= 20;
            } else {
              _hasMoreLiked = false;
            }
            _likedPage++;
          } else {
            print('获取喜欢音频失败: 错误码 ${response.errNo}');
          }
        });
      }
    } catch (e) {
      print('加载喜欢音频失败: $e');
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
                    onPressed: () {},
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
              // 刷新按钮
              if (currentTabIndex == 0) // History tab 刷新按钮
                IconButton(
                  onPressed: _loadHistoryData,
                  icon: const Icon(Icons.refresh, size: 20),
                  tooltip: '刷新历史',
                ),
              if (currentTabIndex == 1) // Like tab 刷新按钮
                IconButton(
                  onPressed: () => _loadLikedAudios(refresh: true),
                  icon: const Icon(Icons.refresh, size: 20),
                  tooltip: '刷新喜欢',
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
                        audios: historyAudios
                            .map(
                              (history) => AudioItem(
                                id: history.id,
                                cover: history.cover,
                                bgImage: history.bgImage,
                                title: history.title,
                                desc: history.desc,
                                author: history.author,
                                avatar: history.avatar,
                                playTimes: history.playTimes,
                                likesCount: history.likesCount,
                                audioUrl: history.audioUrl,
                                duration: history.duration,
                                createdAt: history.createdAt,
                                tags: history.tags,
                                playbackPosition: history.playbackPosition,
                                lastPlayedAt: history.lastPlayedAt,
                                previewStart: history.previewStart,
                                previewDuration: history.previewDuration,
                              ),
                            )
                            .toList(),
                        emptyWidget: _buildEmptyWidget('No history'),
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
