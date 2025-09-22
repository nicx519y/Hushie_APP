import 'dart:convert';
import 'dart:async';
import '../models/api_response.dart';
import 'api/google_auth_service.dart';
import 'secure_storage_service.dart';
import 'package:flutter/foundation.dart';

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

/// 认证管理器 - 单例模式，管理Token生命周期和自动刷新
class AuthManager {
  static final AuthManager _instance = AuthManager._internal();
  static AuthManager get instance => _instance;
  
  AuthManager._internal();

  AccessTokenResponse? _currentToken;
  GoogleAuthResponse? _currentUser;
  AuthStatus _currentStatus = AuthStatus.unknown;
  Future<bool>? _refreshFuture;
  Timer? _refreshTimer;
  bool _isInitialized = false;

  // 认证状态变化事件流
  final StreamController<AuthStatusChangeEvent> _authStatusController =
      StreamController<AuthStatusChangeEvent>.broadcast();

  /// 认证状态变化事件流（供外部订阅）
  Stream<AuthStatusChangeEvent> get authStatusChanges =>
      _authStatusController.stream;

  /// 获取当前认证状态
  AuthStatus get currentAuthStatus => _currentStatus;

  /// 通知认证状态变化
  void _notifyAuthStatusChange(
    AuthStatus status, {
    GoogleAuthResponse? user,
  }) {
    if (_currentStatus != status) {
      _currentStatus = status;
      final event = AuthStatusChangeEvent(status: status, user: user);
      _authStatusController.add(event);
      debugPrint('🔐 [AUTH] 认证状态变化: ${event}');
    }
  }

  /// 初始化认证管理器
  Future<void> initialize() async {
    if (_isInitialized) {
      debugPrint('🔐 [AUTH] AuthManager已经初始化，跳过');
      return;
    }

    try {
      debugPrint('🔐 [AUTH] 开始初始化AuthManager');
      
      // 加载存储的Token和用户信息
      await _loadTokenFromStorage();
      
      // 检查登录状态并刷新Token
      final isValid = await _refreshTokenIfNeeded(force: false);
      
      // 设置认证状态
      _notifyAuthStatusChange(
        isValid ? AuthStatus.authenticated : AuthStatus.unauthenticated,
        user: _currentUser,
      );
      
      // 启动定时刷新
      _startTokenRefreshTimer();
      
      _isInitialized = true;
      debugPrint('🔐 [AUTH] AuthManager初始化完成: ${_currentStatus}');
    } catch (e) {
      debugPrint('🔐 [AUTH] 初始化AuthManager失败: $e');
      _notifyAuthStatusChange(AuthStatus.unauthenticated);
      _isInitialized = true; // 即使失败也标记为已初始化
    }
  }

  /// 启动Token定时刷新
  void _startTokenRefreshTimer() {
    // 取消现有定时器
    _refreshTimer?.cancel();
    
    // 设置定时器，每30分钟检查一次Token是否需要刷新
    _refreshTimer = Timer.periodic(const Duration(minutes: 30), (timer) async {
      debugPrint('🔐 [AUTH] 定时检查Token状态');
      try {
        final refreshed = await _refreshTokenIfNeeded(force: false);
        if (!refreshed && _currentStatus == AuthStatus.authenticated) {
          debugPrint('🔐 [AUTH] Token刷新失败，更新认证状态为未认证');
          _notifyAuthStatusChange(AuthStatus.unauthenticated);
        }
      } catch (e) {
        debugPrint('🔐 [AUTH] 定时刷新Token异常: $e');
      }
    });
    
    debugPrint('🔐 [AUTH] Token定时刷新器已启动');
  }
  /// 获取当前访问Token
  Future<String?> getAccessToken() async {
    // 先从内存中检查
    if (_currentToken != null &&
        _currentToken!.accessToken.isNotEmpty &&
        !_currentToken!.isExpiringSoon) {
      return _currentToken!.accessToken;
    }

    // 从存储中加载
    await _loadTokenFromStorage();

    if (_currentToken == null) {
      return null;
    }

    // 检查是否需要刷新
    if (_currentToken!.isExpiringSoon) {
      final refreshSuccess = await _refreshTokenIfNeeded();
      if (!refreshSuccess) {
        return null; // 刷新失败
      }
    }

    return _currentToken!.accessToken;
  }

  /// 获取当前用户信息
  Future<GoogleAuthResponse?> getCurrentUser() async {
    if (_currentUser != null) {
      return _currentUser;
    }

    // 用户信息已在_loadTokenFromStorage中一起加载
    await _loadTokenFromStorage();
    return _currentUser;
  }

  /// 执行Google登录流程
  Future<ApiResponse<GoogleAuthResponse>> signInWithGoogle() async {
    try {
      // 第一步：获取Google认证信息（授权码或idToken）
      final googleAuthResult = await GoogleAuthService.googleSignIn();

      if (googleAuthResult.errNo != 0 || googleAuthResult.data == null) {
        debugPrint('Google登录失败: googleAuthResult.errNo: ${googleAuthResult.errNo}');
        _notifyAuthStatusChange(AuthStatus.unauthenticated);
        return googleAuthResult;
      }

      final googleAuth = googleAuthResult.data!;

      // 第二步：用Google认证信息换取业务服务器Token
      final tokenResult = await GoogleAuthService.getAccessToken(
        googleToken: googleAuth.authCode,
      );

      if (tokenResult.errNo != 0 || tokenResult.data == null) {
        debugPrint('Google登录失败: tokenResult.errNo: ${tokenResult.errNo}');
        _notifyAuthStatusChange(AuthStatus.unauthenticated);
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
      debugPrint('Google登录流程失败: $e');
      // 通知登录失败
      _notifyAuthStatusChange(AuthStatus.unauthenticated);
      return ApiResponse.error(errNo: -1);
    }
  }

  /// 登出
  Future<void> signOut() async {
    try {
      // 停止定时器
      _refreshTimer?.cancel();
      
      // 调用服务器登出接口
      await GoogleAuthService.logout();

      // 清除本地数据
      await SecureStorageService.clearAll();

      _currentToken = null;
      _currentUser = null;

      // 通知登出状态变化
      _notifyAuthStatusChange(AuthStatus.unauthenticated);
    } catch (e) {
      debugPrint('登出失败，但是强行登出: $e');
      // 即使服务器登出失败，也要清除本地数据
      await SecureStorageService.clearAll();

      _currentToken = null;
      _currentUser = null;

      // 通知登出状态变化
      _notifyAuthStatusChange(AuthStatus.unauthenticated);
    }
  }

  /// 删除账户
  Future<void> deleteAccount() async {
    try {
      // 停止定时器
      _refreshTimer?.cancel();
      
      // 调用服务器删除账户接口
      await GoogleAuthService.deleteAccount();

      // 清除本地数据
      await SecureStorageService.clearAll();

      _currentToken = null;
      _currentUser = null;

      // 通知账户删除状态变化
      _notifyAuthStatusChange(AuthStatus.unauthenticated);
    } catch (e) {
      debugPrint('删除账户失败，但是强行清除本地数据: $e');
      // 即使服务器删除失败，也要清除本地数据
      await SecureStorageService.clearAll();

      _currentToken = null;
      _currentUser = null;

      // 通知账户删除状态变化
      _notifyAuthStatusChange(AuthStatus.unauthenticated);
      rethrow; // 重新抛出异常，让调用者处理
    }
  }

  /// 验证当前Token是否有效
  Future<bool> isTokenValid() async {
    try {
      final token = await getAccessToken();
      return token != null && token.isNotEmpty;
    } catch (e) {
      debugPrint('验证Token失败: $e');
      return false;
    }
  }

  /// 检查是否已登录
  Future<bool> isSignedIn() async {
    try {
      // 判断token是否存在 并且不为空 并且没过期，如果过期 强制刷新
      final isTokenValid = await _refreshTokenIfNeeded(force: false);

      // 更新认证状态（如果状态未知）
      if (_currentStatus == AuthStatus.unknown) {
        _notifyAuthStatusChange(
          isTokenValid ? AuthStatus.authenticated : AuthStatus.unauthenticated,
          user: _currentUser,
        );
      }

      return isTokenValid;
    } catch (e) {
      debugPrint('🔐 [AUTH] isSignedIn异常: $e');
      // 通知认证状态为未知
      if (_currentStatus != AuthStatus.unauthenticated) {
        _notifyAuthStatusChange(AuthStatus.unauthenticated);
      }
      return false;
    }
  }

  /// 强制刷新Token
  Future<bool> refreshToken() async {
    return await _refreshTokenIfNeeded(force: true);
  }

  /// 内部方法：刷新Token（如果需要）
  Future<bool> _refreshTokenIfNeeded({bool force = false}) async {
    // 如果已经有刷新操作在进行，直接返回该Future
    if (_refreshFuture != null) {
      debugPrint('🔐 [AUTH] Token刷新已在进行中，等待完成...');
      try {
        return await _refreshFuture!.timeout(
          const Duration(seconds: 35),
          onTimeout: () {
            debugPrint('🔐 [AUTH] 等待Token刷新超时');
            _refreshFuture = null; // 清除超时的Future
            return false;
          },
        );
      } catch (e) {
        debugPrint('🔐 [AUTH] 等待Token刷新异常: $e');
        _refreshFuture = null; // 清除异常的Future
        return false;
      }
    }

    // 没有已经在刷新的操作
    if (_currentToken == null) {
      await _loadTokenFromStorage();
    }

    // 没有刷新Token
    if (_currentToken == null || _currentToken!.refreshToken.isEmpty) {
      return false;
    }

    // 检查是否需要刷新
    if (!force && !_currentToken!.isExpiringSoon) {
      return true; // 不需要刷新
    }

    // 创建新的刷新Future
    _refreshFuture = _performTokenRefresh();
    
    try {
      final result = await _refreshFuture!;
      return result;
    } finally {
      // 刷新完成后清除Future引用
      _refreshFuture = null;
    }
  }

  /// 执行实际的Token刷新操作
  Future<bool> _performTokenRefresh() async {
    debugPrint('🔐 [AUTH] 开始刷新Token...');
    debugPrint('🔐 [AUTH] 当前RefreshToken长度: ${_currentToken?.refreshToken.length ?? 0}');
    
    try {
      debugPrint('🔐 [AUTH] 调用GoogleAuthService.refreshAccessToken...');
      final result = await GoogleAuthService.refreshAccessToken(
        refreshToken: _currentToken!.refreshToken,
      ).timeout(
        const Duration(seconds: 30),
        onTimeout: () {
          debugPrint('🔐 [AUTH] Token刷新请求超时(30秒)');
          throw TimeoutException('Token refresh timeout', const Duration(seconds: 30));
        },
      );

      debugPrint('🔐 [AUTH] GoogleAuthService返回结果: errNo=${result.errNo}');
      
      if (result.errNo == 0 && result.data != null) {
        var newToken = result.data!;
        debugPrint('🔐 [AUTH] 获得新Token，AccessToken长度: ${newToken.accessToken.length}');
        debugPrint('🔐 [AUTH] 新Token过期时间: ${newToken.expiresAt}');

        // 保留原有的refresh token（如果新的为空）
        if (newToken.refreshToken.isEmpty && _currentToken != null) {
          debugPrint('🔐 [AUTH] 新RefreshToken为空，保留原有RefreshToken');
          newToken = AccessTokenResponse(
            accessToken: newToken.accessToken,
            refreshToken: _currentToken!.refreshToken,
            expiresIn: newToken.expiresIn,
            tokenType: newToken.tokenType,
            expiresAt: newToken.expiresAt,
          );
        }

        debugPrint('🔐 [AUTH] 保存新Token到安全存储...');
        await _saveTokenToSecureStorage(newToken);
        _currentToken = newToken;

        debugPrint('🔐 [AUTH] Token刷新成功');
        return true;
      } else {
        debugPrint('🔐 [AUTH] Token刷新失败: errNo=${result.errNo}');
        debugPrint('🔐 [AUTH] 响应数据为空: ${result.data == null}');
        // 刷新失败，清除Token
        await _clearTokenFromSecureStorage();
        _currentToken = null;
        // 通知Token失效
        _notifyAuthStatusChange(AuthStatus.unauthenticated);
        return false;
      }
    } catch (e) {
      debugPrint('🔐 [AUTH] Token刷新异常: $e');
      debugPrint('🔐 [AUTH] 异常类型: ${e.runtimeType}');
      if (e is TimeoutException) {
        debugPrint('🔐 [AUTH] 这是一个超时异常');
      }
      // 刷新异常，清除Token
      await _clearTokenFromSecureStorage();
      _currentToken = null;
      // 通知Token失效
      _notifyAuthStatusChange(AuthStatus.unauthenticated);
      return false;
    }
    debugPrint('🔐 [AUTH] 开始刷新Token...');
    debugPrint('🔐 [AUTH] 当前RefreshToken长度: ${_currentToken?.refreshToken.length ?? 0}');
    
    try {
      debugPrint('🔐 [AUTH] 调用GoogleAuthService.refreshAccessToken...');
      final result = await GoogleAuthService.refreshAccessToken(
        refreshToken: _currentToken!.refreshToken,
      ).timeout(
        const Duration(seconds: 30),
        onTimeout: () {
          debugPrint('🔐 [AUTH] Token刷新请求超时(30秒)');
          throw TimeoutException('Token refresh timeout', const Duration(seconds: 30));
        },
      );

      debugPrint('🔐 [AUTH] GoogleAuthService返回结果: errNo=${result.errNo}');
      
      if (result.errNo == 0 && result.data != null) {
        var newToken = result.data!;
        debugPrint('🔐 [AUTH] 获得新Token，AccessToken长度: ${newToken.accessToken.length}');
        debugPrint('🔐 [AUTH] 新Token过期时间: ${newToken.expiresAt}');

        // 保留原有的refresh token（如果新的为空）
        if (newToken.refreshToken.isEmpty && _currentToken != null) {
          debugPrint('🔐 [AUTH] 新RefreshToken为空，保留原有RefreshToken');
          newToken = AccessTokenResponse(
            accessToken: newToken.accessToken,
            refreshToken: _currentToken!.refreshToken,
            expiresIn: newToken.expiresIn,
            tokenType: newToken.tokenType,
            expiresAt: newToken.expiresAt,
          );
        }

        debugPrint('🔐 [AUTH] 保存新Token到安全存储...');
        await _saveTokenToSecureStorage(newToken);
        _currentToken = newToken;

        debugPrint('🔐 [AUTH] Token刷新成功');
        return true;
      } else {
        debugPrint('🔐 [AUTH] Token刷新失败: errNo=${result.errNo}');
        debugPrint('🔐 [AUTH] 响应数据为空: ${result.data == null}');
        // 刷新失败，清除Token
        await _clearTokenFromSecureStorage();
        _currentToken = null;
        // 通知Token失效
        _notifyAuthStatusChange(AuthStatus.unauthenticated);
        return false;
      }
    } catch (e) {
      debugPrint('🔐 [AUTH] Token刷新异常: $e');
      debugPrint('🔐 [AUTH] 异常类型: ${e.runtimeType}');
      if (e is TimeoutException) {
        debugPrint('🔐 [AUTH] 这是一个超时异常');
      }
      // 刷新异常，清除Token
      await _clearTokenFromSecureStorage();
      _currentToken = null;
      // 通知Token失效
      _notifyAuthStatusChange(AuthStatus.unauthenticated);
      return false;
    }
  }

  /// 从安全存储加载Token和用户信息（批量读取优化）
  Future<void> _loadTokenFromStorage() async {
    try {
      // 一次性读取所有认证相关数据，减少IO操作
      final authData = await SecureStorageService.getAllAuthData();
      
      final accessToken = authData['accessToken'];
      final refreshToken = authData['refreshToken'];
      final expiresAtStr = authData['expiresAt'];
      final userInfoJson = authData['userInfo'];

      // 处理Token数据
      if (accessToken != null && refreshToken != null) {
        final expiresAtMs = expiresAtStr != null ? int.tryParse(expiresAtStr) : null;
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

      // 处理用户信息数据
      if (userInfoJson != null) {
        final userMap = json.decode(userInfoJson) as Map<String, dynamic>;
        _currentUser = GoogleAuthResponse.fromMap(userMap);
      }
    } catch (e) {
      debugPrint('加载Token和用户信息失败: $e');
    }
  }

  /// 保存Token到安全存储
  Future<void> _saveTokenToSecureStorage(
    AccessTokenResponse token,
  ) async {
    try {
      await SecureStorageService.saveAccessToken(token.accessToken);
      await SecureStorageService.saveRefreshToken(token.refreshToken);

      await SecureStorageService.saveTokenExpiresAt(
        token.expiresAt * 1000, // 转换为毫秒
      );
    } catch (e) {
      debugPrint('保存Token失败: $e');
    }
  }

  /// 清除Token从安全存储
  Future<void> _clearTokenFromSecureStorage() async {
    try {
      await SecureStorageService.deleteAccessToken();
      await SecureStorageService.deleteRefreshToken();
      await SecureStorageService.deleteTokenExpiresAt();
    } catch (e) {
      debugPrint('清除Token失败: $e');
    }
  }

  /// 保存用户信息到安全存储
  Future<void> _saveUserToSecureStorage(GoogleAuthResponse user) async {
    try {
      final userJson = json.encode(user.toMap());
      await SecureStorageService.saveUserInfo(userJson);
    } catch (e) {
      debugPrint('保存用户信息失败: $e');
    }
  }

  /// 清除所有认证数据
  Future<void> clearAllAuthData() async {
    try {
      // 停止定时器
      _refreshTimer?.cancel();
      
      await SecureStorageService.clearAll();
      _currentToken = null;
      _currentUser = null;

      // 通知认证数据清除
      _notifyAuthStatusChange(AuthStatus.unauthenticated);
    } catch (e) {
      debugPrint('清除所有认证数据失败: $e');
    }
  }

  /// 关闭事件流（应用退出时调用）
  Future<void> dispose() async {
    // 停止定时器
    _refreshTimer?.cancel();
    
    await _authStatusController.close();
    debugPrint('🔐 [AUTH] 认证管理器已关闭');
  }
}
