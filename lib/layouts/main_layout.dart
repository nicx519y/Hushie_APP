import 'package:flutter/material.dart';
import '../components/bottom_navigation_bar.dart';
import '../pages/video_player_page.dart';

class MainLayout extends StatefulWidget {
  final List<Widget> pages;
  final List<String> pageTitles;
  final int initialIndex;

  const MainLayout({
    super.key,
    required this.pages,
    required this.pageTitles,
    this.initialIndex = 0,
  });

  @override
  State<MainLayout> createState() => _MainLayoutState();
}

class _MainLayoutState extends State<MainLayout> {
  late int _currentIndex;

  @override
  void initState() {
    super.initState();
    _currentIndex = widget.initialIndex;
  }

  // 处理底部导航栏点击
  void _onBottomNavTap(int index) {
    setState(() {
      _currentIndex = index;
    });

    switch (index) {
      case 0:
        print('切换到Home页面');
        break;
      case 1:
        print('切换到Profile页面');
        break;
    }
  }

  // 处理播放按钮点击
  void _onPlayButtonTap() {
    Navigator.push(
      context,
      PageRouteBuilder(
        pageBuilder: (context, animation, secondaryAnimation) =>
            const VideoPlayerPage(
              videoTitle: 'Sticky Situation',
              artist: 'Buddah Bless',
              description:
                  'Quiet and reserved, she doesn\'t say much but is quite intriguing for something exotic. More',
              likesCount: 689,
              videoUrl: 'https://example.com/video.mp4',
              coverUrl: 'https://picsum.photos/400/600?random=1',
            ),
        transitionDuration: const Duration(milliseconds: 300),
        reverseTransitionDuration: const Duration(milliseconds: 300),
        transitionsBuilder: (context, animation, secondaryAnimation, child) {
          // 从下到上的滑动动画
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
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,

      body: Stack(
        children: [
          // 页面主体内容
          SafeArea(
            bottom: false,
            child: IndexedStack(index: _currentIndex, children: widget.pages),
          ),

          // 底部导航栏（放在Stack最上层，脱离Scaffold默认布局）
          Positioned(
            left: 0,
            right: 0,
            bottom: -30, // 考虑底部安全区域
            child: Stack(
              children: [
                // 自定义阴影
                CustomPaint(
                  painter: BottomNavShadowPainter(),
                  size: Size(
                    MediaQuery.of(context).size.width,
                    120 + MediaQuery.of(context).padding.bottom,
                  ),
                ),
                // 导航栏内容
                ClipPath(
                  clipper: BottomNavClipper(),
                  child: CustomBottomNavigationBar(
                    currentIndex: _currentIndex,
                    onTap: _onBottomNavTap,
                    onPlayButtonTap: _onPlayButtonTap,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
      // 禁用默认的bottomNavigationBar
      bottomNavigationBar: const SizedBox.shrink(),
    );
  }
}

// 共享的路径生成函数
Path createBottomNavPath(Size size, {double offsetY = 0}) {
  final path = Path();
  final width = size.width;
  final height = size.height;
  final radius = 50.0;
  final d = 18.0;
  final arcRadius = 30.0;
  final sideRadius = 20.0;

  // 从左下角开始
  path.moveTo(0, height);

  // 左侧直线向上
  path.lineTo(0, d + offsetY);

  // 左侧水平延伸到曲线起点
  path.lineTo(width / 2 - radius, d + offsetY);

  // 第一段：从左侧到顶部的三次贝塞尔曲线
  path.cubicTo(
    width / 2 - radius + sideRadius,
    d + offsetY,
    width / 2 - arcRadius,
    0 + offsetY,
    width / 2,
    0 + offsetY,
  );

  // 第二段：从顶部到右侧的三次贝塞尔曲线
  path.cubicTo(
    width / 2 + arcRadius,
    0 + offsetY,
    width / 2 + radius - sideRadius,
    d + offsetY,
    width / 2 + radius,
    d + offsetY,
  );

  // 右侧水平延伸
  path.lineTo(width, d + offsetY);

  // 右侧直线到底部
  path.lineTo(width, height);

  // 闭合路径
  path.close();

  return path;
}

// 自定义裁剪器，实现中间凸起的形状
class BottomNavClipper extends CustomClipper<Path> {
  @override
  Path getClip(Size size) {
    return createBottomNavPath(size);
  }

  @override
  bool shouldReclip(covariant CustomClipper<Path> oldClipper) => false;
}

// 自定义阴影绘制器
class BottomNavShadowPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.black.withOpacity(0.15)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 10);

    // 使用共享的路径生成函数，向上偏移2像素
    final path = createBottomNavPath(size, offsetY: -2);
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
