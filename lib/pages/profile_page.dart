import 'package:flutter/material.dart';
import '../models/audio_item.dart';
import '../models/tab_item.dart';
import '../models/audio_history.dart';
import '../components/custom_tab_bar.dart';
import '../components/audio_list.dart';
import '../components/user_header.dart';
import '../components/premium_access_card.dart';
import '../services/audio_history_manager.dart';
import 'package:flutter_svg/flutter_svg.dart';

class ProfilePage extends StatefulWidget {
  const ProfilePage({super.key});

  @override
  State<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage>
    with TickerProviderStateMixin {
  // 模拟登录状态
  bool isLoggedIn = false;
  String userName = 'Queen X';

  // 标签页状态
  late TabController _tabController;
  int currentTabIndex = 0;

  // 定义 tabs
  late List<TabItem> _tabItems;

  // 音频数据
  List<AudioHistory> historyAudios = [];
  List<AudioItem> likedAudios = [];
  bool _isLoadingHistory = false;

  @override
  void initState() {
    super.initState();
    _initTabs();
    _initMockData();
  }

  void _initTabs() {
    _tabItems = [
      const TabItem(id: 'history', title: 'History', order: 0),
      const TabItem(id: 'like', title: 'Like', order: 1),
    ];

    _tabController = TabController(length: _tabItems.length, vsync: this);
    _tabController.addListener(() {
      if (_tabController.indexIsChanging) {
        setState(() {
          currentTabIndex = _tabController.index;
        });
      }
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  void _initMockData() async {
    // 从 AudioHistoryManager 获取历史数据
    await _loadHistoryData();

    // 模拟喜欢的音频数据（暂时保留，后续可以改为从其他接口获取）
    likedAudios = [
      AudioItem(
        id: '1',
        cover: '',
        title: 'Music in the Wires - From A to Z ...',
        desc: 'The dark pop-rock track opens extended +22',
        author: 'Buddha',
        avatar: '',
        playTimes: 1300,
        likesCount: 2293,
      ),
      AudioItem(
        id: '2',
        cover: '',
        title: 'Sticky Situation',
        desc: 'A female vocalist sings a monster related +19',
        author: 'Misha G',
        avatar: '',
        playTimes: 1300,
        likesCount: 2293,
      ),
      AudioItem(
        id: '3',
        cover: '',
        title: 'Matched Yours (rock) from Scratch',
        desc: 'Lo-fi, electronics, nostalgic, and reggaeton',
        author: 'ElJay',
        avatar: '',
        playTimes: 1300,
        likesCount: 2293,
      ),
      AudioItem(
        id: '4',
        cover: '',
        title: 'Matched Yours (rock) from Scratch',
        desc: 'Lo-fi, electronics, nostalgic, and reggaeton',
        author: 'ElJay',
        avatar: '',
        playTimes: 1300,
        likesCount: 2293,
      ),
    ];
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: SafeArea(
        child: Container(
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              // 设置按钮
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  Container(
                    decoration: const BoxDecoration(color: Colors.white),
                    child: InkWell(
                      onTap: () {
                        // 设置页面逻辑
                      },
                      child: Padding(
                        padding: const EdgeInsets.all(8.0),
                        child: SvgPicture.asset(
                          'assets/icons/setup.svg',
                          width: 20,
                          height: 20,
                        ),
                      ),
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 5),

              // 用户头部组件
              UserHeader(
                isLoggedIn: isLoggedIn,
                userName: userName,
                onLoginTap: () {
                  setState(() {
                    isLoggedIn = false;
                  });
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
              if (currentTabIndex == 0) // 只在 History tab 显示刷新按钮
                IconButton(
                  onPressed: _loadHistoryData,
                  icon: const Icon(Icons.refresh, size: 20),
                  tooltip: '刷新历史',
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
                                cover: history.coverUrl ?? '',
                                title: history.title,
                                desc: history.description ?? '',
                                author: history.artist,
                                avatar: '',
                                playTimes: history.likesCount ?? 0,
                                likesCount: history.likesCount ?? 0,
                              ),
                            )
                            .toList(),
                        emptyWidget: _buildEmptyWidget('No history'),
                      ),
                // Like 标签页
                AudioList(
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
                    'Log in to access data.',
                    style: TextStyle(fontSize: 16, color: Color(0xFFC1C1C1)),
                  ),
                  const SizedBox(height: 24),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 20,
                      vertical: 12,
                    ),
                    decoration: BoxDecoration(
                      border: Border.all(color: Color(0xFFC1C1C1)),
                      borderRadius: BorderRadius.circular(25),
                    ),
                    child: InkWell(
                      onTap: () {
                        setState(() {
                          isLoggedIn = true;
                        });
                      },
                      child: const Text(
                        'Sign up / Log in',
                        style: TextStyle(fontSize: 16, color: Colors.grey),
                      ),
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
