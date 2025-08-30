import 'package:flutter/material.dart';
import 'dart:async';
import '../layouts/main_layout.dart';
import '../pages/home_page.dart';
import '../pages/profile_page.dart';
import '../services/audio_manager.dart';
import '../services/audio_data_pool.dart';
import '../services/audio_history_manager.dart';

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
    // 并行执行：服务初始化 和 2秒延迟
    await Future.wait([
      _initializeServices(),
      Future.delayed(const Duration(seconds: 2)),
    ]);

    // 都完成后跳转到主页（无动画）
    if (mounted) {
      Navigator.of(context).pushReplacement(
        PageRouteBuilder(
          pageBuilder: (context, animation, secondaryAnimation) =>
              const MainApp(),
          transitionDuration: Duration.zero, // 无过渡动画
          reverseTransitionDuration: Duration.zero,
        ),
      );
    }
  }

  Future<void> _initializeServices() async {
    try {
      // 先初始化音频历史管理器（确保数据库可用）
      await AudioHistoryManager.instance.initialize();

      // 再初始化音频数据池（从历史数据库加载数据）
      await AudioDataPool.instance.initialize();

      // 初始化音频服务
      await AudioManager.instance.init();

      setState(() {
        _servicesInitialized = true;
      });
    } catch (e) {
      print('服务初始化失败: $e');
      // 即使服务初始化失败，也继续跳转
      setState(() {
        _servicesInitialized = true;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white, // 白色背景
      body: Container(
        width: double.infinity,
        height: double.infinity,
        decoration: const BoxDecoration(color: Colors.white),
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
            if (!_servicesInitialized)
              Column(
                children: [
                  const CircularProgressIndicator(
                    valueColor: AlwaysStoppedAnimation<Color>(
                      Color(0xFFF359AA),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    '正在初始化服务...',
                    style: TextStyle(fontSize: 14, color: Colors.grey[600]),
                  ),
                ],
              ),
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
    return MainLayout(
      pages: [HomePage(), ProfilePage()],
      pageTitles: ['Home', 'Profile'],
      initialIndex: 0,
    );
  }
}
