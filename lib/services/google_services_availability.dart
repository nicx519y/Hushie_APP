import 'dart:io';
import 'package:flutter/services.dart';
import 'package:flutter/foundation.dart';

/// Google Play 服务可用性检查
class GoogleServicesAvailability {
  static const MethodChannel _channel = MethodChannel('app_signature_verification');

  /// 简单检查：Google Play 服务是否可用
  static Future<bool> isGmsAvailable() async {
    if (!Platform.isAndroid) return true; // 非安卓平台视为可用
    try {
      final bool result = await _channel.invokeMethod('isGooglePlayServicesAvailable');
      return result;
    } catch (e) {
      debugPrint('🔧 [GMS] 检查Google Play服务可用性失败: $e');
      return false;
    }
  }

  /// 详细状态（可选用于调试）
  static Future<Map<String, dynamic>?> getGmsStatus() async {
    if (!Platform.isAndroid) return {
      'isAvailable': true,
      'status': 0,
      'isUserResolvable': false,
      'gmsVersionName': null,
    };
    try {
      final Map<dynamic, dynamic> result =
          await _channel.invokeMethod('getGooglePlayServicesStatus');
      return Map<String, dynamic>.from(result);
    } catch (e) {
      debugPrint('🔧 [GMS] 获取Google Play服务状态失败: $e');
      return null;
    }
  }
}