import '../services/api_service.dart';

class ApiConfig {
  // API 基础配置
  static const String baseUrl = 'https://api.hushie.ai/api/v1';
  static const Duration defaultTimeout = Duration(seconds: 10);

  // 分页配置
  static const int defaultPageSize = 10;
  static const int maxPageSize = 50;

  // Mock 数据配置
  static const bool enableMockMode = false; // 可以通过环境变量控制
  static const int mockNetworkDelayMs = 1000; // Mock 网络延迟
  static const double mockErrorRate = 0.05; // Mock 错误概率 (5%)

  // 缓存配置
  static const Duration cacheExpiry = Duration(minutes: 10);
  static const int maxCacheItems = 100;

  // API安全验签配置
  static const String appId = 'hushie_app_v1';
  static const String apiVersion = 'v1';
  static const String clientPlatform = 'flutter';

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

  /// 获取应用密钥（安全方式）
  /// 在实际项目中，这里应该实现更安全的密钥获取方式
  static String getAppSecret() {
    // TODO: 在生产环境中替换为安全的密钥获取方式
    // 例如：从环境变量、安全存储或远程服务获取
    return _appSecret;
  }

  /// 初始化 API 配置
  static void initialize({ApiMode? initialMode, bool? debugMode = false}) {
    // 根据环境设置初始模式
    final mode = initialMode ?? (enableMockMode ? ApiMode.mock : ApiMode.real);

    ApiService.setApiMode(mode);

    if (debugMode == true) {
      print('API 配置初始化完成');
      print('基础 URL: $baseUrl');
      print('当前模式: ${mode == ApiMode.mock ? 'Mock 数据' : '真实接口'}');
      print('应用 ID: $appId');
      print('API 版本: $apiVersion');
      print('签名算法: $signatureAlgorithm');
    }
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
      'User-Agent': 'HushieApp/1.0.0',
      'X-API-Version': apiVersion,
      'X-App-ID': appId,
      'X-Client-Platform': clientPlatform,
    };
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

  // 用户相关接口
  static const String userProfile = '/user/profile';
  static const String userLikes = '/user/likes';

  // 认证相关接口
  static const String googleLogin = '/auth/google/login';
  static const String googleLogout = '/auth/google/logout';
  static const String googleDeleteAccount = '/auth/google/delete';
  static const String googleRefreshToken = '/auth/google/refresh';
  static const String googleTokenValidate = '/auth/google/validate';
  static const String userInfo = '/auth/userinfo';

  static const String homeTabs = '/home/tabs';
  // 首页相关接口
}
