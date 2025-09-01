import 'dart:convert';
import 'dart:math';
import 'package:http/http.dart' as http;
import 'package:crypto/crypto.dart';
import 'device_info_service.dart';
import 'auth_service.dart';
import '../config/api_config.dart';

/// HTTP客户端服务
/// 自动处理公共请求头：device_id、accessToken、签名验证等
class HttpClientService {
  static const Duration _defaultTimeout = Duration(seconds: 30);

  // 从配置获取API签名相关参数
  static String get _appId => ApiConfig.appId;
  static String get _appSecret => ApiConfig.getAppSecret();
  static String get _apiVersion => ApiConfig.apiVersion;

  /// 发送GET请求
  static Future<http.Response> get(
    Uri uri, {
    Map<String, String>? headers,
    Duration? timeout,
  }) async {
    final requestHeaders = await _buildHeaders(headers, 'GET', uri.path);

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
    final requestHeaders = await _buildHeaders(headers, 'POST', uri.path, body);

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
    final requestHeaders = await _buildHeaders(headers, 'PUT', uri.path, body);

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
    final requestHeaders = await _buildHeaders(
      headers,
      'DELETE',
      uri.path,
      body,
    );

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
    final requestHeaders = await _buildHeaders(
      headers,
      'PATCH',
      uri.path,
      body,
    );

    return http
        .patch(uri, headers: requestHeaders, body: body)
        .timeout(timeout ?? _defaultTimeout);
  }

  /// 构建请求头 - 包含完整的安全验签参数
  static Future<Map<String, String>> _buildHeaders(
    Map<String, String>? customHeaders,
    String method,
    String path, [
    Object? body,
  ]) async {
    final timestamp = DateTime.now().millisecondsSinceEpoch.toString();
    final nonce = _generateNonce();

    // 从配置获取基础请求头
    final Map<String, String> headers = Map.from(ApiConfig.getDefaultHeaders());

    // 添加安全验签相关头
    headers.addAll({
      // 时间戳和随机数 - 防重放攻击
      'X-Timestamp': timestamp,
      'X-Nonce': nonce,

      // 请求ID - 用于链路追踪
      'X-Request-ID': _generateRequestId(),
    });

    // 添加自定义请求头
    if (customHeaders != null) {
      headers.addAll(customHeaders);
    }

    // 自动添加设备ID
    try {
      final deviceId = await DeviceInfoService.getDeviceId();
      headers['X-Device-ID'] = deviceId;
    } catch (e) {
      print('获取设备ID失败: $e');
      headers['X-Device-ID'] = 'unknown_device';
    }

    // 自动添加用户Token（如果存在）
    try {
      final accessToken = await AuthService.getAccessToken();
      if (accessToken != null && accessToken.isNotEmpty) {
        headers['Authorization'] = 'Bearer $accessToken';
      }
    } catch (e) {
      print('获取access token失败: $e');
      // 不添加Authorization头
    }

    // 生成API签名
    final signature = await _generateSignature(
      method: method,
      path: path,
      headers: headers,
      body: body,
      timestamp: timestamp,
      nonce: nonce,
    );
    headers['X-Signature'] = signature;

    return headers;
  }

  /// 生成API请求签名
  /// 签名算法：HMAC-SHA256(method + path + timestamp + nonce + bodyHash + keyHeaders)
  static Future<String> _generateSignature({
    required String method,
    required String path,
    required Map<String, String> headers,
    Object? body,
    required String timestamp,
    required String nonce,
  }) async {
    try {
      // 1. 准备签名字符串的各个部分
      final List<String> signatureParts = [];

      // HTTP方法
      signatureParts.add(method.toUpperCase());

      // 请求路径
      signatureParts.add(path);

      // 时间戳
      signatureParts.add(timestamp);

      // 随机数
      signatureParts.add(nonce);

      // 请求体哈希（如果有请求体）
      if (body != null) {
        final bodyString = body is String ? body : json.encode(body);
        final bodyHash = sha256.convert(utf8.encode(bodyString)).toString();
        signatureParts.add(bodyHash);
      } else {
        signatureParts.add('');
      }

      // 关键请求头（按字母顺序排序）
      final keyHeaders = ['X-Device-ID', 'X-App-ID', 'X-API-Version'];
      for (final headerName in keyHeaders) {
        final headerValue = headers[headerName] ?? '';
        signatureParts.add('$headerName:$headerValue');
      }

      // 2. 构建签名字符串
      final signatureString = signatureParts.join('\n');

      // 3. 使用HMAC-SHA256生成签名
      final key = utf8.encode(_appSecret);
      final bytes = utf8.encode(signatureString);
      final hmacSha256 = Hmac(sha256, key);
      final digest = hmacSha256.convert(bytes);

      return digest.toString();
    } catch (e) {
      print('生成签名失败: $e');
      return '';
    }
  }

  /// 生成随机数 - 防重放攻击
  static String _generateNonce() {
    const chars =
        'abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789';
    final random = Random.secure();
    final length = ApiConfig.nonceLength;
    return List.generate(
      length,
      (index) => chars[random.nextInt(chars.length)],
    ).join();
  }

  /// 生成请求ID - 用于链路追踪
  static String _generateRequestId() {
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    final random = Random().nextInt(999999).toString().padLeft(6, '0');
    return 'req_${timestamp}_$random';
  }

  /// 发送JSON POST请求的便捷方法
  static Future<http.Response> postJson(
    Uri uri, {
    Map<String, String>? headers,
    Map<String, dynamic>? body,
    Duration? timeout,
  }) async {
    final jsonBody = body != null ? json.encode(body) : null;
    final requestHeaders = await _buildHeaders(
      headers,
      'POST',
      uri.path,
      jsonBody,
    );

    return http
        .post(uri, headers: requestHeaders, body: jsonBody)
        .timeout(timeout ?? _defaultTimeout);
  }

  /// 发送JSON PUT请求的便捷方法
  static Future<http.Response> putJson(
    Uri uri, {
    Map<String, String>? headers,
    Map<String, dynamic>? body,
    Duration? timeout,
  }) async {
    final jsonBody = body != null ? json.encode(body) : null;
    final requestHeaders = await _buildHeaders(
      headers,
      'PUT',
      uri.path,
      jsonBody,
    );

    return http
        .put(uri, headers: requestHeaders, body: jsonBody)
        .timeout(timeout ?? _defaultTimeout);
  }

  /// 发送JSON PATCH请求的便捷方法
  static Future<http.Response> patchJson(
    Uri uri, {
    Map<String, String>? headers,
    Map<String, dynamic>? body,
    Duration? timeout,
  }) async {
    final jsonBody = body != null ? json.encode(body) : null;
    final requestHeaders = await _buildHeaders(
      headers,
      'PATCH',
      uri.path,
      jsonBody,
    );

    return http
        .patch(uri, headers: requestHeaders, body: jsonBody)
        .timeout(timeout ?? _defaultTimeout);
  }

  /// 验证响应签名（可选，用于双向验签）
  static bool verifyResponseSignature(
    http.Response response,
    String expectedSignature,
  ) {
    try {
      // 构建响应签名字符串
      final signatureParts = [response.statusCode.toString(), response.body];

      final signatureString = signatureParts.join('\n');
      final key = utf8.encode(_appSecret);
      final bytes = utf8.encode(signatureString);
      final hmacSha256 = Hmac(sha256, key);
      final calculatedSignature = hmacSha256.convert(bytes).toString();

      return calculatedSignature == expectedSignature;
    } catch (e) {
      print('验证响应签名失败: $e');
      return false;
    }
  }
}
