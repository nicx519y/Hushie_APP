import 'dart:async';
import 'package:flutter/material.dart';
import 'package:just_audio/just_audio.dart';
import '../services/audio_manager.dart';
import '../services/duration_proxy_service.dart';

class AudioProgressBar extends StatefulWidget {
  final Function() onOutPreview;
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
    required this.onOutPreview,
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
  Duration _totalDuration = Duration.zero;
  Duration _previewStartPosition = Duration.zero;
  Duration _previewDuration = Duration.zero;
  bool _isPreviewMode = true;
  bool _disabled = false;
  
  // 时长代理服务
  DurationProxyService? _durationProxy;
  
  // 渲染用的位置和时长（经过代理转换）
  Duration _renderPosition = Duration.zero;
  Duration _renderStart = Duration.zero;
  Duration _renderDuration = Duration.zero;
  Duration _renderBufferedPosition = Duration.zero;
  Duration _renderPreviewStart = Duration.zero;
  Duration _renderPreviewDuration = Duration.zero;
  
  late AudioManager _audioManager;
  
  // StreamSubscription列表，用于在dispose时取消
  final List<StreamSubscription> _subscriptions = [];

  @override
  void initState() {
    super.initState();
    _audioManager = AudioManager.instance;
    _listenToAudioState();
  }
  
  void _listenToAudioState() {
    // 监听当前音频
    _subscriptions.add(_audioManager.currentAudioStream.listen((audio) {
      if (mounted) {
        setState(() {
          _totalDuration = audio?.duration ?? Duration.zero;
          _createDurationProxy();
        });
      }
    }));

    // 是否能播放全部时长
    _subscriptions.add(_audioManager.canPlayAllDurationStream.listen((canPlayAll) {
      if (mounted) {
        setState(() {
          _isPreviewMode = !canPlayAll;
          _createDurationProxy();
        });
      }
    }));

    // 监听播放位置
    _subscriptions.add(_audioManager.positionStream.listen((position) {
      if (mounted) {
        setState(() {
          if (_durationProxy != null) {
            _renderPosition = _durationProxy!.realPositionToRenderPosition(position);
            debugPrint('[playAudio] ==============================');
            debugPrint('[playAudio] renderStart: ${_durationProxy!.renderStart} previewStart: ${_previewStartPosition}');
            debugPrint('[playAudio] position: $position renderPosition: ${_durationProxy!.realPositionToRenderPosition(position)}');
            debugPrint('[playAudio] ==============================');
          } else {
            _renderPosition = position;
          }
          if (!_isDragging) {
            _dragValue = _renderDuration.inMilliseconds > 0
                ? _renderPosition.inMilliseconds / _renderDuration.inMilliseconds
                : 0.0;
          }
        });
      }
    }));

    // 监听播放时长
    _subscriptions.add(_audioManager.durationStream.listen((duration) {
      if (mounted) {
        setState(() {
          if (duration.totalDuration > Duration.zero) {
            _totalDuration = duration.totalDuration;
            _previewStartPosition = duration.previewStart ?? Duration.zero;
            _previewDuration = duration.previewDuration ?? Duration.zero;
            _createDurationProxy();
          }
        });
      }
    }));

    // 监听播放状态
    _subscriptions.add(_audioManager.playerStateStream.listen((playerState) {
      if (mounted) {
        setState(() {
          _disabled = playerState.processingState == ProcessingState.loading;
        });
      }
    }));

    // 监听缓冲位置
    _subscriptions.add(_audioManager.bufferedPositionStream.listen((bufferedPosition) {
      if (mounted) {
        setState(() {
          if (_durationProxy != null) {
            _renderBufferedPosition = _durationProxy!.realPositionToRenderPosition(bufferedPosition);
          } else {
            _renderBufferedPosition = bufferedPosition;
          }
        });
      }
    }));
  }
  
  /// 创建时长代理服务
  void _createDurationProxy() {
    if (_totalDuration == Duration.zero) {
      _durationProxy = null;
      _renderDuration = Duration.zero;
      return;
    }
    
    // 根据是否能播放全部时长来决定是否启用预览模式
    if (!_isPreviewMode) {
      // 可以播放全部时长，使用普通模式
      _durationProxy = DurationProxyService.createNormal(_totalDuration);
    } else {
      // 只能播放预览时长，使用预览模式
      _durationProxy = DurationProxyService.createPreview(
        duration: _totalDuration,
        previewStart: _previewStartPosition,
        previewDuration: _previewDuration,
      );
    }

    // 转换时长
    _renderDuration = _durationProxy!.renderDuration;
    _renderStart = _durationProxy!.renderStart;
    _renderPreviewStart = _previewStartPosition - _durationProxy!.renderStart;
    // 在预览模式下，预览时长就是整个渲染时长
    // 在普通模式下，预览时长需要转换为渲染坐标系
    if (_durationProxy!.isPreviewMode) {
      _renderPreviewDuration = _previewDuration;
    } else {
      _renderPreviewDuration = Duration.zero;
    }
  }
  
  Future<void> _onSeek(Duration position) async {
    // 将渲染位置转换为真实位置后进行seek
    Duration realPosition = position;
    if (_durationProxy != null) {
      realPosition = _durationProxy!.renderPositionToRealPosition(position);
    }
    await _audioManager.seek(realPosition);
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
    super.dispose();
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
    if (_renderDuration.inMilliseconds > 0) {
      progress = _isDragging
          ? _dragValue
          : _renderPosition.inMilliseconds / _renderDuration.inMilliseconds;
    }

    // 计算预览区域（在渲染坐标系中，预览区域就是整个可见区域）
    double previewStart = 0.0;
    double previewEnd = 1.0;
    double bufferedProgress = 0.0;
    previewStart = _renderPreviewStart.inMilliseconds / _renderDuration.inMilliseconds;
    previewEnd = (_renderPreviewStart.inMilliseconds + _renderPreviewDuration.inMilliseconds) / _renderDuration.inMilliseconds;
    bufferedProgress = _renderBufferedPosition.inMilliseconds / _renderDuration.inMilliseconds;

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
              trackHeight: 2.0,
              thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 4.0),
              overlayShape: const RoundSliderOverlayShape(overlayRadius: 16.0),
              activeTrackColor: Color(0xFF999999)/*.withAlpha(200)*/,
              inactiveTrackColor: Color(0xFF999999)/*.withAlpha(200)*/,
              thumbColor: Colors.white,
              overlayColor: Colors.white/*.withAlpha(64)*/,
              // 自定义轨道形状，传递预览区域参数
              trackShape: CustomTrackShape(
                previewStart: previewStart,
                previewEnd: previewEnd,
                showPreview: _durationProxy!.isPreviewMode == true,
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
              onChanged: _disabled ? null : (value) async {
                setState(() {
                  _isDragging = true;
                  _dragValue = value;
                });
                
                // 检查是否超出预览区域
                 if (_isPreviewMode && value < previewStart || value > previewEnd) {
                   // 预览模式下，检查是否需要触发解锁回调
                    widget.onOutPreview();
                 }
                
                final realValue = _isPreviewMode ?  value.clamp(previewStart, previewEnd) : value;
                // 将slider值转换为渲染位置
                final renderPosition = Duration(
                  milliseconds: (realValue * _renderDuration.inMilliseconds).round(),
                );

                final realPosition = _durationProxy!.renderPositionToRealPosition(renderPosition);
                // 通过_onSeek方法进行seek，它会自动转换为真实位置
                await _onSeek(realPosition);
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
                _formatDuration(_renderPosition),
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 10,
                  fontWeight: FontWeight.w400,
                ),
              ),
              Text(
                _formatDuration(_renderDuration),
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
    final trackHeight = 1.6;
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
    double additionalActiveTrackHeight = 2.0,
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
