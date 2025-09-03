import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/api_response.dart';
import 'api/google_auth_service.dart';
import '../services/mock/google_auth_mock.dart';

/// 认证服务 - 管理Token生命周期和自动刷新
class AuthService {
  static const String _accessTokenKey = 'access_token';
  static const String _refreshTokenKey = 'refresh_token';
  static const String _tokenExpiresAtKey = 'token_expires_at';
  static const String _userInfoKey = 'user_info';

  static AccessTokenResponse? _currentToken;
  static GoogleAuthResponse? _currentUser;

  /// 获取当前访问Token
  static Future<String?> getAccessToken() async {
    if (_currentToken != null &&
        _currentToken!.accessToken.isNotEmpty &&
        !_currentToken!.isExpiringSoon) {
      return _currentToken!.accessToken;
    }
    await _loadTokenFromStorage();

    if (_currentToken == null) {
      return null;
    }

    if (_currentToken!.isExpiringSoon) {
      final refreshed = await _refreshTokenIfNeeded();
      if (!refreshed) {
        return null;
      } else {
        return _currentToken!.accessToken;
      }
    }

    return _currentToken!.accessToken;
  }

  /// 获取当前用户信息
  static Future<GoogleAuthResponse?> getCurrentUser() async {
    if (_currentUser != null) {
      return _currentUser;
    }

    await _loadUserFromStorage();
    return _currentUser;
  }

  /// 执行Google登录流程
  static Future<ApiResponse<GoogleAuthResponse>> signInWithGoogle() async {
    try {
      // 第一步：获取Google认证信息（授权码或idToken）
      final googleAuthResult = await GoogleAuthService.googleSignIn();

      if (googleAuthResult.errNo != 0 || googleAuthResult.data == null) {
        return googleAuthResult;
      }

      final googleAuth = googleAuthResult.data!;

      // 第二步：用Google认证信息换取服务器Token
      final tokenResult = await GoogleAuthService.getAccessToken(
        googleToken: googleAuth.authCode,
      );

      if (tokenResult.errNo != 0 || tokenResult.data == null) {
        return ApiResponse.error(errNo: tokenResult.errNo);
      }

      final accessToken = tokenResult.data!;

      // 第三步：保存Token和用户信息
      await _saveTokenToStorage(accessToken);
      await _saveUserToStorage(googleAuth);

      _currentToken = accessToken;
      _currentUser = googleAuth;

      return googleAuthResult;
    } catch (e) {
      print('Google登录流程失败: $e');
      return ApiResponse.error(errNo: -1);
    }
  }

  /// 登出
  static Future<void> signOut() async {
    try {
      // 调用服务器登出接口
      await GoogleAuthService.logout();

      // 清除本地数据
      await _clearTokenFromStorage();
      await _clearUserFromStorage();

      _currentToken = null;
      _currentUser = null;
    } catch (e) {
      print('登出失败: $e');
      // 即使服务器登出失败，也要清除本地数据
      await _clearTokenFromStorage();
      await _clearUserFromStorage();
      _currentToken = null;
      _currentUser = null;
    }
  }

  /// 验证当前Token是否有效
  static Future<bool> validateCurrentToken() async {
    final token = await getAccessToken();
    if (token == null) return false;

    try {
      final result = await GoogleAuthService.validateToken(accessToken: token);
      return result.errNo == 0 && result.data?.isValid == true;
    } catch (e) {
      print('Token验证失败: $e');
      return false;
    }
  }

  /// 检查是否已登录
  static Future<bool> isSignedIn() async {
    print('🔐 [AUTH] 开始检查登录状态');
    try {
      final token = await getAccessToken();
      print(
        '🔐 [AUTH] getAccessToken完成: ${token != null ? "有token" : "无token"}',
      );
      if (token == null) {
        print('🔐 [AUTH] 无token，返回false');
        return false;
      }

      print('🔐 [AUTH] 开始验证token');
      final isValid = await validateCurrentToken();
      print('🔐 [AUTH] token验证完成: $isValid');
      return isValid;
    } catch (e) {
      print('🔐 [AUTH] isSignedIn异常: $e');
      return false;
    }
  }

  /// 强制刷新Token
  static Future<bool> refreshToken() async {
    return await _refreshTokenIfNeeded(force: true);
  }

  /// 内部方法：刷新Token（如果需要）
  static Future<bool> _refreshTokenIfNeeded({bool force = false}) async {
    if (_currentToken == null) {
      await _loadTokenFromStorage();
    }

    if (_currentToken == null || _currentToken!.refreshToken.isEmpty) {
      return false;
    }

    // 检查是否需要刷新
    if (!force && !_currentToken!.isExpiringSoon && !_currentToken!.isExpired) {
      return true; // 不需要刷新
    }

    try {
      final result = await GoogleAuthService.refreshAccessToken(
        refreshToken: _currentToken!.refreshToken,
      );

      if (result.errNo == 0 && result.data != null) {
        var newToken = result.data!;

        // 保留原有的refresh token（如果新的为空）
        if (newToken.refreshToken.isEmpty && _currentToken != null) {
          newToken = AccessTokenResponse(
            accessToken: newToken.accessToken,
            refreshToken: _currentToken!.refreshToken,
            expiresIn: newToken.expiresIn,
            tokenType: newToken.tokenType,
            expiresAt: newToken.expiresAt,
          );
        }

        await _saveTokenToStorage(newToken);
        _currentToken = newToken;
        return true;
      }
    } catch (e) {
      print('Token刷新失败: $e');
    }

    // 刷新失败，清除Token
    await _clearTokenFromStorage();
    _currentToken = null;
    return false;
  }

  /// 从本地存储加载Token
  static Future<void> _loadTokenFromStorage() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final accessToken = prefs.getString(_accessTokenKey);
      final refreshToken = prefs.getString(_refreshTokenKey);
      final expiresAtMs = prefs.getInt(_tokenExpiresAtKey);

      if (accessToken != null && refreshToken != null) {
        _currentToken = AccessTokenResponse(
          accessToken: accessToken,
          refreshToken: refreshToken,
          expiresIn: 3600, // 默认1小时
          tokenType: 'Bearer',
          expiresAt: expiresAtMs != null
              ? DateTime.fromMillisecondsSinceEpoch(expiresAtMs)
              : null,
        );
      }
    } catch (e) {
      print('加载Token失败: $e');
    }
  }

  /// 保存Token到本地存储
  static Future<void> _saveTokenToStorage(AccessTokenResponse token) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_accessTokenKey, token.accessToken);
      await prefs.setString(_refreshTokenKey, token.refreshToken);

      if (token.expiresAt != null) {
        await prefs.setInt(
          _tokenExpiresAtKey,
          token.expiresAt!.millisecondsSinceEpoch,
        );
      }
    } catch (e) {
      print('保存Token失败: $e');
    }
  }

  /// 清除Token从本地存储
  static Future<void> _clearTokenFromStorage() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_accessTokenKey);
      await prefs.remove(_refreshTokenKey);
      await prefs.remove(_tokenExpiresAtKey);
    } catch (e) {
      print('清除Token失败: $e');
    }
  }

  /// 从本地存储加载用户信息
  static Future<void> _loadUserFromStorage() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final userJson = prefs.getString(_userInfoKey);

      if (userJson != null) {
        final userMap = json.decode(userJson) as Map<String, dynamic>;
        _currentUser = GoogleAuthResponse.fromMap(userMap);
      }
    } catch (e) {
      print('加载用户信息失败: $e');
    }
  }

  /// 保存用户信息到本地存储
  static Future<void> _saveUserToStorage(GoogleAuthResponse user) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final userJson = json.encode(user.toMap());
      await prefs.setString(_userInfoKey, userJson);
    } catch (e) {
      print('保存用户信息失败: $e');
    }
  }

  /// 清除用户信息从本地存储
  static Future<void> _clearUserFromStorage() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_userInfoKey);
    } catch (e) {
      print('清除用户信息失败: $e');
    }
  }

  /// 获取带有认证头的请求头
  static Future<Map<String, String>> getAuthHeaders() async {
    final token = await getAccessToken();
    final headers = <String, String>{
      'Content-Type': 'application/json',
      'Accept': 'application/json',
    };

    if (token != null) {
      headers['Authorization'] = 'Bearer $token';
    }

    return headers;
  }
}
