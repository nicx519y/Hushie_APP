import 'dart:convert';
import 'dart:async';
import '../models/api_response.dart';
import 'api/google_auth_service.dart';
import 'secure_storage_service.dart';

/// 认证状态枚举
enum AuthStatus {
  unknown, // 未知状态（初始化中）
  authenticated, // 已认证
  unauthenticated, // 未认证
}

/// 认证状态变化事件
class AuthStatusChangeEvent {
  final AuthStatus status;
  final GoogleAuthResponse? user;
  final DateTime timestamp;

  AuthStatusChangeEvent({required this.status, this.user, DateTime? timestamp})
    : timestamp = timestamp ?? DateTime.now();

  @override
  String toString() {
    return 'AuthStatusChangeEvent(status: $status, user: ${user?.email}, timestamp: $timestamp)';
  }
}

/// 认证服务 - 管理Token生命周期和自动刷新
class AuthService {
  static const String _accessTokenKey = 'access_token';
  static const String _refreshTokenKey = 'refresh_token';
  static const String _tokenExpiresAtKey = 'token_expires_at';
  static const String _userInfoKey = 'user_info';

  static AccessTokenResponse? _currentToken;
  static GoogleAuthResponse? _currentUser;
  static AuthStatus _currentStatus = AuthStatus.unknown;

  // 认证状态变化事件流
  static final StreamController<AuthStatusChangeEvent> _authStatusController =
      StreamController<AuthStatusChangeEvent>.broadcast();

  /// 认证状态变化事件流（供外部订阅）
  static Stream<AuthStatusChangeEvent> get authStatusChanges =>
      _authStatusController.stream;

  /// 获取当前认证状态
  static AuthStatus get currentAuthStatus => _currentStatus;

  /// 通知认证状态变化
  static void _notifyAuthStatusChange(
    AuthStatus status, {
    GoogleAuthResponse? user,
  }) {
    if (_currentStatus != status) {
      _currentStatus = status;
      final event = AuthStatusChangeEvent(status: status, user: user);
      _authStatusController.add(event);
      print('🔐 [AUTH] 认证状态变化: ${event}');
    }
  }

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

      // 第三步：保存Token和用户信息到安全存储
      await _saveTokenToSecureStorage(accessToken);
      await _saveUserToSecureStorage(googleAuth);

      _currentToken = accessToken;
      _currentUser = googleAuth;

      // 通知登录状态变化
      _notifyAuthStatusChange(AuthStatus.authenticated, user: googleAuth);

      return googleAuthResult;
    } catch (e) {
      print('Google登录流程失败: $e');
      // 通知登录失败
      _notifyAuthStatusChange(AuthStatus.unauthenticated);
      return ApiResponse.error(errNo: -1);
    }
  }

  /// 登出
  static Future<void> signOut() async {
    try {
      // 调用服务器登出接口
      await GoogleAuthService.logout();

      // 清除本地数据
      await _clearTokenFromSecureStorage();
      await _clearUserFromSecureStorage();

      _currentToken = null;
      _currentUser = null;

      // 通知登出状态变化
      _notifyAuthStatusChange(AuthStatus.unauthenticated);
    } catch (e) {
      print('登出失败: $e');
      // 即使服务器登出失败，也要清除本地数据
      await _clearTokenFromSecureStorage();
      await _clearUserFromSecureStorage();
      _currentToken = null;
      _currentUser = null;

      // 通知登出状态变化
      _notifyAuthStatusChange(AuthStatus.unauthenticated);
    }
  }

  /// 删除账户
  static Future<void> deleteAccount() async {
    try {
      // 调用服务器删除账户接口
      await GoogleAuthService.deleteAccount();

      // 清除本地数据
      await _clearTokenFromSecureStorage();
      await _clearUserFromSecureStorage();

      _currentToken = null;
      _currentUser = null;

      // 通知账户删除状态变化
      _notifyAuthStatusChange(AuthStatus.unauthenticated);
    } catch (e) {
      print('删除账户失败: $e');
      // 即使服务器删除失败，也要清除本地数据
      await _clearTokenFromSecureStorage();
      await _clearUserFromSecureStorage();
      _currentToken = null;
      _currentUser = null;

      // 通知账户删除状态变化
      _notifyAuthStatusChange(AuthStatus.unauthenticated);
      rethrow; // 重新抛出异常，让调用者处理
    }
  }

  /// 验证当前Token是否有效
  static Future<bool> isTokenValid() async {
    try {
      final token = await getAccessToken();
      return token != null && token.isNotEmpty;
    } catch (e) {
      print('验证Token失败: $e');
      return false;
    }
  }

  /// 检查是否已登录
  static Future<bool> isSignedIn() async {
    try {
      final token = await getAccessToken();
      final isValid = token != null && token.isNotEmpty;

      // 更新认证状态（如果状态未知）
      if (_currentStatus == AuthStatus.unknown) {
        _notifyAuthStatusChange(
          isValid ? AuthStatus.authenticated : AuthStatus.unauthenticated,
          user: _currentUser,
        );
      }

      return isValid;
    } catch (e) {
      print('🔐 [AUTH] isSignedIn异常: $e');
      // 通知认证状态为未知
      if (_currentStatus != AuthStatus.unauthenticated) {
        _notifyAuthStatusChange(AuthStatus.unauthenticated);
      }
      return false;
    }
  }

  /// 初始化认证状态（应用启动时调用）
  static Future<void> initializeAuthStatus() async {
    try {
      print('🔐 [AUTH] 初始化认证状态');
      await _loadTokenFromStorage();
      await _loadUserFromStorage();

      final isValid =
          _currentToken != null &&
          _currentToken!.accessToken.isNotEmpty &&
          !_currentToken!.isExpiringSoon;

      _notifyAuthStatusChange(
        isValid ? AuthStatus.authenticated : AuthStatus.unauthenticated,
        user: _currentUser,
      );

      print('🔐 [AUTH] 认证状态初始化完成: ${_currentStatus}');
    } catch (e) {
      print('🔐 [AUTH] 初始化认证状态失败: $e');
      _notifyAuthStatusChange(AuthStatus.unauthenticated);
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
    if (!force && !_currentToken!.isExpiringSoon) {
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

        await _saveTokenToSecureStorage(newToken);
        _currentToken = newToken;
        return true;
      }
    } catch (e) {
      print('Token刷新失败: $e');
    }

    // 刷新失败，清除Token
    await _clearTokenFromSecureStorage();
    _currentToken = null;
    // 通知Token失效
    _notifyAuthStatusChange(AuthStatus.unauthenticated);
    return false;
  }

  /// 从安全存储加载Token
  static Future<void> _loadTokenFromStorage() async {
    try {
      final accessToken = await SecureStorageService.getAccessToken();
      final refreshToken = await SecureStorageService.getRefreshToken();
      final expiresAtMs = await SecureStorageService.getTokenExpiresAt();

      if (accessToken != null && refreshToken != null) {
        _currentToken = AccessTokenResponse(
          accessToken: accessToken,
          refreshToken: refreshToken,
          expiresIn: 3600, // 默认1小时
          tokenType: 'Bearer',
          expiresAt: expiresAtMs != null
              ? (expiresAtMs ~/ 1000)
              : (DateTime.now().millisecondsSinceEpoch ~/ 1000) + 3600,
        );
      }
    } catch (e) {
      print('加载Token失败: $e');
    }
  }

  /// 保存Token到安全存储
  static Future<void> _saveTokenToSecureStorage(
    AccessTokenResponse token,
  ) async {
    try {
      await SecureStorageService.saveAccessToken(token.accessToken);
      await SecureStorageService.saveRefreshToken(token.refreshToken);

      await SecureStorageService.saveTokenExpiresAt(
        token.expiresAt * 1000, // 转换为毫秒
      );
    } catch (e) {
      print('保存Token失败: $e');
    }
  }

  /// 清除Token从安全存储
  static Future<void> _clearTokenFromSecureStorage() async {
    try {
      await SecureStorageService.deleteAccessToken();
      await SecureStorageService.deleteRefreshToken();
      await SecureStorageService.deleteTokenExpiresAt();
    } catch (e) {
      print('清除Token失败: $e');
    }
  }

  /// 从安全存储加载用户信息
  static Future<void> _loadUserFromStorage() async {
    try {
      final userJson = await SecureStorageService.getUserInfo();

      if (userJson != null) {
        final userMap = json.decode(userJson) as Map<String, dynamic>;
        _currentUser = GoogleAuthResponse.fromMap(userMap);
      }
    } catch (e) {
      print('加载用户信息失败: $e');
    }
  }

  /// 保存用户信息到安全存储
  static Future<void> _saveUserToSecureStorage(GoogleAuthResponse user) async {
    try {
      final userJson = json.encode(user.toMap());
      await SecureStorageService.saveUserInfo(userJson);
    } catch (e) {
      print('保存用户信息失败: $e');
    }
  }

  /// 清除用户信息从安全存储
  static Future<void> _clearUserFromSecureStorage() async {
    try {
      await SecureStorageService.deleteUserInfo();
    } catch (e) {
      print('清除用户信息失败: $e');
    }
  }

  /// 清除所有认证数据
  static Future<void> clearAllAuthData() async {
    try {
      await SecureStorageService.clearAllAuthData();
      _currentToken = null;
      _currentUser = null;

      // 通知认证数据清除
      _notifyAuthStatusChange(AuthStatus.unauthenticated);
    } catch (e) {
      print('清除所有认证数据失败: $e');
    }
  }

  /// 关闭事件流（应用退出时调用）
  static Future<void> dispose() async {
    await _authStatusController.close();
    print('🔐 [AUTH] 认证服务事件流已关闭');
  }
}
