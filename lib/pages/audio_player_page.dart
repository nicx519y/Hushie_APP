import 'package:flutter/material.dart';
import 'package:hushie_app/services/auth_service.dart';
import '../models/audio_item.dart';
import '../services/audio_manager.dart';
import '../services/api/audio_like_service.dart';
import '../components/audio_progress_bar.dart';
import '../utils/custom_icons.dart';
import '../components/history_list.dart';
import '../components/fallback_image.dart';
import '../utils/number_formatter.dart';
import '../router/navigation_utils.dart';
import 'package:just_audio/just_audio.dart';

/// 音频播放器页面专用的上滑过渡效果
class SlideUpPageRoute<T> extends PageRouteBuilder<T> {
  final Widget page;

  SlideUpPageRoute({required this.page})
    : super(
        pageBuilder: (context, animation, secondaryAnimation) => page,
        transitionDuration: const Duration(milliseconds: 300),
        reverseTransitionDuration: const Duration(milliseconds: 300),
        maintainState: true,
        fullscreenDialog: true,
        opaque: false,
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

  @override
  bool get popGestureEnabled => false;

  @override
  Future<RoutePopDisposition> willPop() async {
    return RoutePopDisposition.pop;
  }
}

class AudioPlayerPage extends StatefulWidget {
  const AudioPlayerPage({super.key});

  /// 使用标准上滑动画打开播放器页面

  @override
  State<AudioPlayerPage> createState() => _AudioPlayerPageState();
}

class _AudioPlayerPageState extends State<AudioPlayerPage> {
  bool _isPlaying = false;
  Duration _currentPosition = Duration.zero;
  Duration _totalDuration = Duration.zero;
  Duration _previewStartPosition = Duration.zero;
  Duration _previewDuration = Duration.zero;
  bool _canPlayAllDuration = true;

  late AudioManager _audioManager;
  AudioItem? _currentAudio;
  bool _isLiked = false;
  bool _isAudioLoading = false; // 是否正在加载metadata

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
          
          _totalDuration = Duration(milliseconds: audio!.durationMs!);

        });
      }
    });

    // 是否能播放全部时长，否则只能播放预览时长
    _audioManager.canPlayAllDurationStream.listen((canPlayAll) {
      if (mounted) {
        setState(() {
          _canPlayAllDuration = canPlayAll;
        });
      }
    });

    // 监听音频播放状态
    // _audioManager.isPlayingStream.listen((isPlaying) {
    //   if (mounted) {
    //     setState(() {
    //       _isPlaying = isPlaying;
    //     });
    //   }
    // });

    // 监听播放位置 - 使用防抖动技术减少更新频率
    _audioManager.positionStream
    // .debounceTime(const Duration(milliseconds: 200)) // 添加200ms的防抖动
    .listen((position) {
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
          // _totalDuration = duration.totalDuration;
          // 如果通过音频流获取到了时长，也要结束加载状态
          if (duration.totalDuration > Duration.zero) {
            _totalDuration = duration.totalDuration;
            _previewStartPosition = duration.previewStart ?? Duration.zero;
            _previewDuration = duration.previewDuration ?? Duration.zero;
          }
        });
      }
    });

    _audioManager.playerStateStream.listen((playerState) {
      if (mounted) {
        setState(() {
          _isPlaying = playerState.playing;
          if(playerState.processingState == ProcessingState.loading || playerState.processingState == ProcessingState.buffering) {
            _isAudioLoading = true;
          } else {
            _isAudioLoading = false;
          }
        });
      }
    });
  }

  void _togglePlay() {
    // 如果正在加载metadata，不允许播放
    if (_isAudioLoading) return;

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
    final isLogin = await AuthService.isSignedIn();
    if (!isLogin) {
      // 打开登录页
      NavigationUtils.navigateToLogin(context);
      return;
    }

    // 如果正在请求中，直接返回
    if (_isLikeRequesting) return;

    // 如果当前音频为空，直接返回
    if (_currentAudio == null) return;

    // 设置请求状态
    setState(() {
      _isLikeRequesting = true;
    });

    try {
      // 调用API
      final response = await AudioLikeService.likeAudio(
        audioId: _currentAudio!.id,
        isLiked: !_localIsLiked,
      );

      final finalIsLiked = response['is_liked'];
      final finalLikesCount = response['likes_count'];

      setState(() {
        _localIsLiked = finalIsLiked;
        _localLikesCount = finalLikesCount;
      });
    } catch (e) {
      // 网络异常，回滚本地状态
      print('点赞操作异常: $e');
    } finally {
      // 重置请求状态
      setState(() {
        _isLikeRequesting = false;
      });
    }
  }

  void _onPlaylistButtonTap() async {
    final isLogin = await AuthService.isSignedIn();
    if (!isLogin) {
      // 打开登录页
      NavigationUtils.navigateToLogin(context);
      return;
    }

    showHistoryListWithAnimation(
      context,
      onItemTap: (audio) {
        _audioManager.playAudio(audio);
      },
    );
  }

  Future<void> _onSeek(Duration position) async {
    await _audioManager.seek(position);
  }

  // 解锁全功能提示点击事件
  void _onUnlockFullAccessTap() async {}

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
    final bgImageUrl = _currentAudio?.bgImage
        ?.getBestResolution(screenWidth)
        .url;

    return Positioned.fill(
      child: Stack(
        children: [
          // 背景图片层 - 使用RepaintBoundary避免频繁重绘
          RepaintBoundary(child: _buildBackgroundImage(bgImageUrl)),
          // 渐变遮罩层
          Container(
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
        ],
      ),
    );
  }

  // 缓存当前背景图片URL
  String? _cachedBgImageUrl;
  // 缓存的背景图片组件
  Widget? _cachedBackgroundImage;

  // 构建背景图片，包含备用图片逻辑和缓存机制
  Widget _buildBackgroundImage(String? imageUrl) {
    // 如果图片URL没有变化，直接返回缓存的组件
    if (_cachedBgImageUrl == imageUrl && _cachedBackgroundImage != null) {
      return _cachedBackgroundImage!;
    }

    // 更新缓存
    _cachedBgImageUrl = imageUrl;
    _cachedBackgroundImage = FallbackImage(
      imageUrl: imageUrl,
      fallbackImage: 'assets/images/backup.png',
      fit: BoxFit.cover,
      width: double.infinity,
      height: double.infinity,
      fadeInDuration: const Duration(milliseconds: 300),
    );

    return _cachedBackgroundImage!;
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

            Row(
              children: [
              Expanded(child: _buildProgressBar()),
              const SizedBox(width: 10),
              _buildUnlockFullAccessTip()]),
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
            backgroundColor: _localIsLiked
                ? Colors.white
                : const Color(0x66000000),
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
              : Transform.translate(
                  offset: const Offset(0, -1),
                  child: Icon(
                    CustomIcons.likes,
                    color: _localIsLiked ? Color(0xFFFF254E) : Colors.white,
                    size: 14,
                  ),
                ),
        ),
        const SizedBox(height: 4),
        Text(
          NumberFormatter.countNumFilter(_localLikesCount),
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
    // 如果正在加载metadata或没有时长信息，隐藏进度条
    // if (_isLoadingMetadata || _totalDuration == Duration.zero) {
    //   return const SizedBox(height: 40); // 保持布局高度
    // }

    return AnimatedOpacity(
      opacity: 1.0,
      duration: const Duration(milliseconds: 300),
      child: AudioProgressBar(
        currentPosition: _currentPosition,
        totalDuration: _totalDuration,
        onSeek: _onSeek,
        previewStartPosition: _previewStartPosition,
        previewDuration: _previewDuration,
        needInPreviewDuration: !_canPlayAllDuration,
        onOutPreview: _onUnlockFullAccessTap,
      ),
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
      onPressed: _onPlaylistButtonTap,
      icon: Icon(CustomIcons.menu, color: Colors.white, size: 20),
    );
  }

  // 构建播放/暂停按钮
  Widget _buildPlayPauseButton() {
    return IconButton(
      alignment: Alignment.center,
      style: IconButton.styleFrom(
        minimumSize: const Size(64, 64),
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(32)),
      ),
      onPressed: _togglePlay,
      icon: _isAudioLoading
          ? const SizedBox(
              width: 24,
              height: 24,
              child: CircularProgressIndicator(
                strokeWidth: 2.5,
                valueColor: AlwaysStoppedAnimation<Color>(Colors.black),
              ),
            )
          : Transform.translate(
              offset: !_isPlaying
                  ? const Offset(2, 0)
                  : const Offset(0, 0), // 播放箭头向右偏移2像素
              child: Icon(
                !_isPlaying ? CustomIcons.play_arrow : CustomIcons.pause,
                color: Colors.black,
                size: !_isPlaying ? 26 : 22,
              ),
            ),
    );
  }

  // 构建解锁全功能提示
  Widget _buildUnlockFullAccessTip() {
    return InkWell(
      onTap: _onUnlockFullAccessTap,
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            padding: EdgeInsets.all(6),
            decoration: BoxDecoration(
              color: Colors.white.withAlpha(50),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Image.asset(
              'assets/images/crown_mini.png',
              fit: BoxFit.contain,
            ),
          ),
          const SizedBox(width: 4),
          SizedBox(
            width: 86,
            height: 40,
            child: ShaderMask(
              shaderCallback: (bounds) => LinearGradient(
                colors: [Color(0xFFFEED96), Color(0xFFFFC733)],
                begin: Alignment.centerLeft,
                end: Alignment.centerRight,
              ).createShader(bounds),
              child: Text(
                'Unlock\nFull Access',
                maxLines: 2,
                style: TextStyle(
                  color: Colors.white, // 这里必须设置颜色，会被shader覆盖
                  fontSize: 16,
                  height: 1.25,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
