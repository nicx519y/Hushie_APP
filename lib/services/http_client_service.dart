import 'dart:convert';
import 'package:http/http.dart' as http;
import 'device_info_service.dart';
import 'auth_service.dart';

/// HTTP客户端服务
/// 自动处理公共请求头：device_id 和 accessToken
class HttpClientService {
  static const Duration _defaultTimeout = Duration(seconds: 30);

  /// 发送GET请求
  static Future<http.Response> get(
    Uri uri, {
    Map<String, String>? headers,
    Duration? timeout,
  }) async {
    final requestHeaders = await _buildHeaders(headers);

    return http
        .get(uri, headers: requestHeaders)
        .timeout(timeout ?? _defaultTimeout);
  }

  /// 发送POST请求
  static Future<http.Response> post(
    Uri uri, {
    Map<String, String>? headers,
    Object? body,
    Duration? timeout,
  }) async {
    final requestHeaders = await _buildHeaders(headers);

    return http
        .post(uri, headers: requestHeaders, body: body)
        .timeout(timeout ?? _defaultTimeout);
  }

  /// 发送PUT请求
  static Future<http.Response> put(
    Uri uri, {
    Map<String, String>? headers,
    Object? body,
    Duration? timeout,
  }) async {
    final requestHeaders = await _buildHeaders(headers);

    return http
        .put(uri, headers: requestHeaders, body: body)
        .timeout(timeout ?? _defaultTimeout);
  }

  /// 发送DELETE请求
  static Future<http.Response> delete(
    Uri uri, {
    Map<String, String>? headers,
    Object? body,
    Duration? timeout,
  }) async {
    final requestHeaders = await _buildHeaders(headers);

    return http
        .delete(uri, headers: requestHeaders, body: body)
        .timeout(timeout ?? _defaultTimeout);
  }

  /// 发送PATCH请求
  static Future<http.Response> patch(
    Uri uri, {
    Map<String, String>? headers,
    Object? body,
    Duration? timeout,
  }) async {
    final requestHeaders = await _buildHeaders(headers);

    return http
        .patch(uri, headers: requestHeaders, body: body)
        .timeout(timeout ?? _defaultTimeout);
  }

  /// 构建请求头
  /// 自动添加 device_id 和 accessToken
  static Future<Map<String, String>> _buildHeaders(
    Map<String, String>? customHeaders,
  ) async {
    final Map<String, String> headers = {
      'Content-Type': 'application/json',
      'Accept': 'application/json',
      'User-Agent': 'Hushie.AI/1.0.0',
    };

    // 添加自定义请求头
    if (customHeaders != null) {
      headers.addAll(customHeaders);
    }

    // 自动添加 device_id
    try {
      final deviceId = await DeviceInfoService.getDeviceId();
      headers['X-Device-ID'] = deviceId;
    } catch (e) {
      print('获取设备ID失败: $e');
      headers['X-Device-ID'] = 'unknown_device';
    }

    // 自动添加 accessToken（如果存在）
    try {
      final accessToken = await AuthService.getAccessToken();
      if (accessToken != null && accessToken.isNotEmpty) {
        headers['Authorization'] = 'Bearer $accessToken';
      }
    } catch (e) {
      print('获取access token失败: $e');
      // 不添加Authorization头
    }

    return headers;
  }

  /// 发送JSON POST请求的便捷方法
  static Future<http.Response> postJson(
    Uri uri, {
    Map<String, String>? headers,
    Map<String, dynamic>? body,
    Duration? timeout,
  }) async {
    final requestHeaders = await _buildHeaders(headers);

    return http
        .post(
          uri,
          headers: requestHeaders,
          body: body != null ? json.encode(body) : null,
        )
        .timeout(timeout ?? _defaultTimeout);
  }

  /// 发送JSON PUT请求的便捷方法
  static Future<http.Response> putJson(
    Uri uri, {
    Map<String, String>? headers,
    Map<String, dynamic>? body,
    Duration? timeout,
  }) async {
    final requestHeaders = await _buildHeaders(headers);

    return http
        .put(
          uri,
          headers: requestHeaders,
          body: body != null ? json.encode(body) : null,
        )
        .timeout(timeout ?? _defaultTimeout);
  }

  /// 发送JSON PATCH请求的便捷方法
  static Future<http.Response> patchJson(
    Uri uri, {
    Map<String, String>? headers,
    Map<String, dynamic>? body,
    Duration? timeout,
  }) async {
    final requestHeaders = await _buildHeaders(headers);

    return http
        .patch(
          uri,
          headers: requestHeaders,
          body: body != null ? json.encode(body) : null,
        )
        .timeout(timeout ?? _defaultTimeout);
  }
}
