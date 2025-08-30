import 'package:flutter/material.dart';
import 'layouts/main_layout.dart';
import 'pages/home_page.dart';
import 'pages/profile_page.dart';
import 'pages/splash_page.dart';
import 'services/audio_manager.dart';
import 'services/audio_data_pool.dart';
import 'services/audio_history_manager.dart';
import 'config/api_config.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // 初始化 API 配置（同步操作，快速）
  ApiConfig.initialize(
    debugMode: true, // 在开发环境启用调试模式
  );

  // 立即启动应用，服务初始化在启动页中处理
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Hushie.AI',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFFF359AA)),
        primarySwatch: Colors.pink,
      ),
      home: const SplashPage(),
    );
  }
}

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
