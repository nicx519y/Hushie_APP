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
        authCode: 'mock_authorization_code_${Random().nextInt(1000000)}',
        authType: 'authorization_code',
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
  final String authCode; // 授权码或idToken
  final String authType; // 'authorization_code' 或 'id_token'

  GoogleAuthResponse({
    required this.userId,
    required this.email,
    required this.displayName,
    this.photoUrl,
    required this.authCode,
    required this.authType,
  });

  factory GoogleAuthResponse.fromMap(Map<String, dynamic> map) {
    return GoogleAuthResponse(
      userId: map['user_id'] ?? '',
      email: map['email'] ?? '',
      displayName: map['display_name'] ?? '',
      photoUrl: map['photo_url'],
      authCode: map['auth_code'] ?? map['id_token'] ?? '',
      authType: map['auth_type'] ?? 'id_token',
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'user_id': userId,
      'email': email,
      'display_name': displayName,
      'photo_url': photoUrl,
      'auth_code': authCode,
      'auth_type': authType,
    };
  }
}

/// Access Token响应数据
class AccessTokenResponse {
  final String accessToken;
  final String refreshToken;
  final int expiresIn;
  final String tokenType;
  final DateTime? expiresAt; // 过期时间

  AccessTokenResponse({
    required this.accessToken,
    required this.refreshToken,
    required this.expiresIn,
    required this.tokenType,
    this.expiresAt,
  });

  factory AccessTokenResponse.fromMap(Map<String, dynamic> map) {
    final expiresIn = map['expires_in'] ?? 0;
    return AccessTokenResponse(
      accessToken: map['access_token'] ?? '',
      refreshToken: map['refresh_token'] ?? '',
      expiresIn: expiresIn,
      tokenType: map['token_type'] ?? 'Bearer',
      expiresAt: map['expires_at'] != null
          ? DateTime.fromMillisecondsSinceEpoch(map['expires_at'] * 1000)
          : DateTime.now().add(Duration(seconds: expiresIn)),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'access_token': accessToken,
      'refresh_token': refreshToken,
      'expires_in': expiresIn,
      'token_type': tokenType,
      'expires_at': expiresAt?.millisecondsSinceEpoch != null
          ? (expiresAt!.millisecondsSinceEpoch / 1000).round()
          : null,
    };
  }

  /// 检查Token是否即将过期（5分钟内）
  bool get isExpiringSoon {
    if (expiresAt == null) return false;
    return DateTime.now().add(const Duration(minutes: 5)).isAfter(expiresAt!);
  }

  /// 检查Token是否已过期
  bool get isExpired {
    if (expiresAt == null) return false;
    return DateTime.now().isAfter(expiresAt!);
  }
}

/// Token验证响应数据
class TokenValidationResponse {
  final bool isValid;
  final DateTime? expiresAt;
  final String? userId;
  final String? email;
  final List<String>? scopes;

  TokenValidationResponse({
    required this.isValid,
    this.expiresAt,
    this.userId,
    this.email,
    this.scopes,
  });

  factory TokenValidationResponse.fromMap(Map<String, dynamic> map) {
    return TokenValidationResponse(
      isValid: map['is_valid'] ?? false,
      expiresAt: map['expires_at'] != null
          ? DateTime.fromMillisecondsSinceEpoch(map['expires_at'] * 1000)
          : null,
      userId: map['user_id'],
      email: map['email'],
      scopes: map['scopes'] != null ? List<String>.from(map['scopes']) : null,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'is_valid': isValid,
      'expires_at': expiresAt?.millisecondsSinceEpoch != null
          ? (expiresAt!.millisecondsSinceEpoch / 1000).round()
          : null,
      'user_id': userId,
      'email': email,
      'scopes': scopes,
    };
  }
}
