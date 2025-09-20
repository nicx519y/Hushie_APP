import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:in_app_purchase/in_app_purchase.dart';
import 'package:in_app_purchase_android/in_app_purchase_android.dart';
import 'package:in_app_purchase_android/billing_client_wrappers.dart';
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
  Future<PurchaseResultData> purchaseProduct(String basePlanId, {String? offerToken, String? offerId}) async {
    try {
      // 从SubscribePrivilegeManager获取商品信息
      final productData = await SubscribePrivilegeManager.instance.getProductData();
      if (productData == null) {
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
        return PurchaseResultData(
          result: PurchaseResult.error,
          message: '未找到对应的产品或基础计划',
        );
      }
      
      // 查询Google Play产品详情
      final ProductDetailsResponse response = await _inAppPurchase.queryProductDetails({targetProduct.googlePlayProductId});
  
      if (response.error != null) {
        return PurchaseResultData(
          result: PurchaseResult.error,
          message: '查询产品详情失败: ${response.error}',
        );
      }
      
      if (response.productDetails.isEmpty) {
        return PurchaseResultData(
          result: PurchaseResult.error,
          message: '未找到产品详情',
        );
      }
      
      final ProductDetails productDetails = response.productDetails.first;
      
      late PurchaseParam purchaseParam;
      
      // 处理订阅产品
      if (productDetails is GooglePlayProductDetails) {
        final productDetailsWrapper = productDetails.productDetails;
        
        if (productDetailsWrapper.productType == ProductType.subs) {
          // 查找匹配的优惠 - 使用subscriptionOfferDetails来指定Base Plan
          if (productDetailsWrapper.subscriptionOfferDetails != null && 
              productDetailsWrapper.subscriptionOfferDetails!.isNotEmpty) {
            
            // 查找匹配指定basePlanId的优惠
            SubscriptionOfferDetailsWrapper? targetOffer;
            
            for (final offer in productDetailsWrapper.subscriptionOfferDetails!) {
              if (offer.basePlanId == basePlanId) {
                // 如果指定了offerId，则需要精确匹配
                if (offerId != null) {
                  if (offer.offerId == offerId) {
                    targetOffer = offer;
                    debugPrint('指定了offerId，找到匹配的优惠: basePlanId=${targetOffer.basePlanId}, offerId=${targetOffer.offerId}, offerIdToken=${targetOffer.offerIdToken}');
                    break;
                  }
                } else {
                  // 如果没有指定offerId，使用第一个匹配basePlanId的优惠
                  targetOffer = offer;
                  debugPrint('没有指定offerId，找到匹配的优惠: basePlanId=${targetOffer.basePlanId}, offerId=${targetOffer.offerId}, offerIdToken=${targetOffer.offerIdToken}');
                  break;
                }
              }
            }
            
            if (targetOffer == null) {
              return PurchaseResultData(
                result: PurchaseResult.error,
                message: 'Has no available offer',
              );
            }
            
            // 使用找到的优惠Token创建购买参数
            purchaseParam = GooglePlayPurchaseParam(
              productDetails: productDetails,
              offerToken: targetOffer.offerIdToken,
              applicationUserName: null,
              changeSubscriptionParam: null,
            );
            
            
          } else {
            return PurchaseResultData(
              result: PurchaseResult.failed,
              message: 'Has no available offer',
            );
          }
        } else {
          return PurchaseResultData(
            result: PurchaseResult.failed,
            message: 'Product type is not subscription',
          );
        }
      } else {
        // 处理一次性购买
        purchaseParam = PurchaseParam(productDetails: productDetails);
      }
      
      // 创建Completer来等待购买结果
      final completer = Completer<PurchaseResultData>();
      _purchaseCompleters[targetProduct.googlePlayProductId] = completer;
      
      // 使用 buyNonConsumable 购买订阅
      final success = await _inAppPurchase.buyNonConsumable(purchaseParam: purchaseParam);
      
      if (!success) {
        _purchaseCompleters.remove(targetProduct.googlePlayProductId);
        return PurchaseResultData(
          result: PurchaseResult.error,
          message: 'Purchase failed',
        );
      }
      
      return await completer.future;
    } catch (e) {
      return PurchaseResultData(
        result: PurchaseResult.error,
        message: 'Purchase failed: $e',
      );
    }
  }
  
  // 处理购买更新
  void _handlePurchaseUpdates(List<PurchaseDetails> purchaseDetailsList) {
    for (final PurchaseDetails purchaseDetails in purchaseDetailsList) {
      debugPrint('[GooglePlayBillingService] 购买状态更新: ${purchaseDetails.status}');
      // 记录调试信息
      debugPrint('[GooglePlayBillingService]  - 产品ID: ${purchaseDetails.productID}');
      debugPrint('[GooglePlayBillingService]  - 购买令牌: ${purchaseDetails.verificationData}');
      debugPrint('[GooglePlayBillingService]  - 购买时间: ${purchaseDetails.transactionDate}');
      // 获取对应的Completer
      final completer = _purchaseCompleters[purchaseDetails.productID];
      
      switch (purchaseDetails.status) {
        case PurchaseStatus.pending:
          _handlePendingPurchase(purchaseDetails);
          if (completer != null && !completer.isCompleted) {
            completer.complete(PurchaseResultData(
              result: PurchaseResult.pending,
              message: 'Purchase pending',
              purchaseDetails: purchaseDetails,
            ));
          }
          break;
        case PurchaseStatus.purchased:
          // 异步处理购买成功，不在这里直接完成 completer
          _handlePurchaseWithVerification(purchaseDetails, 'Purchase success');
          break;
        case PurchaseStatus.error:
          _handleFailedPurchase(purchaseDetails);
          if (completer != null && !completer.isCompleted) {
            completer.complete(PurchaseResultData(
              result: PurchaseResult.error,
              message: purchaseDetails.error?.message ?? 'Purchase failed',
              purchaseDetails: purchaseDetails,
            ));
          }
          break;
        case PurchaseStatus.canceled:
          _handleCanceledPurchase(purchaseDetails);
          if (completer != null && !completer.isCompleted) {
            completer.complete(PurchaseResultData(
              result: PurchaseResult.canceled,
              message: 'Purchase canceled',
              purchaseDetails: purchaseDetails,
            ));
          }
          break;
        case PurchaseStatus.restored:
          // 异步处理购买恢复，不在这里直接完成 completer
          _handleRestoredPurchase(purchaseDetails);
          break;
      }
      
      // 清理Completer - 只在非异步处理的情况下清理
      if (completer != null && 
          purchaseDetails.status != PurchaseStatus.purchased && 
          purchaseDetails.status != PurchaseStatus.restored) {
        _purchaseCompleters.remove(purchaseDetails.productID);
      }
      
      // 完成购买处理 server调用，端就不调了
      // if (purchaseDetails.pendingCompletePurchase) {
      //   _inAppPurchase.completePurchase(purchaseDetails);
      // }
    }
  }
  
  // 处理待处理的购买
  void _handlePendingPurchase(PurchaseDetails purchaseDetails) {
    debugPrint('购买待处理: ${purchaseDetails.productID}');
    // 可以在这里显示加载指示器
  }
  
  // 处理成功的购买或恢复的购买
  Future<void> _handlePurchaseWithVerification(PurchaseDetails purchaseDetails, String actionType) async {
    debugPrint('$actionType: ${purchaseDetails.productID}');
    
    // 获取对应的Completer
    final completer = _purchaseCompleters[purchaseDetails.productID];
    
    // 验证购买
    final verifyResult = await _verifyPurchase(purchaseDetails);
    
    if (completer != null && !completer.isCompleted) {
      if (verifyResult) {

        SubscribePrivilegeManager.instance.updateSubscribePrivilege();

        // 验证成功，返回成功结果
        completer.complete(PurchaseResultData(
          result: PurchaseResult.success,
          message: '$actionType and verified',
          purchaseDetails: purchaseDetails,
        ));
      } else {
        // 验证失败，返回错误结果
        completer.complete(PurchaseResultData(
          result: PurchaseResult.error,
          message: '${actionType.toLowerCase()} verification failed',
          purchaseDetails: purchaseDetails,
        ));
      }
      // 清理Completer
      _purchaseCompleters.remove(purchaseDetails.productID);
    }
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
  Future<void> _handleRestoredPurchase(PurchaseDetails purchaseDetails) async {
    await _handlePurchaseWithVerification(purchaseDetails, 'Purchase restored');
  }
  
  // 验证购买
  Future<bool> _verifyPurchase(PurchaseDetails purchaseDetails) async {
    try {
      debugPrint('开始验证购买: ${purchaseDetails.productID}');
      
      // 从SubscribePrivilegeManager获取商品信息，找到对应的basePlanId
    final productData = await SubscribePrivilegeManager.instance.getProductData();
      if (productData == null) {
        debugPrint('无法获取商品数据进行验证');
        return false;
      }
      
      // 根据productID查找对应的basePlanId
      String? basePlanId;
      Product? matchedProduct;
      
      for (final product in productData.products) {
        if (product.googlePlayProductId == purchaseDetails.productID) {
          matchedProduct = product;
          
          // 如果有多个基础计划，这里需要更精确的逻辑来确定是哪个计划
          // 理想情况下应该从购买详情中获取具体的 basePlanId
          // 但由于当前 PurchaseDetails 不包含这些信息，暂时使用第一个可用的基础计划
          if (product.basePlans.isNotEmpty) {
            // 优先选择可用的基础计划
            final availableBasePlans = product.basePlans.where((plan) => plan.isAvailable).toList();
            if (availableBasePlans.isNotEmpty) {
              basePlanId = availableBasePlans.first.googlePlayBasePlanId;
              debugPrint('验证购买: 使用第一个可用的基础计划: $basePlanId');
            } else {
              basePlanId = product.basePlans.first.googlePlayBasePlanId;
              debugPrint('验证购买: 使用第一个基础计划（可能不可用）: $basePlanId');
            }
          }
          break;
        }
      }
      
      if (matchedProduct == null) {
        debugPrint('验证购买失败: 未找到匹配的产品 ${purchaseDetails.productID}');
        return false;
      }
      
      if (basePlanId == null || basePlanId.isEmpty) {
        debugPrint('验证购买失败: 产品 ${purchaseDetails.productID} 没有可用的基础计划');
        return false;
      }
      
      // 使用 SubscribeService 在业务服务器 验证购买并创建订阅记录
      final result = await SubscribeService.createGooglePlaySubscribe(
        productId: purchaseDetails.productID,
        basePlanId: basePlanId, // 使用找到的basePlanId
        purchaseToken: purchaseDetails.verificationData.serverVerificationData,
      );
      
      if (result.data != null) {
        debugPrint('✅ 购买验证成功: ${purchaseDetails.productID}');
        debugPrint('  - 订阅ID: ${result.data!.id}');
        debugPrint('  - 订阅状态: ${result.data!.status}');
        return true;
      } else {
        debugPrint('❌ 购买验证失败: errNo=${result.errNo}');
        return false;
      }
    } catch (e) {
      debugPrint('❌ 购买验证异常: $e');
      return false;
    }
  }
  
  // 新增：验证 Base Plan 匹配逻辑的辅助方法
  Future<bool> validateBasePlanConfiguration(String basePlanId) async {
    try {
      debugPrint('=== 验证 Base Plan 配置 ===');
      debugPrint('  - 目标 basePlanId: $basePlanId');
      
      // 从SubscribePrivilegeManager获取商品信息
      final productData = await SubscribePrivilegeManager.instance.getProductData();
      if (productData == null) {
        debugPrint('❌ 无法获取商品数据');
        return false;
      }
      
      // 查找匹配的产品和基础计划
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
        debugPrint('❌ 未找到匹配的产品或基础计划');
        debugPrint('可用的产品和基础计划:');
        for (final product in productData.products) {
          debugPrint('  产品: ${product.name} (${product.googlePlayProductId})');
          for (final plan in product.basePlans) {
            debugPrint('    - 基础计划: ${plan.name} (${plan.googlePlayBasePlanId}) - 可用: ${plan.isAvailable}');
          }
        }
        return false;
      }
      
      debugPrint('✅ 找到匹配的配置:');
      debugPrint('  - 产品: ${targetProduct.name} (${targetProduct.googlePlayProductId})');
      debugPrint('  - 基础计划: ${targetBasePlan.name} (${targetBasePlan.googlePlayBasePlanId})');
      debugPrint('  - 基础计划可用性: ${targetBasePlan.isAvailable}');
      
      // 查询 Google Play 产品详情进行验证
      final ProductDetailsResponse response = await _inAppPurchase.queryProductDetails({targetProduct.googlePlayProductId});
      
      if (response.error != null) {
        debugPrint('❌ Google Play 产品查询失败: ${response.error}');
        return false;
      }
      
      if (response.productDetails.isEmpty) {
        debugPrint('❌ Google Play 中未找到产品: ${targetProduct.googlePlayProductId}');
        return false;
      }
      
      final productDetails = response.productDetails.first;
      if (productDetails is GooglePlayProductDetails) {
        final wrapper = productDetails.productDetails;
        
        if (wrapper.subscriptionOfferDetails != null && wrapper.subscriptionOfferDetails!.isNotEmpty) {
          debugPrint('Google Play 中的可用优惠:');
          bool foundMatchingOffer = false;
          
          for (final offer in wrapper.subscriptionOfferDetails!) {
            debugPrint('  - basePlanId: ${offer.basePlanId}, offerId: ${offer.offerId}');
            if (offer.basePlanId == basePlanId) {
              foundMatchingOffer = true;
              debugPrint('    ✅ 找到匹配的优惠');
            }
          }
          
          if (!foundMatchingOffer) {
            debugPrint('❌ Google Play 中未找到匹配 basePlanId 的优惠');
            return false;
          }
        } else {
          debugPrint('❌ Google Play 产品没有可用的订阅优惠');
          return false;
        }
      } else {
        debugPrint('❌ 产品不是 GooglePlayProductDetails 类型');
        return false;
      }
      
      debugPrint('✅ Base Plan 配置验证通过');
      return true;
    } catch (e) {
      debugPrint('❌ Base Plan 配置验证异常: $e');
      return false;
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