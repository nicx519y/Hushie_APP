import 'package:flutter/material.dart';
import 'dart:async';
import '../layouts/main_layout.dart';
import '../pages/home_page.dart';
import '../pages/profile_page.dart';
import '../services/audio_manager.dart';
import '../router/navigation_utils.dart';

class SplashPage extends StatefulWidget {
  const SplashPage({super.key});

  @override
  State<SplashPage> createState() => _SplashPageState();
}

class _SplashPageState extends State<SplashPage> {
  bool _servicesInitialized = false;

  @override
  void initState() {
    super.initState();
    _initializeApp();
  }

  Future<void> _initializeApp() async {
    debugPrint('🔄 [SPLASH] 开始初始化应用');

    // 先显示启动页2秒，让用户看到启动画面
    debugPrint('🔄 [SPLASH] 等待2秒显示启动画面');
    await Future.delayed(const Duration(seconds: 2));
    debugPrint('🔄 [SPLASH] 启动画面显示完成');

    // 然后异步初始化服务，不阻塞UI
    debugPrint('🔄 [SPLASH] 开始异步初始化服务');
    _initializeServices();

    // 延迟跳转，给服务初始化一些时间
    // debugPrint('🔄 [SPLASH] 等待500ms后跳转');
    // await Future.delayed(const Duration(milliseconds: 500));
    // debugPrint('🔄 [SPLASH] 延迟完成，准备跳转');

    // 跳转到主页（无动画）
    if (mounted) {
      debugPrint('🔄 [SPLASH] 开始跳转到MainApp');
      NavigationUtils.navigateToMainApp(context, const MainApp());
      debugPrint('🔄 [SPLASH] 跳转完成');
    } else {
      debugPrint('🔄 [SPLASH] 组件已卸载，取消跳转');
    }
  }

  Future<void> _initializeServices() async {
    try {
      await AudioManager.instance.init();
      if (mounted) {
        setState(() {
          _servicesInitialized = true;
        });
      }
    } catch (e) {
      debugPrint('Failed to initialize services: $e');
      if (mounted) {
        setState(() {
          _servicesInitialized = true;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white, // 白色背景
      body: Container(
        width: double.infinity,
        height: double.infinity,
        decoration: const BoxDecoration(
          image: DecorationImage(
            image: AssetImage('assets/images/luster_bg.png'),
            colorFilter: ColorFilter.mode(Colors.transparent, BlendMode.color),
            fit: BoxFit.fill,
            alignment: Alignment.topCenter,
          ),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // 启动页图片
            Image.asset(
              'assets/images/splash.png',
              width: MediaQuery.of(context).size.width * 0.5, // 图片宽度为屏幕宽度的60%
              fit: BoxFit.contain, // 保持图片比例
            ),
            const SizedBox(height: 40),
            // 加载指示器
            // if (!_servicesInitialized)
            //   Column(
            //     children: [
            //       const CircularProgressIndicator(
            //         valueColor: AlwaysStoppedAnimation<Color>(
            //           Color(0xFFF359AA),
            //         ),
            //       ),
            //       const SizedBox(height: 16),
            //       Text(
            //         'Initializing services...',
            //         style: TextStyle(fontSize: 14, color: Colors.grey[600]),
            //       ),
            //     ],
            //   ),
          ],
        ),
      ),
    );
  }
}

// 独立的MainApp组件，从main.dart中提取
class MainApp extends StatelessWidget {
  const MainApp({super.key});

  @override
  Widget build(BuildContext context) {
    debugPrint('🏠 [MAIN_APP] MainApp构建开始');
    final result = MainLayout(
      pages: const [HomePage(), ProfilePage()],
      pageTitles: const ['Home', 'Profile'],
      initialIndex: 0,
    );
    debugPrint('🏠 [MAIN_APP] MainApp构建完成');
    return result;
  }
}
