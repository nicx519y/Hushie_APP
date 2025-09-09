import 'dart:convert';
import 'package:google_sign_in/google_sign_in.dart';
import '../../models/api_response.dart';
import '../../config/api_config.dart';
import '../http_client_service.dart';
import 'package:flutter/foundation.dart';

/// Google认证服务
class GoogleAuthService {
  static Duration get _defaultTimeout => ApiConfig.defaultTimeout;

  // 创建GoogleSignIn实例，配置服务器端认证
  static final GoogleSignIn _googleSignIn = GoogleSignIn(
    scopes: ['email', 'profile'],
    // 配置Web客户端ID，用于获取serverAuthCode
    serverClientId:
        '464599900807-jtkjnpb7ovn9m7r1gph7re0pd0q89cia.apps.googleusercontent.com',
  );

  /// Google账号登录 - 完整的OAuth 2.0流程
  static Future<ApiResponse<GoogleAuthResponse>> googleSignIn() async {
    return _getRealGoogleSignIn();
  }

  /// 用Google登录凭证获取access token
  static Future<ApiResponse<AccessTokenResponse>> getAccessToken({
    required String googleToken,
  }) async {
    return _getRealAccessToken(googleToken: googleToken);
  }

  /// 刷新Access Token
  static Future<ApiResponse<AccessTokenResponse>> refreshAccessToken({
    required String refreshToken,
  }) async {
    return _getRealRefreshToken(refreshToken: refreshToken);
  }

  /// 验证Token是否有效
  static Future<ApiResponse<TokenValidationResponse>> validateToken({
    required String accessToken,
  }) async {
    return _getRealTokenValidation(accessToken: accessToken);
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
        debugPrint('google 登录失败. googleUser is null.');
        return ApiResponse.error(errNo: -2);
      }
      debugPrint('Google用户信息: ${googleUser}');

      // 获取认证信息
      final GoogleSignInAuthentication googleAuth =
          await googleUser.authentication;

      debugPrint('Google认证信息: ${googleAuth}');

      // 在标准OAuth 2.0流程中，这里应该获取授权码
      // 但Google Sign-In Flutter插件直接返回tokens
      // 如果需要完整的OAuth流程，应该使用Web Auth或自定义OAuth实现

      final String? authorizationCode = googleAuth.serverAuthCode;
      final String? idToken = googleAuth.idToken;

      if (authorizationCode == null && idToken == null) {
        debugPrint(
          'google 授权码或者idToken为null. authorizationCode: ${authorizationCode}, idToken: ${idToken}',
        );
        return ApiResponse.error(errNo: -3);
      }

      debugPrint(
        'google 授权码或者idToken不为null. authorizationCode: ${authorizationCode}, idToken: ${idToken}',
      );

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

      debugPrint('Google登录成功: ${googleAuthResponse}');

      return ApiResponse.success(data: googleAuthResponse, errNo: 0);
    } catch (e) {
      debugPrint('Google登录失败: $e');
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
      debugPrint('🔐 [GOOGLE_AUTH] 开始刷新Token请求');
      debugPrint('🔐 [GOOGLE_AUTH] RefreshToken长度: ${refreshToken.length}');
      
      final uri = Uri.parse(
        ApiConfig.getFullUrl(ApiEndpoints.googleRefreshToken),
      );
      debugPrint('🔐 [GOOGLE_AUTH] 请求URL: $uri');

      final requestBody = {'refresh_token': refreshToken, 'grant_type': 'refresh_token'};
      debugPrint('🔐 [GOOGLE_AUTH] 请求体: ${requestBody.keys.toList()}');
      
      debugPrint('🔐 [GOOGLE_AUTH] 发送HTTP请求...');
      final response = await HttpClientService.postJson(
        uri,
        body: requestBody,
        timeout: _defaultTimeout,
      );

      debugPrint('🔐 [GOOGLE_AUTH] HTTP响应状态码: ${response.statusCode}');
      debugPrint('🔐 [GOOGLE_AUTH] HTTP响应体长度: ${response.body.length}');
      
      if (response.statusCode == 200) {
        debugPrint('🔐 [GOOGLE_AUTH] 开始解析JSON响应...');
        final Map<String, dynamic> jsonData = json.decode(response.body);
        debugPrint('🔐 [GOOGLE_AUTH] JSON解析成功，errNo: ${jsonData['errNo']}');

        final apiResponse = ApiResponse.fromJson(
          jsonData,
          (dataJson) => AccessTokenResponse.fromMap(dataJson),
        );
        debugPrint('🔐 [GOOGLE_AUTH] Token刷新API调用完成，errNo: ${apiResponse.errNo}');
        return apiResponse;
      } else {
        debugPrint('🔐 [GOOGLE_AUTH] HTTP请求失败，状态码: ${response.statusCode}');
        debugPrint('🔐 [GOOGLE_AUTH] 错误响应体: ${response.body}');
        return ApiResponse.error(errNo: response.statusCode);
      }
    } catch (e) {
      debugPrint('🔐 [GOOGLE_AUTH] Token刷新请求异常: $e');
      debugPrint('🔐 [GOOGLE_AUTH] 异常类型: ${e.runtimeType}');
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
      debugPrint('Google登出失败: $e');
    }
  }

  /// 服务器登出接口
  static Future<ApiResponse<void>> logout() async {
    return _getRealLogout();
  }

  /// 删除账户接口
  static Future<ApiResponse<void>> deleteAccount() async {
    return _getRealDeleteAccount();
  }

  /// 检查是否已登录
  static Future<bool> isSignedIn() async {
    try {
      return await _googleSignIn.isSignedIn();
    } catch (e) {
      debugPrint('检查Google登录状态失败: $e');
      return false;
    }
  }

  /// 获取当前登录用户
  static Future<GoogleSignInAccount?> getCurrentUser() async {
    try {
      return await _googleSignIn.currentUser;
    } catch (e) {
      debugPrint('获取当前Google用户失败: $e');
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
