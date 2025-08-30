import 'package:flutter/material.dart';
import '../components/custom_app_bar.dart';
import '../components/audio_grid.dart';
import '../models/audio_item.dart';
import '../services/api_service.dart';
import 'search_page.dart';
import 'audio_player_page.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  List<AudioItem> _audioItems = [];
  bool _isLoading = true;
  String _searchQuery = '';
  String? _errorMessage;
  int _currentPage = 1;
  final int _pageSize = 10;
  bool _hasMoreData = true;

  @override
  void initState() {
    super.initState();
    _loadAudioData();
  }

  Future<void> _loadAudioData({bool refresh = false}) async {
    if (refresh) {
      setState(() {
        _isLoading = true;
        _currentPage = 1;
        _audioItems.clear();
        _errorMessage = null;
        _hasMoreData = true;
      });
    }

    try {
      final response = await ApiService.getHomeAudioList(
        page: _currentPage,
        pageSize: _pageSize,
        searchQuery: _searchQuery.isNotEmpty ? _searchQuery : null,
      );

      if (mounted) {
        setState(() {
          _isLoading = false;

          if (response.success && response.data != null) {
            if (refresh || _currentPage == 1) {
              _audioItems = response.data!.items;
            } else {
              _audioItems.addAll(response.data!.items);
            }
            _hasMoreData = response.data!.hasNextPage;
            _errorMessage = null;
          } else {
            _errorMessage = response.message;
          }
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _errorMessage = '加载失败: $e';
        });
      }
    }
  }

  Future<void> _loadMoreData() async {
    if (!_hasMoreData || _isLoading) return;

    setState(() {
      _currentPage++;
    });

    await _loadAudioData();
  }

  // 获取用于显示的数据列表（转换为 Map 格式以兼容现有组件）
  List<Map<String, dynamic>> get _filteredDataList {
    return _audioItems.map((item) => item.toMap()).toList();
  }

  void _onSearchChanged(String query) {
    setState(() {
      _searchQuery = query;
    });

    // 延迟搜索，避免频繁请求
    Future.delayed(const Duration(milliseconds: 500), () {
      if (_searchQuery == query) {
        _loadAudioData(refresh: true);
      }
    });
  }

  void _onSearchSubmitted() {
    _loadAudioData(refresh: true);
  }

  void _onSearchTap() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const SearchPage()),
    );
  }

  void _onAudioTap(Map<String, dynamic> item) {
    Navigator.push(
      context,
      PageRouteBuilder(
        pageBuilder: (context, animation, secondaryAnimation) => AudioPlayerPage(
          audioTitle: item['title'],
          artist: item['author'],
          description: item['desc'],
          likesCount: item['likes_count'],
          audioUrl:
              item['audio_url'] ??
              'https://www.soundhelix.com/examples/mp3/SoundHelix-Song-1.mp3',
          coverUrl: item['cover'],
        ),
        transitionDuration: const Duration(milliseconds: 300),
        reverseTransitionDuration: const Duration(milliseconds: 300),
        transitionsBuilder: (context, animation, secondaryAnimation, child) {
          const begin = Offset(0.0, 1.0);
          const end = Offset.zero;
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

  void _onPlayTap(Map<String, dynamic> item) {
    print('播放音频: ${item['title']}');
    // 这里可以实现播放逻辑
    _onAudioTap(item); // 暂时跳转到播放页面
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

        // API 模式切换按钮（开发用）
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                '当前模式: ${ApiService.currentMode == ApiMode.mock ? 'Mock 数据' : '真实接口'}',
                style: const TextStyle(fontSize: 12, color: Colors.grey),
              ),
              TextButton(onPressed: _toggleApiMode, child: const Text('切换模式')),
            ],
          ),
        ),

        // 内容区域
        Expanded(
          child: _errorMessage != null
              ? _buildErrorWidget()
              : AudioGrid(
                  dataList: _filteredDataList,
                  isLoading: _isLoading,
                  onRefresh: () => _loadAudioData(refresh: true),
                  onItemTap: _onAudioTap,
                  onPlayTap: _onPlayTap,
                  onLikeTap: _onLikeTap,
                ),
        ),
      ],
    );
  }

  Widget _buildErrorWidget() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.error_outline, size: 64, color: Colors.grey[400]),
          const SizedBox(height: 16),
          Text(
            _errorMessage!,
            style: const TextStyle(color: Colors.grey, fontSize: 16),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 16),
          ElevatedButton(
            onPressed: () => _loadAudioData(refresh: true),
            child: const Text('重试'),
          ),
        ],
      ),
    );
  }
}
