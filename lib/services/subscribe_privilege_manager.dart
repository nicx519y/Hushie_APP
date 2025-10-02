import 'dart:async';
import 'package:flutter/foundation.dart';
import '../models/user_privilege_model.dart';
import '../models/product_model.dart';
import 'auth_manager.dart';
import 'api/user_privilege_service.dart';
import 'api/product_service.dart';
import 'performance_service.dart';

/// 用户权益变化事件
class PrivilegeChangeEvent {
  /// 用户权限信息（包含 hasPremium 和 premiumExpireTime）
  final UserPrivilege? privilege;
  
  /// 事件发生时间
  final DateTime timestamp;

  const PrivilegeChangeEvent({
    required this.privilege,
    required this.timestamp,
  });

  /// 获取是否拥有高级权限（向后兼容）
  bool get hasPremium => privilege?.hasPremium ?? false;

  @override
  String toString() {
    return 'PrivilegeChangeEvent{privilege: $privilege, timestamp: $timestamp}';
  }
}

/// 订阅权限管理器 - 统一管理用户权限和商品数据
/// 
/// 功能特性：
/// - 监听认证状态变化，自动获取/清理权限数据
/// - 内存缓存用户权限和商品列表
/// - 定时刷新数据（每2小时）
/// - 提供统一的数据访问接口
class SubscribePrivilegeManager {
  static final SubscribePrivilegeManager _instance = SubscribePrivilegeManager._internal();
  factory SubscribePrivilegeManager() => _instance;
  SubscribePrivilegeManager._internal();

  static SubscribePrivilegeManager get instance => _instance;

  // 缓存数据
  UserPrivilege? _cachedPrivilege;
  ProductData? _cachedProductData;
  DateTime? _lastFetchTime;

  // 定时器和监听器
  Timer? _refreshTimer;
  StreamSubscription<AuthStatusChangeEvent>? _authStatusSubscription;

  // 权益变化事件流
  final StreamController<PrivilegeChangeEvent> _privilegeChangeController = 
      StreamController<PrivilegeChangeEvent>.broadcast();

  // 数据刷新间隔（5分钟）
  static const Duration _refreshInterval = Duration(minutes: 5);

  // 服务状态
  bool _isInitialized = false;
  bool _isDataLoading = false;
  
  // 避免重复执行的Future
  Future<void>? _loadProductDataFuture;
  Future<void>? _loadPrivilegeDataFuture;

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
      _authStatusSubscription = AuthManager.instance.authStatusChanges.listen(
        _handleAuthStatusChange,
        onError: (error) {
          debugPrint('🏆 [PRIVILEGE_SERVICE] 认证状态监听异常: $error');
        },
      );

      // 检查当前认证状态并初始化数据
      final currentStatus = AuthManager.instance.currentAuthStatus;
      debugPrint('🏆 [PRIVILEGE_SERVICE] 当前认证状态: $currentStatus');

      if (currentStatus == AuthStatus.authenticated) {
        // 如果已登录，立即获取权限和商品数据
        await _loadPrivilegeAndProductData();
      } else if (currentStatus == AuthStatus.unauthenticated) {
        // 如果未登录，只获取商品数据
        await _loadProductData();
      } else {
        // 如果状态未知，等待状态确定
        debugPrint('🏆 [PRIVILEGE_SERVICE] 认证状态未知，等待状态确定');
      }

      // 无论登录状态如何，都启动定时器
      _startRefreshTimer();

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
        break;
      case AuthStatus.unauthenticated:
        // 用户登出，只清理权限数据，保留商品数据
        _clearPrivilegeData();
        break;
      case AuthStatus.unknown:
        // 状态未知，暂不处理
        break;
    }
  }

  /// 加载商品数据
  Future<void> _loadProductData() async {
    // 如果已有正在执行的请求，等待其完成
    if (_loadProductDataFuture != null) {
      debugPrint('🏆 [PRIVILEGE_SERVICE] 商品数据正在加载中，等待完成');
      return _loadProductDataFuture!;
    }

    // 创建新的加载任务
    _loadProductDataFuture = _doLoadProductData();
    
    try {
      await _loadProductDataFuture!;
    } finally {
      // 清理Future引用，允许下次调用
      _loadProductDataFuture = null;
    }
  }

  Future<void> _doLoadProductData() async {
    try {
      debugPrint('🏆 [PRIVILEGE_SERVICE] 开始加载商品数据');
      
      final productData = await ProductService.instance.getProducts();
      _cachedProductData = productData;
      _lastFetchTime = DateTime.now();

      debugPrint('🏆 [PRIVILEGE_SERVICE] 商品数据加载完成');
      debugPrint('🏆 [PRIVILEGE_SERVICE] 商品数量: ${_cachedProductData?.products.length}');

      // 尝试设置 currency 全局属性（用于地区推断的辅助）
      try {
        final products = productData.products;
        String? currency;
        if (products.isNotEmpty) {
          final firstProduct = products.first;
          if (firstProduct.basePlans.isNotEmpty) {
            final basePlan = firstProduct.basePlans.first;
            // 优先使用可用的 offer 的货币，其次使用基础计划的货币
            Offer? availableOffer;
            try {
              availableOffer = basePlan.offers.firstWhere((o) => o.isAvailable);
            } catch (_) {}
            currency = availableOffer?.currency ??
                (basePlan.offers.isNotEmpty ? basePlan.offers.first.currency : basePlan.currency);
          }
        }
        if (currency != null && currency.isNotEmpty) {
          PerformanceService().setGlobalAttribute('currency', currency);
        }
      } catch (e) {
        debugPrint('🏆 [PRIVILEGE_SERVICE] 设置 currency 属性失败: $e');
      }
    } catch (e) {
      debugPrint('🏆 [PRIVILEGE_SERVICE] 加载商品数据失败: $e');
      // 加载失败时不清理现有缓存，保持旧数据可用
    }
  }

  /// 加载用户权限数据
  Future<void> _loadPrivilegeData() async {
    // 如果已有正在执行的请求，等待其完成
    if (_loadPrivilegeDataFuture != null) {
      debugPrint('🏆 [PRIVILEGE_SERVICE] 用户权限数据正在加载中，等待完成');
      return _loadPrivilegeDataFuture!;
    }

    // 创建新的加载任务
    _loadPrivilegeDataFuture = _doLoadPrivilegeData();
    
    try {
      await _loadPrivilegeDataFuture!;
    } finally {
      // 清理Future引用，允许下次调用
      _loadPrivilegeDataFuture = null;
    }
  }

  Future<void> _doLoadPrivilegeData() async {
    try {
      debugPrint('🏆 [PRIVILEGE_SERVICE] 开始加载用户权限数据');
      
      // 保存之前的权限状态
      final previousHasPremium = _cachedPrivilege?.hasPremium ?? false;
      
      final privilege = await UserPrivilegeService.instance.checkUserPrivilege(forceRefresh: true);
      _cachedPrivilege = privilege;

      debugPrint('🏆 [PRIVILEGE_SERVICE] 用户权限数据加载完成');
      debugPrint('🏆 [PRIVILEGE_SERVICE] 权限状态: hasPremium=${_cachedPrivilege?.hasPremium}');

      // 根据权限状态更新 plan_tier 全局属性
      try {
        String planTier;
        if (!(privilege.hasPremium)) {
          planTier = 'free';
        } else if (privilege.isValidPremium) {
          planTier = 'premium';
        } else {
          planTier = 'expired';
        }
        PerformanceService().setGlobalAttribute('plan_tier', planTier);
      } catch (e) {
        debugPrint('🏆 [PRIVILEGE_SERVICE] 设置 plan_tier 属性失败: $e');
      }
      
      // 检查权限状态是否发生变化
      final currentHasPremium = _cachedPrivilege?.hasPremium ?? false;
      // final currentHasPremium = true;
      if (previousHasPremium != currentHasPremium) {
        debugPrint('🏆 [PRIVILEGE_SERVICE] 权限状态发生变化: $previousHasPremium -> $currentHasPremium');
        _notifyPrivilegeChange(_cachedPrivilege);
      }
    } catch (e) {
      debugPrint('🏆 [PRIVILEGE_SERVICE] 加载用户权限数据失败: $e');
      // 加载失败时不清理现有缓存，保持旧数据可用
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
      await Future.wait([
        _loadPrivilegeData(),
        _loadProductData(),
      ]);

      debugPrint('🏆 [PRIVILEGE_SERVICE] 数据加载完成');
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
      
      // 根据登录状态决定刷新内容
      if (AuthManager.instance.currentAuthStatus == AuthStatus.authenticated) {
        // 已登录：刷新权限和商品数据
        _loadPrivilegeAndProductData();
      } else {
        // 未登录：只刷新商品数据
        _loadProductData();
      }
    });

    debugPrint('🏆 [PRIVILEGE_SERVICE] 定时刷新器已启动（间隔: ${_refreshInterval.inMinutes}分钟）');
  }

  /// 停止定时刷新器
  void _stopRefreshTimer() {
    _refreshTimer?.cancel();
    _refreshTimer = null;
    debugPrint('🏆 [PRIVILEGE_SERVICE] 定时刷新器已停止');
  }

  /// 清理用户权限缓存数据
  void _clearPrivilegeData() {
    // 保存之前的权限状态
    final previousHasPremium = _cachedPrivilege?.hasPremium ?? false;
    
    _cachedPrivilege = null;
    debugPrint('🏆 [PRIVILEGE_SERVICE] 用户权限缓存数据已清理');
    
    // 如果之前有权限，现在清理了，发送状态变化事件
    if (previousHasPremium) {
      debugPrint('🏆 [PRIVILEGE_SERVICE] 权限状态发生变化: true -> false (用户登出)');
      _notifyPrivilegeChange(null);
    }

    // 登出时重置 plan_tier 到 free
    try {
      PerformanceService().setGlobalAttribute('plan_tier', 'free');
    } catch (_) {}
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
      if (AuthManager.instance.currentAuthStatus != AuthStatus.authenticated) {
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
  /// 返回商品数据，如果获取失败返回null
  Future<ProductData?> getProductData({bool forceRefresh = false}) async {
    try {
      // 如果需要强制刷新或缓存为空，重新获取数据
      if (forceRefresh || _cachedProductData == null) {
        await _loadProductData();
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
      // return true;
    } catch (e) {
      debugPrint('🏆 [PRIVILEGE_SERVICE] 检查高级权限失败: $e');
      return false;
    }
  }

  /// 手动刷新数据
  /// 
  /// 立即刷新权限和商品数据
  Future<void> refreshData() async {
    debugPrint('🏆 [PRIVILEGE_SERVICE] 手动刷新数据');
    await _loadPrivilegeAndProductData();
  }

  /// 更新订阅权限
  /// 
  /// 在订阅成功后调用此方法，强制刷新用户权限和商品数据
  /// 通常在 Google Play 订阅购买成功后调用，确保权限状态及时更新
  Future<void> updateSubscribePrivilege() async {
    try {
      debugPrint('🏆 [PRIVILEGE_SERVICE] 订阅成功，开始更新权限数据');
      
      // 检查认证状态
      if (AuthManager.instance.currentAuthStatus != AuthStatus.authenticated) {
        debugPrint('🏆 [PRIVILEGE_SERVICE] 用户未登录，无法更新权限数据');
        return;
      }

      // 强制刷新权限和商品数据
      await _loadPrivilegeAndProductData();
      
      debugPrint('🏆 [PRIVILEGE_SERVICE] 订阅权限更新完成');
    } catch (e) {
      debugPrint('🏆 [PRIVILEGE_SERVICE] 更新订阅权限失败: $e');
      // 即使更新失败，也不抛出异常，避免影响购买流程
    }
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

  /// 发送权限变化事件通知
  void _notifyPrivilegeChange(UserPrivilege? privilege) {
    final event = PrivilegeChangeEvent(
      privilege: privilege,
      timestamp: DateTime.now(),
    );
    
    if (!_privilegeChangeController.isClosed) {
      _privilegeChangeController.add(event);
      debugPrint('🏆 [PRIVILEGE_SERVICE] 发送权限变化事件: $event');
    }
  }

  /// 获取权限变化事件流
  /// 
  /// 返回权限变化事件的广播流，可以监听 hasPremium 状态的变化
  Stream<PrivilegeChangeEvent> get privilegeChanges => _privilegeChangeController.stream;

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

    // 关闭事件流
    await _privilegeChangeController.close();

    // 清理缓存数据
    _clearCachedData();

    _isInitialized = false;
    _isDataLoading = false;

    debugPrint('🏆 [PRIVILEGE_SERVICE] 权限服务已销毁');
  }
}