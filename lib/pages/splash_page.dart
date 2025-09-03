import 'package:flutter/material.dart';
import 'dart:async';
import '../layouts/main_layout.dart';
import '../pages/home_page.dart';
import '../pages/profile_page.dart';
import '../services/audio_manager.dart';
import '../services/audio_playlist.dart';
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
    // 先显示启动页2秒，让用户看到启动画面
    await Future.delayed(const Duration(seconds: 2));

    // 然后异步初始化服务，不阻塞UI
    _initializeServices();

    // 延迟跳转，给服务初始化一些时间
    await Future.delayed(const Duration(milliseconds: 500));

    // 跳转到主页（无动画）
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
      // 异步初始化音频服务，不阻塞UI
      unawaited(
        AudioManager.instance
            .init()
            .then((_) {
              if (mounted) {
                setState(() {
                  _servicesInitialized = true;
                });
              }
            })
            .catchError((e) {
              print('服务初始化失败: $e');
              if (mounted) {
                setState(() {
                  _servicesInitialized = true;
                });
              }
            }),
      );
    } catch (e) {
      print('服务初始化失败: $e');
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
                    'Initializing services...',
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
      pages: const [HomePage(), ProfilePage()],
      pageTitles: const ['Home', 'Profile'],
      initialIndex: 0,
    );
  }
}
