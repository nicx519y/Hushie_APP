import 'dart:async';
import 'package:flutter/material.dart';
import 'package:just_audio/just_audio.dart';
import '../services/audio_manager.dart';
import '../services/audio_service.dart';
import '../services/audio_state_proxy.dart';
import '../services/subscribe_privilege_manager.dart';

class AudioProgressBar extends StatefulWidget {
  final Function()? onOutPreview;
  final double? width; // 添加宽度参数

  // 预览条样式参数
  final Color previewColor;
  final double previewOpacity;

  // 缓冲条样式参数
  final Color bufferColor;
  final double bufferOpacity;
  final bool showBufferBar;

  const AudioProgressBar({
    super.key,
    this.onOutPreview,
    this.width,
    // 预览条样式参数默认值
    this.previewColor = Colors.white,
    this.previewOpacity = 1.0,
    // 缓冲条样式参数默认值
    this.bufferColor = Colors.white,
    this.bufferOpacity = 0.5,
    this.showBufferBar = true,
  });

  @override
  State<AudioProgressBar> createState() => _AudioProgressBarState();
}

class _AudioProgressBarState extends State<AudioProgressBar> {
  double _dragValue = 0.0;
  bool _isDragging = false;

  // 内部状态
  bool _isPreviewMode = true;
  StreamSubscription<PrivilegeChangeEvent>? _previewModeSubscription;
  bool _disabled = false;

  // 渲染用的位置和时长（直接使用audioState中已代理的值）
  Duration _renderPosition = Duration.zero;
  Duration _renderDuration = Duration.zero;
  Duration _renderPreviewStart = Duration.zero;
  Duration _renderPreviewEnd = Duration.zero;
  Duration _renderBufferedPosition = Duration.zero;

  // 真实的音频时长（用于位置转换）
  Duration _realDuration = Duration.zero;
  Duration _realPosition = Duration.zero;

  late AudioManager _audioManager;

  // StreamSubscription列表，用于在dispose时取消
  final List<StreamSubscription> _subscriptions = [];

  // 本地状态缓存，用于差异对比
  AudioPlayerState? _lastAudioState;

  // 代理流引用，用于位置转换
  AudioStateProxyStream? _proxyStream;

  @override
  void initState() {
    super.initState();
    _audioManager = AudioManager.instance;
    _initializePreviewMode().then((value) {
      _resetAudioStateListener();
      _setupPreviewModeListener();
    });
  }

  Future<void> _initializePreviewMode() async {
    // 从权益管理器获取权限状态，然后计算预览模式
    final hasPremium = await SubscribePrivilegeManager.instance
        .hasValidPremium();
    setState(() {
      _isPreviewMode = !hasPremium; // 有权限时不是预览模式，无权限时是预览模式
    });
  }

  void _setupPreviewModeListener() {
    _previewModeSubscription = SubscribePrivilegeManager
        .instance
        .privilegeChanges
        .listen((event) {
          if (mounted) {
            setState(() {
              _isPreviewMode = !event.hasPremium; // 有权限时不是预览模式，无权限时是预览模式
              _resetAudioStateListener();
            });
          }
        });
  }

  void _resetAudioStateListener() {
    _unListenerToAudioState();
    _listenToAudioState();
  }

  void _unListenerToAudioState() {
    for (var subscription in _subscriptions) {
      subscription.cancel();
    }
    _subscriptions.clear();
  }

  void _listenToAudioState() {
    // 监听原始音频状态流，获取真实duration
    _subscriptions.add(
      _audioManager.audioStateStream.listen((originalState) {
        if (mounted) {
          if (originalState.duration != _realDuration) {
            _realDuration = originalState.duration;
          }

          if (originalState.position != _realPosition) {
            _realPosition = originalState.position;
          }
        }
      }),
    );


    debugPrint('[progressBar] 初始化预览模式: $_isPreviewMode');

    if (_isPreviewMode) {
      // 使用代理后的音频状态流，自动处理duration过滤
      final durationProxy = AudioStateProxy.createDurationFilter();
      _proxyStream = _audioManager.audioStateStream.proxy(durationProxy);
      _subscriptions.add(
        _proxyStream!.listen((audioState) {
          if (mounted) {
            // 如果是第一次接收状态或状态发生变化，才进行处理
            if (_lastAudioState == null ||
                _hasStateChanged(_lastAudioState!, audioState)) {
              bool needsUpdate = false;

              // 检查当前音频是否变化
              if (_lastAudioState?.currentAudio?.id !=
                  audioState.currentAudio?.id) {
                needsUpdate = true;
              }

              // 检查渲染预览区域是否变化
              if (_lastAudioState?.renderPreviewStart !=
                      audioState.renderPreviewStart ||
                  _lastAudioState?.renderPreviewEnd !=
                      audioState.renderPreviewEnd) {
                _renderPreviewStart = audioState.renderPreviewStart;
                _renderPreviewEnd = audioState.renderPreviewEnd;
                needsUpdate = true;
              }

              // 检查duration是否变化（audioState.duration已经过代理处理）
              if (_lastAudioState?.duration != audioState.duration) {
                _renderDuration = audioState.duration;
                needsUpdate = true;
              }

              // 检查播放位置是否变化
              if (_lastAudioState?.position != audioState.position) {
                debugPrint('[progressBar] 渲染位置：${audioState.position} 预览模式: $_isPreviewMode');
                _renderPosition = audioState.position;
                if (!_isDragging) {
                  _dragValue = _renderDuration.inMilliseconds > 0
                      ? _renderPosition.inMilliseconds /
                            _renderDuration.inMilliseconds
                      : 0.0;
                }
                needsUpdate = true;
              }

              // 检查缓冲位置是否变化
              if (_lastAudioState?.bufferedPosition !=
                  audioState.bufferedPosition) {
                _renderBufferedPosition = audioState.bufferedPosition;
                needsUpdate = true;
              }

              // 检查播放器状态是否变化
              if (_lastAudioState?.playerState.processingState !=
                  audioState.playerState.processingState) {
                final playerState = audioState.playerState;
                if (playerState != null) {
                  _disabled =
                      playerState.processingState == ProcessingState.loading;
                }
                needsUpdate = true;
              }

              // 只有在需要更新时才调用setState
              if (needsUpdate) {
                setState(() {
                  // 状态已在上面更新，这里只需要触发重建
                });
              }

              // 更新本地状态缓存
              _lastAudioState = audioState;
            }
          }
        }),
      );
    } else {
      _subscriptions.add(_audioManager.audioStateStream.listen((audioState) {
        if (mounted) {
          // 如果是第一次接收状态或状态发生变化，才进行处理
          if (_lastAudioState == null ||
              _hasStateChanged(_lastAudioState!, audioState)) {
            bool needsUpdate = false;

            // 检查当前音频是否变化
            if (_lastAudioState?.currentAudio?.id !=
                audioState.currentAudio?.id) {
              needsUpdate = true;
            }

            // 非预览模式下不需要预览区域，直接使用真实duration
            if (_lastAudioState?.duration != audioState.duration) {
              _renderDuration = audioState.duration ?? Duration.zero;
              debugPrint('[progressBar] 渲染duration：${_renderDuration.inSeconds}');
              needsUpdate = true;
            }

            // 检查播放位置是否变化（使用真实位置）
            if (_lastAudioState?.position != audioState.position) {
              _renderPosition = audioState.position ?? Duration.zero;
              if (!_isDragging) {
                _dragValue = _renderDuration.inMilliseconds > 0
                    ? _renderPosition.inMilliseconds /
                          _renderDuration.inMilliseconds
                    : 0.0;
              }
              needsUpdate = true;
            }

            // 检查缓冲位置是否变化（使用真实缓冲位置）
            if (_lastAudioState?.bufferedPosition !=
                audioState.bufferedPosition) {
              _renderBufferedPosition = audioState.bufferedPosition ?? Duration.zero;
              needsUpdate = true;
            }

            // 检查播放器状态是否变化
            if (_lastAudioState?.playerState.processingState !=
                audioState.playerState.processingState) {
              final playerState = audioState.playerState;
              if (playerState != null) {
                _disabled =
                    playerState.processingState == ProcessingState.loading;
              }
              needsUpdate = true;
            }

            // 只有在需要更新时才调用setState
            if (needsUpdate) {
              setState(() {
                // 状态已在上面更新，这里只需要触发重建
              });
            }

            // 更新本地状态缓存
            _lastAudioState = audioState;
          }
        }
      }));
    }
  }

  Future<void> _onSeek(Duration position) async {
    // 直接使用position进行seek，因为audio_state_proxy已经处理了位置转换
    await _audioManager.seek(position);
  }

  @override
  void didUpdateWidget(AudioProgressBar oldWidget) {
    super.didUpdateWidget(oldWidget);
    // 移除旧的逻辑，现在由内部监听处理
  }

  @override
  void dispose() {
    // 手动取消所有StreamSubscription以避免内存泄漏
    for (final subscription in _subscriptions) {
      subscription.cancel();
    }
    _subscriptions.clear();
    _previewModeSubscription?.cancel();
    _lastAudioState = null; // 清空状态缓存
    _proxyStream = null; // 清空代理流引用
    _realDuration = Duration.zero; // 清空真实时长
    _realPosition = Duration.zero; // 清空真实位置
    super.dispose();
  }

  /// 检查音频状态是否发生实质性变化
  bool _hasStateChanged(AudioPlayerState oldState, AudioPlayerState newState) {
    return oldState.currentAudio?.id != newState.currentAudio?.id ||
        oldState.isPlaying != newState.isPlaying ||
        oldState.position != newState.position ||
        oldState.duration != newState.duration ||
        oldState.speed != newState.speed ||
        oldState.bufferedPosition != newState.bufferedPosition ||
        oldState.playerState.processingState !=
            newState.playerState.processingState ||
        oldState.renderPreviewStart != newState.renderPreviewStart ||
        oldState.renderPreviewEnd != newState.renderPreviewEnd;
  }

  String _formatDuration(Duration duration) {
    String twoDigits(int n) => n.toString().padLeft(2, '0');
    String twoDigitMinutes = twoDigits(duration.inMinutes.remainder(60));
    String twoDigitSeconds = twoDigits(duration.inSeconds.remainder(60));
    return "$twoDigitMinutes:$twoDigitSeconds";
  }

  @override
  Widget build(BuildContext context) {
    // 计算进度
    double progress = 0.0;
    // 计算预览区域和缓冲进度
    double previewStart = 0.0;
    double previewEnd = 1.0;
    double bufferedProgress = 0.0;

    // 计算预览区域的相对位置
    if (_renderDuration.inMilliseconds > 0) {
      progress = _isDragging
          ? _dragValue
          : _renderPosition.inMilliseconds / _renderDuration.inMilliseconds;


      // debugPrint('AudioProgressBar build, progress: $progress, _renderPosition: $_renderPosition.inSeconds, _renderDuration: $_renderDuration.inSeconds');

      previewStart =
          _renderPreviewStart.inMilliseconds / _renderDuration.inMilliseconds;
      previewEnd =
          _renderPreviewEnd.inMilliseconds / _renderDuration.inMilliseconds;
      // 确保预览区域在有效范围内
      previewStart = previewStart.clamp(0.0, 1.0);
      previewEnd = previewEnd.clamp(0.0, 1.0);
      // 计算缓冲进度
      bufferedProgress =
          _renderBufferedPosition.inMilliseconds /
          _renderDuration.inMilliseconds;
    }

    return Opacity(
      opacity: _disabled ? 0.7 : 1.0, // 禁用时透明度降低50%
      child: AbsorbPointer(
        absorbing: _disabled, // 禁用时阻止所有交互
        child: Column(
          children: [
            // 进度条
            SizedBox(
              width: double.infinity,
              height: 24,
              child: SliderTheme(
                data: SliderTheme.of(context).copyWith(
                  trackHeight: 1.0,
                  thumbShape: const RoundSliderThumbShape(
                    enabledThumbRadius: 4.0,
                  ),
                  overlayShape: const RoundSliderOverlayShape(
                    overlayRadius: 16.0,
                  ),
                  activeTrackColor: Color(0xff999999) /*.withAlpha(200)*/,
                  inactiveTrackColor: Color(0xff999999) /*.withAlpha(200)*/,
                  thumbColor: Colors.white,
                  overlayColor: Colors.white /*.withAlpha(64)*/,
                  // 自定义轨道形状，传递预览区域参数
                  trackShape: CustomTrackShape(
                    previewStart: previewStart,
                    previewEnd: previewEnd,
                    showPreview: _isPreviewMode,
                    bufferedProgress: bufferedProgress,
                    // 预览条样式参数
                    previewColor: widget.previewColor,
                    previewOpacity: widget.previewOpacity,
                    showPreviewBar: true,
                    // 缓冲条样式参数
                    bufferColor: widget.bufferColor,
                    bufferOpacity: widget.bufferOpacity,
                    showBufferBar: widget.showBufferBar,
                  ),
                ),
                child: Slider(
                  value: progress.clamp(0.0, 1.0),
                  onChanged: _disabled
                      ? null
                      : (value) async {
                          setState(() {
                            _isDragging = true;
                            _dragValue = value;
                          });

                          // 检查是否超出预览区域
                          if (_isPreviewMode &&
                              (value < previewStart || value > previewEnd)) {
                            // 预览模式下，检查是否需要触发解锁回调
                            if (widget.onOutPreview != null) {
                              widget.onOutPreview!();
                            }
                          }

                          final realValue = _isPreviewMode
                              ? value.clamp(previewStart, previewEnd)
                              : value;

                          // 计算渲染位置（避免往返转换的精度损失）
                          final renderPosition = Duration(
                            milliseconds:
                                (realValue * _renderDuration.inMilliseconds)
                                    .round(),
                          );
                          // debugPrint('[progressBar] 转换前渲染值: ${Duration(milliseconds: (realValue * _renderDuration.inMilliseconds).round())}');

                          // 使用代理流的方法将渲染值转换为真实位置进行seek
                          Duration position;
                          if (_isPreviewMode &&
                              _proxyStream != null &&
                              _lastAudioState != null &&
                              _realDuration > Duration.zero) {
                            position = _proxyStream!.renderValueToRealPosition(
                              realValue,
                              _lastAudioState!,
                              _realDuration,
                            );
                            // debugPrint('[progressBar] 转换后真实位置: $position');
                          } else {
                            // 降级处理：直接使用渲染位置
                            position = renderPosition;
                          }

                          // 直接更新渲染位置，避免往返转换
                          // _renderPosition = renderPosition;
                          // debugPrint('[progressBar] 渲染位置：$_renderPosition');

                          // 直接seek到目标位置
                          await _onSeek(position);
                        },
                  onChangeEnd: (value) {
                    setState(() {
                      _isDragging = false;
                    });
                  },
                ),
              ),
            ),

            // 时间显示
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 0, vertical: 0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    _formatDuration(_realPosition),
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 10,
                      fontWeight: FontWeight.w400,
                    ),
                  ),
                  Text(
                    _formatDuration(_realDuration), // 显示真实时长
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 10,
                      fontWeight: FontWeight.w400,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// 自定义轨道形状，支持预览区域绘制
class CustomTrackShape extends RoundedRectSliderTrackShape {
  final double previewStart;
  final double previewEnd;
  final bool showPreview;
  final double bufferedProgress;

  // 预览条样式参数
  final Color previewColor;
  final double previewOpacity;
  final bool showPreviewBar;

  // 缓冲条样式参数
  final Color bufferColor;
  final double bufferOpacity;
  final bool showBufferBar;

  const CustomTrackShape({
    this.previewStart = 0.0,
    this.previewEnd = 1.0,
    this.showPreview = false,
    this.bufferedProgress = 0.0,
    // 预览条样式参数默认值
    this.previewColor = Colors.black,
    this.previewOpacity = 1.0,
    this.showPreviewBar = true,
    // 缓冲条样式参数默认值
    this.bufferColor = Colors.blue,
    this.bufferOpacity = .4,
    this.showBufferBar = true,
  });

  @override
  Rect getPreferredRect({
    required RenderBox parentBox,
    Offset offset = Offset.zero,
    required SliderThemeData sliderTheme,
    bool isEnabled = false,
    bool isDiscrete = false,
  }) {
    final trackHeight = 1.0;
    final trackLeft = offset.dx;
    final trackTop = offset.dy + (parentBox.size.height - trackHeight) / 2;
    final trackWidth = parentBox.size.width;
    return Rect.fromLTWH(trackLeft, trackTop, trackWidth, trackHeight);
  }

  @override
  void paint(
    PaintingContext context,
    Offset offset, {
    required RenderBox parentBox,
    required SliderThemeData sliderTheme,
    required Animation<double> enableAnimation,
    required TextDirection textDirection,
    required Offset thumbCenter,
    Offset? secondaryOffset,
    bool isEnabled = false,
    bool isDiscrete = false,
    double additionalActiveTrackHeight = 0.0,
  }) {
    // 先绘制默认轨道
    super.paint(
      context,
      offset,
      parentBox: parentBox,
      sliderTheme: sliderTheme,
      enableAnimation: enableAnimation,
      textDirection: textDirection,
      thumbCenter: thumbCenter,
      secondaryOffset: secondaryOffset,
      isEnabled: isEnabled,
      isDiscrete: isDiscrete,
      additionalActiveTrackHeight: additionalActiveTrackHeight,
    );

    final trackRect = getPreferredRect(
      parentBox: parentBox,
      offset: offset,
      sliderTheme: sliderTheme,
      isEnabled: isEnabled,
      isDiscrete: isDiscrete,
    );

    // 绘制缓冲条
    if (showBufferBar && bufferedProgress > 0) {
      final bufferedWidth = trackRect.width * bufferedProgress;
      final bufferedRect = Rect.fromLTWH(
        trackRect.left,
        trackRect.top,
        bufferedWidth,
        trackRect.height,
      );

      final bufferedPaint = Paint()
        ..color = bufferColor.withAlpha((bufferOpacity * 255).toInt())
        ..style = PaintingStyle.fill;

      context.canvas.drawRRect(
        RRect.fromRectAndRadius(
          bufferedRect,
          Radius.circular(trackRect.height / 2),
        ),
        bufferedPaint,
      );
    }

    // 如果需要显示预览区域，绘制预览条
    if (showPreview && showPreviewBar) {
      final previewLeft = trackRect.left + (trackRect.width * previewStart);
      final previewWidth = trackRect.width * (previewEnd - previewStart);

      final previewRect = Rect.fromLTWH(
        previewLeft,
        trackRect.top,
        previewWidth,
        trackRect.height,
      );

      final previewPaint = Paint()
        ..color = previewColor.withAlpha((previewOpacity * 255).toInt())
        ..style = PaintingStyle.fill;

      // 绘制预览条
      context.canvas.drawRRect(
        RRect.fromRectAndRadius(
          previewRect,
          Radius.circular(trackRect.height / 2),
        ),
        previewPaint,
      );

      // 绘制预览条两端的圆点（半径2px）
      final circlePaint = Paint()
        ..color = previewColor.withAlpha((previewOpacity * 255).toInt())
        ..style = PaintingStyle.fill;

      final circleRadius = 2.0;
      final trackCenterY = trackRect.center.dy;

      // 左端圆点
      context.canvas.drawCircle(
        Offset(previewLeft, trackCenterY),
        circleRadius,
        circlePaint,
      );

      // 右端圆点
      context.canvas.drawCircle(
        Offset(previewLeft + previewWidth, trackCenterY),
        circleRadius,
        circlePaint,
      );
    }
  }
}
