import 'package:flutter/material.dart';
import '../models/audio_item.dart';
import '../components/profile_tab_view.dart';
import '../components/profile_tab_header.dart';
import '../components/audio_list.dart';
import '../components/user_header.dart';
import '../components/premium_access_card.dart';
import 'package:flutter_svg/flutter_svg.dart';

class ProfilePage extends StatefulWidget {
  const ProfilePage({super.key});

  @override
  State<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> {
  // 模拟登录状态
  bool isLoggedIn = false;
  String userName = 'Queen X';

  // 标签页状态
  int currentTabIndex = 0;

  // 模拟视频数据
  List<AudioItem> historyaudios = [];
  List<AudioItem> likedaudios = [];

  @override
  void initState() {
    super.initState();
    _initMockData();
  }

  void _initMockData() {
    // 模拟历史视频数据
    historyaudios = [
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
    ];

    // 模拟喜欢的视频数据
    likedaudios = [
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
          ProfileTabHeader(
            currentIndex: currentTabIndex,
            isLoggedIn: isLoggedIn,
            onTabChanged: (index) {
              setState(() {
                currentTabIndex = index;
              });
            },
          ),

          const SizedBox(height: 20),

          // 内容区域
          Expanded(
            child: IndexedStack(
              index: currentTabIndex,
              children: [
                // History 标签页
                AudioList(
                  audios: historyaudios,
                  emptyWidget: const Center(
                    child: Text(
                      '暂无观看历史',
                      style: TextStyle(color: Colors.grey, fontSize: 16),
                    ),
                  ),
                ),
                // Like 标签页
                AudioList(
                  audios: likedaudios,
                  emptyWidget: const Center(
                    child: Text(
                      '暂无喜欢内容',
                      style: TextStyle(color: Colors.grey, fontSize: 16),
                    ),
                  ),
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
          ProfileTabHeader(
            currentIndex: currentTabIndex,
            isLoggedIn: isLoggedIn,
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
}
