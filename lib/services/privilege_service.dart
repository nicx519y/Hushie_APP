import 'dart:async';
import 'package:flutter/foundation.dart';
import '../models/user_privilege_model.dart';
import '../models/product_model.dart';
import 'auth_service.dart';
import 'api/user_privilege_service.dart';
import 'api/product_service.dart';

/// 权限服务 - 统一管理用户权限和商品数据
/// 
/// 功能特性：
/// - 监听认证状态变化，自动获取/清理权限数据
/// - 内存缓存用户权限和商品列表
/// - 定时刷新数据（每2小时）
/// - 提供统一的数据访问接口
class PrivilegeService {
  static final PrivilegeService _instance = PrivilegeService._internal();
  factory PrivilegeService() => _instance;
  PrivilegeService._internal();

  static PrivilegeService get instance => _instance;

  // 缓存数据
  UserPrivilege? _cachedPrivilege;
  ProductData? _cachedProductData;
  DateTime? _lastFetchTime;

  // 定时器和监听器
  Timer? _refreshTimer;
  StreamSubscription<AuthStatusChangeEvent>? _authStatusSubscription;

  // 数据刷新间隔（2小时）
  static const Duration _refreshInterval = Duration(hours: 2);

  // 服务状态
  bool _isInitialized = false;
  bool _isDataLoading = false;

  /// 初始化服务
  /// 
  /// 开始监听认证状态变化，并根据当前状态初始化数据
  Future<void> initialize() async {
    if (_isInitialized) {
      debugPrint('🏆 [PRIVILEGE_SERVICE] 服务已初始化，跳过重复初始化');
      return;
    }

    try {
      debugPrint('🏆 [PRIVILEGE_SERVICE] 开始初始化权限服务');

      // 监听认证状态变化
      _authStatusSubscription = AuthService.authStatusChanges.listen(
        _handleAuthStatusChange,
        onError: (error) {
          debugPrint('🏆 [PRIVILEGE_SERVICE] 认证状态监听异常: $error');
        },
      );

      // 检查当前认证状态并初始化数据
      final currentStatus = AuthService.currentAuthStatus;
      debugPrint('🏆 [PRIVILEGE_SERVICE] 当前认证状态: $currentStatus');

      if (currentStatus == AuthStatus.authenticated) {
        // 如果已登录，立即获取数据
        await _loadPrivilegeAndProductData();
        _startRefreshTimer();
      } else if (currentStatus == AuthStatus.unknown) {
        // 如果状态未知，等待状态确定
        debugPrint('🏆 [PRIVILEGE_SERVICE] 认证状态未知，等待状态确定');
      } else {
        // 如果未登录，确保数据已清理
        _clearCachedData();
      }

      _isInitialized = true;
      debugPrint('🏆 [PRIVILEGE_SERVICE] 权限服务初始化完成');
    } catch (e) {
      debugPrint('🏆 [PRIVILEGE_SERVICE] 初始化失败: $e');
      rethrow;
    }
  }

  /// 处理认证状态变化
  void _handleAuthStatusChange(AuthStatusChangeEvent event) {
    debugPrint('🏆 [PRIVILEGE_SERVICE] 认证状态变化: ${event.status}');

    switch (event.status) {
      case AuthStatus.authenticated:
        // 用户登录，获取权限和商品数据
        _loadPrivilegeAndProductData();
        _startRefreshTimer();
        break;
      case AuthStatus.unauthenticated:
        // 用户登出，清理缓存数据和定时器
        _clearCachedData();
        _stopRefreshTimer();
        break;
      case AuthStatus.unknown:
        // 状态未知，暂不处理
        break;
    }
  }

  /// 加载权限和商品数据
  Future<void> _loadPrivilegeAndProductData() async {
    if (_isDataLoading) {
      debugPrint('🏆 [PRIVILEGE_SERVICE] 数据加载中，跳过重复请求');
      return;
    }

    _isDataLoading = true;
    try {
      debugPrint('🏆 [PRIVILEGE_SERVICE] 开始加载权限和商品数据');

      // 并行获取权限和商品数据
      final results = await Future.wait([
        UserPrivilegeService.instance.checkUserPrivilege(forceRefresh: true),
        ProductService.instance.getProducts(),
      ]);

      _cachedPrivilege = results[0] as UserPrivilege;
      _cachedProductData = results[1] as ProductData;
      _lastFetchTime = DateTime.now();

      debugPrint('🏆 [PRIVILEGE_SERVICE] 数据加载完成');
      debugPrint('🏆 [PRIVILEGE_SERVICE] 权限状态: hasPremium=${_cachedPrivilege?.hasPremium}');
      debugPrint('🏆 [PRIVILEGE_SERVICE] 商品数量: ${_cachedProductData?.products.length}');
    } catch (e) {
      debugPrint('🏆 [PRIVILEGE_SERVICE] 加载数据失败: $e');
      // 加载失败时不清理现有缓存，保持旧数据可用
    } finally {
      _isDataLoading = false;
    }
  }

  /// 启动定时刷新器
  void _startRefreshTimer() {
    _stopRefreshTimer(); // 先停止现有定时器

    _refreshTimer = Timer.periodic(_refreshInterval, (timer) {
      debugPrint('🏆 [PRIVILEGE_SERVICE] 定时刷新数据');
      _loadPrivilegeAndProductData();
    });

    debugPrint('🏆 [PRIVILEGE_SERVICE] 定时刷新器已启动（间隔: ${_refreshInterval.inHours}小时）');
  }

  /// 停止定时刷新器
  void _stopRefreshTimer() {
    _refreshTimer?.cancel();
    _refreshTimer = null;
    debugPrint('🏆 [PRIVILEGE_SERVICE] 定时刷新器已停止');
  }

  /// 清理缓存数据
  void _clearCachedData() {
    _cachedPrivilege = null;
    _cachedProductData = null;
    _lastFetchTime = null;
    debugPrint('🏆 [PRIVILEGE_SERVICE] 缓存数据已清理');
  }

  /// 获取用户权限信息
  /// 
  /// [forceRefresh] 是否强制刷新数据
  /// 返回用户权限信息，如果未登录或获取失败返回null
  Future<UserPrivilege?> getUserPrivilege({bool forceRefresh = false}) async {
    try {
      // 检查认证状态
      if (AuthService.currentAuthStatus != AuthStatus.authenticated) {
        debugPrint('🏆 [PRIVILEGE_SERVICE] 用户未登录，无法获取权限信息');
        return null;
      }

      // 如果需要强制刷新或缓存为空，重新获取数据
      if (forceRefresh || _cachedPrivilege == null) {
        await _loadPrivilegeAndProductData();
      }

      return _cachedPrivilege;
    } catch (e) {
      debugPrint('🏆 [PRIVILEGE_SERVICE] 获取用户权限失败: $e');
      return null;
    }
  }

  /// 获取商品列表
  /// 
  /// [forceRefresh] 是否强制刷新数据
  /// 返回商品数据，如果未登录或获取失败返回null
  Future<ProductData?> getProductData({bool forceRefresh = false}) async {
    try {
      // 检查认证状态
      if (AuthService.currentAuthStatus != AuthStatus.authenticated) {
        debugPrint('🏆 [PRIVILEGE_SERVICE] 用户未登录，无法获取商品数据');
        return null;
      }

      // 如果需要强制刷新或缓存为空，重新获取数据
      if (forceRefresh || _cachedProductData == null) {
        await _loadPrivilegeAndProductData();
      }

      return _cachedProductData;
    } catch (e) {
      debugPrint('🏆 [PRIVILEGE_SERVICE] 获取商品数据失败: $e');
      return null;
    }
  }

  /// 获取订阅类型商品列表
  /// 
  /// [forceRefresh] 是否强制刷新数据
  /// 返回订阅商品列表
  Future<List<Product>> getSubscriptionProducts({bool forceRefresh = false}) async {
    try {
      final productData = await getProductData(forceRefresh: forceRefresh);
      if (productData == null) return [];

      return productData.products
          .where((product) => product.productType == 'subscription')
          .toList();
    } catch (e) {
      debugPrint('🏆 [PRIVILEGE_SERVICE] 获取订阅商品失败: $e');
      return [];
    }
  }

  /// 检查用户是否拥有有效的高级权限
  /// 
  /// [forceRefresh] 是否强制刷新数据
  /// 返回true表示用户拥有有效的高级权限
  Future<bool> hasValidPremium({bool forceRefresh = false}) async {
    try {
      final privilege = await getUserPrivilege(forceRefresh: forceRefresh);
      return privilege?.isValidPremium ?? false;
    } catch (e) {
      debugPrint('🏆 [PRIVILEGE_SERVICE] 检查高级权限失败: $e');
      return false;
    }
  }

  /// 获取权限状态描述
  /// 
  /// [forceRefresh] 是否强制刷新数据
  /// 返回权限状态的中文描述
  Future<String> getPrivilegeStatusDescription({bool forceRefresh = false}) async {
    try {
      final privilege = await getUserPrivilege(forceRefresh: forceRefresh);
      if (privilege == null) {
        return '未登录';
      }

      if (!privilege.hasPremium) {
        return '未开通高级权限';
      }

      if (privilege.isValidPremium) {
        final remainingDays = privilege.remainingDays;
        if (remainingDays > 30) {
          return '高级权限有效';
        } else if (remainingDays > 7) {
          return '高级权限即将到期（剩余${remainingDays}天）';
        } else if (remainingDays > 0) {
          return '高级权限即将到期（剩余${remainingDays}天）';
        } else {
          return '高级权限今日到期';
        }
      } else {
        return '高级权限已过期';
      }
    } catch (e) {
      debugPrint('🏆 [PRIVILEGE_SERVICE] 获取权限状态描述失败: $e');
      return '权限状态未知';
    }
  }

  /// 手动刷新数据
  /// 
  /// 立即刷新权限和商品数据
  Future<void> refreshData() async {
    debugPrint('🏆 [PRIVILEGE_SERVICE] 手动刷新数据');
    await _loadPrivilegeAndProductData();
  }

  /// 获取数据最后更新时间
  /// 
  /// 返回数据最后更新的时间，如果没有数据返回null
  DateTime? getLastUpdateTime() {
    return _lastFetchTime;
  }

  /// 检查数据是否正在加载
  /// 
  /// 返回true表示数据正在加载中
  bool get isDataLoading => _isDataLoading;

  /// 检查服务是否已初始化
  /// 
  /// 返回true表示服务已初始化
  bool get isInitialized => _isInitialized;

  /// 获取缓存的权限信息（不触发网络请求）
  /// 
  /// 返回缓存的权限信息，如果没有缓存则返回null
  UserPrivilege? getCachedPrivilege() {
    return _cachedPrivilege;
  }

  /// 获取缓存的商品数据（不触发网络请求）
  /// 
  /// 返回缓存的商品数据，如果没有缓存则返回null
  ProductData? getCachedProductData() {
    return _cachedProductData;
  }

  /// 销毁服务
  /// 
  /// 清理所有资源，停止监听和定时器
  Future<void> dispose() async {
    debugPrint('🏆 [PRIVILEGE_SERVICE] 开始销毁权限服务');

    // 停止认证状态监听
    await _authStatusSubscription?.cancel();
    _authStatusSubscription = null;

    // 停止定时刷新器
    _stopRefreshTimer();

    // 清理缓存数据
    _clearCachedData();

    _isInitialized = false;
    _isDataLoading = false;

    debugPrint('🏆 [PRIVILEGE_SERVICE] 权限服务已销毁');
  }
}