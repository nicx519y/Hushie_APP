import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../models/audio_item.dart';
import '../services/audio_manager.dart';
import '../services/api/audio_like_service.dart';
import '../components/audio_progress_bar.dart';
import '../utils/custom_icons.dart';

/// 音频播放器页面专用的上滑过渡效果
class SlideUpPageRoute<T> extends PageRouteBuilder<T> {
  final Widget page;

  SlideUpPageRoute({required this.page})
    : super(
        pageBuilder: (context, animation, secondaryAnimation) => page,
        transitionDuration: const Duration(milliseconds: 300),
        reverseTransitionDuration: const Duration(milliseconds: 300),
        transitionsBuilder: (context, animation, secondaryAnimation, child) {
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
      );
}

class AudioPlayerPage extends StatefulWidget {
  const AudioPlayerPage({super.key});

  /// 使用标准上滑动画打开播放器页面
  static Future<T?> show<T extends Object?>(BuildContext context) {
    return Navigator.push<T>(
      context,
      SlideUpPageRoute(page: const AudioPlayerPage()),
    );
  }

  @override
  State<AudioPlayerPage> createState() => _AudioPlayerPageState();
}

class _AudioPlayerPageState extends State<AudioPlayerPage> {
  bool _isPlaying = false;
  Duration _currentPosition = Duration.zero;
  Duration _totalDuration = Duration.zero;
  late AudioManager _audioManager;
  AudioItem? _currentAudio;
  bool _isLiked = false;

  // 点赞相关状态管理
  bool _isLikeRequesting = false; // 是否正在请求点赞
  bool _localIsLiked = false; // 本地点赞状态
  int _localLikesCount = 0; // 本地点赞数

  @override
  void initState() {
    super.initState();
    _audioManager = AudioManager.instance;
    // 只监听音频播放状态，不主动加载音频
    _listenToAudioState();
  }

  void _listenToAudioState() {
    // 监听当前音频
    _audioManager.currentAudioStream.listen((audio) {
      if (mounted) {
        setState(() {
          _currentAudio = audio;
          _isLiked = _currentAudio?.isLiked ?? false;
          // 初始化本地状态
          _localIsLiked = _isLiked;
          _localLikesCount = _currentAudio?.likesCount ?? 0;
        });
      }
    });

    // 监听音频播放状态
    _audioManager.isPlayingStream.listen((isPlaying) {
      if (mounted) {
        setState(() {
          _isPlaying = isPlaying;
        });
      }
    });

    // 监听播放位置
    _audioManager.positionStream.listen((position) {
      if (mounted) {
        setState(() {
          _currentPosition = position;
        });
      }
    });

    // 监听播放时长
    _audioManager.durationStream.listen((duration) {
      if (mounted) {
        setState(() {
          _totalDuration = duration;
        });
      }
    });
  }

  void _togglePlay() {
    if (!_isPlaying) {
      // 如果当前没有播放，或者播放的不是当前音频，则开始播放当前音频
      final currentAudio = _audioManager.currentAudio;
      final currentAudioId = (_currentAudio?.id ?? 'unknown');

      if (currentAudio == null || currentAudio.id != currentAudioId) {
        // 如果没有当前音频信息，无法播放
        if (_currentAudio == null) return;

        // 创建音频模型并播放
        _audioManager.playAudio(_currentAudio!);
      } else {
        // 如果是同一首音频，直接恢复播放
        _audioManager.togglePlayPause();
      }
    } else {
      // 暂停播放
      _audioManager.togglePlayPause();
    }
  }

  void _onLikeButtonPressed() async {
    // 如果正在请求中，直接返回
    if (_isLikeRequesting) return;

    // 如果当前音频为空，直接返回
    if (_currentAudio == null) return;

    // 设置请求状态
    setState(() {
      _isLikeRequesting = true;
    });

    // 先更新本地状态（乐观更新）
    final newIsLiked = !_localIsLiked;
    final newLikesCount = newIsLiked
        ? _localLikesCount + 1
        : _localLikesCount - 1;

    setState(() {
      _localIsLiked = newIsLiked;
      _localLikesCount = newLikesCount;
    });

    try {
      // 调用API
      final response = await AudioLikeService.likeAudio(
        audioId: _currentAudio!.id,
        isLiked: newIsLiked,
      );
      setState(() {
        _localIsLiked = !newIsLiked;
        _localLikesCount = newIsLiked
            ? _localLikesCount - 1
            : _localLikesCount + 1;
      });
    } catch (e) {
      // 网络异常，回滚本地状态
      print('点赞操作异常: $e');
      setState(() {
        _localIsLiked = !newIsLiked;
        _localLikesCount = newIsLiked
            ? _localLikesCount - 1
            : _localLikesCount + 1;
      });
    } finally {
      // 重置请求状态
      setState(() {
        _isLikeRequesting = false;
      });
    }
  }

  void _onSeek(Duration position) {
    _audioManager.seek(position);
  }

  // void _toggleControls() {
  //   setState(() {
  //     _showControls = !_showControls;
  //   });
  // }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: GestureDetector(
        // onTap: _toggleControls,
        child: Stack(
          children: [
            _buildAudioBackground(),
            _buildStatusBar(),
            _buildControlBar(),
          ],
        ),
      ),
    );
  }

  // 构建音频背景
  Widget _buildAudioBackground() {
    final screenWidth = MediaQuery.of(context).size.width;
    final bgImage =
        _currentAudio?.bgImage?.getBestResolution(screenWidth).url ??
        'assets/images/logo.png';

    return Positioned.fill(
      child: Container(
        decoration: BoxDecoration(
          image: DecorationImage(
            image: bgImage.startsWith('http')
                ? NetworkImage(bgImage)
                : AssetImage(bgImage) as ImageProvider,
            fit: BoxFit.cover,
            onError: (exception, stackTrace) {
              print('背景图片加载失败: $exception，使用默认图片');
            },
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
            _buildAudioInfo(),
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
      alignment: Alignment.center,
      style: IconButton.styleFrom(
        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
        backgroundColor: const Color(0x66000000),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        minimumSize: const Size(40, 40),
      ),
      onPressed: () => Navigator.pop(context),
      icon: Transform.translate(
        offset: const Offset(-2, 0),
        child: Icon(CustomIcons.arrow_down, color: Colors.white, size: 9),
      ),
    );
  }

  // 构建音频信息
  Widget _buildAudioInfo() {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildAudioTitle(),
              const SizedBox(height: 8),
              _buildArtistInfo(),
              const SizedBox(height: 10),
              _buildAudioDescription(),
            ],
          ),
        ),
        const SizedBox(width: 16),
        _buildLikeButton(),
      ],
    );
  }

  // 构建音频标题
  Widget _buildAudioTitle() {
    final title = _currentAudio?.title ?? 'Unknown Title';

    return Text(
      title,
      maxLines: 3,
      overflow: TextOverflow.ellipsis,
      style: const TextStyle(
        color: Colors.white,
        fontSize: 16,
        fontWeight: FontWeight.w700,
      ),
    );
  }

  // 构建艺术家信息
  Widget _buildArtistInfo() {
    return Column(
      children: [
        Row(
          children: [
            const Icon(CustomIcons.user, color: Colors.white, size: 12),
            const SizedBox(width: 6),
            Text(
              _currentAudio?.author ?? '',
              style: const TextStyle(
                fontSize: 12,
                color: Colors.white,
                fontWeight: FontWeight.w400,
              ),
            ),
          ],
        ),
      ],
    );
  }

  // 构建音频描述
  Widget _buildAudioDescription() {
    final desc = _currentAudio?.desc ?? 'No description available';

    return Text(
      desc,
      style: const TextStyle(
        fontSize: 12,
        height: 1.4,
        color: Colors.white,
        fontWeight: FontWeight.w300,
      ),
      textAlign: TextAlign.left,
      maxLines: 3,
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
          onPressed: _isLikeRequesting ? null : _onLikeButtonPressed, // 请求中禁用按钮
          icon: _isLikeRequesting
              ? const SizedBox(
                  width: 14,
                  height: 14,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                  ),
                )
              : Icon(
                  CustomIcons.likes,
                  color: _localIsLiked ? Colors.pink : Colors.white,
                  size: 14,
                ),
        ),
        const SizedBox(height: 4),
        Text(
          '${_localLikesCount}',
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
    return AudioProgressBar(
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
        // TODO: 播放列表功能
      },
      icon: Icon(CustomIcons.menu, color: Colors.white, size: 20),
    );
  }

  // 构建播放/暂停按钮
  Widget _buildPlayPauseButton() {
    return GestureDetector(
      onTap: _togglePlay,
      child: IconButton(
        alignment: Alignment.center,
        style: IconButton.styleFrom(
          minimumSize: const Size(64, 64),
          backgroundColor: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(32),
          ),
        ),
        onPressed: _togglePlay,
        icon: Transform.translate(
          offset: !_isPlaying
              ? const Offset(2, 0)
              : const Offset(0, 0), // 播放箭头向右偏移2像素
          child: Icon(
            !_isPlaying ? CustomIcons.play_arrow : CustomIcons.pause,
            color: Colors.black,
            size: !_isPlaying ? 26 : 22,
          ),
        ),
      ),
    );
  }
}
