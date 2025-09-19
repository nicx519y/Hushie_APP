import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:in_app_purchase/in_app_purchase.dart';
import 'api/subscribe_service.dart';
import 'subscribe_privilege_manager.dart';
import '../models/product_model.dart';

// 购买结果枚举
enum PurchaseResult {
  success,
  failed,
  canceled,
  pending,
  error,
}

// 购买结果数据类
class PurchaseResultData {
  final PurchaseResult result;
  final String? message;
  final PurchaseDetails? purchaseDetails;

  PurchaseResultData({
    required this.result,
    this.message,
    this.purchaseDetails,
  });
}

class GooglePlayBillingService {
  // 单例模式
  static final GooglePlayBillingService _instance = GooglePlayBillingService._internal();
  factory GooglePlayBillingService() => _instance;
  GooglePlayBillingService._internal();
  
  final InAppPurchase _inAppPurchase = InAppPurchase.instance;
  
  StreamSubscription<List<PurchaseDetails>>? _subscription;
  
  // 购买结果的Completer，用于将购买流监听结果封装成Future
  final Map<String, Completer<PurchaseResultData>> _purchaseCompleters = {};
  
  // 初始化服务
  Future<bool> initialize() async {
    try {
      // 检查平台支持
      final bool available = await _inAppPurchase.isAvailable();
      if (!available) {
        debugPrint('Google Play Billing不可用');
        return false;
      }
      
      // 监听购买更新
      _subscription = _inAppPurchase.purchaseStream.listen(
        _handlePurchaseUpdates,
        onDone: () => debugPrint('购买流监听结束'),
        onError: (error) => debugPrint('购买流监听错误: $error'),
      );
      
      debugPrint('Google Play Billing初始化成功');
      return true;
    } catch (e) {
      debugPrint('Google Play Billing初始化失败: $e');
      return false;
    }
  }
  
  // 根据产品ID获取Google Play产品详情
  Future<ProductDetails?> getProductById(String productId) async {
    try {
      // 从SubscribePrivilegeManager获取商品信息
    final productData = await SubscribePrivilegeManager.instance.getProductData();
      if (productData == null) {
        debugPrint('无法获取商品数据');
        return null;
      }
      
      // 查找对应的产品
      final product = productData.products.firstWhere(
        (p) => p.googlePlayProductId == productId,
        orElse: () => throw Exception('Product not found'),
      );
      
      // 查询Google Play产品详情
      final ProductDetailsResponse response = await _inAppPurchase.queryProductDetails({productId});
      
      if (response.error != null) {
        debugPrint('查询产品详情失败: ${response.error}');
        return null;
      }
      
      return response.productDetails.isNotEmpty ? response.productDetails.first : null;
    } catch (e) {
      debugPrint('获取产品详情失败: $e');
      return null;
    }
  }
  
  // 购买产品 - 返回Future<PurchaseResultData>
  Future<PurchaseResultData> purchaseProduct(String basePlanId, {String? offerToken}) async {
    try {
      // 从SubscribePrivilegeManager获取商品信息
    final productData = await SubscribePrivilegeManager.instance.getProductData();
      if (productData == null) {
        debugPrint('无法获取商品数据');
        return PurchaseResultData(
          result: PurchaseResult.error,
          message: '无法获取商品数据',
        );
      }
      
      // 根据basePlanId查找对应的产品和基础计划
      Product? targetProduct;
      BasePlan? targetBasePlan;
      
      for (final product in productData.products) {
        for (final basePlan in product.basePlans) {
          if (basePlan.googlePlayBasePlanId == basePlanId) {
            targetProduct = product;
            targetBasePlan = basePlan;
            break;
          }
        }
        if (targetProduct != null) break;
      }
      
      if (targetProduct == null || targetBasePlan == null) {
        debugPrint('未找到基础计划: $basePlanId');
        return PurchaseResultData(
          result: PurchaseResult.error,
          message: '未找到对应的产品或基础计划',
        );
      }
      
      // 查询Google Play产品详情
      final ProductDetailsResponse response = await _inAppPurchase.queryProductDetails({targetProduct.googlePlayProductId});
      
      if (response.error != null) {
        debugPrint('查询产品详情失败: ${response.error}');
        return PurchaseResultData(
          result: PurchaseResult.error,
          message: '查询产品详情失败: ${response.error}',
        );
      }
      
      if (response.productDetails.isEmpty) {
        debugPrint('产品不存在: ${targetProduct.googlePlayProductId}');
        return PurchaseResultData(
          result: PurchaseResult.error,
          message: '未找到产品详情',
        );
      }
      
      final ProductDetails productDetails = response.productDetails.first;
      late PurchaseParam purchaseParam;
      bool success;
      
      // 订阅产品处理
      // 注意：Flutter的in_app_purchase包目前不直接支持offerToken参数
      // offerToken信息已包含在ProductDetails中，Google Play会自动处理
      purchaseParam = PurchaseParam(
        productDetails: productDetails,
        applicationUserName: null, // 可以设置用户标识
      );
      
      // 记录调试信息
      if (offerToken != null && offerToken.isNotEmpty) {
        debugPrint('GooglePlayBillingService: 购买带优惠的订阅，offerToken: $offerToken');
      } else {
        debugPrint('GooglePlayBillingService: 购买普通订阅');
      }
      
      // 创建Completer来等待购买结果
      final completer = Completer<PurchaseResultData>();
      _purchaseCompleters[targetProduct.googlePlayProductId] = completer;
      
      // 使用 buyNonConsumable 购买订阅（Google Play 推荐方式）
      success = await _inAppPurchase.buyNonConsumable(purchaseParam: purchaseParam);
      debugPrint('订阅购买请求结果: $success, basePlanId: $basePlanId, offerToken: $offerToken');
      
      if (!success) {
        _purchaseCompleters.remove(targetProduct.googlePlayProductId);
        return PurchaseResultData(
          result: PurchaseResult.error,
          message: '发起购买失败',
        );
      }
      
      // 等待购买结果
      return await completer.future;
    } catch (e) {
      debugPrint('购买失败: $e');
      return PurchaseResultData(
        result: PurchaseResult.error,
        message: '购买失败: $e',
      );
    }
  }
  
  // 处理购买更新
  void _handlePurchaseUpdates(List<PurchaseDetails> purchaseDetailsList) {
    for (final PurchaseDetails purchaseDetails in purchaseDetailsList) {
      debugPrint('购买状态更新: ${purchaseDetails.status}');
      
      // 获取对应的Completer
      final completer = _purchaseCompleters[purchaseDetails.productID];
      
      switch (purchaseDetails.status) {
        case PurchaseStatus.pending:
          _handlePendingPurchase(purchaseDetails);
          if (completer != null && !completer.isCompleted) {
            completer.complete(PurchaseResultData(
              result: PurchaseResult.pending,
              message: '购买待处理',
              purchaseDetails: purchaseDetails,
            ));
          }
          break;
        case PurchaseStatus.purchased:
          _handleSuccessfulPurchase(purchaseDetails);
          if (completer != null && !completer.isCompleted) {
            completer.complete(PurchaseResultData(
              result: PurchaseResult.success,
              message: '购买成功',
              purchaseDetails: purchaseDetails,
            ));
          }
          break;
        case PurchaseStatus.error:
          _handleFailedPurchase(purchaseDetails);
          if (completer != null && !completer.isCompleted) {
            completer.complete(PurchaseResultData(
              result: PurchaseResult.error,
              message: purchaseDetails.error?.message ?? '购买失败',
              purchaseDetails: purchaseDetails,
            ));
          }
          break;
        case PurchaseStatus.canceled:
          _handleCanceledPurchase(purchaseDetails);
          if (completer != null && !completer.isCompleted) {
            completer.complete(PurchaseResultData(
              result: PurchaseResult.canceled,
              message: '购买被取消',
              purchaseDetails: purchaseDetails,
            ));
          }
          break;
        case PurchaseStatus.restored:
          _handleRestoredPurchase(purchaseDetails);
          if (completer != null && !completer.isCompleted) {
            completer.complete(PurchaseResultData(
              result: PurchaseResult.success,
              message: '购买已恢复',
              purchaseDetails: purchaseDetails,
            ));
          }
          break;
      }
      
      // 清理Completer
      if (completer != null) {
        _purchaseCompleters.remove(purchaseDetails.productID);
      }
      
      // 完成购买处理
      if (purchaseDetails.pendingCompletePurchase) {
        _inAppPurchase.completePurchase(purchaseDetails);
      }
    }
  }
  
  // 处理待处理的购买
  void _handlePendingPurchase(PurchaseDetails purchaseDetails) {
    debugPrint('购买待处理: ${purchaseDetails.productID}');
    // 可以在这里显示加载指示器
  }
  
  // 处理成功的购买
  void _handleSuccessfulPurchase(PurchaseDetails purchaseDetails) {
    debugPrint('购买成功: ${purchaseDetails.productID}');
    
    // 验证购买
    _verifyPurchase(purchaseDetails);
  }
  
  // 处理失败的购买
  void _handleFailedPurchase(PurchaseDetails purchaseDetails) {
    debugPrint('购买失败: ${purchaseDetails.error}');
    // 可以在这里显示错误消息
  }
  
  // 处理取消的购买
  void _handleCanceledPurchase(PurchaseDetails purchaseDetails) {
    debugPrint('购买被取消: ${purchaseDetails.productID}');
    // 可以在这里处理取消逻辑
  }
  
  // 处理恢复的购买
  void _handleRestoredPurchase(PurchaseDetails purchaseDetails) {
    debugPrint('购买已恢复: ${purchaseDetails.productID}');
    // 验证恢复的购买
    _verifyPurchase(purchaseDetails);
  }
  
  // 验证购买
  Future<void> _verifyPurchase(PurchaseDetails purchaseDetails) async {
    try {
      debugPrint('开始验证购买: ${purchaseDetails.productID}');
      
      // 从SubscribePrivilegeManager获取商品信息，找到对应的basePlanId
    final productData = await SubscribePrivilegeManager.instance.getProductData();
      if (productData == null) {
        debugPrint('无法获取商品数据进行验证');
        return;
      }
      
      // 根据productID查找对应的basePlanId
      String? basePlanId;
      for (final product in productData.products) {
        if (product.googlePlayProductId == purchaseDetails.productID) {
          // 如果有多个基础计划，这里需要更精确的逻辑来确定是哪个计划
          // 暂时使用第一个可用的基础计划
          if (product.basePlans.isNotEmpty) {
            basePlanId = product.basePlans.first.googlePlayBasePlanId;
          }
          break;
        }
      }
      
      // 使用 SubscribeService 验证购买并创建订阅记录
      final result = await SubscribeService.createGooglePlaySubscribe(
        productId: purchaseDetails.productID,
        basePlanId: basePlanId ?? '', // 使用找到的basePlanId
        purchaseToken: purchaseDetails.verificationData.serverVerificationData,
      );
      
      if (result.data != null) {
        debugPrint('购买验证成功: ${purchaseDetails.productID}');
        debugPrint('订阅ID: ${result.data!.id}');
        debugPrint('订阅状态: ${result.data!.status}');
      } else {
        debugPrint('购买验证失败: errNo=${result.errNo}');
      }
    } catch (e) {
      debugPrint('购买验证异常: $e');
    }
  }

  // 恢复购买
  Future<void> restorePurchases() async {
    try {
      await _inAppPurchase.restorePurchases();
      debugPrint('开始恢复购买');
    } catch (e) {
      debugPrint('恢复购买失败: $e');
    }
  }
  
  // 检查是否有活跃订阅
  Future<bool> hasActiveSubscription(String productId) async {
    try {
      // 这里应该检查用户是否有活跃的订阅
      // 可以通过查询购买历史或调用后端API来实现
      debugPrint('检查活跃订阅: $productId');
      return false; // 临时返回false
    } catch (e) {
      debugPrint('检查订阅状态失败: $e');
      return false;
    }
  }
  
  // 获取订阅状态
  Future<Map<String, dynamic>?> getSubscriptionStatus(String productId) async {
    try {
      // 这里应该返回订阅的详细状态信息
      // 包括到期时间、是否自动续费等
      debugPrint('获取订阅状态: $productId');
      return null; // 临时返回null
    } catch (e) {
      debugPrint('获取订阅状态失败: $e');
      return null;
    }
  }
  
  // 释放资源
  void dispose() {
    _subscription?.cancel();
  }
}