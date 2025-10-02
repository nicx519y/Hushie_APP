import 'dart:convert';
import 'dart:async';
import '../models/api_response.dart';
import 'api/google_auth_service.dart';
import 'secure_storage_service.dart';
import 'package:flutter/foundation.dart';
import 'network_healthy_manager.dart';
import '../utils/toast_helper.dart';
import '../utils/toast_messages.dart';

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

  /// 在认证相关操作前进行网络健康检查
  /// 网络不健康或检测异常时，提示用户并阻止后续登录/刷新流程，避免误清除登录态
  Future<bool> _ensureNetworkHealthy({String action = ''}) async {
    try {
      final status = await NetworkHealthyManager.instance.checkNetworkHealth();
      if (status == NetworkHealthStatus.healthy) {
        return true;
      }
      ToastHelper.showError(ToastMessages.networkUnavailable);
      debugPrint('🔐 [AUTH] 网络不健康（$status） - 跳过$action');
      return false;
    } catch (e) {
      ToastHelper.showError(ToastMessages.networkCheckFailed);
      debugPrint('🔐 [AUTH] 网络检测异常 - 跳过$action: $e');
      return false;
    }
  }

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
      
      final isLogin = await isSignedIn();

      // 如果有Token，设置为已认证状态，否则设置为未认证状态
      if (isLogin) {
        _notifyAuthStatusChange(AuthStatus.authenticated, user: _currentUser);
        // 启动定时器检查Token过期时间
        _startTokenRefreshTimer();
      } else {
        _notifyAuthStatusChange(AuthStatus.unauthenticated);
      }
      
      _isInitialized = true;
      debugPrint('🔐 [AUTH] AuthManager初始化完成: ${_currentStatus}');
    } catch (e) {
      debugPrint('🔐 [AUTH] 初始化AuthManager失败: $e');
      // 初始化失败时，如果有Token就保持认证状态，否则设为未认证
      if (_currentToken != null && _currentToken!.accessToken.isNotEmpty) {
        _notifyAuthStatusChange(AuthStatus.authenticated, user: _currentUser);
      } else {
        _notifyAuthStatusChange(AuthStatus.unauthenticated);
      }
      _isInitialized = true; // 即使失败也标记为已初始化
    }
  }

  /// 启动Token定时刷新
  void _startTokenRefreshTimer() {
    // 取消现有定时器
    _refreshTimer?.cancel();
    
    // 设置定时器，每30秒检查一次Token过期时间
    _refreshTimer = Timer.periodic(const Duration(seconds: 30), (timer) async {
      debugPrint('🔐 [AUTH] 定时检查Token过期时间');
      try {
        if (_currentToken == null) {
          debugPrint('🔐 [AUTH] 当前Token为空，停止定时检查');
          timer.cancel();
          return;
        }
        // 如果距离过期时间小于1分钟（60秒），则自动刷新
        _refreshTokenIfNeeded();

      } catch (e) {
        debugPrint('🔐 [AUTH] 定时检查Token异常: $e');
      }
    });
    
    debugPrint('🔐 [AUTH] Token定时检查器已启动（每30秒检查一次）');
  }
  /// 获取当前访问Token
  Future<String?> getAccessToken() async {
    // 先从内存中检查
    if (_currentToken != null &&
        _currentToken!.accessToken.isNotEmpty) {
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
      // 网络健康预检：网络不可用时不进行登录流程，避免误判登录失败为未认证
      if (!await _ensureNetworkHealthy(action: 'login')) {
        return ApiResponse.error(errNo: -1);
      }
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

      _startTokenRefreshTimer();

      return googleAuthResult;
    } catch (e) {
      debugPrint('Google登录流程失败: $e');
      // 通知登录失败
      _notifyAuthStatusChange(AuthStatus.unauthenticated);

      _refreshTimer?.cancel();

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

      _refreshTimer?.cancel();

    } catch (e) {
      debugPrint('登出失败，但是强行登出: $e');
      // 即使服务器登出失败，也要清除本地数据
      await SecureStorageService.clearAll();

      _currentToken = null;
      _currentUser = null;

      // 通知登出状态变化
      _notifyAuthStatusChange(AuthStatus.unauthenticated);

      _refreshTimer?.cancel();
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

      _refreshTimer?.cancel();
    } catch (e) {
      debugPrint('删除账户失败，但是强行清除本地数据: $e');
      // 即使服务器删除失败，也要清除本地数据
      await SecureStorageService.clearAll();

      _currentToken = null;
      _currentUser = null;

      // 通知账户删除状态变化
      _notifyAuthStatusChange(AuthStatus.unauthenticated);

      _refreshTimer?.cancel();
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

  /// 检查本地是否有有效的登录凭证（检查过期时间并自动刷新）
  Future<bool> isSignedIn() async {
    try {
      // 如果内存中没有Token，从存储中加载
      if (_currentToken == null) {
        await _loadTokenFromStorage();
      }
      
      // 检查是否有Token
      if (_currentToken == null || 
          _currentToken!.accessToken.isEmpty || 
          _currentToken!.refreshToken.isEmpty) {
        debugPrint('🔐 [AUTH] 没有有效的Token');
        return false;
      }

      // 检查Token是否过期
      if (_currentToken!.isExpiringSoon) {
        debugPrint('🔐 [AUTH] Token已过期或即将过期，尝试刷新');
        
        // 尝试刷新Token
        final refreshSuccess = await _refreshTokenIfNeeded(force: true);
        
        if (!refreshSuccess) {
          debugPrint('🔐 [AUTH] Token刷新失败，保留现有登录态，稍后重试');
          // 软失败：保留现有态，不立即清除，交由定时器或下次请求重试
          return true;
        }
        
        debugPrint('🔐 [AUTH] Token刷新成功');
      }

      // Token有效且未过期
      return true;
    } catch (e) {
      debugPrint('🔐 [AUTH] isSignedIn异常: $e');
      // 发生异常时，为了安全起见，退出登录态
      await clearAllAuthData();
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

    // 创建新的刷新Future（加入短期退避重试）
    _refreshFuture = () async {
      // 首次尝试
      bool ok = await _performTokenRefresh();
      if (ok) return true;
      // 若失败，不清除本地（除服务器判定无效的情况在 _performTokenRefresh 中处理），进行两次退避重试
      for (int i = 1; i <= 2; i++) {
        final delayMs = 1000 * i;
        debugPrint('🔄 [AUTH] 刷新失败，${delayMs}ms后重试 第${i}次');
        await Future.delayed(Duration(milliseconds: delayMs));
        ok = await _performTokenRefresh();
        if (ok) return true;
      }
      return false;
    }();
    
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
    
    // 网络健康预检：网络不可用时跳过刷新且不清除本地凭证，避免误登出
    if (!await _ensureNetworkHealthy(action: 'Token refresh')) {
      return false;
    }

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
        // 分类处理：-1 网络/异常 -> 保留现态；其它错误视为服务器判定无效 -> 清理并登出
        if (result.errNo == -1) {
          debugPrint('🔐 [AUTH] 刷新失败（网络/异常），保留现有登录态');
          return false;
        } else {
          debugPrint('🔐 [AUTH] 服务器判定RefreshToken无效，清除Token并进入非登录态');
          await _clearTokenFromSecureStorage();
          _currentToken = null;
          _notifyAuthStatusChange(AuthStatus.unauthenticated);
          return false;
        }
      }
    } catch (e) {
      debugPrint('🔐 [AUTH] Token刷新异常: $e');
      debugPrint('🔐 [AUTH] 异常类型: ${e.runtimeType}');
      
      // 对于网络超时异常，不清除Token，保持当前状态
      if (e is TimeoutException) {
        debugPrint('🔐 [AUTH] 这是一个超时异常，不进入非登录态');
        return false;
      }
      
      // 其他异常（网络错误等）保留现态，避免误登出
      debugPrint('🔐 [AUTH] 刷新发生网络/未知异常，保留现态');
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
