import 'package:flutter/material.dart';
import 'dart:math' as math;

import '../utils/custom_icons.dart';

class CircularPlayButton extends StatefulWidget {
  final double size;
  final String? coverImageUrl;
  final bool isPlaying;
  final double progress; // 0.0 到 1.0
  final VoidCallback? onTap;
  final Color progressColor;
  final Color backgroundColor;
  final double strokeWidth;

  const CircularPlayButton({
    super.key,
    this.size = 64.0,
    this.coverImageUrl,
    this.isPlaying = false,
    this.progress = 0.0,
    this.onTap,
    this.progressColor = const Color(0xFF5B37F9),
    this.backgroundColor = Colors.grey,
    this.strokeWidth = 3.0,
  });

  @override
  State<CircularPlayButton> createState() => _CircularPlayButtonState();
}

class _CircularPlayButtonState extends State<CircularPlayButton>
    with SingleTickerProviderStateMixin {
  late AnimationController _rotationController;

  @override
  void initState() {
    super.initState();
    _rotationController = AnimationController(
      duration: const Duration(seconds: 10),
      vsync: this,
    );

    // 如果正在播放，启动旋转动画
    if (widget.isPlaying) {
      _rotationController.repeat();
    }
  }

  @override
  void didUpdateWidget(CircularPlayButton oldWidget) {
    super.didUpdateWidget(oldWidget);

    // 根据播放状态控制旋转动画
    if (widget.isPlaying && !oldWidget.isPlaying) {
      _rotationController.repeat();
    } else if (!widget.isPlaying && oldWidget.isPlaying) {
      _rotationController.stop();
    }
  }

  @override
  void dispose() {
    _rotationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final playIconSize = widget.isPlaying
        ? widget.size *
              0.3 // 暂停图标大小
        : widget.size * 0.36; // 播放图标大小

    return GestureDetector(
      onTap: widget.onTap,
      child: Container(
        width: widget.size,
        height: widget.size,
        child: Stack(
          alignment: Alignment.center,
          children: [
            // 外围进度圆环
            SizedBox(
              width: widget.size,
              height: widget.size,
              child: CustomPaint(
                painter: _CircularProgressPainter(
                  progress: widget.progress,
                  progressColor: widget.progressColor,
                  backgroundColor: widget.backgroundColor.withOpacity(0.2),
                  strokeWidth: widget.strokeWidth,
                ),
              ),
            ),

            // 中间的封面和播放图标区域
            AnimatedBuilder(
              animation: _rotationController,
              builder: (context, child) {
                return Transform.rotate(
                  angle: widget.isPlaying
                      ? _rotationController.value * 2 * math.pi
                      : 0,
                  child: Container(
                    width: widget.size - widget.strokeWidth * 2,
                    height: widget.size - widget.strokeWidth * 2,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.1),
                          blurRadius: 4,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: ClipOval(
                      child: widget.coverImageUrl != null
                          ? Image.network(
                              widget.coverImageUrl!,
                              fit: BoxFit.cover,
                              errorBuilder: (context, error, stackTrace) {
                                return _buildDefaultCover();
                              },
                              loadingBuilder:
                                  (context, child, loadingProgress) {
                                    if (loadingProgress == null) return child;
                                    return _buildDefaultCover();
                                  },
                            )
                          : _buildDefaultCover(),
                    ),
                  ),
                );
              },
            ),

            // 播放/暂停图标覆盖层
            Transform.translate(
              offset: widget.isPlaying
                  ? const Offset(0, 0)
                  : Offset(playIconSize / 10, 0),
              child: Icon(
                widget.isPlaying ? CustomIcons.pause : CustomIcons.play_arrow,
                color: Colors.white,
                size: playIconSize,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDefaultCover() {
    return Container(
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: RadialGradient(
          center: const Alignment(0.6, -0.3),
          radius: 1.0,
          stops: [0.0, 0.08, 0.4, 0.9, 1.0],
          colors: [
            widget.progressColor.withOpacity(0.0),
            widget.progressColor.withOpacity(0.0),
            widget.progressColor.withOpacity(0.5),
            widget.progressColor.withOpacity(1.0),
            widget.progressColor.withOpacity(1.0),
          ],
        ),
      ),
    );
  }
}

class _CircularProgressPainter extends CustomPainter {
  final double progress;
  final Color progressColor;
  final Color backgroundColor;
  final double strokeWidth;

  _CircularProgressPainter({
    required this.progress,
    required this.progressColor,
    required this.backgroundColor,
    required this.strokeWidth,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = (size.width - strokeWidth) / 2;

    // 绘制背景圆环
    final backgroundPaint = Paint()
      ..color = backgroundColor
      ..strokeWidth = strokeWidth
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    canvas.drawCircle(center, radius, backgroundPaint);

    // 绘制进度圆环
    if (progress > 0) {
      final progressPaint = Paint()
        ..color = progressColor
        ..strokeWidth = strokeWidth
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.round;

      final sweepAngle = 2 * math.pi * progress;
      canvas.drawArc(
        Rect.fromCircle(center: center, radius: radius),
        -math.pi / 2, // 从顶部开始
        sweepAngle,
        false,
        progressPaint,
      );
    }
  }

  @override
  bool shouldRepaint(_CircularProgressPainter oldDelegate) {
    return oldDelegate.progress != progress ||
        oldDelegate.progressColor != progressColor ||
        oldDelegate.backgroundColor != backgroundColor ||
        oldDelegate.strokeWidth != strokeWidth;
  }
}
