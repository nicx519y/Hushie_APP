import 'package:flutter/material.dart';

class AudioProgressBar extends StatefulWidget {
  final Duration currentPosition;
  final Duration totalDuration;
  final Duration previewStartPosition;
  final Duration previewDuration; 
  final bool needInPreviewDuration;
  final Function() onOutPreview;
  final Function(Duration) onSeek;
  final bool isDragging;
  final double? width; // 添加宽度参数

  const AudioProgressBar({
    super.key,
    required this.currentPosition,
    required this.totalDuration,
    required this.previewStartPosition,
    required this.previewDuration,
    required this.needInPreviewDuration,
    required this.onOutPreview,
    required this.onSeek,
    this.isDragging = false,
    this.width,
  });

  @override
  State<AudioProgressBar> createState() => _AudioProgressBarState();
}

class _AudioProgressBarState extends State<AudioProgressBar> {
  double _dragValue = 0.0;
  bool _isDragging = false;

  @override
  void initState() {
    super.initState();
    _isDragging = widget.isDragging;
  }

  @override
  void didUpdateWidget(AudioProgressBar oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!_isDragging) {
      _dragValue =
          widget.currentPosition.inMilliseconds /
          widget.totalDuration.inMilliseconds;
    }
  }

  String _formatDuration(Duration duration) {
    String twoDigits(int n) => n.toString().padLeft(2, '0');
    String twoDigitMinutes = twoDigits(duration.inMinutes.remainder(60));
    String twoDigitSeconds = twoDigits(duration.inSeconds.remainder(60));
    return "$twoDigitMinutes:$twoDigitSeconds";
  }

  @override
  Widget build(BuildContext context) {
    final progress = _isDragging
        ? _dragValue
        : widget.currentPosition.inMilliseconds /
              widget.totalDuration.inMilliseconds;

    // 计算预览区域的相对位置
    final previewStart = widget.previewStartPosition.inMilliseconds /
        widget.totalDuration.inMilliseconds;
    final previewEnd = (widget.previewStartPosition.inMilliseconds +
            widget.previewDuration.inMilliseconds) /
        widget.totalDuration.inMilliseconds;

    return Column(
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
              activeTrackColor: Color(0xFF999999).withAlpha(200),
              inactiveTrackColor: Color(0xFF999999).withAlpha(200),
              thumbColor: Colors.white,
              overlayColor: Colors.white.withAlpha(64),
              // 自定义轨道形状，传递预览区域参数
              trackShape: CustomTrackShape(
                previewStart: previewStart,
                previewEnd: previewEnd,
                showPreview: widget.needInPreviewDuration,
              ),
            ),
            child: Slider( 
              value: progress.clamp(0.0, 1.0),
              onChanged: (value) async {
                // 如果需要限制在预览区域内
                if (widget.needInPreviewDuration) {
                  // 检查是否超出预览区域边界
                  if (value < previewStart || value > previewEnd) {
                    // 触发边界回调
                    widget.onOutPreview();
                    return; // 不更新位置
                  }
                  // 限制在预览区域内
                  value = value.clamp(previewStart, previewEnd);
                }
                
                setState(() {
                  _isDragging = true;
                  _dragValue = value;
                });
                final newPosition = Duration(
                  milliseconds: (value * widget.totalDuration.inMilliseconds)
                      .round(),
                );
                await widget.onSeek(newPosition);
              },
              onChangeEnd: (value) async {
                // 如果需要限制在预览区域内
                if (widget.needInPreviewDuration) {
                  value = value.clamp(previewStart, previewEnd);
                }
                
                final newPosition = Duration(
                  milliseconds: (value * widget.totalDuration.inMilliseconds)
                      .round(),
                );
                await widget.onSeek(newPosition);
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
                _formatDuration(widget.currentPosition),
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 10,
                  fontWeight: FontWeight.w400,
                ),
              ),
              Text(
                _formatDuration(widget.totalDuration),
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
    );
  }
}

// 自定义轨道形状，支持预览区域绘制
class CustomTrackShape extends RoundedRectSliderTrackShape {
  final double previewStart;
  final double previewEnd;
  final bool showPreview;

  const CustomTrackShape({
    this.previewStart = 0.0,
    this.previewEnd = 1.0,
    this.showPreview = false,
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

    // 如果需要显示预览区域，绘制白色预览条
    if (showPreview) {
      final trackRect = getPreferredRect(
        parentBox: parentBox,
        offset: offset,
        sliderTheme: sliderTheme,
        isEnabled: isEnabled,
        isDiscrete: isDiscrete,
      );

      final previewLeft = trackRect.left + (trackRect.width * previewStart);
      final previewWidth = trackRect.width * (previewEnd - previewStart);
      
      final previewRect = Rect.fromLTWH(
        previewLeft,
        trackRect.top,
        previewWidth,
        trackRect.height,
      );

      final previewPaint = Paint()
        ..color = Colors.white
        ..style = PaintingStyle.fill;

      // 绘制预览条
      context.canvas.drawRRect(
        RRect.fromRectAndRadius(
          previewRect,
          Radius.circular(trackRect.height / 2),
        ),
        previewPaint,
      );

      // 绘制预览条两端的白色圆点（半径2px）
      final circlePaint = Paint()
        ..color = Colors.white
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
