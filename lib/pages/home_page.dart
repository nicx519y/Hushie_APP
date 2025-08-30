import 'package:flutter/material.dart';
import '../components/custom_app_bar.dart';
import '../components/audio_grid.dart';
import 'search_page.dart';
import 'audio_player_page.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  List<Map<String, dynamic>> _dataList = [];
  bool _isLoading = true;
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    _loadImages();
  }

  Future<void> _loadImages() async {
    loadDataList();
  }

  void loadDataList() {
    setState(() {
      _dataList = [
        {
          'id': '1',
          'cover': 'https://picsum.photos/300/400?random=1',
          'title': 'Music in the Wires - From A to Z (Extended)',
          'desc': 'The dark pop-rock track +22',
          'author': 'Buddah Bless',
          'avatar': 'https://picsum.photos/40/40?random=101',
          'play_times': 13000,
          'likes_count': 168,
        },
        {
          'id': '2',
          'cover': 'https://picsum.photos/300/400?random=2',
          'title': 'Sticky Situation',
          'desc': 'A female vocalist sings a +133',
          'author': 'Misha Whisky',
          'avatar': 'https://picsum.photos/40/40?random=102',
          'play_times': 639,
          'likes_count': 18,
        },
        {
          'id': '3',
          'cover': 'https://picsum.photos/300/400?random=3',
          'title': 'Dark side (Remix and Extended)',
          'desc': 'Female vocals, grunge +249',
          'author': 'Jaccuse Angle',
          'avatar': 'https://picsum.photos/40/40?random=103',
          'play_times': 18000,
          'likes_count': 996,
        },
        {
          'id': '4',
          'cover': 'https://picsum.photos/300/400?random=4',
          'title': 'Matched Yours (rock) from Scratch',
          'desc': 'Genre Tags Slowcore, Trip +30',
          'author': 'Foggy Queen',
          'avatar': 'https://picsum.photos/40/40?random=104',
          'play_times': 2500,
          'likes_count': 45,
        },
        {
          'id': '5',
          'cover': 'https://picsum.photos/300/400?random=5',
          'title': 'Electric Dreams - Synthwave Mix',
          'desc': 'Retro synthwave vibes +156',
          'author': 'Neon Pulse',
          'avatar': 'https://picsum.photos/40/40?random=105',
          'play_times': 8900,
          'likes_count': 234,
        },
        {
          'id': '6',
          'cover': 'https://picsum.photos/300/400?random=6',
          'title': 'Midnight Jazz Session',
          'desc': 'Smooth jazz improvisation +89',
          'author': 'Jazz Master',
          'avatar': 'https://picsum.photos/40/40?random=106',
          'play_times': 4200,
          'likes_count': 127,
        },
        {
          'id': '7',
          'cover': 'https://picsum.photos/300/400?random=7',
          'title': 'Urban Beats Collection',
          'desc': 'Hip-hop instrumentals +312',
          'author': 'Beat Maker',
          'avatar': 'https://picsum.photos/40/40?random=107',
          'play_times': 15600,
          'likes_count': 445,
        },
        {
          'id': '8',
          'cover': 'https://picsum.photos/300/400?random=8',
          'title': 'Acoustic Serenity',
          'desc': 'Peaceful acoustic melodies +67',
          'author': 'String Theory',
          'avatar': 'https://picsum.photos/40/40?random=108',
          'play_times': 7800,
          'likes_count': 189,
        },
        {
          'id': '9',
          'cover': 'https://picsum.photos/300/400?random=9',
          'title': 'Electronic Fusion',
          'desc': 'Experimental electronic +203',
          'author': 'Digital Mind',
          'avatar': 'https://picsum.photos/40/40?random=109',
          'play_times': 11200,
          'likes_count': 298,
        },
        {
          'id': '10',
          'cover': 'https://picsum.photos/300/400?random=10',
          'title': 'Classical Reimagined',
          'desc': 'Modern classical arrangements +134',
          'author': 'Symphony Now',
          'avatar': 'https://picsum.photos/40/40?random=110',
          'play_times': 6300,
          'likes_count': 167,
        },
      ];
      _isLoading = false;
    });
  }

  // 搜索功能
  void _onSearchChanged(String query) {
    setState(() {
      _searchQuery = query;
    });
  }

  void _onSearchSubmitted() {
    // 实现搜索逻辑
    print('搜索: $_searchQuery');
  }

  // 搜索框点击事件
  void _onSearchTap() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const SearchPage()),
    );
  }

  // 获取过滤后的数据
  List<Map<String, dynamic>> get _filteredDataList {
    if (_searchQuery.isEmpty) {
      return _dataList;
    }
    return _dataList.where((item) {
      final title = item['title'].toString().toLowerCase();
      final author = item['author'].toString().toLowerCase();
      final desc = item['desc'].toString().toLowerCase();
      final query = _searchQuery.toLowerCase();

      return title.contains(query) ||
          author.contains(query) ||
          desc.contains(query);
    }).toList();
  }

  // 处理视频项点击
  void _onAudioTap(Map<String, dynamic> item) {
    print('点击视频: ${item['title']}');
    // 这里可以导航到视频详情页
  }

  // 处理播放按钮点击
  void _onPlayTap(Map<String, dynamic> item) {
    print('播放视频: ${item['title']}');
    Navigator.push(
      context,
      PageRouteBuilder(
        pageBuilder: (context, animation, secondaryAnimation) =>
            AudioPlayerPage(
              audioTitle: item['title'] ?? 'Unknown Title',
              artist: item['author'] ?? 'Unknown Artist',
              description: item['desc'] ?? 'No description available',
              likesCount: item['likes_count'] ?? 0,
              audioUrl: 'https://example.com/audio.mp4',
              coverUrl:
                  item['cover'] ?? 'https://picsum.photos/400/600?random=1',
            ),
        transitionDuration: const Duration(milliseconds: 300),
        reverseTransitionDuration: const Duration(milliseconds: 300),
        transitionsBuilder: (context, animation, secondaryAnimation, child) {
          // 从下到上的滑动动画
          const begin = Offset(0.0, 1.0); // 从底部开始
          const end = Offset.zero; // 到正常位置
          const curve = Curves.easeInOut;

          var tween = Tween(
            begin: begin,
            end: end,
          ).chain(CurveTween(curve: curve));

          return SlideTransition(
            position: animation.drive(tween),
            child: child,
          );
        },
      ),
    );
  }

  // 处理点赞按钮点击
  void _onLikeTap(Map<String, dynamic> item) {
    print('点赞视频: ${item['title']}');
    // 这里可以实现点赞逻辑
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // 自定义头部
        CustomAppBar(
          hintText: 'Search audio',
          onSearchChanged: _onSearchChanged,
          onSearchSubmitted: _onSearchSubmitted,
          onSearchTap: _onSearchTap,
        ),
        // 内容区域
        Expanded(
          child: AudioGrid(
            dataList: _filteredDataList,
            isLoading: _isLoading,
            onRefresh: _loadImages,
            onItemTap: _onAudioTap,
            onPlayTap: _onPlayTap,
            onLikeTap: _onLikeTap,
          ),
        ),
      ],
    );
  }
}
