import 'dart:async';
import 'package:flutter/material.dart';
import 'package:hushie_app/components/subscribe_dialog.dart';
import 'package:hushie_app/services/auth_service.dart';
import '../models/audio_item.dart';
import '../services/audio_manager.dart';
import '../services/audio_service.dart';
import '../services/api/audio_like_service.dart';
import '../components/audio_progress_bar.dart';
import '../utils/custom_icons.dart';
import '../components/history_list.dart';
import '../components/fallback_image.dart';
import '../utils/number_formatter.dart';
import '../router/navigation_utils.dart';
import '../services/audio_state_proxy.dart';
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
  final AudioItem? initialAudio;
  
  const AudioPlayerPage({super.key, this.initialAudio});

  /// 使用标准上滑动画打开播放器页面

  @override
  State<AudioPlayerPage> createState() => _AudioPlayerPageState();
}

class _AudioPlayerPageState extends State<AudioPlayerPage> {
  bool _isPlaying = false;
  bool _isPreviewMode = true;
  // Duration _currentPosition = Duration.zero;

  // 移除时长代理服务和渲染相关状态，现在由AudioProgressBar内部管理
 

  late AudioManager _audioManager;
  AudioItem? _currentAudio;
  bool _isLiked = false;
  bool _isAudioLoading = false; // 是否正在加载metadata

  // 点赞相关状态管理
  bool _isLikeRequesting = false; // 是否正在请求点赞
  bool _localIsLiked = false; // 本地点赞状态
  int _localLikesCount = 0; // 本地点赞数

  // 播放列表相关状态管理
  bool _isShowingPlaylist = false; // 是否正在显示播放列表

  bool _isDescExpended = false; // 描述是否展开
  
  // StreamSubscription列表，用于在dispose时取消
  final List<StreamSubscription> _subscriptions = [];
  
  // 本地状态缓存，用于差异对比
  AudioPlayerState? _lastAudioState;

  @override
  void initState() {
    super.initState();
    _audioManager = AudioManager.instance;
    // 只监听音频播放状态，不主动加载音频
    _listenToAudioState();
    
    // 如果有初始音频，用初始音频信息渲染
    if (widget.initialAudio != null) {
      setState(() {
        _currentAudio = widget.initialAudio;
        _isAudioLoading = true;
        _isPreviewMode = _audioManager.isPreviewMode;
      });
    }
  }

  void _listenToAudioState() {
    // 使用代理后的音频状态流，自动处理duration过滤
    final durationProxy = AudioStateProxy.createDurationFilter();
    _subscriptions.add(_audioManager.audioStateStream
        .proxy(durationProxy)
        .listen((audioState) {
      if (mounted) {
        // 如果是第一次接收状态或状态发生变化，才进行处理
        if (_lastAudioState == null || _hasStateChanged(_lastAudioState!, audioState)) {
          bool needsUpdate = false;
          
          // 检查当前音频是否变化
          if (_lastAudioState?.currentAudio?.id != audioState.currentAudio?.id) {
            _currentAudio = audioState.currentAudio;
            _isLiked = _currentAudio?.isLiked ?? false;
            // 初始化本地状态
            _localIsLiked = _isLiked;
            _localLikesCount = _currentAudio?.likesCount ?? 0;
            needsUpdate = true;
          }
          
          // 检查播放状态是否变化
          if (_lastAudioState?.isPlaying != audioState.isPlaying) {
            _isPlaying = audioState.isPlaying;
            needsUpdate = true;
          }
          
          // 检查播放器状态是否变化
          if (_lastAudioState?.playerState.processingState != audioState.playerState.processingState) {
            final playerState = audioState.playerState;
            if (playerState != null) {
              if (playerState.processingState == ProcessingState.loading ||
                  playerState.processingState == ProcessingState.buffering) {
                _isAudioLoading = true;
              } else {
                _isAudioLoading = false;
              }
            }
            needsUpdate = true;
          }
          
          // 检查播放位置是否变化
          if (_lastAudioState?.position != audioState.position) {
            // _currentPosition = audioState.position;
            needsUpdate = true;
          }
          
          // 只有在需要更新时才调用setState
          if (needsUpdate) {
            setState(() {});
          }
          
          // 更新本地状态缓存
          _lastAudioState = audioState;
        }
      }
    }));

    _subscriptions.add(_audioManager.isPreviewModeStream.listen((isPreviewMode) {
      if (mounted) {
        setState(() {
          _isPreviewMode = isPreviewMode;
        });
      }
    }));

    // 监听预览区间即将超出事件
    _subscriptions.add(AudioManager.previewOutEvents.listen((previewOutEvent) {
      if (mounted) {
        debugPrint('🎵 [PLAYER] 预览区间即将超出，触发解锁提示: ${previewOutEvent.position}');
        _onUnlockFullAccessTap();
      }
    }));
  }

  void _togglePlay() {
    // 如果正在加载metadata，不允许播放
    debugPrint(
      '点击了播放/暂停按钮 isAudioLoading: $_isAudioLoading $_isPlaying $_currentAudio.id',
    );
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
    if (_isLikeRequesting == true) {
      return;
    }

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

    // 先立即更新本地状态
    final newIsLiked = !_localIsLiked;
    final newLikesCount = newIsLiked
        ? _localLikesCount + 1
        : _localLikesCount - 1;

    setState(() {
      _localIsLiked = newIsLiked;
      _localLikesCount = newLikesCount;
      _isLikeRequesting = true; // 设置请求状态
    });

    try {
      // 调用API
      await AudioLikeService.likeAudio(
        audioId: _currentAudio!.id,
        isLiked: newIsLiked,
      );

      // 请求成功，不需要再更改本地状态，保持当前状态
    } catch (e) {
      // 网络异常，回滚本地状态
      debugPrint('点赞操作异常: $e');
    } finally {
      // 重置请求状态
      setState(() {
        _isLikeRequesting = false;
      });
    }
  }

  void _onPlaylistButtonTap() async {
    // 如果正在显示播放列表，直接返回
    if (_isShowingPlaylist) return;

    final isLogin = await AuthService.isSignedIn();
    if (!isLogin) {
      // 打开登录页
      NavigationUtils.navigateToLogin(context);
      return;
    }

    // 设置标志位
    setState(() {
      _isShowingPlaylist = true;
    });

    await showHistoryListWithAnimation(
      context,
      onItemTap: (audio) {
        _audioManager.playAudio(audio);
      },
      onClose: () {
        // 播放列表关闭时重置标志位
        if (mounted) {
          setState(() {
            _isShowingPlaylist = false;
          });
        }
      },
    );
  }

  // 移除_createDurationProxy和_onSeek方法，现在由AudioProgressBar内部处理

  // 解锁全功能提示点击事件
  void _onUnlockFullAccessTap() async {
    showSubscribeDialog(context);
  }

  void _onReadMoreTap() {
    setState(() {
      _isDescExpended = !_isDescExpended;
    });
  }

  @override
  void dispose() {
    // 手动取消所有StreamSubscription以避免内存泄漏
    for (final subscription in _subscriptions) {
      subscription.cancel();
    }
    _subscriptions.clear();
    _lastAudioState = null; // 清空状态缓存
    super.dispose();
  }
  
  /// 检查音频状态是否发生实质性变化
  bool _hasStateChanged(AudioPlayerState oldState, AudioPlayerState newState) {
    return oldState.currentAudio?.id != newState.currentAudio?.id ||
           oldState.isPlaying != newState.isPlaying ||
           oldState.position != newState.position ||
           oldState.duration != newState.duration ||
           oldState.speed != newState.speed ||
           oldState.playerState.processingState != newState.playerState.processingState ||
           oldState.renderPreviewStart != newState.renderPreviewStart ||
           oldState.renderPreviewEnd != newState.renderPreviewEnd;
  }

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
        ],
      ),
    );
  }

  // 构建背景图片，包含备用图片逻辑和缓存机制
  Widget _buildBackgroundImage(String? imageUrl) {
    final screenWidth = MediaQuery.of(context).size.width;
    return FallbackImage(
      fit: BoxFit.cover,
      width: screenWidth,
      height: double.infinity,
      imageResource: _currentAudio?.bgImage,
      fallbackImage: 'assets/images/player_bg_backup.jpg',
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
      child: RepaintBoundary(
        child: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              stops: [0, 0.2, 1],
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                Colors.transparent,
                Colors.black.withAlpha(100),
                Colors.black.withAlpha(180),
              ],
            ),
          ),
          padding: EdgeInsets.only(
            top: 40,
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
                  _isPreviewMode ? const SizedBox(width: 10) : const SizedBox.shrink(),
                  _isPreviewMode ? Transform.translate(
                    offset: const Offset(0, -8),
                    child: _buildUnlockFullAccessTip(),
                  ) : const SizedBox.shrink(),
                ],
              ),
              const SizedBox(height: 20),
              _buildPlaybackControls(),
              const SizedBox(height: 40),
            ],
          ),
        ),
      ),
    );
  }

  // 构建关闭按钮
  Widget _buildCloseButton() {
    return IconButton(
      alignment: Alignment.center,
      style: IconButton.styleFrom(
        // tapTargetSize: MaterialTapTargetSize.shrinkWrap,
        backgroundColor: const Color(0x66000000),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        minimumSize: const Size(40, 40),
      ),
      onPressed: () => Navigator.pop(context),
      icon: Transform.translate(
        offset: const Offset(-2.5, 0),
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
        const SizedBox(width: 26),
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

    return InkWell(
      onTap: _onReadMoreTap,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            desc,
            style: const TextStyle(
              // letterSpacing: 0,
              fontSize: 12,
              height: 1.7,
              color: Colors.white,
              // fontWeight: FontWeight.w300,
            ),
            textAlign: TextAlign.left,
            maxLines: _isDescExpended ? 20 : 2,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 6),
          Row(
            children: [
              SizedBox(
                width: 32,
                child: Text(
                  _isDescExpended ? 'Fold' : 'More',
                  style: const TextStyle(
                    fontSize: 12,
                    color: Colors.white,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),

              const SizedBox(width: 6),
              Transform.scale(
                scaleY: _isDescExpended ? -1 : 1,
                alignment: Alignment.center, // 设置旋转中心为组件中心
                child: Icon(
                  CustomIcons.arrow_down,
                  color: Colors.white,
                  size: 9,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // 构建点赞按钮
  Widget _buildLikeButton() {
    return Column(
      children: [
        IconButton(
          style: IconButton.styleFrom(
            padding: EdgeInsets.zero,
            // tapTargetSize: MaterialTapTargetSize.shrinkWrap,
            backgroundColor: _localIsLiked
                ? Colors.white
                : const Color(0x66000000),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20),
            ),
            minimumSize: const Size(40, 40),
          ),
          onPressed: _onLikeButtonPressed, // 请求中禁用按钮
          icon: Transform.translate(
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
    return RepaintBoundary(
      child: AudioProgressBar(
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
        const SizedBox(width: 48), // 占位按钮保持对称
      ],
    );
  }

  // 构建播放列表按钮
  Widget _buildPlaylistButton() {
    return IconButton(
      style: IconButton.styleFrom(
        minimumSize: Size.zero,
        padding: EdgeInsets.zero,
        // tapTargetSize: MaterialTapTargetSize.shrinkWrap,
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
            // width: 92,
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
