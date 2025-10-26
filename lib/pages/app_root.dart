import 'package:flutter/material.dart';
import 'dart:async';
import '../layouts/main_layout.dart';
import '../pages/home_page.dart';
import '../pages/profile_page.dart';
import '../pages/onboarding_page.dart';
import '../services/audio_manager.dart';
import '../services/subscribe_privilege_manager.dart';
import '../services/auth_manager.dart';
import '../services/network_healthy_manager.dart';
import '../services/onboarding_manager.dart';
import '../services/api/tracking_service.dart';

/// 应用根组件 - 包含 MainApp 和 Splash 浮层
class AppRoot extends StatefulWidget {
  const AppRoot({super.key});

  @override
  State<AppRoot> createState() => _AppRootState();
}

class _AppRootState extends State<AppRoot> with WidgetsBindingObserver {
  bool servicesInitialized = false;
  bool onboardingChecked = false;
  bool showOnboarding = false;
  // 冷启动与前台恢复打点控制
  bool _startupAppOpenSent = false;
  bool _shouldSendOnResume = false;

  @override
  void initState() {
    super.initState();
    // 添加应用生命周期观察者，用于前台时打点
    WidgetsBinding.instance.addObserver(this);
    
    // 冷启动立即发送 app_open（避免依赖生命周期首个回调不稳定）
    TrackingService.track(actionType: 'app_open');
    _startupAppOpenSent = true;
    _shouldSendOnResume = false; // 直到进入后台后才在下次恢复时再次发送

    // 异步初始化服务和检查新手引导状态
    _initializeApp();
  }

  @override
  void dispose() {
    // 释放生命周期观察者
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      // App回到前台，发送 app_open 打点（避免冷启动重复）
      if (_shouldSendOnResume || !_startupAppOpenSent) {
        TrackingService.track(actionType: 'app_open');
        debugPrint('📊 [TRACKING] App resumed -> app_open sent');
        _startupAppOpenSent = true;
        _shouldSendOnResume = false;
      }
    } else if (state == AppLifecycleState.paused || state == AppLifecycleState.inactive) {
      // 应用进入后台或非活动态：标记下次恢复打点，并上报后台事件
      _shouldSendOnResume = true;
      try {
        TrackingService.trackHomeToBackground();
        debugPrint('📊 [TRACKING] App -> background sent');
      } catch (e) {
        debugPrint('📍 [TRACKING] app_background error: $e');
      }
    }
  }

  /// 初始化应用：检查新手引导状态并初始化服务
  Future<void> _initializeApp() async {
    try {

      final bool isOnboardingCompleted = await OnboardingManager().isOnboardingCompleted();
      
      setState(() {
        showOnboarding = !isOnboardingCompleted;
        onboardingChecked = true;
      });

    } catch (e) {
      debugPrint('🎯 [APP_ROOT] 初始化应用失败: $e');
      // 出错时默认不显示新手引导，继续正常流程
      setState(() {
        showOnboarding = false;
        onboardingChecked = true;
      });
    }

    await _initializeServices();

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
    // 如果还没检查新手引导状态，显示加载页面
    if (!onboardingChecked) {
      return const Scaffold(
        body: Center(
          child: CircularProgressIndicator(),
        ),
      );
    }

    // 如果需要显示新手引导
    if (showOnboarding) {
      return const Scaffold(
        body: OnboardingPage(),
      );
    }

    // 正常显示主应用
    return const Scaffold(
      body: MainApp(),
    );
  }
}

// 删除 Flutter 层浮层，改用原生启动页

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
