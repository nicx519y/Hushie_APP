import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:hushie_app/components/subscribe_dialog.dart';
import 'package:hushie_app/services/audio_likes_manager.dart';
import 'package:hushie_app/services/auth_manager.dart';
import 'package:hushie_app/services/subscribe_privilege_manager.dart';
import '../models/audio_item.dart';
import '../services/audio_manager.dart';
import '../services/audio_service.dart';
import '../services/api/audio_detail_service.dart';
import '../components/audio_progress_bar.dart';
import '../utils/custom_icons.dart';
import '../components/audio_history_dialog.dart';
import '../components/fallback_image.dart';
import '../utils/number_formatter.dart';
import '../router/navigation_utils.dart';
import '../services/analytics_service.dart';
import 'package:just_audio/just_audio.dart';
import '../components/swipe_to_close_container.dart';
import '../models/srt_model.dart';
import '../components/srt_browser.dart';
import '../components/audio_free_tag.dart';

class AudioPlayerPage extends StatefulWidget {

  const AudioPlayerPage({super.key});

  /// 使用标准上滑动画打开播放器页面

  @override
  State<AudioPlayerPage> createState() => _AudioPlayerPageState();
}

class _AudioPlayerPageState extends State<AudioPlayerPage>
    with AutomaticKeepAliveClientMixin, WidgetsBindingObserver {
  bool _isPlaying = false;
  bool _hasPremium = false;
  // 删除预览模式标志，统一使用非预览逻辑
  // bool _isPreviewMode = true;
  // Duration _currentPosition = Duration.zero;

  // 移除时长代理服务和渲染相关状态，现在由AudioProgressBar内部管理

  late AudioManager _audioManager;
  AudioItem? _currentAudio;
  // bool _isLiked = false;
  bool _isAudioLoading = false; // 是否正在加载metadata
  bool _isDetailLoading = false; // 是否正在加载音频详情

  // 点赞相关状态管理
  bool _isLikeRequesting = false; // 是否正在请求点赞
  bool _localIsLiked = false; // 本地点赞状态
  int _localLikesCount = 0; // 本地点赞数
  bool _isLikeButtonVisible = false; // 点赞按钮是否可见
  bool _isUserScrolling = false; // 用户是否在手动滚动字幕

  // 播放列表相关状态管理
  bool _isShowingPlaylist = false; // 是否正在显示播放列表

  // StreamSubscription列表，用于在dispose时取消
  final List<StreamSubscription> _subscriptions = [];
  // 字幕段落
  List<SrtParagraphModel> _srtParagraphs = [];
  // 字幕浏览控制器
  late SrtBrowserController _srtController;

  // 本地状态缓存，用于差异对比
  AudioPlayerState? _lastAudioState;

  // 新增：内部状态跟踪，记录已处理过详情的音频ID
  String? _lastProcessedAudioId;

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _audioManager = AudioManager.instance;
    _srtController = SrtBrowserController();

    // 从AudioManager获取当前音频进度并同步到_srtController
    // _syncCurrentAudioProgressToSrtController();

    SubscribePrivilegeManager.instance
        .hasValidPremium(forceRefresh: false)
        .then((value) {
          setState(() {
            _hasPremium = value;
            _listenToAudioState();
          });
        });
  }

  @override
  Widget build(BuildContext context) {
    super.build(context); // 必须调用以支持AutomaticKeepAliveClientMixin
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: const SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: Brightness.light,
        statusBarBrightness: Brightness.dark,
        systemNavigationBarColor: Colors.black,
        systemNavigationBarIconBrightness: Brightness.light,
      ),
      child: SwipeToCloseContainer(
        onClose: _closePage,
        showDragIndicator: false,
        backgroundColor: Colors.transparent,
        child: Scaffold(
          backgroundColor: Colors.black,
          body: Stack(
            children: [
              _buildAudioBackground(),
              Positioned.fill(
                child: ColoredBox(color: Colors.black.withAlpha(128)),
              ),
              // _buildStatusBar(),
              Column(
                children: [
                  const SizedBox(height: 76),
                  _buildAudioInfo(),
                  const SizedBox(height: 18),
                  Expanded(
                    child: Column(
                      children: [
                        Expanded(
                          child: _isDetailLoading
                              ? const SizedBox.expand()
                              : _srtParagraphs.isEmpty
                              ? _buildDesc()
                              : RepaintBoundary(
                                  child: SrtBrowser(
                                    key: ValueKey('srt_browser_${_currentAudio?.id}'), // 使用音频ID作为key
                                    paragraphs: _srtParagraphs,
                                    controller: _srtController,
                                    onScrollStateChanged: _onScrollStateChanged,
                                    onParagraphTap: _onParagraphTap,
                                    canViewAllText: _hasPremium || (_currentAudio?.isFree ?? false), // 直接计算避免方法调用
                                    initProgress: _audioManager.position,
                                  ),
                                ),
                        ), // 字幕组件
                        _hasPremium
                            ? const SizedBox.shrink()
                            : Padding(
                                padding: EdgeInsets.only(
                                  left: 24,
                                  right: 24,
                                  top: 16,
                                ),
                                child: Align(
                                  alignment: Alignment.centerLeft,
                                  child: _buildUnlockFullAccessTip(),
                                ),
                              ),
                      ],
                    ),
                  ),

                  _buildControlBar(),
                ],
              ),
              _buildCloseButton(),
              Positioned(
                bottom: MediaQuery.of(context).padding.bottom + 20 + 174,
                right: 16,
                child: _buildLikeButton(),
              ),

              Positioned(
                bottom: MediaQuery.of(context).size.height / 2 - 20,
                right: 16,
                child: _buildReturnButton(),
              ),
            ],
          ),
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
      backgroundColor: Colors.black,
    );
  }

  // 构建控制栏
  Widget _buildControlBar() {
    return RepaintBoundary(
      child: Container(
        padding: EdgeInsets.only(
          top: 20,
          left: 28,
          right: 28,
          bottom: MediaQuery.of(context).padding.bottom + 20,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
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
    return Positioned(
      top: 64,
      left: 16,
      child: IconButton(
        alignment: Alignment.center,
        style: IconButton.styleFrom(
          // tapTargetSize: MaterialTapTargetSize.shrinkWrap,
          backgroundColor: const Color(0xFF000000).withAlpha(128),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          minimumSize: const Size(40, 40),
        ),
        onPressed: () => _closePage(),
        icon: Transform.translate(
          offset: const Offset(-2.5, 0),
          child: Icon(CustomIcons.arrow_down, color: Colors.white, size: 9),
        ),
      ),
    );
  }

  // 构建音频信息
  Widget _buildAudioInfo() {
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: 65),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                _buildAudioTitle(),
                const SizedBox(height: 6),
                _buildArtistInfo(),
                // const SizedBox(height: 10),
                // _buildAudioDescription(),
              ],
            ),
          ),
          // const SizedBox(width: 26),
          // _buildLikeButton(),
        ],
      ),
    );
  }

  // 构建音频标题
  Widget _buildAudioTitle() {
    final title = _currentAudio?.title ?? 'Unknown Title';
    final bool isFree = _currentAudio?.isFree ?? false;

    return SizedBox(
      width: double.infinity,
      child: RichText(
        textAlign: TextAlign.center,
        overflow: TextOverflow.ellipsis,
        maxLines: 3,
        text: TextSpan(
          style: const TextStyle(
            color: Colors.white,
            fontSize: 16,
            height: 1.2,
            fontWeight: FontWeight.w700,
          ),
          children: [
            if (isFree) ...[
              WidgetSpan(
                alignment: PlaceholderAlignment.middle,
                child: const AudioFreeTag(),
              ),
              const WidgetSpan(child: SizedBox(width: 6)),
            ],
            TextSpan(text: title),
          ],
        ),
      ),
    );
  }

  // 构建艺术家信息
  Widget _buildArtistInfo() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        const Icon(CustomIcons.user, color: Colors.white, size: 12),
        const SizedBox(width: 4),
        Text(
          _currentAudio?.author ?? '',
          style: const TextStyle(
            fontSize: 12,
            color: Colors.white,
            fontWeight: FontWeight.w400,
          ),
        ),
      ],
    );
  }

  // 构建描述内容，当没有字幕时显示
  Widget _buildDesc() {
    final desc = _currentAudio?.desc ?? '';
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 63),
      child: SingleChildScrollView(
        child: Text(
          desc.isNotEmpty ? desc : '',
          style: const TextStyle(
            color: Colors.white,
            fontSize: 12,
            height: 1.3,
            fontWeight: FontWeight.w400,
          ),
        ),
      ),
    );
  }

  // 构建返回按钮
  Widget _buildReturnButton() {
    if (!_isUserScrolling) {
      return const SizedBox(width: 48, height: 48);
    }

    return IconButton(
      style: IconButton.styleFrom(
        padding: EdgeInsets.zero,
        // tapTargetSize: MaterialTapTargetSize.shrinkWrap,
        backgroundColor: const Color(0xFF000000).withAlpha(128),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(23)),
        minimumSize: const Size(46, 46),
        side: BorderSide(color: Color(0xFF3E3E3E).withAlpha(128), width: 1),
      ),
      onPressed: _onReturnButtonPressed,
      icon: Icon(CustomIcons.return_button, color: Colors.white, size: 18),
    );
  }

  // 构建点赞按钮
  Widget _buildLikeButton() {
    // 如果点赞按钮不可见，返回占位符
    if (!_isLikeButtonVisible) {
      return const SizedBox(width: 48, height: 48);
    }

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
              borderRadius: BorderRadius.circular(23),
            ),
            minimumSize: const Size(46, 46),
            side: BorderSide(color: Color(0xFF3E3E3E).withAlpha(128), width: 1),
          ),
          onPressed: _onLikeButtonPressed, // 请求中禁用按钮
          icon: Transform.translate(
            offset: const Offset(0, -1),
            child: Icon(
              CustomIcons.likes,
              color: _localIsLiked ? Color(0xFFFF254E) : Colors.white,
              size: 18,
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
    // 仅使用 title 段的时间点作为关键点
    final List<Duration> keyPoints = _srtParagraphs
        .where((p) => p.type == SrtParagraphType.title)
        .map((p) {
          final parts = p.startTime.split(':');
          int h = 0, m = 0, s = 0;
          if (parts.length == 3) {
            h = int.tryParse(parts[0]) ?? 0;
            m = int.tryParse(parts[1]) ?? 0;
            s = int.tryParse(parts[2]) ?? 0;
          } else if (parts.length == 2) {
            m = int.tryParse(parts[0]) ?? 0;
            s = int.tryParse(parts[1]) ?? 0;
          } else if (parts.length == 1) {
            s = int.tryParse(parts[0]) ?? 0;
          }
          return Duration(seconds: h * 3600 + m * 60 + s);
        })
        .toList();

    return RepaintBoundary(child: AudioProgressBar(keyPoints: keyPoints));
  }

  // 构建播放控制按钮
  Widget _buildPlaybackControls() {
    return Row(
      children: [
        _buildPlaylistButton(),
        Expanded(
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const SizedBox(width: 76), // 占位按钮保持对称
              _buildPlayPauseButton(),
              const SizedBox(width: 48), // 占位按钮保持对称
              _buildNextButton(),
            ],
          ),
        ),
        const SizedBox(width: 48), // 占位按钮保持对称
        // _buildNextButton(),
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

  Future<void> _onNextButtonTap() async {
    if (!_isAudioLoading &&
        _currentAudio != null &&
        _currentAudio?.id != null) {
      await AudioManager.instance.playNextAudio(_currentAudio!.id);
    }
  }

  Widget _buildNextButton() {
    return IconButton(
      style: IconButton.styleFrom(
        minimumSize: Size.zero,
        padding: EdgeInsets.zero,
        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
      ),
      onPressed: _onNextButtonTap,
      icon: Icon(CustomIcons.skip_next, color: Colors.white, size: 32),
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
      onPressed: _playAndPauseBtnPress,
      icon: (_isAudioLoading && _canPlay())
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
      child: Align(
        alignment: Alignment.centerLeft,
        widthFactor: 1.0, // 使宽度跟随子内容
        child: Container(
          padding: EdgeInsets.symmetric(horizontal: 10, vertical: 8),
          decoration: BoxDecoration(
            color: Colors.white.withAlpha(50),
            borderRadius: BorderRadius.circular(24),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min, // 行宽度最小化，紧贴内容
            children: [
              Image.asset(
                'assets/images/crown_mini.png',
                width: 27,
                height: 20,
              ),
              const SizedBox(width: 8),
              ShaderMask(
                shaderCallback: (Rect bounds) {
                  return const LinearGradient(
                    colors: [
                      Color(0xFFFFCB35), // 橙色
                      Color(0xFFEED960),
                      Color(0xFFFEEF96),
                      Color(0xFFFFC733), // 红橙色
                    ],
                    begin: Alignment.centerLeft,
                    end: Alignment.centerRight,
                  ).createShader(
                    Rect.fromLTWH(0, 0, bounds.width, bounds.height),
                  );
                },
                blendMode: BlendMode.srcIn,
                child: const Text(
                  'Unlock Full Access',
                  maxLines: 1,
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 14,
                    height: 1.25,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // 构建拖拽指示器

  // 段落点击回调：跳转到指定时间
  void _onParagraphTap(SrtParagraphModel paragraph) {
    try {
      // 解析时间字符串为 Duration
      final Duration seekTime = _parseTimeStringToDuration(paragraph.startTime);

      // 调用 AudioManager 的 seek 方法跳转到指定时间
      _audioManager.seek(seekTime);

      // 打印调试信息
      debugPrint(
        '[AudioPlayerPage] 段落点击跳转: ${paragraph.startTime} -> ${seekTime.inSeconds}秒',
      );
    } catch (e) {
      debugPrint('[AudioPlayerPage] 段落点击跳转失败: $e');
    }
  }

  // 解析时间字符串为 Duration 对象
  Duration _parseTimeStringToDuration(String timeStr) {
    try {
      final parts = timeStr.split(':');
      int h = 0, m = 0, s = 0;

      if (parts.length == 3) {
        h = int.tryParse(parts[0]) ?? 0;
        m = int.tryParse(parts[1]) ?? 0;
        s = int.tryParse(parts[2]) ?? 0;
      } else if (parts.length == 2) {
        m = int.tryParse(parts[0]) ?? 0;
        s = int.tryParse(parts[1]) ?? 0;
      } else if (parts.length == 1) {
        s = int.tryParse(parts[0]) ?? 0;
      }

      return Duration(hours: h, minutes: m, seconds: s);
    } catch (e) {
      debugPrint('[AudioPlayerPage] 时间解析失败: $timeStr, 错误: $e');
      return Duration.zero;
    }
  }

  bool _canPlay() {
    if (_currentAudio != null) {
      return _hasPremium || (_currentAudio?.isFree ?? false);
    } else {
      return false;
    }
  }

  void _onScrollStateChanged(bool isUserScrolling) {
    setState(() {
      _isUserScrolling = isUserScrolling;
    });
  }

  void _onReturnButtonPressed() {
    _srtController.resetToAutoScroll();
  }

  void _listenToAudioState() {
    // 直接监听原始音频状态流，使用真实 position/duration
    _subscriptions.add(
      _audioManager.audioStateStream.listen((audioState) {
        if (mounted) {
          // 如果是第一次接收状态或状态发生变化，才进行处理
          if (_lastAudioState == null ||
              _hasStateChanged(_lastAudioState!, audioState)) {
            bool needsUpdate = false;

            // 检查当前音频是否变化
            if (_lastAudioState?.currentAudio?.id !=
                audioState.currentAudio?.id) {
              _currentAudio = audioState.currentAudio;
              // _isLiked = _currentAudio?.isLiked ?? false;
              // 初始化本地状态
              // _localIsLiked = _isLiked;
              // _localLikesCount = _currentAudio?.likesCount ?? 0;
              _isLikeButtonVisible = false; // 音频变化时隐藏点赞按钮
              _isUserScrolling = false; // 音频更换时重置手动滚动状态
              _srtController.resetToAutoScroll(); // 同步重置字幕控制器为自动滚动
              needsUpdate = true;

              // 切换音频后先清空字幕列表
              _srtParagraphs = [];

              // 获取音频详情并更新点赞状态
              if (_currentAudio != null) {
                final audioId = _currentAudio?.id;
                if (audioId != null && _lastProcessedAudioId != audioId) {
                  _fetchAudioDetail(audioId);
                }
              }
            }

            // 检查播放状态是否变化
            if (_lastAudioState?.isPlaying != audioState.isPlaying) {
              _isPlaying = audioState.isPlaying;

              // 记录播放/暂停事件
              if (_currentAudio != null) {
                final audio = _currentAudio;
                if (audio != null) {
                  if (audioState.isPlaying) {
                    AnalyticsService().logAudioPlay(
                      audioId: audio.id,
                      audioTitle: audio.title,
                      category: 'audio_player',
                      duration: audioState.duration?.inSeconds,
                    );
                  } else {
                    AnalyticsService().logAudioPause(
                      audioId: audio.id,
                      audioTitle: audio.title,
                      position: audioState.position.inSeconds,
                    );
                  }
                }
              }

              needsUpdate = true;
            }

            // 检查播放器状态是否变化
            if (_lastAudioState?.playerState.processingState !=
                audioState.playerState.processingState) {
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

            // 检查播放位置是否变化，驱动字幕高亮
            if (_lastAudioState?.position != audioState.position) {
              final duration = audioState.duration;
              // debugPrint('[audio_player_page: _listenToAudioState]  position: ${audioState.position}');
              if (duration != null && duration.inMilliseconds > 0) {
                // 改为按具体时间定位字幕
                _srtController.setActiveByProgress(
                  audioState.position,
                  !_isUserScrolling, // 用户滚动时不使用动画
                );
              }
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
      }),
    );

    _subscriptions.add(
      SubscribePrivilegeManager.instance.privilegeChanges.listen((event) {
        if (mounted) {
          setState(() {
            _hasPremium = event.hasPremium;
          });
        }
      }),
    );
  }

  void _playAndPauseBtnPress() {
    // 如果正在加载metadata，不允许播放
    debugPrint(
      '点击了播放/暂停按钮 isAudioLoading: $_isAudioLoading $_isPlaying $_currentAudio.id',
    );
    if (_isAudioLoading) return;

    if (!_isPlaying) {
      // 如果当前没有播放，或者播放的不是当前音频，则开始播放当前音频
      final currentAudio = _audioManager.currentAudio;
      final currentAudioId = (_currentAudio?.id ?? 'unknown');

      if (currentAudio != null && !_canPlay()) {
        // 检查是否可以播放 如果不能播放 则显示订阅对话框
        showSubscribeDialog(context, scene: 'player');
        return;
      }

      if (currentAudio == null || currentAudio.id != currentAudioId) {
        // 如果没有当前音频信息，无法播放
        if (_currentAudio == null) return;

        // 创建音频模型并播放
        final audioToPlay = _currentAudio;
        if (audioToPlay != null) {
          _audioManager.playAudio(audioToPlay);
        }
      } else {
        // 如果是同一首音频，直接恢复播放（不再检查预览区间）
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

    final isLogin = await AuthManager.instance.isSignedIn();
    if (!isLogin) {
      // 打开登录页
      NavigationUtils.navigateToLogin(context);
      return;
    }

    // 如果正在请求中，直接返回
    if (_isLikeRequesting) return;

    // 捕获当前音频引用，避免在异步期间发生变化导致空断言崩溃
    final audio = _currentAudio;
    if (audio == null) return;

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

    // 记录点赞事件
    AnalyticsService().logAudioLike(
      audioId: audio.id,
      audioTitle: audio.title,
      isLiked: newIsLiked,
    );

    try {
      // 调用API
      await AudioLikesManager.instance.setLike(audio, newIsLiked);
      
      // 请求成功，更新缓存中的点赞状态
      await AudioDetailService.updateAudioLikedCache(
        audio.id,
        isLiked: newIsLiked,
        likesCount: newLikesCount,
      );
      
      // 请求成功，不需要再更改本地状态，保持当前状态
    } catch (e) {
      // 网络异常，回滚本地状态
      debugPrint('点赞操作异常: $e');
    } finally {
      // 重置请求状态
      if (mounted) {
        setState(() {
          _isLikeRequesting = false;
        });
      }
    }
  }

  /// 获取音频详情并更新点赞状态
  Future<void> _fetchAudioDetail(String audioId) async {
    if (mounted) {
      setState(() {
        _isDetailLoading = true;
      });
    }
    try {
      debugPrint('🎵 [PLAYER] 开始获取音频详情: $audioId');

      // 获取最新的音频详情
      final audioDetail = await AudioDetailService.getAudioDetail(audioId);

      if (mounted && _currentAudio?.id == audioId) {
        // 只有当前音频ID匹配时才更新状态
        setState(() {
          _localIsLiked = audioDetail.isLiked ?? false;
          _localLikesCount = audioDetail.likesCount ?? 0;
          _isLikeButtonVisible = true; // 获取成功后显示点赞按钮
          _srtParagraphs = audioDetail.srtParagraphs ?? [];
          _isDetailLoading = false; // 详情加载完成
        });

        // 更新已处理的音频ID
        _lastProcessedAudioId = audioId;

        debugPrint(
          '🎵 [PLAYER] 音频详情获取成功，更新点赞状态: isLiked=${audioDetail.isLiked}, likesCount=${audioDetail.likesCount}',
        );
      }
    } catch (e) {
      debugPrint('🎵 [PLAYER] 获取音频详情失败: $e');

      if (mounted) {
        // 获取失败时也要显示点赞按钮，使用当前的状态
        setState(() {
          _isLikeButtonVisible = true;
          _isDetailLoading = false; // 失败也结束加载状态
        });
      }
    }
  }

  void _onPlaylistButtonTap() async {
    // 如果正在显示播放列表，直接返回
    if (_isShowingPlaylist) return;

    final isLogin = await AuthManager.instance.isSignedIn();
    if (!isLogin) {
      // 打开登录页
      NavigationUtils.navigateToLogin(context);
      return;
    }

    // 设置标志位
    setState(() {
      _isShowingPlaylist = true;
    });

    showAudioHistoryDialog(
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

  void _closePage() {
    // 使用标准的Navigator.pop关闭页面
    Navigator.of(context).pop();
  }

  // 解锁全功能提示点击事件
  void _onUnlockFullAccessTap() async {
    showSubscribeDialog(context);
  }

  @override
  Future<bool> didPopRoute() async {
    // 拦截系统返回键，使用标准Navigator.pop关闭页面
    Navigator.of(context).pop();
    return true; // 表示已处理返回键事件
  }

  @override
  void dispose() {
    // 取消系统事件观察者
    WidgetsBinding.instance.removeObserver(this);
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
        oldState.playerState.processingState !=
            newState.playerState.processingState;
  }

  // 从AudioManager获取当前音频进度并同步到_srtController
  void _syncCurrentAudioProgressToSrtController() {
    // 直接获取当前播放进度，不使用流监听
    final currentPosition = _audioManager.position;
    debugPrint('🎵 [PLAYER] 当前播放进度: $currentPosition');
    if (mounted && _audioManager.currentAudio != null) {
      // 使用setActiveByProgress方法根据当前播放位置定位字幕
      Future.delayed(const Duration(milliseconds: 500), () {
        _srtController.setActiveByProgress(
          currentPosition,
          false, // 初始化时不使用动画
        );
      });
    }
  }

}
