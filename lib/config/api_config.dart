import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

class ApiConfig {
  // API 基础配置
  static const String baseUrl = 'https://api.hushie.ai/api/v1';
  static const String healthCheckUrl = 'https://api.hushie.ai/health';
  static const Duration defaultTimeout = Duration(seconds: 10);

  // 分页配置
  static const int defaultPageSize = 10;
  static const int maxPageSize = 50;

  // 缓存配置
  static const Duration cacheExpiry = Duration(minutes: 10);
  static const int maxCacheItems = 100;

  // API安全验签配置
  static const String appId = 'hushie_app_v1';
  static const String apiVersion = 'v1';
  static const String clientPlatform = 'flutter';

  // 应用版本配置（可动态修改）
  static String _appVersion = '1.0.4';

  // 是否使用预埋数据（可动态修改并持久化）
  static bool _useEmbeddedData = false;
  static const String _useEmbeddedDataKey = 'use_embedded_data';

  /// 初始化应用版本（从存储中加载）
  static Future<void> _initializeAppVersion() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final storedVersion = prefs.getString('app_version');
      if (storedVersion != null && storedVersion.isNotEmpty) {
        _appVersion = storedVersion;
      }
    } catch (e) {
      debugPrint('初始化应用版本失败: $e');
      // 使用默认版本
    }
  }

  /// 初始化是否使用预埋数据的开关（从存储中加载）
  static Future<void> _initializeUseEmbeddedData() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final stored = prefs.getBool(_useEmbeddedDataKey);
      if (stored != null) {
        _useEmbeddedData = stored;
      }
    } catch (e) {
      debugPrint('初始化预埋数据开关失败: $e');
      // 使用默认开关值
    }
  }

  /// 获取是否使用预埋数据
  static bool get useEmbeddedData => _useEmbeddedData;

  /// 设置是否使用预埋数据（并持久化）
  static Future<void> setUseEmbeddedData(bool value) async {
    _useEmbeddedData = value;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_useEmbeddedDataKey, value);
    } catch (e) {
      debugPrint('保存预埋数据开关失败: $e');
    }
  }

  // 注意：在生产环境中，appSecret应该通过以下方式之一获取：
  // 1. 环境变量
  // 2. 安全配置文件（不包含在版本控制中）
  // 3. 远程配置服务
  // 4. 设备证书存储
  static const String _appSecret = 'your_app_secret_key_here';

  // 签名算法配置
  static const String signatureAlgorithm = 'HMAC-SHA256';
  static const int nonceLength = 16;
  static const int maxTimestampDrift = 300; // 5分钟时间戳漂移容忍度（秒）

  // WebView页面配置 - 网络优先，本地回退
  static const String WebviewAboutUsUrl = 'https://af.hushie.ai/html/about.html'; // 网络URL
  static const String WebviewAboutUsFallback = 'assets/html/about.html'; // 本地回退
  
  static const String AccountDeletionAgreement = 'https://af.hushie.ai/html/account_deletion_agreement.html'; // 网络URL
  static const String AccountDeletionAgreementFallback = 'assets/html/account_deletion_agreement.html'; // 本地回退

  // WebView页面配置 - 网络优先，本地回退
  static const String TermsOfUseUrl = 'https://af.hushie.ai/html/terms_of_use.html'; // 网络URL
  static const String TermsOfUseFallback = 'assets/html/terms_of_use.html'; // 本地回退
  
  static const String EndUserLicenseAgreementUrl = 'https://af.hushie.ai/html/end_user_license_agreement.html'; // 网络URL
  static const String EndUserLicenseAgreementFallback = 'assets/html/end_user_license_agreement.html'; // 本地回退
  
  static const String PrivacyPolicyUrl = 'https://af.hushie.ai/html/privacy_policy.html'; // 网络URL
  static const String PrivacyPolicyFallback = 'assets/html/privacy_policy.html'; // 本地回退
  
  static const String AutoRenewInfoUrl = 'https://af.hushie.ai/html/renew_info.html'; // 网络URL
  static const String AutoRenewInfoFallback = 'assets/html/renew_info.html'; // 本地回退

  /// 获取应用密钥（安全方式）
  /// 在实际项目中，这里应该实现更安全的密钥获取方式
  static String getAppSecret() {
    // TODO: 在生产环境中替换为安全的密钥获取方式
    // 例如：从环境变量、安全存储或远程服务获取
    return _appSecret;
  }

  /// 初始化 API 配置
  static Future<void> initialize({bool? debugMode = false}) async {
    await _initializeAppVersion();
    await _initializeUseEmbeddedData();
  }

  /// 获取完整的 API URL
  static String getFullUrl(String endpoint) {
    if (endpoint.startsWith('/')) {
      return '$baseUrl$endpoint';
    } else {
      return '$baseUrl/$endpoint';
    }
  }

  /// 获取默认请求头
  static Map<String, String> getDefaultHeaders() {
    return {
      'Content-Type': 'application/json',
      'Accept': 'application/json',
      'App-Version': _appVersion,
      'X-API-Version': apiVersion,
      'X-App-ID': appId,
      'X-Client-Platform': clientPlatform,
    };
  }

  /// 获取当前应用版本
  static String getAppVersion() {
    return _appVersion;
  }

  /// 设置应用版本
  static Future<void> setAppVersion(String version) async {
    _appVersion = version;
    // 保存到存储中
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('app_version', version);
    } catch (e) {
      debugPrint('保存应用版本到存储失败: $e');
    }
  }

  /// 获取认证请求头（如果需要）
  static Map<String, String> getAuthHeaders({String? token}) {
    final headers = getDefaultHeaders();
    if (token != null) {
      headers['Authorization'] = 'Bearer $token';
    }
    return headers;
  }

  /// 验证时间戳是否在有效范围内
  static bool isTimestampValid(int timestamp) {
    final now = DateTime.now().millisecondsSinceEpoch ~/ 1000;
    final diff = (now - timestamp).abs();
    return diff <= maxTimestampDrift;
  }

  /// 获取安全配置信息
  static Map<String, dynamic> getSecurityConfig() {
    return {
      'app_id': appId,
      'api_version': apiVersion,
      'client_platform': clientPlatform,
      'signature_algorithm': signatureAlgorithm,
      'nonce_length': nonceLength,
      'max_timestamp_drift': maxTimestampDrift,
    };
  }
}

/// API 端点常量
class ApiEndpoints {

  // 音频相关接口
  static const String audioList = '/audio/list';
  static const String audioSearch = '/audio/search';
  static const String audioLike = '/audio/like';
  static const String audioDetail = '/audios'; // 音频详情接口，需要拼接ID

  // 用户相关接口
  static const String userProfile = '/user/profile';
  static const String userLikes = '/user/likes';
  static const String userHistoryList = '/user/history-list';
  static const String userPlayProgress = '/user/play';

  // 认证相关接口
  static const String googleLogin = '/auth/google/login';
  static const String googleLogout = '/auth/google/logout';
  static const String googleDeleteAccount = '/auth/google/delete';
  static const String googleRefreshToken = '/auth/google/refresh';
  static const String googleTokenValidate = '/auth/google/validate';
  static const String userInfo = '/auth/userinfo';

  // 首页相关接口
  static const String homeTabs = '/home/tabs';

  // 产品相关接口
  static const String productList = '/products';

  // 用户权限相关接口
  static const String userPrivilegeCheck = '/user/privilege/check';

  // 订阅相关接口
  static const String subscribeCreate = '/subscriptions';

  // 追踪打点接口
  static const String tracking = '/tracking';
}
