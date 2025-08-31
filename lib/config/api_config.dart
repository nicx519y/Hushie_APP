import '../services/api_service.dart';

class ApiConfig {
  // API 基础配置
  static const String baseUrl = 'https://your-api-domain.com/api/v1';
  static const Duration defaultTimeout = Duration(seconds: 10);

  // 分页配置
  static const int defaultPageSize = 10;
  static const int maxPageSize = 50;

  // Mock 数据配置
  static const bool enableMockMode = true; // 可以通过环境变量控制
  static const int mockNetworkDelayMs = 1000; // Mock 网络延迟
  static const double mockErrorRate = 0.05; // Mock 错误概率 (5%)

  // 缓存配置
  static const Duration cacheExpiry = Duration(minutes: 10);
  static const int maxCacheItems = 100;

  /// 初始化 API 配置
  static void initialize({ApiMode? initialMode, bool? debugMode = false}) {
    // 根据环境设置初始模式
    final mode = initialMode ?? (enableMockMode ? ApiMode.mock : ApiMode.real);

    ApiService.setApiMode(mode);

    if (debugMode == true) {
      print('API 配置初始化完成');
      print('基础 URL: $baseUrl');
      print('当前模式: ${mode == ApiMode.mock ? 'Mock 数据' : '真实接口'}');
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
}

/// API 端点常量
class ApiEndpoints {
  // 音频相关接口
  static const String audioList = '/audio/list';
  static const String audioSearch = '/audio/search';

  // 用户相关接口
  static const String userProfile = '/user/profile';
  static const String userLikes = '/user/likes';

  // 认证相关接口
  static const String googleLogin = '/auth/google/login';
  static const String googleLogout = '/auth/google/logout';
  static const String googleDeleteAccount = '/auth/google/delete';

  static const String homeTabs = '/home/tabs';
  // 首页相关接口
}
