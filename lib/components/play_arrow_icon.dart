import 'package:flutter/material.dart';
import 'dart:math';

class PlayArrowIcon extends StatelessWidget {
  final double size;
  final double triangleSize;
  final double cornerRadius;
  final Color color;

  const PlayArrowIcon({
    super.key,
    this.size = 64.0,
    this.triangleSize = 20.0,
    this.cornerRadius = 3.0,
    this.color = Colors.white,
  });

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      size: Size(size, size),
      painter: PlayArrowPainter(
        triangleSize: triangleSize,
        cornerRadius: cornerRadius,
        color: color,
      ),
    );
  }
}

// 播放箭头绘制器
class PlayArrowPainter extends CustomPainter {
  final double triangleSize; // 三角形边长参数
  final double cornerRadius; // 圆角半径参数
  final Color color; // 颜色参数

  PlayArrowPainter({
    this.triangleSize = 16.0,
    this.cornerRadius = 2.0,
    this.color = Colors.white,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.fill;

    final path = Path();

    // 计算中心点
    final centerX = size.width / 2;
    final centerY = size.height / 2;

    // 绘制播放箭头（等边三角形）
    // 创建一个指向右侧的等边三角形，几何中心与画布中心重合
    final radius = triangleSize / 2; // 外接圆半径

    // 等边三角形的三个顶点（相对于外接圆圆心）
    // 右侧尖端（0度）
    final rightPoint = Offset(centerX + radius, centerY);
    // 左上点（120度）
    final leftTopPoint = Offset(
      centerX + radius * cos(2 * pi / 3),
      centerY + radius * sin(2 * pi / 3),
    );
    // 左下点（240度）
    final leftBottomPoint = Offset(
      centerX + radius * cos(4 * pi / 3),
      centerY + radius * sin(4 * pi / 3),
    );

    // 使用圆角路径
    path.moveTo(leftTopPoint.dx, leftTopPoint.dy);

    // 从左上到左下的圆角连接
    _addRoundedConnection(
      path,
      leftTopPoint,
      leftBottomPoint,
      rightPoint,
      cornerRadius,
    );

    // 从左下到右侧的圆角连接
    _addRoundedConnection(
      path,
      leftBottomPoint,
      rightPoint,
      leftTopPoint,
      cornerRadius,
    );

    // 从右侧到左上的圆角连接
    _addRoundedConnection(
      path,
      rightPoint,
      leftTopPoint,
      leftBottomPoint,
      cornerRadius,
    );

    path.close();
    canvas.drawPath(path, paint);
  }

  // 添加圆角连接的辅助方法
  void _addRoundedConnection(
    Path path,
    Offset from,
    Offset to,
    Offset next,
    double radius,
  ) {
    // 计算两个向量
    final vec1 = Offset(from.dx - to.dx, from.dy - to.dy);
    final vec2 = Offset(next.dx - to.dx, next.dy - to.dy);

    // 计算向量长度
    final len1 = sqrt(vec1.dx * vec1.dx + vec1.dy * vec1.dy);
    final len2 = sqrt(vec2.dx * vec2.dx + vec2.dy * vec2.dy);

    // 标准化向量
    final norm1 = Offset(vec1.dx / len1, vec1.dy / len1);
    final norm2 = Offset(vec2.dx / len2, vec2.dy / len2);

    // 计算圆角的起点和终点
    final startPoint = Offset(
      to.dx + norm1.dx * radius,
      to.dy + norm1.dy * radius,
    );
    final endPoint = Offset(
      to.dx + norm2.dx * radius,
      to.dy + norm2.dy * radius,
    );

    // 绘制到圆角起点
    path.lineTo(startPoint.dx, startPoint.dy);

    // 绘制圆角
    path.quadraticBezierTo(to.dx, to.dy, endPoint.dx, endPoint.dy);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
