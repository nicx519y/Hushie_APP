import 'dart:convert';
import 'dart:math';
import 'package:http/http.dart' as http;
import 'package:crypto/crypto.dart';
import '../config/api_config.dart';
import 'device_info_service.dart';
import 'auth_service.dart';
import 'app_signature_service.dart';
import 'package:flutter/foundation.dart';

/// HTTP客户端服务
class HttpClientService {
  static const Duration _defaultTimeout = Duration(seconds: 10);

  // 缓存设备ID，避免重复获取
  static String? _cachedDeviceId;
  static bool _isDeviceIdInitializing = false;

  /// 获取应用密钥
  static String get _appSecret => ApiConfig.getAppSecret();

  /// 获取设备ID（带缓存）
  static Future<String> _getCachedDeviceId() async {
    // debugPrint('📱 [DEVICE] 开始获取设备ID...');
    
    if (_cachedDeviceId != null) {
      // debugPrint('📱 [DEVICE] 使用缓存的设备ID: ${_cachedDeviceId!.substring(0, 8)}...');
      return _cachedDeviceId!;
    }

    if (_isDeviceIdInitializing) {
      debugPrint('📱 [DEVICE] 设备ID正在初始化中，等待...');
      // 等待初始化完成
      while (_isDeviceIdInitializing) {
        await Future.delayed(const Duration(milliseconds: 100));
        if (_cachedDeviceId != null) {
          debugPrint('📱 [DEVICE] 等待完成，获得设备ID: ${_cachedDeviceId!.substring(0, 8)}...');
          return _cachedDeviceId!;
        }
      }
    }

    debugPrint('📱 [DEVICE] 开始初始化设备ID...');
    _isDeviceIdInitializing = true;

    try {
      debugPrint('📱 [DEVICE] 调用DeviceInfoService.getDeviceId()...');
      final deviceId = await DeviceInfoService.getDeviceId();
      _cachedDeviceId = deviceId;
      debugPrint('📱 [DEVICE] 设备ID获取成功: ${deviceId.substring(0, 8)}...');
      return deviceId;
    } catch (e) {
      debugPrint('📱 [DEVICE] 获取设备ID失败: $e');
      debugPrint('📱 [DEVICE] 异常类型: ${e.runtimeType}');
      _cachedDeviceId = 'unknown_device';
      debugPrint('📱 [DEVICE] 使用默认设备ID: unknown_device');
      return _cachedDeviceId!;
    } finally {
      _isDeviceIdInitializing = false;
      debugPrint('📱 [DEVICE] 设备ID初始化完成');
    }
  }

  /// 清除设备ID缓存
  static void clearDeviceIdCache() {
    _cachedDeviceId = null;
    _isDeviceIdInitializing = false;
  }

  /// 发送GET请求
  static Future<http.Response> get(
    Uri uri, {
    Map<String, String>? headers,
    Duration? timeout,
  }) async {
    debugPrint('🌐 [HTTP] 开始GET请求: $uri');
    
    try {
      final requestHeaders = await _buildRequestHeaders(
        method: 'GET',
        path: uri.path,
        customHeaders: headers,
      );
      
      final response = await http
          .get(uri, headers: requestHeaders)
          .timeout(timeout ?? _defaultTimeout);
      
      return response;
    } catch (e) {
      debugPrint('🌐 [HTTP] HTTP GET请求异常: $e');
      debugPrint('🌐 [HTTP] 异常类型: ${e.runtimeType}');
      rethrow;
    }
  }

  /// 发送POST请求
  static Future<http.Response> post(
    Uri uri, {
    Map<String, String>? headers,
    Object? body,
    Duration? timeout,
  }) async {
    final requestHeaders = await _buildRequestHeaders(
      method: 'POST',
      path: uri.path,
      customHeaders: headers,
      body: body,
    );

    return http
        .post(
          uri,
          headers: requestHeaders,
          body: body is String ? body : json.encode(body),
        )
        .timeout(timeout ?? _defaultTimeout);
  }

  /// 发送PUT请求
  static Future<http.Response> put(
    Uri uri, {
    Map<String, String>? headers,
    Object? body,
    Duration? timeout,
  }) async {
    final requestHeaders = await _buildRequestHeaders(
      method: 'PUT',
      path: uri.path,
      customHeaders: headers,
      body: body,
    );

    return http
        .put(
          uri,
          headers: requestHeaders,
          body: body is String ? body : json.encode(body),
        )
        .timeout(timeout ?? _defaultTimeout);
  }

  /// 发送DELETE请求
  static Future<http.Response> delete(
    Uri uri, {
    Map<String, String>? headers,
    Object? body,
    Duration? timeout,
  }) async {
    final requestHeaders = await _buildRequestHeaders(
      method: 'DELETE',
      path: uri.path,
      customHeaders: headers,
      body: body,
    );

    return http
        .delete(
          uri,
          headers: requestHeaders,
          body: body is String ? body : json.encode(body),
        )
        .timeout(timeout ?? _defaultTimeout);
  }

  /// 发送PATCH请求
  static Future<http.Response> patch(
    Uri uri, {
    Map<String, String>? headers,
    Object? body,
    Duration? timeout,
  }) async {
    final requestHeaders = await _buildRequestHeaders(
      method: 'PATCH',
      path: uri.path,
      customHeaders: headers,
      body: body,
    );

    return http
        .patch(
          uri,
          headers: requestHeaders,
          body: body is String ? body : json.encode(body),
        )
        .timeout(timeout ?? _defaultTimeout);
  }

  /// 构建请求头
  static Future<Map<String, String>> _buildRequestHeaders({
    required String method,
    required String path,
    Map<String, String>? customHeaders,
    Object? body,
  }) async {
    final headers = <String, String>{};

    // 添加基础请求头
    // debugPrint('🔧 [HTTP] 添加基础请求头...');
    headers.addAll(ApiConfig.getDefaultHeaders());
    // debugPrint('🔧 [HTTP] 基础请求头添加完成，包含 ${headers.length} 个字段');

    // 添加自定义请求头
    if (customHeaders != null) {
      // debugPrint('🔧 [HTTP] 添加自定义请求头，包含 ${customHeaders.length} 个字段');
      headers.addAll(customHeaders);
    } else {
      // debugPrint('🔧 [HTTP] 无自定义请求头');
    }

    // 自动添加设备ID（使用缓存）
    try {
      // debugPrint('🔧 [HTTP] 开始获取设备ID...');
      final deviceId = await _getCachedDeviceId();
      headers['X-Device-ID'] = deviceId;
      // debugPrint('🔧 [HTTP] 设备ID获取成功: ${deviceId.substring(0, 8)}...');
    } catch (e) {
      // debugPrint('🔧 [HTTP] 获取设备ID失败: $e');
      headers['X-Device-ID'] = 'unknown_device';
    }

    // 自动添加用户Token（如果存在）
    // 注意：对于Token刷新请求，跳过Token获取以避免循环依赖
    if (!path.contains('/auth/google/refresh')) {
      try {
        // debugPrint('🔐 [HTTP] 开始获取访问令牌');
        final accessToken = await AuthService.getAccessToken();
        if (accessToken != null && accessToken.isNotEmpty) {
          headers['Authorization'] = 'Bearer $accessToken';
          // debugPrint('🔐 [HTTP] 成功添加 Authorization 头，令牌长度: ${accessToken.length}');
        } else {
          debugPrint('🔐 [HTTP] 访问令牌为空，跳过 Authorization 头');
        }
      } catch (e) {
        debugPrint('🔐 [HTTP] 获取access token失败: $e');
        debugPrint('🔐 [HTTP] 异常类型: ${e.runtimeType}');
        // 不添加Authorization头
      }
    } else {
      // debugPrint('🔐 [HTTP] Token刷新请求，跳过Authorization头以避免循环依赖');
    }
    
    // debugPrint('🔧 [HTTP] 请求头构建完成，最终包含 ${headers.length} 个字段');

    // debugPrint("Authorization 成功 ${headers['Authorization']}");
    
    // 添加动态签名验证信息
    try {
      final appSignatureService = AppSignatureService();
      
      // 生成动态签名参数
      final Map<String, String>? dynamicSignature = await appSignatureService.generateDynamicSignature();
      
      if (dynamicSignature != null) {
        // 添加动态签名相关请求头
        headers['X-Dynamic-Signature'] = dynamicSignature['signature'] ?? '';
        headers['X-Timestamp'] = dynamicSignature['timestamp'] ?? '';
        headers['X-Nonce'] = dynamicSignature['nonce'] ?? '';
        
        // 获取应用签名哈希
        final signatureHash = await appSignatureService.getSignatureHash();
        if (signatureHash != null) {
          headers['X-App-Signature-Hash'] = signatureHash;
        }
        
        // 获取完整性验证信息
        final integrityInfo = await appSignatureService.getIntegrityInfo();
        headers['X-App-Integrity'] = json.encode({
          'signature_valid': integrityInfo['isSignatureValid'],
          'trusted_source': integrityInfo['isFromTrustedSource'],
          'debug_build': integrityInfo['isDebugBuild'],
        });
        
        debugPrint('🔐 [DYNAMIC_SIGNATURE] 动态签名生成成功');
      } else {
        debugPrint('⚠️ [DYNAMIC_SIGNATURE] 动态签名生成失败，使用备用签名');
        
        // 备用方案：使用旧的签名方式
        final signature = await _generateSignature(
          method: method,
          path: path,
          headers: headers,
          body: body,
          timestamp: _generateTimestamp(),
          nonce: _generateNonce(),
        );
        headers['X-Signature'] = signature;
        
        // 标记为备用签名
        headers['X-Signature-Type'] = 'fallback';
      }
    } catch (e) {
      debugPrint('❌ [DYNAMIC_SIGNATURE] 生成动态签名失败: $e');
      
      // 异常处理：使用备用签名方式
      try {
        final signature = await _generateSignature(
          method: method,
          path: path,
          headers: headers,
          body: body,
          timestamp: _generateTimestamp(),
          nonce: _generateNonce(),
        );
        headers['X-Signature'] = signature;
        headers['X-Signature-Type'] = 'fallback';
        headers['X-Signature-Error'] = 'dynamic_signature_failed';
      } catch (fallbackError) {
        debugPrint('❌ [SIGNATURE] 备用签名也失败: $fallbackError');
        headers['X-Signature-Error'] = 'all_signature_methods_failed';
      }
    }

    // debugPrint("X-Signature 成功 ${headers['X-Signature']}");

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
      debugPrint('生成签名失败: $e');
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

  /// 生成时间戳
  static String _generateTimestamp() {
    return DateTime.now().millisecondsSinceEpoch.toString();
  }

  /// 发送JSON POST请求的便捷方法
  static Future<http.Response> postJson(
    Uri uri, {
    Map<String, String>? headers,
    Map<String, dynamic>? body,
    Duration? timeout,
  }) async {
    final jsonBody = body != null ? json.encode(body) : null;
    final requestHeaders = await _buildRequestHeaders(
      method: 'POST',
      path: uri.path,
      customHeaders: headers,
      body: jsonBody,
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
    final requestHeaders = await _buildRequestHeaders(
      method: 'PUT',
      path: uri.path,
      customHeaders: headers,
      body: jsonBody,
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
    final requestHeaders = await _buildRequestHeaders(
      method: 'PATCH',
      path: uri.path,
      customHeaders: headers,
      body: jsonBody,
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
      debugPrint('验证响应签名失败: $e');
      return false;
    }
  }
}
