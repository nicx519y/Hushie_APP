import 'dart:math';
import '../../data/mock_data.dart';
import '../../models/api_response.dart';

/// Google认证接口的Mock数据
class GoogleAuthMock {
  /// 获取Mock Google登录数据
  static Future<ApiResponse<GoogleAuthResponse>> getMockGoogleSignIn() async {
    try {
      // 模拟网络延迟
      await MockData.simulateNetworkDelay(Random().nextInt(500) + 200);

      // Mock Google登录数据
      final googleAuthResponse = GoogleAuthResponse(
        userId: 'google_${Random().nextInt(1000000)}',
        email: 'user${Random().nextInt(1000)}@gmail.com',
        displayName: 'User ${Random().nextInt(1000)}',
        photoUrl: 'https://via.placeholder.com/150',
        idToken: 'mock_google_id_token_${Random().nextInt(1000000)}',
      );

      // 随机模拟一些错误情况用于测试
      if (Random().nextDouble() < 0.05) {
        // 5% 概率失败
        return ApiResponse.error(errNo: 500);
      }

      return ApiResponse.success(data: googleAuthResponse, errNo: 0);
    } catch (e) {
      return ApiResponse.error(errNo: 500);
    }
  }

  /// 获取Mock Access Token数据
  static Future<ApiResponse<AccessTokenResponse>> getMockAccessToken({
    required String googleToken,
  }) async {
    try {
      // 模拟网络延迟
      await MockData.simulateNetworkDelay(Random().nextInt(300) + 100);

      // Mock Access Token数据
      final accessTokenResponse = AccessTokenResponse(
        accessToken: 'mock_access_token_${Random().nextInt(1000000)}',
        refreshToken: 'mock_refresh_token_${Random().nextInt(1000000)}',
        expiresIn: 3600, // 1小时
        tokenType: 'Bearer',
      );

      // 随机模拟一些错误情况用于测试
      if (Random().nextDouble() < 0.05) {
        // 5% 概率失败
        return ApiResponse.error(errNo: 500);
      }

      return ApiResponse.success(data: accessTokenResponse, errNo: 0);
    } catch (e) {
      return ApiResponse.error(errNo: 500);
    }
  }

  /// 获取Mock登出数据
  static Future<ApiResponse<void>> getMockLogout() async {
    try {
      // 模拟网络延迟
      await MockData.simulateNetworkDelay(Random().nextInt(200) + 100);

      // 随机模拟一些错误情况用于测试
      if (Random().nextDouble() < 0.05) {
        // 5% 概率失败
        return ApiResponse.error(errNo: 500);
      }

      return ApiResponse.success(data: null, errNo: 0);
    } catch (e) {
      return ApiResponse.error(errNo: 500);
    }
  }

  /// 获取Mock删除账户数据
  static Future<ApiResponse<void>> getMockDeleteAccount() async {
    try {
      // 模拟网络延迟
      await MockData.simulateNetworkDelay(Random().nextInt(300) + 200);

      // 随机模拟一些错误情况用于测试
      if (Random().nextDouble() < 0.05) {
        // 5% 概率失败
        return ApiResponse.error(errNo: 500);
      }

      return ApiResponse.success(data: null, errNo: 0);
    } catch (e) {
      return ApiResponse.error(errNo: 500);
    }
  }
}

/// Google认证响应数据
class GoogleAuthResponse {
  final String userId;
  final String email;
  final String displayName;
  final String? photoUrl;
  final String idToken;

  GoogleAuthResponse({
    required this.userId,
    required this.email,
    required this.displayName,
    this.photoUrl,
    required this.idToken,
  });

  factory GoogleAuthResponse.fromMap(Map<String, dynamic> map) {
    return GoogleAuthResponse(
      userId: map['user_id'] ?? '',
      email: map['email'] ?? '',
      displayName: map['display_name'] ?? '',
      photoUrl: map['photo_url'],
      idToken: map['id_token'] ?? '',
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'user_id': userId,
      'email': email,
      'display_name': displayName,
      'photo_url': photoUrl,
      'id_token': idToken,
    };
  }
}

/// Access Token响应数据
class AccessTokenResponse {
  final String accessToken;
  final String refreshToken;
  final int expiresIn;
  final String tokenType;

  AccessTokenResponse({
    required this.accessToken,
    required this.refreshToken,
    required this.expiresIn,
    required this.tokenType,
  });

  factory AccessTokenResponse.fromMap(Map<String, dynamic> map) {
    return AccessTokenResponse(
      accessToken: map['access_token'] ?? '',
      refreshToken: map['refresh_token'] ?? '',
      expiresIn: map['expires_in'] ?? 0,
      tokenType: map['token_type'] ?? 'Bearer',
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'access_token': accessToken,
      'refresh_token': refreshToken,
      'expires_in': expiresIn,
      'token_type': tokenType,
    };
  }
}
