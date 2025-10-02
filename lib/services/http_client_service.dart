import 'dart:convert';
import 'dart:math';
import 'package:http/http.dart' as http;
import 'package:crypto/crypto.dart';
import '../config/api_config.dart';
import 'device_info_service.dart';
import 'auth_manager.dart';
import 'app_signature_service.dart';
import '../utils/toast_helper.dart';
import '../utils/toast_messages.dart';
import 'package:flutter/foundation.dart';
import '../services/analytics_service.dart';
import 'performance_service.dart';
import 'package:firebase_performance/firebase_performance.dart';



/// HTTP客户端服务
class HttpClientService {
  static const Duration _defaultTimeout = Duration(seconds: 10);

  // 重试配置参数
  static int _maxRetries = 3; // 默认重试3次
  static Duration _retryDelay = Duration(milliseconds: 500); // 重试间隔500ms
  static List<int> _retryStatusCodes = [404, 500, 502, 503, 504]; // 需要重试的状态码

  // 缓存设备ID，避免重复获取
  static String? _cachedDeviceId;
  static bool _isDeviceIdInitializing = false;

  // 动态签名缓存和并发控制
  static Map<String, dynamic>? _cachedDynamicSignature;
  static bool _isDynamicSignatureGenerating = false;
  static DateTime? _signatureCacheTime;
  static const Duration _signatureCacheExpiry = Duration(minutes: 5); // 签名缓存5分钟

  /// 配置重试参数
  static void configureRetry({
    int? maxRetries,
    Duration? retryDelay,
    List<int>? retryStatusCodes,
  }) {
    if (maxRetries != null) _maxRetries = maxRetries;
    if (retryDelay != null) _retryDelay = retryDelay;
    if (retryStatusCodes != null) _retryStatusCodes = retryStatusCodes;
  }

  /// 统一的重试逻辑
  static Future<http.Response> _executeWithRetry(
    Future<http.Response> Function() request,
    String requestType,
    Uri uri,
  ) async {
    int attempt = 0;
    http.Response? lastResponse;
    dynamic lastException;
    
    while (attempt <= _maxRetries) {
      try {
        debugPrint('🔄 [RETRY] $requestType 请求尝试 ${attempt + 1}/${_maxRetries + 1}: $uri');
        // 启动 HttpMetric（按尝试次序记录）
        final httpMethod = _mapHttpMethod(requestType);
        final metric = await PerformanceService().startHttpMetric(uri, httpMethod);
        metric?.putAttribute('attempt', '${attempt + 1}');
        metric?.putAttribute('path', uri.path);
        metric?.putAttribute('host', uri.host);
        
        final response = await request();
        lastResponse = response;
        
        // 401 统一处理：先尝试刷新Token并重发一次
        if (response.statusCode == 401) {
          debugPrint('🔐 [HTTP] 检测到401未授权，尝试刷新Token后重发');

          // 记录401事件
          await AnalyticsService().logCustomEvent(
            eventName: 'StatusCode_401',
            parameters: {
              'uri': uri.toString(),
              'timestamp': DateTime.now().millisecondsSinceEpoch,
            },
          );

          try {
            final refreshed = await AuthManager.instance.refreshToken();
            if (refreshed) {
              debugPrint('🔐 [HTTP] 刷新成功，重发请求');
              await PerformanceService().stopHttpMetric(
                metric,
                responseCode: response.statusCode,
                responsePayloadSize: response.bodyBytes.length,
                contentType: response.headers['content-type'],
              );
              final retryResponse = await request();
              return retryResponse;
            } else {
              debugPrint('🔐 [HTTP] 刷新失败，提示登录过期');
              _showErrorToast(ToastMessages.authExpired);
              await PerformanceService().stopHttpMetric(
                metric,
                responseCode: response.statusCode,
                responsePayloadSize: response.bodyBytes.length,
                contentType: response.headers['content-type'],
              );
              return response; // 返回原响应，避免无限循环
            }
          } catch (e) {
            debugPrint('🔐 [HTTP] 刷新流程异常: $e');
            _showErrorToast(ToastMessages.authExpired);
            await PerformanceService().stopHttpMetric(
              metric,
              responseCode: response.statusCode,
              responsePayloadSize: response.bodyBytes.length,
              contentType: response.headers['content-type'],
            );
            return response;
          }
        }

        // 检查是否需要重试
        if (_shouldRetry(response.statusCode, attempt)) {
          debugPrint('⚠️ [RETRY] $requestType 请求失败，状态码: ${response.statusCode}，准备重试...');
          await PerformanceService().stopHttpMetric(
            metric,
            responseCode: response.statusCode,
            responsePayloadSize: response.bodyBytes.length,
            contentType: response.headers['content-type'],
          );
          attempt++;
          if (attempt <= _maxRetries) {
            await Future.delayed(_retryDelay);
            continue;
          } else {
            // 重试次数用尽，显示状态码相关的Toast提示
            final errorMessage = _getStatusCodeMessage(response.statusCode);
            _showErrorToast(errorMessage);
            debugPrint('💥 [RETRY] $requestType 请求重试次数用尽，状态码: ${response.statusCode}');
          }
        } else if (response.statusCode >= 400) {
          // 不需要重试的错误状态码，直接显示Toast提示
          final errorMessage = _getStatusCodeMessage(response.statusCode);
          _showErrorToast(errorMessage);
          debugPrint('💥 [RETRY] $requestType 请求失败，不重试，状态码: ${response.statusCode}');
        }
        
        debugPrint('✅ [RETRY] $requestType 请求成功，状态码: ${response.statusCode}');
        await PerformanceService().stopHttpMetric(
          metric,
          responseCode: response.statusCode,
          responsePayloadSize: response.bodyBytes.length,
          contentType: response.headers['content-type'],
        );
        return response;
        
      } catch (e) {
        debugPrint('❌ [RETRY] $requestType 请求异常: $e');
        debugPrint('🔄 [RETRY] 异常类型: ${e.runtimeType}');
        lastException = e;
        
        // 检查是否是需要重试的异常
        if (_shouldRetryException(e, attempt)) {
          debugPrint('⚠️ [RETRY] 异常需要重试，准备重试...');
          attempt++;
          if (attempt <= _maxRetries) {
            await Future.delayed(_retryDelay);
            continue;
          } else {
            // 重试次数用尽，显示异常相关的Toast提示
            final errorMessage = _getExceptionMessage(e);
            _showErrorToast(errorMessage);
            debugPrint('💥 [RETRY] $requestType 请求重试次数用尽，异常: $e');
          }
        } else {
          // 不需要重试的异常，直接显示Toast并抛出
          final errorMessage = _getExceptionMessage(e);
          _showErrorToast(errorMessage);
          debugPrint('💥 [RETRY] $requestType 请求最终失败，不再重试');
          rethrow;
        }
      }
    }
    
    // 如果有最后的响应，返回它；否则抛出最后的异常
    if (lastResponse != null) {
      return lastResponse;
    } else if (lastException != null) {
      throw lastException;
    } else {
      final errorMessage = ToastMessages.httpRetryExhausted;
      _showErrorToast(errorMessage);
      throw Exception(errorMessage);
    }
  }

  /// 将字符串方法映射到 Firebase HttpMethod
  static HttpMethod _mapHttpMethod(String requestType) {
    switch (requestType.toUpperCase()) {
      case 'GET':
        return HttpMethod.Get;
      case 'POST':
      case 'POST_JSON':
        return HttpMethod.Post;
      case 'PUT':
      case 'PUT_JSON':
        return HttpMethod.Put;
      case 'DELETE':
        return HttpMethod.Delete;
      case 'PATCH':
      case 'PATCH_JSON':
        return HttpMethod.Patch;
      default:
        return HttpMethod.Get;
    }
  }

  /// 判断是否需要重试（基于状态码）
  static bool _shouldRetry(int statusCode, int currentAttempt) {
    return currentAttempt < _maxRetries && _retryStatusCodes.contains(statusCode);
  }

  /// 判断是否需要重试（基于异常）
  static bool _shouldRetryException(dynamic exception, int currentAttempt) {
    if (currentAttempt >= _maxRetries) return false;
    
    // 超时异常需要重试
    if (exception.toString().contains('TimeoutException') ||
        exception.toString().contains('timeout')) {
      return true;
    }
    
    // 网络连接异常需要重试
    if (exception.toString().contains('SocketException') ||
        exception.toString().contains('HandshakeException') ||
        exception.toString().contains('Connection')) {
      return true;
    }
    
    return false;
  }

  /// 根据状态码获取错误消息
  static String _getStatusCodeMessage(int statusCode) {
    return ToastMessages.getHttpStatusMessage(statusCode);
  }

  /// 根据异常类型获取错误消息
  static String _getExceptionMessage(dynamic exception) {
    return ToastMessages.getNetworkExceptionMessage(exception);
  }

  /// 显示错误Toast提示
  static void _showErrorToast(String message) {
    try {
      ToastHelper.showError(message);
    } catch (e) {
      debugPrint('❌ [TOAST] 显示Toast失败: $e');
    }
  }

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

  /// 清除动态签名缓存
  static void clearDynamicSignatureCache() {
    _cachedDynamicSignature = null;
    _isDynamicSignatureGenerating = false;
    _signatureCacheTime = null;
  }

  /// 生成动态签名（带缓存和并发控制）
  static Future<Map<String, dynamic>?> _generateDynamicSignatureWithCache() async {

    // 检查缓存是否有效
    if (_cachedDynamicSignature != null && _signatureCacheTime != null) {
      final now = DateTime.now();
      final cacheAge = now.difference(_signatureCacheTime!);
      
      if (cacheAge < _signatureCacheExpiry) {
        debugPrint('🔐 [DYNAMIC_SIGNATURE] 使用缓存的动态签名，剩余有效期: ${_signatureCacheExpiry - cacheAge}');
        return _cachedDynamicSignature;
      } else {
        debugPrint('🔐 [DYNAMIC_SIGNATURE] 缓存的动态签名已过期，需要重新生成');
        _cachedDynamicSignature = null;
        _signatureCacheTime = null;
      }
    }

    // 如果正在生成中，等待结果
    if (_isDynamicSignatureGenerating) {
      debugPrint('🔐 [DYNAMIC_SIGNATURE] 动态签名正在生成中，等待...');
      
      // 等待生成完成，最多等待10秒
      int waitCount = 0;
      const maxWaitCount = 100; // 10秒 (100 * 100ms)
      
      while (_isDynamicSignatureGenerating && waitCount < maxWaitCount) {
        await Future.delayed(const Duration(milliseconds: 100));
        waitCount++;
        
        // 如果在等待期间生成完成，返回结果
        if (_cachedDynamicSignature != null && _signatureCacheTime != null) {
          final now = DateTime.now();
          final cacheAge = now.difference(_signatureCacheTime!);
          
          if (cacheAge < _signatureCacheExpiry) {
            debugPrint('🔐 [DYNAMIC_SIGNATURE] 等待完成，获得动态签名');
            return _cachedDynamicSignature;
          }
        }
      }
      
      if (waitCount >= maxWaitCount) {
        debugPrint('⚠️ [DYNAMIC_SIGNATURE] 等待动态签名生成超时');
        _isDynamicSignatureGenerating = false;
        return null;
      }
    }

    // 开始生成新的动态签名
    debugPrint('🔐 [DYNAMIC_SIGNATURE] 开始生成新的动态签名...');
    _isDynamicSignatureGenerating = true;

    try {
      final appSignatureService = AppSignatureService();
      
      // 生成动态签名参数
      final Map<String, String>? dynamicSignature = await appSignatureService.generateDynamicSignature();
      
      if (dynamicSignature != null) {
        // 获取应用签名哈希
        final signatureHash = await appSignatureService.getSignatureHash();
        
        // 获取完整性验证信息
        final integrityInfo = await appSignatureService.getIntegrityInfo();
        
        // 构建完整的签名信息
        final completeSignature = <String, dynamic>{
          'signature': dynamicSignature['signature'] ?? '',
          'timestamp': dynamicSignature['timestamp'] ?? '',
          'nonce': dynamicSignature['nonce'] ?? '',
          'signatureHash': signatureHash,
          'integrityInfo': integrityInfo,
        };
        
        // 缓存结果
        _cachedDynamicSignature = completeSignature;
        _signatureCacheTime = DateTime.now();
        
        debugPrint('🔐 [DYNAMIC_SIGNATURE] 动态签名生成成功并已缓存');
        return completeSignature;
      } else {
        debugPrint('⚠️ [DYNAMIC_SIGNATURE] 动态签名生成失败');
        return null;
      }
    } catch (e) {
      debugPrint('❌ [DYNAMIC_SIGNATURE] 生成动态签名异常: $e');
      return null;
    } finally {
      _isDynamicSignatureGenerating = false;
      debugPrint('🔐 [DYNAMIC_SIGNATURE] 动态签名生成流程完成');
    }
  }

  /// 发送GET请求
  static Future<http.Response> get(
    Uri uri, {
    Map<String, String>? headers,
    Duration? timeout,
  }) async {
    return _executeWithRetry(
      () async {
        final requestHeaders = await _buildRequestHeaders(
          method: 'GET',
          path: uri.path,
          customHeaders: headers,
        );
        
        return http
            .get(uri, headers: requestHeaders)
            .timeout(timeout ?? _defaultTimeout);
      },
      'GET',
      uri,
    );
  }

  /// 发送POST请求
  static Future<http.Response> post(
    Uri uri, {
    Map<String, String>? headers,
    Object? body,
    Duration? timeout,
  }) async {
    return _executeWithRetry(
      () async {
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
      },
      'POST',
      uri,
    );
  }

  /// 发送PUT请求
  static Future<http.Response> put(
    Uri uri, {
    Map<String, String>? headers,
    Object? body,
    Duration? timeout,
  }) async {
    return _executeWithRetry(
      () async {
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
      },
      'PUT',
      uri,
    );
  }

  /// 发送DELETE请求
  static Future<http.Response> delete(
    Uri uri, {
    Map<String, String>? headers,
    Object? body,
    Duration? timeout,
  }) async {
    return _executeWithRetry(
      () async {
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
      },
      'DELETE',
      uri,
    );
  }

  /// 发送PATCH请求
  static Future<http.Response> patch(
    Uri uri, {
    Map<String, String>? headers,
    Object? body,
    Duration? timeout,
  }) async {
    return _executeWithRetry(
      () async {
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
      },
      'PATCH',
      uri,
    );
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
    if (!path.contains(ApiEndpoints.googleRefreshToken)) {
      try {
        // debugPrint('🔐 [HTTP] 开始获取访问令牌');
        final accessToken = await AuthManager.instance.getAccessToken();
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
      // 使用新的缓存和并发控制的动态签名生成函数
      final Map<String, dynamic>? completeSignature = await _generateDynamicSignatureWithCache();
      
      if (completeSignature != null) {
        // 添加动态签名相关请求头
        headers['X-Dynamic-Signature'] = completeSignature['signature'] ?? '';
        headers['X-Timestamp'] = completeSignature['timestamp'] ?? '';
        headers['X-Nonce'] = completeSignature['nonce'] ?? '';
        
        // 添加应用签名哈希
        if (completeSignature['signatureHash'] != null) {
          headers['X-App-Signature-Hash'] = completeSignature['signatureHash'];
        }
        
        // 添加完整性验证信息
        final integrityInfo = completeSignature['integrityInfo'];
        if (integrityInfo != null) {
          headers['X-App-Integrity'] = json.encode({
            'signature_valid': integrityInfo['isSignatureValid'],
            'trusted_source': integrityInfo['isFromTrustedSource'],
            'debug_build': integrityInfo['isDebugBuild'],
          });
        }
        
        debugPrint('🔐 [DYNAMIC_SIGNATURE] 动态签名添加成功');
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
    return _executeWithRetry(
      () async {
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
      },
      'POST_JSON',
      uri,
    );
  }

  /// 发送JSON PUT请求的便捷方法
  static Future<http.Response> putJson(
    Uri uri, {
    Map<String, String>? headers,
    Map<String, dynamic>? body,
    Duration? timeout,
  }) async {
    return _executeWithRetry(
      () async {
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
      },
      'PUT_JSON',
      uri,
    );
  }

  /// 发送JSON PATCH请求的便捷方法
  static Future<http.Response> patchJson(
    Uri uri, {
    Map<String, String>? headers,
    Map<String, dynamic>? body,
    Duration? timeout,
  }) async {
    return _executeWithRetry(
      () async {
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
      },
      'PATCH_JSON',
      uri,
    );
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
