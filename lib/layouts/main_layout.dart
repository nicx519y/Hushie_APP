import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../components/bottom_navigation_bar.dart';
import '../pages/home_page.dart';
import '../pages/profile_page.dart';
import '../utils/toast_helper.dart';
import '../utils/toast_messages.dart';
import '../services/app_operations_service.dart';

// 全局路由观察者
final RouteObserver<ModalRoute<void>> globalRouteObserver =
    RouteObserver<ModalRoute<void>>();

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
  int _currentIndex = 0;
  DateTime? _lastPressedAt;

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
        debugPrint('切换到Home页面');
        break;
      case 1:
        debugPrint('切换到Me页面');
        break;
    }
  }

  /// 处理返回按键事件
  Future<void> _onWillPop() async {
    final now = DateTime.now();
    
    // 检查是否在2秒内连续按下返回键
    if (_lastPressedAt == null || now.difference(_lastPressedAt!) > const Duration(seconds: 2)) {
      // 第一次按下或超过2秒，显示提示并记录时间
      _lastPressedAt = now;
      ToastHelper.showInfo(ToastMessages.appWillClose);
      return;
    }
    
    // 第二次按下且在2秒内，使用原生方法退到后台
    await _exitWithNativeAnimation();
  }

  /// 使用原生动画退到后台
  Future<void> _exitWithNativeAnimation() async {
    try {
      await AppOperationsService.sendToBackground();
    } catch (e) {
      // 如果原生方法失败，使用系统默认退出
      SystemNavigator.pop();
    }
  }



  @override
  Widget build(BuildContext context) {
    debugPrint('🏗️ [MAIN_LAYOUT] MainLayout构建开始');
    return PopScope(
      canPop: false, // 禁止默认的返回行为
      onPopInvoked: (didPop) {
        if (!didPop) {
          _onWillPop();
        }
      },
      child: RepaintBoundary(
        child: _buildMainContent(),
      ),
    );
  }

  Widget _buildMainContent() {
    return Scaffold(
        backgroundColor: Colors.white,
        extendBodyBehindAppBar: true, // 让body延伸到状态栏后面

        body: Stack(
          children: [
            // 页面主体内容
            SafeArea(
              top: true, // 确保内容不被状态栏遮挡
              bottom: true,
              child: RepaintBoundary(
                child: IndexedStack(index: _currentIndex, children: widget.pages),
              ),
            ),

            // 底部导航栏（放在Stack最上层，脱离Scaffold默认布局）
            Positioned(
              left: 0,
              right: 0,
              bottom: -46 + MediaQuery.of(context).padding.bottom, // 智能适配底部安全区域
              child: Stack(
                children: [
                  // 自定义阴影
                  CustomPaint(
                    painter: BottomNavShadowPainter(),
                    size: Size(
                      MediaQuery.of(context).size.width,
                      108,
                    ),
                  ),
                  // 导航栏内容
                  ClipPath(
                    clipper: BottomNavClipper(),
                    child: CustomBottomNavigationBar(
                      currentIndex: _currentIndex,
                      onTap: _onBottomNavTap,
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
  final radius = 46.0;
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
      ..color = Colors.black.withAlpha(40)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 10);

    // 使用共享的路径生成函数，向上偏移2像素
    final path = createBottomNavPath(size, offsetY: -2);
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
