import 'package:flutter/material.dart';
import 'dart:io';
import 'package:flutter/services.dart';
import 'package:just_audio_media_kit/just_audio_media_kit.dart';
import 'package:firebase_core/firebase_core.dart';
import 'dart:io';
import 'package:device_info_plus/device_info_plus.dart';

import 'config/api_config.dart';
import 'pages/app_root.dart';
import 'services/device_info_service.dart';
import 'services/analytics_service.dart';
import 'services/crashlytics_service.dart';
import 'services/performance_service.dart';

void main() async {
  debugPrint('🚀 [MAIN] 应用启动开始');
  WidgetsFlutterBinding.ensureInitialized();
  debugPrint('🚀 [MAIN] Flutter绑定初始化完成');

  // 在 Android 上延迟首帧，确保原生启动页可见（华为设备延长时间）
  // if (Platform.isAndroid) {
  //   WidgetsBinding.instance.deferFirstFrame();
  //   try {
  //     final isHuawei = await DeviceInfoService.isHuaweiDevice();
  //     final hold = isHuawei
  //         ? const Duration(milliseconds: 800)
  //         : const Duration(milliseconds: 450);
  //     Future.delayed(hold, () {
  //       WidgetsBinding.instance.allowFirstFrame();
  //     });
  //   } catch (e) {
  //     Future.delayed(const Duration(milliseconds: 500), () {
  //       WidgetsBinding.instance.allowFirstFrame();
  //     });
  //   }
  // }

  // 将系统UI设置移动到首帧之后，避免干扰原生启动页显示

  // 华为设备特殊配置（非阻塞）
  _configureHuaweiStatusBar().then((_) {
    debugPrint('🚀 [MAIN] 华为设备状态栏特殊配置完成');
  }).catchError((e) {
    debugPrint('🚀 [MAIN] 华为设备状态栏配置失败: $e');
  });

  try {
    // Android 上通过 Manifest 固定方向，避免在非全屏/分屏模式下抛出异常
    if (!Platform.isAndroid) {
      await SystemChrome.setPreferredOrientations([
        DeviceOrientation.portraitUp,
      ]);
      debugPrint('🚀 [MAIN] 屏幕方向配置完成 (非Android)');
    } else {
      debugPrint('🚀 [MAIN] Android 使用 Manifest 固定方向，跳过运行时设置');
    }
  } catch (e) {
    debugPrint('⚠️ [MAIN] 设置屏幕方向失败，已忽略: $e');
  }

  // 在 runApp 之前初始化 Firebase 和 Analytics，确保 observer 可用
  try {
    await Firebase.initializeApp();
    debugPrint('🔥 [FIREBASE] Firebase初始化完成（启动前）');
    AnalyticsService().initialize();
    debugPrint('📊 [ANALYTICS] Analytics服务初始化完成（启动前）');
  } catch (e) {
    debugPrint('❌ [INIT] 启动前初始化失败: $e');
  }

  // 立即启动应用，服务初始化在启动页中处理
  debugPrint('🚀 [MAIN] 开始运行应用');
  runApp(const MyApp());

  // 将核心服务初始化移至首帧之后，避免阻塞首屏渲染
  WidgetsBinding.instance.addPostFrameCallback((_) {
    // 配置系统UI样式 - 首帧后设置，避免影响启动页
    try {
      SystemChrome.setSystemUIOverlayStyle(
        const SystemUiOverlayStyle(
          statusBarColor: Colors.transparent,
          statusBarIconBrightness: Brightness.dark,
          statusBarBrightness: Brightness.light,
          systemNavigationBarColor: Colors.white,
          systemNavigationBarIconBrightness: Brightness.dark,
        ),
      );
      SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    } catch (e) {
      SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    }

    _initializeCoreServices();
  });
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
      await SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
      
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
      // 全局包裹系统栏样式，确保不同页面不会覆盖导致图标变白
      builder: (context, child) => AnnotatedRegion<SystemUiOverlayStyle>(
        value: const SystemUiOverlayStyle(
          statusBarColor: Colors.transparent,
          statusBarIconBrightness: Brightness.dark,
          statusBarBrightness: Brightness.light,
          systemNavigationBarColor: Colors.white,
          systemNavigationBarIconBrightness: Brightness.dark,
        ),
        child: child ?? const SizedBox.shrink(),
      ),
      home: const AppRoot(),
      navigatorObservers: [AnalyticsService().observer],
      debugShowCheckedModeBanner: false,
  );
  }
}


/// 首帧后初始化核心服务，减少冷启动耗时
Future<void> _initializeCoreServices() async {
  debugPrint('🚀 [INIT] 首帧后开始初始化核心服务');

  try {
    AnalyticsService().logAppOpen();
  } catch (e) {
    debugPrint('❌ [ANALYTICS] 记录 app_open 失败: $e');
  }

  // 初始化 just_audio_media_kit 并配置缓冲大小（非关键路径）
  try {
    JustAudioMediaKit.ensureInitialized();
    JustAudioMediaKit.bufferSize = 128 * 1024 * 1024;
    debugPrint('🎵 [AUDIO] MediaKit 初始化完成并设置缓冲');
  } catch (e) {
    debugPrint('🎵 [AUDIO] MediaKit 初始化失败: $e');
  }

  // 初始化 API 配置（非阻塞）
  try {
    debugPrint('🚀 [INIT] 开始初始化API配置');
    await ApiConfig.initialize(debugMode: true);
    debugPrint('🚀 [INIT] API配置初始化完成');
  } catch (e) {
    debugPrint('❌ [INIT] API配置初始化失败: $e');
  }

  // 初始化 Firebase 及相关服务（并发执行，避免串行等待）
  try {
    // 并发初始化非关键服务，并在完成后记录 app_open
    await Future.wait(<Future<void>>[
      CrashlyticsService().initialize(),
      PerformanceService().initialize(),
    ]);
    debugPrint('🚀 [INIT] 首帧后核心服务初始化完成');
  } catch (e) {
    debugPrint('❌ [INIT] 首帧后核心服务初始化失败: $e');
  }

  
}

// 删除 Flutter 层整屏 Splash，直接进入 AppRoot，依赖原生启动页

