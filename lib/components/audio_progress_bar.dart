import 'dart:async';
import 'package:flutter/material.dart';
import 'package:just_audio/just_audio.dart';
import '../services/audio_manager.dart';
import '../services/audio_service.dart';


class AudioProgressBar extends StatefulWidget {
  final double? width;
  // 新增：关键点参数，使用 Duration 表示时间点
  final List<Duration> keyPoints;

  const AudioProgressBar({
    super.key,
    this.width,
    this.keyPoints = const [],
  });

  @override
  State<AudioProgressBar> createState() => _AudioProgressBarState();
}

class _AudioProgressBarState extends State<AudioProgressBar> {
  double _dragValue = 0.0;
  bool _isDragging = false;

  // 内部状态
  bool _disabled = false;

  // 渲染用的位置和时长
  Duration _renderPosition = Duration.zero;
  Duration _renderDuration = Duration.zero;

  // 真实的音频时长（用于显示）
  Duration _realDuration = Duration.zero;
  Duration _realPosition = Duration.zero;

  late AudioManager _audioManager;

  // StreamSubscription列表，用于在dispose时取消
  final List<StreamSubscription> _subscriptions = [];

  // 本地状态缓存，用于差异对比
  AudioPlayerState? _lastAudioState;

  @override
  void initState() {
    super.initState();
    _audioManager = AudioManager.instance;
    _resetAudioStateListener();
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

    // 始终使用非预览模式逻辑
    _subscriptions.add(
      _audioManager.audioStateStream.listen((audioState) {
        if (mounted) {
          final lastState = _lastAudioState;
          if (lastState == null || _hasStateChanged(lastState, audioState)) {
            bool needsUpdate = false;

            // 检查当前音频是否变化
            if (_lastAudioState?.currentAudio?.id !=
                audioState.currentAudio?.id) {
              // 音频切换时立即清零所有展现值
              // _renderPosition = Duration.zero;
              // _renderDuration = Duration.zero;
              // _realPosition = Duration.zero;
              // _realDuration = Duration.zero;
              // _dragValue = 0.0;
              needsUpdate = true;
            }

            // 非预览模式下直接使用真实duration
            if (_renderDuration != audioState.duration) {
              _renderDuration = audioState.duration ?? Duration.zero;
              needsUpdate = true;
            }

            // 检查播放位置是否变化
            if (_lastAudioState?.position != audioState.position) {
              _renderPosition = audioState.position;
              if (!_isDragging) {
                _dragValue = _renderDuration.inMilliseconds > 0
                    ? _renderPosition.inMilliseconds /
                        _renderDuration.inMilliseconds
                    : 0.0;
              }
              needsUpdate = true;
            }

            // 已移除缓冲位置跟踪

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

            if (needsUpdate) {
              setState(() {});
            }

            _lastAudioState = audioState;
          }
        }
      }),
    );
  }

  Future<void> _onSeek(Duration position) async {
    await _audioManager.seek(position);
  }

  @override
  void didUpdateWidget(AudioProgressBar oldWidget) {
    super.didUpdateWidget(oldWidget);
    // 移除旧的逻辑，现在由内部监听处理
  }

  @override
  void dispose() {
    for (final subscription in _subscriptions) {
      subscription.cancel();
    }
    _subscriptions.clear();
    _lastAudioState = null;
    _realDuration = Duration.zero;
    _realPosition = Duration.zero;
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

  String _formatDuration(Duration duration) {
    String twoDigits(int n) => n.toString().padLeft(2, '0');
    final hours = duration.inHours;
    final minutes = duration.inMinutes.remainder(60);
    final seconds = duration.inSeconds.remainder(60);
    if (hours > 0) {
      return "${twoDigits(hours)}:${twoDigits(minutes)}:${twoDigits(seconds)}";
    } else {
      return "${twoDigits(minutes)}:${twoDigits(seconds)}";
    }
  }

  @override
  Widget build(BuildContext context) {
    // 计算进度
    double progress = 0.0;
    // 移除未使用的缓冲进度变量
    // double bufferedProgress = 0.0;

    // 计算关键点的归一化位置（0.0 ~ 1.0）
    final List<double> keyPointPositions = (_renderDuration.inMilliseconds > 0)
        ? widget.keyPoints
            .where((d) => !d.isNegative && d <= _renderDuration)
            .map((d) => d.inMilliseconds / _renderDuration.inMilliseconds)
            .map((p) => p.clamp(0.0, 1.0))
            .toList()
        : const [];

    if (_renderDuration.inMilliseconds > 0) {
      progress = _isDragging
          ? _dragValue
          : _renderPosition.inMilliseconds / _renderDuration.inMilliseconds;

      // 已移除缓冲进度计算
    }

    return Opacity(
      opacity: _disabled ? 1.0 : 1.0, // 禁用时透明度降低50%
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
                  thumbShape: const RoundSliderThumbShape(
                    enabledThumbRadius: 5.0, // 拖拽点半径
                  ),
                  overlayShape: const RoundSliderOverlayShape(
                    overlayRadius: 16.0,
                  ),
                  activeTrackColor: Color(0xffffffff).withAlpha(128),
                  inactiveTrackColor: Color(0xff999999).withAlpha(128),
                  thumbColor: Colors.white,
                  overlayColor: Colors.white,
                  // 使用包含关键点的自定义轨道
                  trackShape: CustomTrackShape(
                    keyPointPositions: _disabled ? [] : keyPointPositions,
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

                          final renderPosition = Duration(
                            milliseconds:
                                (value * _renderDuration.inMilliseconds)
                                    .round(),
                          );

                          await _onSeek(renderPosition);
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
                  // _realDuration > Duration.zero
                      Text(
                          _realDuration > Duration.zero ? _formatDuration(_realPosition) : '00:00',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 10,
                            fontWeight: FontWeight.w400,
                          ),
                        ),
                      // : Container(),
                  // _realDuration > Duration.zero
                      Text(
                          _realDuration > Duration.zero ? _formatDuration(_realDuration) : '00:00',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 10,
                            fontWeight: FontWeight.w400,
                          ),
                        )
                      // : Container(),
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
  // 新增：关键点位置（0.0 ~ 1.0），以及样式参数
  final List<double> keyPointPositions;
  final Color keyPointColor;
  final double keyPointWidth;

  const CustomTrackShape({
    this.keyPointPositions = const [],
    this.keyPointColor = const Color(0xFFFF2050),
    this.keyPointWidth = 6.0,
  });

  @override
  Rect getPreferredRect({
    required RenderBox parentBox,
    Offset offset = Offset.zero,
    required SliderThemeData sliderTheme,
    bool isEnabled = false,
    bool isDiscrete = false,
  }) {
    final trackHeight = 6.0;
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

    // 绘制关键点标记（竖直短条）
    if (keyPointPositions.isNotEmpty) {
      final Paint markerPaint = Paint()
        ..color = keyPointColor.withOpacity(0.9)
        ..style = PaintingStyle.fill;

      for (final p in keyPointPositions) {
        final clamped = p.clamp(0.0, 1.0);
        final dx = trackRect.left + trackRect.width * clamped;
        final Rect markerRect = Rect.fromLTWH(
          dx - keyPointWidth / 2,
          trackRect.top,
          keyPointWidth,
          trackRect.height,
        );
        final RRect markerRRect = RRect.fromRectAndRadius(
          markerRect,
          Radius.circular(trackRect.height / 2),
        );
        context.canvas.drawRRect(markerRRect, markerPaint);
      }
    }

    // 保留：已移除缓冲条绘制逻辑
  }
}
