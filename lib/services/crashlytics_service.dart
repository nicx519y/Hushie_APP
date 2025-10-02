import 'dart:async';
import 'package:flutter/foundation.dart';
// 注意：PlatformDispatcher 可直接使用（Flutter环境默认可用）
import 'package:firebase_crashlytics/firebase_crashlytics.dart';

/// Crashlytics 服务
/// 统一管理 Crashlytics 初始化、错误上报与自定义键值
class CrashlyticsService {
  static final CrashlyticsService _instance = CrashlyticsService._internal();
  factory CrashlyticsService() => _instance;
  CrashlyticsService._internal();

  bool _initialized = false;

  /// 初始化 Crashlytics，并设置全局错误处理
  Future<void> initialize() async {
    if (_initialized) return;
    try {
      // 根据构建类型控制是否启用采集
      await FirebaseCrashlytics.instance
          .setCrashlyticsCollectionEnabled(!kDebugMode);

      // 捕获 Flutter 框架错误
      FlutterError.onError = (FlutterErrorDetails details) {
        // 保持原始打印，便于开发调试
        FlutterError.presentError(details);
        FirebaseCrashlytics.instance.recordFlutterError(details);
      };

      // 捕获未处理的 Dart 异常（包括异步）
      PlatformDispatcher.instance.onError = (error, stack) {
        FirebaseCrashlytics.instance.recordError(
          error,
          stack,
          fatal: true,
        );
        return true; // 阻止错误继续向上传播
      };

      debugPrint('💥 [CRASHLYTICS] 初始化完成');
      _initialized = true;
    } catch (e) {
      debugPrint('❌ [CRASHLYTICS] 初始化失败: $e');
    }
  }

  /// 记录非致命错误
  Future<void> recordError(
    Object error,
    StackTrace stack, {
    bool fatal = false,
    String? reason,
  }) async {
    try {
      await FirebaseCrashlytics.instance.recordError(
        error,
        stack,
        fatal: fatal,
        reason: reason,
      );
      debugPrint('💥 [CRASHLYTICS] 错误记录: ${reason ?? error.runtimeType}');
    } catch (e) {
      debugPrint('❌ [CRASHLYTICS] 错误记录失败: $e');
    }
  }

  /// 设置用户标识
  Future<void> setUserId(String userId) async {
    try {
      await FirebaseCrashlytics.instance.setUserIdentifier(userId);
    } catch (e) {
      debugPrint('❌ [CRASHLYTICS] 设置用户ID失败: $e');
    }
  }

  /// 设置自定义键值（便于过滤分析）
  Future<void> setCustomKey(String key, Object value) async {
    try {
      await FirebaseCrashlytics.instance.setCustomKey(key, value);
    } catch (e) {
      debugPrint('❌ [CRASHLYTICS] 设置自定义键失败: $e');
    }
  }

  /// 记录日志
  Future<void> log(String message) async {
    try {
      await FirebaseCrashlytics.instance.log(message);
    } catch (e) {
      debugPrint('❌ [CRASHLYTICS] 记录日志失败: $e');
    }
  }
}