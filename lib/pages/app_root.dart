import 'package:flutter/material.dart';
import 'dart:async';
import '../layouts/main_layout.dart';
import '../pages/home_page.dart';
import '../pages/profile_page.dart';
import '../services/audio_manager.dart';
import '../services/subscribe_privilege_manager.dart';
import '../services/auth_manager.dart';
import '../services/network_healthy_manager.dart';

/// 应用根组件 - 包含 MainApp 和 Splash 浮层
class AppRoot extends StatefulWidget {
  const AppRoot({super.key});

  @override
  State<AppRoot> createState() => _AppRootState();
}

class _AppRootState extends State<AppRoot> with TickerProviderStateMixin {
  bool _isInitialized = false;
  bool servicesInitialized = false;
  late AnimationController _fadeController;
  late Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();
    
    // 初始化动画控制器
    _fadeController = AnimationController(
      duration: const Duration(milliseconds: 500),
      vsync: this,
    );
    
    _fadeAnimation = Tween<double>(
      begin: 1.0,
      end: 0.0,
    ).animate(CurvedAnimation(
      parent: _fadeController,
      curve: Curves.easeOut,
    ));
    
    _initializeApp();
  }

  @override
  void dispose() {
    _fadeController.dispose();
    super.dispose();
  }

  Future<void> _initializeApp() async {
    debugPrint('🔄 [APP_ROOT] 开始初始化应用');

    // 异步初始化服务，不阻塞UI渲染
    debugPrint('🔄 [APP_ROOT] 开始异步初始化服务');
    _initializeServices();

    // 显示启动页2秒，让用户看到启动画面
    debugPrint('🔄 [APP_ROOT] 等待2秒显示启动画面');
    await Future.delayed(const Duration(seconds: 2));
    debugPrint('🔄 [APP_ROOT] 启动画面显示完成，开始淡出动画');

    // 开始淡出动画
    if (mounted) {
      await _fadeController.forward();
      setState(() {
        _isInitialized = true;
      });
      debugPrint('🔄 [APP_ROOT] Splash浮层已隐藏');
    }
  }

  Future<void> _initializeServices() async {
    try {
      await AudioManager.instance.preloadLastPlayedAudio(); // 从本地存储中加载上次播放的音频
      debugPrint('🔄 [APP_ROOT] 预加载上次播放音频完成');

      await NetworkHealthyManager.instance.initialize();
      debugPrint('🔄 [APP_ROOT] NetworkHealthyManager 初始化完成');

      await AuthManager.instance.initialize();  // 初始化认证服务
      debugPrint('🔄 [APP_ROOT] AuthManager 初始化完成');

      await SubscribePrivilegeManager.instance.initialize(); // 初始化订阅权益服务
      debugPrint('🔄 [APP_ROOT] SubscribePrivilegeManager 初始化完成');
      
      await AudioManager.instance.init(); // 初始化音频服务
      debugPrint('🔄 [APP_ROOT] AudioManager 初始化完成');

      debugPrint('🔄 [APP_ROOT] _initializeServices 服务初始化完成');
    } catch (e) {
      debugPrint('Failed to initialize services: $e');
    } finally {
      if (mounted) {
        setState(() {
          servicesInitialized = true;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          // 主应用（提前渲染）
          const MainApp(),
          
          // Splash 浮层
          if (!_isInitialized)
            AnimatedBuilder(
              animation: _fadeAnimation,
              builder: (context, child) {
                return Opacity(
                  opacity: _fadeAnimation.value,
                  child: const SplashOverlay(),
                );
              },
            ),
        ],
      ),
    );
  }
}

/// Splash 浮层内容组件
class SplashOverlay extends StatelessWidget {
  const SplashOverlay({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      height: double.infinity,
      color: Colors.white, // 白色背景
      child: Container(
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
              width: MediaQuery.of(context).size.width * 0.5, // 图片宽度为屏幕宽度的50%
              fit: BoxFit.contain, // 保持图片比例
            ),
            const SizedBox(height: 40),
          ],
        ),
       ),
     );
   }
 }

// 独立的MainApp组件，从main.dart中提取
class MainApp extends StatelessWidget {
  const MainApp({super.key});

  // 静态页面列表，避免每次构建时重新创建
  static const List<Widget> _pages = [HomePage(), ProfilePage()];
  static const List<String> _pageTitles = ['Home', 'Profile'];

  @override
  Widget build(BuildContext context) {
    debugPrint('🏠 [MAIN_APP] MainApp构建开始');
    const result = MainLayout(
      pages: _pages,
      pageTitles: _pageTitles,
      initialIndex: 0,
    );
    debugPrint('🏠 [MAIN_APP] MainApp构建完成');
    return result;
  }
}
