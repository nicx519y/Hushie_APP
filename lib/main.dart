import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:just_audio_media_kit/just_audio_media_kit.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_analytics/firebase_analytics.dart';

import 'config/api_config.dart';
import 'pages/app_root.dart';
import 'services/device_info_service.dart';
import 'services/analytics_service.dart';

void main() async {
  debugPrint('🚀 [MAIN] 应用启动开始');
  WidgetsFlutterBinding.ensureInitialized();
  debugPrint('🚀 [MAIN] Flutter绑定初始化完成');

  // 初始化 Firebase
  try {
    await Firebase.initializeApp();
    debugPrint('🔥 [FIREBASE] Firebase初始化完成');
    
    // 初始化 Firebase Analytics
    FirebaseAnalytics.instance;
    debugPrint('📊 [ANALYTICS] Firebase Analytics初始化完成');
    
    // 初始化 Analytics 服务
    AnalyticsService().initialize();
    
    // 记录应用启动事件
    await AnalyticsService().logAppOpen();
  } catch (e) {
    debugPrint('❌ [FIREBASE] Firebase初始化失败: $e');
  }

  // 初始化 just_audio_media_kit 并配置缓冲大小
  JustAudioMediaKit.ensureInitialized();
  // 设置缓冲大小为 128MB（默认32MB）
  JustAudioMediaKit.bufferSize = 128 * 1024 * 1024;

  // 配置系统UI样式 - 针对华为EMUI优化
  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent, // 透明状态栏
      statusBarIconBrightness: Brightness.dark, // 深色状态栏图标
      statusBarBrightness: Brightness.light, // iOS状态栏亮度
      systemNavigationBarColor: Colors.white, // 导航栏颜色
      systemNavigationBarIconBrightness: Brightness.dark, // 深色导航栏图标
    ),
  );
  debugPrint('🚀 [MAIN] 系统UI样式配置完成');

  // 针对华为设备使用更保守的系统UI模式
  try {
    SystemChrome.setEnabledSystemUIMode(
      SystemUiMode.manual,
      overlays: [SystemUiOverlay.top, SystemUiOverlay.bottom],
    );
    debugPrint('🚀 [MAIN] 华为兼容的系统UI模式配置完成');
  } catch (e) {
    debugPrint('🚀 [MAIN] 系统UI模式配置失败，使用默认模式: $e');
    // 如果失败，使用最基本的模式
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
  }

  // 华为设备特殊配置
  _configureHuaweiStatusBar().then((_) {
    debugPrint('🚀 [MAIN] 华为设备状态栏特殊配置完成');
  }).catchError((e) {
    debugPrint('🚀 [MAIN] 华为设备状态栏配置失败: $e');
  });

  SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
  ]);
  debugPrint('🚀 [MAIN] 屏幕方向配置完成');

  // 初始化 API 配置（同步操作，快速）
  debugPrint('🚀 [MAIN] 开始初始化API配置');
  ApiConfig.initialize(
    debugMode: true, // 在开发环境启用调试模式
  );
  debugPrint('🚀 [MAIN] API配置初始化完成');


  // 立即启动应用，服务初始化在启动页中处理
  debugPrint('🚀 [MAIN] 开始运行应用');
  runApp(const MyApp());
}

/// 为华为设备配置特殊的状态栏样式
Future<void> _configureHuaweiStatusBar() async {
  if (await DeviceInfoService.isHuaweiDevice()) {
    debugPrint('🔧 [DEVICE] 检测到华为设备，应用特殊状态栏配置');
    
    try {
      // 华为设备专用状态栏配置
      SystemChrome.setSystemUIOverlayStyle(
        const SystemUiOverlayStyle(
          statusBarColor: Colors.transparent,
          statusBarIconBrightness: Brightness.dark,
          statusBarBrightness: Brightness.light,
          systemNavigationBarColor: Colors.white,
          systemNavigationBarIconBrightness: Brightness.dark,
        ),
      );
      
      // 强制显示系统UI
      await SystemChrome.setEnabledSystemUIMode(
        SystemUiMode.manual,
        overlays: [SystemUiOverlay.top, SystemUiOverlay.bottom],
      );
      
      debugPrint('🔧 [DEVICE] 华为设备状态栏配置完成');
    } catch (e) {
      debugPrint('🔧 [DEVICE] 华为设备状态栏配置失败: $e');
    }
  }
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
        // 全局Checkbox主题配置
        checkboxTheme: CheckboxThemeData(
          // 填充颜色配置
          fillColor: MaterialStateProperty.resolveWith<Color>((
            Set<MaterialState> states,
          ) {
            if (states.contains(MaterialState.selected)) {
              return const Color(0xFFFF2050); // 选中时的背景色（品牌色）
            }
            return Colors.transparent; // 未选中时透明
          }),
          // 勾选标记颜色
          checkColor: MaterialStateProperty.all(Colors.white),
          // 形状配置
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16), // 圆角矩形
          ),
          // 聚焦效果
          splashRadius: 30, // 点击波纹效果半径
        ),
      ),
      home: const AppRoot(),
      navigatorObservers: [AnalyticsService().observer],
      debugShowCheckedModeBanner: false,
    );
  }
}
