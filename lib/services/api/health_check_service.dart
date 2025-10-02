import 'dart:io';
import 'package:http/http.dart' as http;
import '../../config/api_config.dart';

/// 健康检查服务
/// 用于检测网络连接和服务器状态
class HealthCheckService {
  static const Duration _defaultTimeout = Duration(seconds: 5);

  /// 执行健康检查
  /// 
  /// 返回值：
  /// - true: 服务器健康（状态码为200）
  /// - false: 服务器不健康或网络连接失败
  static Future<bool> checkHealth() async {
    try {
      final response = await http.get(
        Uri.parse(ApiConfig.healthCheckUrl),
        headers: {
          // 不使用通用header，只设置基本的User-Agent
          'User-Agent': 'HushieApp/1.0',
        },
      ).timeout(_defaultTimeout);

      // 只检查状态码是否为200
      return response.statusCode == 200;
    } on SocketException {
      // 网络连接失败
      return false;
    } on HttpException {
      // HTTP异常
      return false;
    } on FormatException {
      // URL格式异常
      return false;
    } catch (e) {
      // 其他异常（包括超时）
      return false;
    }
  }

  /// 执行健康检查并返回详细信息
  /// 
  /// 返回Map包含：
  /// - 'isHealthy': bool - 是否健康
  /// - 'statusCode': int? - HTTP状态码（如果请求成功）
  /// - 'responseTime': int - 响应时间（毫秒）
  /// - 'error': String? - 错误信息（如果有）
  static Future<Map<String, dynamic>> checkHealthWithDetails() async {
    final stopwatch = Stopwatch()..start();
    
    try {
      final response = await http.get(
        Uri.parse(ApiConfig.healthCheckUrl),
        headers: {
          'User-Agent': 'HushieApp/1.0',
        },
      ).timeout(_defaultTimeout);

      stopwatch.stop();
      
      final isHealthy = response.statusCode == 200;
      
      return {
        'isHealthy': isHealthy,
        'statusCode': response.statusCode,
        'responseTime': stopwatch.elapsedMilliseconds,
        'error': isHealthy ? null : 'HTTP ${response.statusCode}',
      };
    } on SocketException catch (e) {
      stopwatch.stop();
      return {
        'isHealthy': false,
        'statusCode': null,
        'responseTime': stopwatch.elapsedMilliseconds,
        'error': '网络连接失败: ${e.message}',
      };
    } on HttpException catch (e) {
      stopwatch.stop();
      return {
        'isHealthy': false,
        'statusCode': null,
        'responseTime': stopwatch.elapsedMilliseconds,
        'error': 'HTTP异常: ${e.message}',
      };
    } on FormatException catch (e) {
      stopwatch.stop();
      return {
        'isHealthy': false,
        'statusCode': null,
        'responseTime': stopwatch.elapsedMilliseconds,
        'error': 'URL格式错误: ${e.message}',
      };
    } catch (e) {
      stopwatch.stop();
      return {
        'isHealthy': false,
        'statusCode': null,
        'responseTime': stopwatch.elapsedMilliseconds,
        'error': '未知错误: $e',
      };
    }
  }
}