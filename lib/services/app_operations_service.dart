import 'package:flutter/services.dart';

/// 应用操作服务 - 处理原生平台的应用操作
class AppOperationsService {
  static const MethodChannel _channel = MethodChannel('com.hushie/app_operations');

  /// 将应用退到后台（触发系统原生动画）
  /// 
  /// 这个方法会调用原生代码将应用退到后台，
  /// 系统会自动播放与用户按Home键相同的动画效果
  /// 
  /// 返回值：
  /// - true: 成功退到后台
  /// - false: 操作失败
  static Future<bool> sendToBackground() async {
    try {
      final bool result = await _channel.invokeMethod('sendToBackground');
      return result;
    } on PlatformException catch (e) {
      print('❌ [APP_OPERATIONS] 退到后台失败: ${e.message}');
      return false;
    } catch (e) {
      print('❌ [APP_OPERATIONS] 未知错误: $e');
      return false;
    }
  }
}