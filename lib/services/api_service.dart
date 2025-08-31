import 'dart:convert';
import 'dart:math';
import 'package:http/http.dart' as http;
import '../models/audio_item.dart';
import '../models/api_response.dart';
import '../models/tab_item.dart';
import '../data/mock_data.dart';
import '../config/api_config.dart';
import 'api/audio_list_service.dart';
import 'api/audio_search_service.dart';
import 'api/home_tabs_service.dart';
import 'api/user_likes_service.dart';
import 'api/google_auth_service.dart';
import 'mock/google_auth_mock.dart';
import 'package:google_sign_in/google_sign_in.dart';

enum ApiMode {
  mock, // 使用本地 mock 数据
  real, // 使用真实 API
}

class ApiService {
  // 可以通过环境变量或配置文件设置
  static ApiMode _currentMode = ApiMode.mock;

  // 设置 API 模式
  static void setApiMode(ApiMode mode) {
    _currentMode = mode;
    print('API 模式切换为: ${mode == ApiMode.mock ? 'Mock 数据' : '真实接口'}');
  }

  // 获取当前 API 模式
  static ApiMode get currentMode => _currentMode;

  /// 获取音频列表
  static Future<ApiResponse<SimpleResponse<AudioItem>>> getAudioList({
    String? tag,
    String? cid,
    int count = 10,
  }) async {
    return AudioListService.getAudioList(tag: tag, cid: cid, count: count);
  }

  /// 搜索音频列表
  static Future<ApiResponse<SimpleResponse<AudioItem>>> getAudioSearchList({
    required String searchQuery,
    String? cid,
    int count = 10,
  }) async {
    return AudioSearchService.getAudioSearchList(
      searchQuery: searchQuery,
      cid: cid,
      count: count,
    );
  }

  /// 获取首页 tabs
  static Future<ApiResponse<List<TabItem>>> getHomeTabs() async {
    return HomeTabsService.getHomeTabs();
  }

  /// 获取用户喜欢的音频列表
  static Future<ApiResponse<PaginatedResponse<AudioItem>>> getUserLikedAudios({
    int page = 1,
    int pageSize = 20,
  }) async {
    return UserLikesService.getUserLikedAudios(page: page, pageSize: pageSize);
  }

  /// Google账号登录
  static Future<ApiResponse<GoogleAuthResponse>> googleSignIn() async {
    return GoogleAuthService.googleSignIn();
  }

  /// 用Google登录凭证获取access token
  static Future<ApiResponse<AccessTokenResponse>> getGoogleAccessToken({
    required String googleToken,
  }) async {
    return GoogleAuthService.getAccessToken(googleToken: googleToken);
  }

  /// Google登出
  static Future<void> googleSignOut() async {
    return GoogleAuthService.signOut();
  }

  /// Google服务器登出
  static Future<ApiResponse<void>> googleLogout() async {
    return GoogleAuthService.logout();
  }

  /// Google删除账户
  static Future<ApiResponse<void>> googleDeleteAccount() async {
    return GoogleAuthService.deleteAccount();
  }

  /// 检查Google是否已登录
  static Future<bool> isGoogleSignedIn() async {
    return GoogleAuthService.isSignedIn();
  }

  /// 获取当前Google登录用户
  static Future<GoogleSignInAccount?> getCurrentGoogleUser() async {
    return GoogleAuthService.getCurrentUser();
  }
}
