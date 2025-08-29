import 'package:flutter/material.dart';
import 'package:flutter_svg/svg.dart';
import '../components/video_progress_bar.dart';
import '../components/play_arrow_icon.dart';

class VideoPlayerPage extends StatefulWidget {
  final String videoTitle;
  final String artist;
  final String description;
  final int likesCount;
  final String videoUrl;
  final String coverUrl;

  const VideoPlayerPage({
    super.key,
    required this.videoTitle,
    required this.artist,
    required this.description,
    required this.likesCount,
    required this.videoUrl,
    required this.coverUrl,
  });

  @override
  State<VideoPlayerPage> createState() => _VideoPlayerPageState();
}

class _VideoPlayerPageState extends State<VideoPlayerPage> {
  bool _isPlaying = false;
  Duration _currentPosition = Duration.zero;
  Duration _totalDuration = const Duration(minutes: 3, seconds: 51);
  bool _showControls = true;

  @override
  void initState() {
    super.initState();
    // 模拟视频加载
    _loadVideo();
  }

  void _loadVideo() {
    // 这里应该是实际的视频加载逻辑
    // 现在使用模拟数据
    setState(() {
      _totalDuration = const Duration(minutes: 3, seconds: 51);
      _currentPosition = const Duration(seconds: 2);
    });
  }

  void _togglePlay() {
    setState(() {
      _isPlaying = !_isPlaying;
    });
    // 这里应该控制实际的视频播放/暂停
  }

  void _onSeek(Duration position) {
    setState(() {
      _currentPosition = position;
    });
    // 这里应该控制实际的视频跳转
  }

  void _toggleControls() {
    setState(() {
      _showControls = !_showControls;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: GestureDetector(
        onTap: _toggleControls,
        child: Stack(
          children: [
            _buildVideoBackground(),
            _buildStatusBar(),
            if (_showControls) _buildControlBar(),
          ],
        ),
      ),
    );
  }

  // 构建视频背景
  Widget _buildVideoBackground() {
    return Positioned.fill(
      child: Container(
        decoration: BoxDecoration(
          image: DecorationImage(
            image: NetworkImage(widget.coverUrl),
            fit: BoxFit.cover,
          ),
        ),
        child: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                Colors.transparent,
                Colors.black.withOpacity(0.3),
                Colors.black.withOpacity(0.7),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // 构建状态栏
  Widget _buildStatusBar() {
    return Positioned(
      top: 0,
      left: 0,
      right: 0,
      child: Container(
        padding: EdgeInsets.only(
          top: MediaQuery.of(context).padding.top + 10,
          left: 28,
          right: 28,
          bottom: 10,
        ),
        child: Row(children: [_buildCloseButton()]),
      ),
    );
  }

  // 构建控制栏
  Widget _buildControlBar() {
    return Positioned(
      left: 0,
      right: 0,
      bottom: 0,
      child: Container(
        padding: EdgeInsets.only(
          left: 28,
          right: 28,
          bottom: MediaQuery.of(context).padding.bottom + 20,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildVideoInfo(),
            const SizedBox(height: 30),
            _buildProgressBar(),
            const SizedBox(height: 20),
            _buildPlaybackControls(),
            const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }

  // 构建关闭按钮
  Widget _buildCloseButton() {
    return IconButton(
      style: IconButton.styleFrom(
        padding: EdgeInsets.zero,
        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
        backgroundColor: const Color(0x66000000),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        minimumSize: const Size(40, 40),
      ),
      onPressed: () => Navigator.pop(context),
      icon: SvgPicture.asset(
        'assets/icons/arrow_down.svg',
        color: Colors.white,
        width: 14.07,
        height: 8.49,
      ),
    );
  }

  // 构建视频信息
  Widget _buildVideoInfo() {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildVideoTitle(),
              const SizedBox(height: 8),
              _buildArtistInfo(),
              const SizedBox(height: 18),
              _buildVideoDescription(),
            ],
          ),
        ),
        const SizedBox(width: 16),
        _buildLikeButton(),
      ],
    );
  }

  // 构建视频标题
  Widget _buildVideoTitle() {
    return Text(
      widget.videoTitle,
      style: const TextStyle(
        color: Colors.white,
        fontSize: 20,
        fontWeight: FontWeight.w600,
      ),
    );
  }

  // 构建艺术家信息
  Widget _buildArtistInfo() {
    return Row(
      children: [
        const Icon(Icons.person, color: Colors.white, size: 16),
        const SizedBox(width: 4),
        Text(
          widget.artist,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 14,
            fontWeight: FontWeight.w400,
          ),
        ),
      ],
    );
  }

  // 构建视频描述
  Widget _buildVideoDescription() {
    return Text(
      widget.description,
      style: const TextStyle(
        color: Colors.white,
        fontSize: 14,
        fontWeight: FontWeight.w400,
      ),
      maxLines: 2,
      overflow: TextOverflow.ellipsis,
    );
  }

  // 构建点赞按钮
  Widget _buildLikeButton() {
    return Column(
      children: [
        IconButton(
          style: IconButton.styleFrom(
            padding: EdgeInsets.zero,
            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
            backgroundColor: const Color(0x66000000),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20),
            ),
            minimumSize: const Size(40, 40),
          ),
          onPressed: () {},
          icon: SvgPicture.asset(
            'assets/icons/likes.svg',
            color: Colors.white,
            width: 24,
            height: 14,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          '${widget.likesCount}',
          style: const TextStyle(
            color: Colors.white,
            fontSize: 12,
            fontWeight: FontWeight.w400,
          ),
        ),
      ],
    );
  }

  // 构建进度条
  Widget _buildProgressBar() {
    return VideoProgressBar(
      currentPosition: _currentPosition,
      totalDuration: _totalDuration,
      onSeek: _onSeek,
    );
  }

  // 构建播放控制按钮
  Widget _buildPlaybackControls() {
    return Row(
      children: [
        _buildPlaylistButton(),
        Expanded(
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [_buildPlayPauseButton()],
          ),
        ),
        const SizedBox(width: 19.5), // 占位按钮保持对称
      ],
    );
  }

  // 构建播放列表按钮
  Widget _buildPlaylistButton() {
    return IconButton(
      style: IconButton.styleFrom(
        minimumSize: Size.zero,
        padding: EdgeInsets.zero,
        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
      ),
      onPressed: () {
        // 播放列表功能
      },
      icon: SvgPicture.asset(
        'assets/icons/menu.svg',
        color: Colors.white,
        width: 19.5,
        height: 18.27,
      ),
    );
  }

  // 构建播放/暂停按钮
  Widget _buildPlayPauseButton() {
    return GestureDetector(
      onTap: _togglePlay,
      child: IconButton(
        style: ButtonStyle(
          backgroundColor: WidgetStateProperty.all(Colors.transparent),
        ),
        onPressed: _togglePlay,
        icon: SvgPicture.asset(
          !_isPlaying
              ? 'assets/icons/play_btn.svg'
              : 'assets/icons/pause_btn.svg',
        ),
      ),
    );
  }
}
