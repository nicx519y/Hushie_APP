import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'api_service.dart';

/// 认证服务 - 管理账户相关操作
class AuthService {
  static const FlutterSecureStorage _storage = FlutterSecureStorage();

  // 存储键名
  static const String _accessTokenKey = 'access_token';
  static const String _refreshTokenKey = 'refresh_token';
  static const String _tokenExpiryKey = 'token_expiry';
  static const String _userIdKey = 'user_id';
  static const String _userEmailKey = 'user_email';
  static const String _userDisplayNameKey = 'user_display_name';
  static const String _userPhotoUrlKey = 'user_photo_url';

  /// Google登录流程
  /// 包含：Google账户登录 -> 服务器获取accessToken -> 存储到本地安全存储
  static Future<AuthResult> googleLogin() async {
    try {
      // 1. Google账户登录
      final googleResponse = await ApiService.googleSignIn();
      if (googleResponse.errNo != 0) {
        return AuthResult.error(
          errNo: googleResponse.errNo,
          message: 'Google登录失败',
        );
      }

      final userInfo = googleResponse.data!;

      // 2. 到服务器获取accessToken
      final tokenResponse = await ApiService.getGoogleAccessToken(
        googleToken: userInfo.idToken,
      );

      if (tokenResponse.errNo != 0) {
        return AuthResult.error(
          errNo: tokenResponse.errNo,
          message: '获取access token失败',
        );
      }

      final tokenInfo = tokenResponse.data!;

      // 3. 存储到本地安全存储
      await _saveAuthData(
        accessToken: tokenInfo.accessToken,
        refreshToken: tokenInfo.refreshToken,
        expiresIn: tokenInfo.expiresIn,
        userId: userInfo.userId,
        email: userInfo.email,
        displayName: userInfo.displayName,
        photoUrl: userInfo.photoUrl,
      );

      // 转换为本地类型
      final localUserInfo = UserInfo(
        userId: userInfo.userId,
        email: userInfo.email,
        displayName: userInfo.displayName,
        photoUrl: userInfo.photoUrl,
      );

      final localTokenInfo = AccessTokenInfo(
        accessToken: tokenInfo.accessToken,
        refreshToken: tokenInfo.refreshToken,
        expiresIn: tokenInfo.expiresIn,
        tokenType: tokenInfo.tokenType,
      );

      return AuthResult.success(
        userInfo: localUserInfo,
        tokenInfo: localTokenInfo,
      );
    } catch (e) {
      return AuthResult.error(errNo: -1, message: '登录流程异常: $e');
    }
  }

  /// Google登出流程
  /// 包含：请求服务器logout接口 -> Google账户登出 -> 清除本地安全存储
  static Future<AuthResult> googleLogout() async {
    try {
      // 1. 请求服务器logout接口
      final logoutResponse = await ApiService.googleLogout();
      if (logoutResponse.errNo != 0) {
        print('服务器登出失败: 错误码 ${logoutResponse.errNo}');
      }

      // 2. Google账户登出
      await ApiService.googleSignOut();

      // 3. 清除本地安全存储
      await _clearAuthData();

      return AuthResult.success(message: '登出成功');
    } catch (e) {
      print('登出失败: $e');
      // 即使服务器登出失败，也要清除本地数据
      await _clearAuthData();
      return AuthResult.error(errNo: -1, message: '登出失败: $e');
    }
  }

  /// Google账户删除流程
  /// 包含：Google账户登出 -> 请求服务器删除账户接口 -> 清除本地安全存储
  static Future<AuthResult> googleAccountDelete() async {
    try {
      // 1. Google账户登出
      await ApiService.googleSignOut();

      // 2. 请求服务器删除账户接口
      final deleteResponse = await ApiService.googleDeleteAccount();
      if (deleteResponse.errNo != 0) {
        return AuthResult.error(
          errNo: deleteResponse.errNo,
          message: '服务器删除账户失败: 错误码 ${deleteResponse.errNo}',
        );
      }

      // 3. 清除本地安全存储
      await _clearAuthData();

      return AuthResult.success(message: '账户已成功删除');
    } catch (e) {
      return AuthResult.error(errNo: -1, message: '删除账户失败: $e');
    }
  }

  /// 获取access token
  static Future<String?> getAccessToken() async {
    try {
      final token = await _storage.read(key: _accessTokenKey);
      if (token == null) return null;

      // 检查token是否过期
      final expiry = await _storage.read(key: _tokenExpiryKey);
      if (expiry != null) {
        final expiryTime = int.tryParse(expiry) ?? 0;
        final currentTime = DateTime.now().millisecondsSinceEpoch ~/ 1000;

        if (currentTime >= expiryTime) {
          // Token已过期，尝试刷新
          final refreshed = await _refreshToken();
          if (refreshed) {
            return await _storage.read(key: _accessTokenKey);
          } else {
            // 刷新失败，清除过期数据
            await _clearAuthData();
            return null;
          }
        }
      }

      return token;
    } catch (e) {
      print('获取access token失败: $e');
      return null;
    }
  }

  /// 获取refresh token
  static Future<String?> getRefreshToken() async {
    try {
      return await _storage.read(key: _refreshTokenKey);
    } catch (e) {
      print('获取refresh token失败: $e');
      return null;
    }
  }

  /// 获取用户信息
  static Future<UserInfo?> getUserInfo() async {
    try {
      final userId = await _storage.read(key: _userIdKey);
      final email = await _storage.read(key: _userEmailKey);
      final displayName = await _storage.read(key: _userDisplayNameKey);
      final photoUrl = await _storage.read(key: _userPhotoUrlKey);

      if (userId == null || email == null) return null;

      return UserInfo(
        userId: userId,
        email: email,
        displayName: displayName ?? '',
        photoUrl: photoUrl,
      );
    } catch (e) {
      print('获取用户信息失败: $e');
      return null;
    }
  }

  /// 检查是否已登录
  static Future<bool> isLoggedIn() async {
    try {
      final token = await getAccessToken();
      return token != null;
    } catch (e) {
      return false;
    }
  }

  /// 刷新token
  static Future<bool> _refreshToken() async {
    try {
      final refreshToken = await getRefreshToken();
      if (refreshToken == null) return false;

      // TODO: 实现token刷新API调用
      // final response = await ApiService.refreshToken(refreshToken: refreshToken);
      // if (response.errNo == 0) {
      //   final newTokenInfo = response.data!;
      //   await _updateTokens(
      //         accessToken: newTokenInfo.accessToken,
      //         refreshToken: newTokenInfo.refreshToken,
      //         expiresIn: newTokenInfo.expiresIn,
      //       );
      //   return true;
      // }

      return false;
    } catch (e) {
      print('刷新token失败: $e');
      return false;
    }
  }

  /// 保存认证数据到本地
  static Future<void> _saveAuthData({
    required String accessToken,
    required String refreshToken,
    required int expiresIn,
    required String userId,
    required String email,
    required String displayName,
    String? photoUrl,
  }) async {
    try {
      final currentTime = DateTime.now().millisecondsSinceEpoch ~/ 1000;
      final expiryTime = currentTime + expiresIn;

      await Future.wait([
        _storage.write(key: _accessTokenKey, value: accessToken),
        _storage.write(key: _refreshTokenKey, value: refreshToken),
        _storage.write(key: _tokenExpiryKey, value: expiryTime.toString()),
        _storage.write(key: _userIdKey, value: userId),
        _storage.write(key: _userEmailKey, value: email),
        _storage.write(key: _userDisplayNameKey, value: displayName),
        if (photoUrl != null)
          _storage.write(key: _userPhotoUrlKey, value: photoUrl),
      ]);

      print('认证数据已保存到本地');
    } catch (e) {
      print('保存认证数据失败: $e');
    }
  }

  /// 更新token信息
  static Future<void> _updateTokens({
    required String accessToken,
    required String refreshToken,
    required int expiresIn,
  }) async {
    try {
      final currentTime = DateTime.now().millisecondsSinceEpoch ~/ 1000;
      final expiryTime = currentTime + expiresIn;

      await Future.wait([
        _storage.write(key: _accessTokenKey, value: accessToken),
        _storage.write(key: _refreshTokenKey, value: refreshToken),
        _storage.write(key: _tokenExpiryKey, value: expiryTime.toString()),
      ]);

      print('Token信息已更新');
    } catch (e) {
      print('更新token信息失败: $e');
    }
  }

  /// 清除本地认证数据
  static Future<void> _clearAuthData() async {
    try {
      await Future.wait([
        _storage.delete(key: _accessTokenKey),
        _storage.delete(key: _refreshTokenKey),
        _storage.delete(key: _tokenExpiryKey),
        _storage.delete(key: _userIdKey),
        _storage.delete(key: _userEmailKey),
        _storage.delete(key: _userDisplayNameKey),
        _storage.delete(key: _userPhotoUrlKey),
      ]);

      print('本地认证数据已清除');
    } catch (e) {
      print('清除认证数据失败: $e');
    }
  }
}

/// 认证结果
class AuthResult {
  final bool success;
  final int errNo;
  final String? message;
  final UserInfo? userInfo;
  final AccessTokenInfo? tokenInfo;

  AuthResult.success({this.userInfo, this.tokenInfo, this.message})
    : success = true,
      errNo = 0;

  AuthResult.error({required this.errNo, required this.message})
    : success = false,
      userInfo = null,
      tokenInfo = null;

  @override
  String toString() {
    if (success) {
      return 'AuthResult.success(message: $message)';
    } else {
      return 'AuthResult.error(errNo: $errNo, message: $message)';
    }
  }
}

/// 用户信息
class UserInfo {
  final String userId;
  final String email;
  final String displayName;
  final String? photoUrl;

  UserInfo({
    required this.userId,
    required this.email,
    required this.displayName,
    this.photoUrl,
  });

  @override
  String toString() {
    return 'UserInfo(userId: $userId, email: $email, displayName: $displayName)';
  }
}

/// Access Token信息
class AccessTokenInfo {
  final String accessToken;
  final String refreshToken;
  final int expiresIn;
  final String tokenType;

  AccessTokenInfo({
    required this.accessToken,
    required this.refreshToken,
    required this.expiresIn,
    required this.tokenType,
  });

  @override
  String toString() {
    return 'AccessTokenInfo(expiresIn: $expiresIn, tokenType: $tokenType)';
  }
}
