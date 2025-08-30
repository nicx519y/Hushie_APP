import 'package:flutter/material.dart';
import 'layouts/main_layout.dart';
import 'pages/home_page.dart';
import 'pages/profile_page.dart';
import 'services/audio_manager.dart';
import 'services/audio_data_pool.dart';
import 'services/audio_history_manager.dart';
import 'config/api_config.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // 初始化 API 配置
  ApiConfig.initialize(
    debugMode: true, // 在开发环境启用调试模式
  );

  // 先初始化音频历史管理器（确保数据库可用）
  await AudioHistoryManager.instance.initialize();

  // 再初始化音频数据池（从历史数据库加载数据）
  await AudioDataPool.instance.initialize();

  // 初始化音频服务
  await AudioManager.instance.init();

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: '音乐视频浏览',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.white),
      ),
      home: const MainApp(),
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
