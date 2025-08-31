import 'dart:convert';
import 'package:google_sign_in/google_sign_in.dart';
import '../../models/api_response.dart';
import '../../config/api_config.dart';
import '../api_service.dart';
import '../mock/google_auth_mock.dart';
import '../http_client_service.dart';

/// Google认证服务
class GoogleAuthService {
  static Duration get _defaultTimeout => ApiConfig.defaultTimeout;

  // 创建GoogleSignIn实例
  static final GoogleSignIn _googleSignIn = GoogleSignIn(
    scopes: ['email', 'profile'],
  );

  /// Google账号登录
  static Future<ApiResponse<GoogleAuthResponse>> googleSignIn() async {
    if (ApiService.currentMode == ApiMode.mock) {
      return GoogleAuthMock.getMockGoogleSignIn();
    } else {
      return _getRealGoogleSignIn();
    }
  }

  /// 用Google登录凭证获取access token
  static Future<ApiResponse<AccessTokenResponse>> getAccessToken({
    required String googleToken,
  }) async {
    if (ApiService.currentMode == ApiMode.mock) {
      return GoogleAuthMock.getMockAccessToken(googleToken: googleToken);
    } else {
      return _getRealAccessToken(googleToken: googleToken);
    }
  }

  /// 真实接口 - Google账号登录
  static Future<ApiResponse<GoogleAuthResponse>> _getRealGoogleSignIn() async {
    try {
      // 检查是否已经登录
      if (await _googleSignIn.isSignedIn()) {
        await _googleSignIn.signOut();
      }

      // 执行Google登录
      final GoogleSignInAccount? googleUser = await _googleSignIn.signIn();

      if (googleUser == null) {
        // 用户取消登录
        return ApiResponse.error(errNo: -2);
      }

      // 获取认证信息
      final GoogleSignInAuthentication googleAuth =
          await googleUser.authentication;

      // 构建响应数据
      final googleAuthResponse = GoogleAuthResponse(
        userId: googleUser.id,
        email: googleUser.email,
        displayName: googleUser.displayName ?? '',
        photoUrl: googleUser.photoUrl,
        idToken: googleAuth.idToken ?? '',
      );

      return ApiResponse.success(data: googleAuthResponse, errNo: 0);
    } catch (e) {
      print('Google登录失败: $e');
      return ApiResponse.error(errNo: -1);
    }
  }

  /// 真实接口 - 获取access token
  static Future<ApiResponse<AccessTokenResponse>> _getRealAccessToken({
    required String googleToken,
  }) async {
    try {
      final uri = Uri.parse(ApiConfig.getFullUrl(ApiEndpoints.googleLogin));

      final response = await HttpClientService.postJson(
        uri,
        body: {'google_token': googleToken, 'grant_type': 'google_token'},
        timeout: _defaultTimeout,
      );

      if (response.statusCode == 200) {
        final Map<String, dynamic> jsonData = json.decode(response.body);

        // 使用统一的JSON处理函数
        return ApiResponse.fromJson(
          jsonData,
          (dataJson) => AccessTokenResponse.fromMap(dataJson),
        );
      } else {
        return ApiResponse.error(errNo: response.statusCode);
      }
    } catch (e) {
      return ApiResponse.error(errNo: -1);
    }
  }

  /// 登出
  static Future<void> signOut() async {
    try {
      await _googleSignIn.signOut();
    } catch (e) {
      print('Google登出失败: $e');
    }
  }

  /// 服务器登出接口
  static Future<ApiResponse<void>> logout() async {
    if (ApiService.currentMode == ApiMode.mock) {
      return GoogleAuthMock.getMockLogout();
    } else {
      return _getRealLogout();
    }
  }

  /// 删除账户接口
  static Future<ApiResponse<void>> deleteAccount() async {
    if (ApiService.currentMode == ApiMode.mock) {
      return GoogleAuthMock.getMockDeleteAccount();
    } else {
      return _getRealDeleteAccount();
    }
  }

  /// 检查是否已登录
  static Future<bool> isSignedIn() async {
    try {
      return await _googleSignIn.isSignedIn();
    } catch (e) {
      print('检查Google登录状态失败: $e');
      return false;
    }
  }

  /// 获取当前登录用户
  static Future<GoogleSignInAccount?> getCurrentUser() async {
    try {
      return await _googleSignIn.currentUser;
    } catch (e) {
      print('获取当前Google用户失败: $e');
      return null;
    }
  }

  /// 真实接口 - 服务器登出
  static Future<ApiResponse<void>> _getRealLogout() async {
    try {
      final uri = Uri.parse(ApiConfig.getFullUrl(ApiEndpoints.googleLogout));

      final response = await HttpClientService.postJson(
        uri,
        body: {
          'action': 'logout',
          'timestamp': DateTime.now().millisecondsSinceEpoch,
        },
        timeout: _defaultTimeout,
      );

      if (response.statusCode == 200) {
        final Map<String, dynamic> jsonData = json.decode(response.body);

        // 使用统一的JSON处理函数
        return ApiResponse.fromJson(
          jsonData,
          (dataJson) => null, // logout不需要返回数据
        );
      } else {
        return ApiResponse.error(errNo: response.statusCode);
      }
    } catch (e) {
      return ApiResponse.error(errNo: -1);
    }
  }

  /// 真实接口 - 删除账户
  static Future<ApiResponse<void>> _getRealDeleteAccount() async {
    try {
      final uri = Uri.parse(
        ApiConfig.getFullUrl(ApiEndpoints.googleDeleteAccount),
      );

      final response = await HttpClientService.postJson(
        uri,
        body: {
          'action': 'delete_account',
          'timestamp': DateTime.now().millisecondsSinceEpoch,
          'confirmation': true,
        },
        timeout: _defaultTimeout,
      );

      if (response.statusCode == 200) {
        final Map<String, dynamic> jsonData = json.decode(response.body);

        // 使用统一的JSON处理函数
        return ApiResponse.fromJson(
          jsonData,
          (dataJson) => null, // delete account不需要返回数据
        );
      } else {
        return ApiResponse.error(errNo: response.statusCode);
      }
    } catch (e) {
      return ApiResponse.error(errNo: -1);
    }
  }
}
