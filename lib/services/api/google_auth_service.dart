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

  // 创建GoogleSignIn实例，配置服务器端认证
  static final GoogleSignIn _googleSignIn = GoogleSignIn(
    scopes: ['email', 'profile'],
    // 如果需要服务器端认证，应该配置 serverClientId
    // serverClientId: 'your-server-client-id.googleusercontent.com',
  );

  /// Google账号登录 - 完整的OAuth 2.0流程
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

  /// 刷新Access Token
  static Future<ApiResponse<AccessTokenResponse>> refreshAccessToken({
    required String refreshToken,
  }) async {
    if (ApiService.currentMode == ApiMode.mock) {
      // Mock模式下模拟刷新Token
      return GoogleAuthMock.getMockAccessToken(googleToken: refreshToken);
    } else {
      return _getRealRefreshToken(refreshToken: refreshToken);
    }
  }

  /// 验证Token是否有效
  static Future<ApiResponse<TokenValidationResponse>> validateToken({
    required String accessToken,
  }) async {
    if (ApiService.currentMode == ApiMode.mock) {
      // Mock模式下总是返回有效
      return ApiResponse.success(
        data: TokenValidationResponse(
          isValid: true,
          expiresAt: DateTime.now().add(const Duration(hours: 1)),
          userId: 'mock_user_id',
          email: 'mock@example.com',
        ),
        errNo: 0,
      );
    } else {
      return _getRealTokenValidation(accessToken: accessToken);
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

      // 在标准OAuth 2.0流程中，这里应该获取授权码
      // 但Google Sign-In Flutter插件直接返回tokens
      // 如果需要完整的OAuth流程，应该使用Web Auth或自定义OAuth实现

      final String? authorizationCode = googleAuth.serverAuthCode;
      final String? idToken = googleAuth.idToken;

      if (authorizationCode == null && idToken == null) {
        return ApiResponse.error(errNo: -3);
      }

      // 构建响应数据，优先使用授权码
      final googleAuthResponse = GoogleAuthResponse(
        userId: googleUser.id,
        email: googleUser.email,
        displayName: googleUser.displayName ?? '',
        photoUrl: googleUser.photoUrl,
        // 优先使用授权码，如果没有则使用idToken
        authCode: authorizationCode ?? idToken ?? '',
        authType: authorizationCode != null ? 'authorization_code' : 'id_token',
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
        body: {
          'google_token': googleToken,
          'grant_type': 'google_token', // 或 'authorization_code'
        },
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

  /// 真实接口 - 刷新Token
  static Future<ApiResponse<AccessTokenResponse>> _getRealRefreshToken({
    required String refreshToken,
  }) async {
    try {
      final uri = Uri.parse(
        ApiConfig.getFullUrl(ApiEndpoints.googleRefreshToken),
      );

      final response = await HttpClientService.postJson(
        uri,
        body: {'refresh_token': refreshToken, 'grant_type': 'refresh_token'},
        timeout: _defaultTimeout,
      );

      if (response.statusCode == 200) {
        final Map<String, dynamic> jsonData = json.decode(response.body);

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

  /// 真实接口 - 验证Token
  static Future<ApiResponse<TokenValidationResponse>> _getRealTokenValidation({
    required String accessToken,
  }) async {
    try {
      final uri = Uri.parse(
        ApiConfig.getFullUrl(ApiEndpoints.googleTokenValidate),
      );

      final response = await HttpClientService.postJson(
        uri,
        body: {'access_token': accessToken},
        timeout: _defaultTimeout,
        headers: ApiConfig.getAuthHeaders(token: accessToken),
      );

      if (response.statusCode == 200) {
        final Map<String, dynamic> jsonData = json.decode(response.body);

        return ApiResponse.fromJson(
          jsonData,
          (dataJson) => TokenValidationResponse.fromMap(dataJson),
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
