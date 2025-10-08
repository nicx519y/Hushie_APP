import 'package:flutter/foundation.dart';
import 'package:device_info_plus/device_info_plus.dart';
import 'dart:io';

/// Google Play Billing 错误处理器
/// 专门处理 OnePlus 设备和 Android 11 相关的 PendingIntent 问题
class BillingErrorHandler {
  static final BillingErrorHandler _instance = BillingErrorHandler._internal();
  factory BillingErrorHandler() => _instance;
  BillingErrorHandler._internal();

  // 设备信息缓存
  AndroidDeviceInfo? _deviceInfo;
  bool _isOnePlusDevice = false;
  bool _isAndroid11OrHigher = false;

  /// 初始化设备信息检测
  Future<void> initialize() async {
    if (!Platform.isAndroid) return;

    try {
      final deviceInfoPlugin = DeviceInfoPlugin();
      _deviceInfo = await deviceInfoPlugin.androidInfo;
      
      // 检测是否为 OnePlus 设备
      _isOnePlusDevice = _deviceInfo?.manufacturer.toLowerCase().contains('oneplus') ?? false;
      
      // 检测是否为 Android 11 或更高版本
      _isAndroid11OrHigher = (_deviceInfo?.version.sdkInt ?? 0) >= 30;
      
      debugPrint('🔍 设备信息检测完成:');
      debugPrint('  - 制造商: ${_deviceInfo?.manufacturer}');
      debugPrint('  - 型号: ${_deviceInfo?.model}');
      debugPrint('  - Android 版本: ${_deviceInfo?.version.release}');
      debugPrint('  - SDK 版本: ${_deviceInfo?.version.sdkInt}');
      debugPrint('  - 是否为 OnePlus 设备: $_isOnePlusDevice');
      debugPrint('  - 是否为 Android 11+: $_isAndroid11OrHigher');
      
    } catch (e) {
      debugPrint('❌ 设备信息检测失败: $e');
    }
  }

  /// 检查是否为高风险设备配置
  bool get isHighRiskConfiguration {
    return _isOnePlusDevice && _isAndroid11OrHigher;
  }

  /// 获取设备特定的错误处理建议
  String getDeviceSpecificErrorAdvice(String errorMessage) {
    if (_isOnePlusDevice && errorMessage.contains('PendingIntent')) {
      return '1001'; // OnePlus PendingIntent 问题
    }

    if (_isAndroid11OrHigher && errorMessage.contains('PendingIntent')) {
      return '1002'; // Android 11+ PendingIntent 兼容性问题
    }

    return '1000'; // 购买流程通用错误
  }

  /// 记录设备特定的错误信息
  void logDeviceSpecificError(String error, Map<String, dynamic>? additionalInfo) {
    final errorReport = {
      'error': error,
      'device_manufacturer': _deviceInfo?.manufacturer,
      'device_model': _deviceInfo?.model,
      'android_version': _deviceInfo?.version.release,
      'sdk_int': _deviceInfo?.version.sdkInt,
      'is_oneplus': _isOnePlusDevice,
      'is_android_11_plus': _isAndroid11OrHigher,
      'is_high_risk': isHighRiskConfiguration,
      'additional_info': additionalInfo,
      'timestamp': DateTime.now().toIso8601String(),
    };
    
    debugPrint('🚨 Billing 错误报告:');
    errorReport.forEach((key, value) {
      debugPrint('  $key: $value');
    });
    
    // TODO: 在生产环境中，可以将这些信息发送到错误收集服务
    // 如 Firebase Crashlytics, Sentry 等
  }

  /// 获取推荐的重试策略
  RetryStrategy getRetryStrategy() {
    if (isHighRiskConfiguration) {
      return RetryStrategy(
        maxRetries: 2,
        initialDelay: const Duration(seconds: 3),
        backoffMultiplier: 2.0,
        shouldRetry: true,
      );
    }
    
    return RetryStrategy(
      maxRetries: 1,
      initialDelay: const Duration(seconds: 1),
      backoffMultiplier: 1.5,
      shouldRetry: true,
    );
  }
}

/// 重试策略配置
class RetryStrategy {
  final int maxRetries;
  final Duration initialDelay;
  final double backoffMultiplier;
  final bool shouldRetry;

  const RetryStrategy({
    required this.maxRetries,
    required this.initialDelay,
    required this.backoffMultiplier,
    required this.shouldRetry,
  });
}