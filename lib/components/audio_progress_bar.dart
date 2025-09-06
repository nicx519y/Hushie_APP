import 'package:flutter/material.dart';

class AudioProgressBar extends StatefulWidget {
  final Duration currentPosition;
  final Duration totalDuration;
  final Function(Duration) onSeek;
  final bool isDragging;
  final double? width; // 添加宽度参数

  const AudioProgressBar({
    super.key,
    required this.currentPosition,
    required this.totalDuration,
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

    return Column(
      children: [
        // 进度条
        Container(
          width: double.infinity,
          child: SliderTheme(
            data: SliderTheme.of(context).copyWith(
              trackHeight: 2.0,
              thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 8.0),
              overlayShape: const RoundSliderOverlayShape(overlayRadius: 16.0),
              activeTrackColor: Colors.white,
              inactiveTrackColor: Colors.white.withOpacity(0.3),
              thumbColor: Colors.white,
              overlayColor: Colors.white.withOpacity(0.2),
              // 自定义轨道形状，移除默认padding
              trackShape: const CustomTrackShape(),
            ),
            child: Slider(
              value: progress.clamp(0.0, 1.0),
              onChanged: (value) async {
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
          padding: const EdgeInsets.symmetric(horizontal: 0),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                _formatDuration(widget.currentPosition),
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 12,
                  fontWeight: FontWeight.w400,
                ),
              ),
              Text(
                _formatDuration(widget.totalDuration),
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 12,
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

// 自定义轨道形状，移除默认padding
class CustomTrackShape extends RoundedRectSliderTrackShape {
  const CustomTrackShape();

  @override
  Rect getPreferredRect({
    required RenderBox parentBox,
    Offset offset = Offset.zero,
    required SliderThemeData sliderTheme,
    bool isEnabled = false,
    bool isDiscrete = false,
  }) {
    final trackHeight = sliderTheme.trackHeight ?? 2.0;
    final trackLeft = offset.dx;
    final trackTop = offset.dy + (parentBox.size.height - trackHeight) / 2;
    final trackWidth = parentBox.size.width;
    return Rect.fromLTWH(trackLeft, trackTop, trackWidth, trackHeight);
  }
}
