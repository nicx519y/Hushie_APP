import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'layouts/main_layout.dart';
import 'pages/home_page.dart';
import 'pages/profile_page.dart';
import 'pages/splash_page.dart';
import 'config/api_config.dart';
import 'services/api_service.dart';

void main() async {
  print('🚀 [MAIN] 应用启动开始');
  WidgetsFlutterBinding.ensureInitialized();
  print('🚀 [MAIN] Flutter绑定初始化完成');

  // 配置系统UI样式
  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent, // 透明状态栏
      statusBarIconBrightness: Brightness.dark, // 深色状态栏图标
      statusBarBrightness: Brightness.light, // iOS状态栏亮度
      systemNavigationBarColor: Colors.white, // 导航栏颜色
      systemNavigationBarIconBrightness: Brightness.dark, // 深色导航栏图标
    ),
  );
  print('🚀 [MAIN] 系统UI样式配置完成');

  // 启用Edge-to-Edge模式
  SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
  print('🚀 [MAIN] Edge-to-Edge模式启用完成');

  // 初始化 API 配置（同步操作，快速）
  print('🚀 [MAIN] 开始初始化API配置');
  ApiConfig.initialize(
    initialMode: ApiMode.real, // 暂时使用Mock模式来测试
    debugMode: true, // 在开发环境启用调试模式
  );
  print('🚀 [MAIN] API配置初始化完成');

  // 立即启动应用，服务初始化在启动页中处理
  print('🚀 [MAIN] 开始运行应用');
  runApp(const MyApp());
  print('🚀 [MAIN] 应用运行完成');
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
        // 配置AppBar主题，确保状态栏图标显示正确
        appBarTheme: const AppBarTheme(
          systemOverlayStyle: SystemUiOverlayStyle(
            statusBarColor: Colors.transparent,
            statusBarIconBrightness: Brightness.dark,
            statusBarBrightness: Brightness.light,
          ),
        ),
      ),
      home: const SplashPage(),
      debugShowCheckedModeBanner: false,
    );
  }
}

// class MainApp extends StatelessWidget {
//   const MainApp({super.key});

//   @override
//   Widget build(BuildContext context) {
//     return MainLayout(
//       pages: const [HomePage(), ProfilePage()],
//       pageTitles: const ['Home', 'Profile'],
//       initialIndex: 0,
//     );
//   }
// }
