import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:in_app_purchase/in_app_purchase.dart';
import 'package:in_app_purchase_android/in_app_purchase_android.dart';
import 'package:in_app_purchase_android/billing_client_wrappers.dart';
import 'api/subscribe_service.dart';
import 'subscribe_privilege_manager.dart';
import 'billing_error_handler.dart';
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

// 购买事件类型枚举
enum PurchaseEventType {
  purchaseStarted,    // 购买开始
  purchasePending,    // 购买待处理
  purchaseSuccess,    // 购买成功
  purchaseFailed,     // 购买失败
  purchaseCanceled,   // 购买取消
  purchaseError,      // 购买错误
}

// 购买事件数据类
class PurchaseEvent {
  final PurchaseEventType type;
  final String productId;
  final String basePlanId;
  final String? message;
  final PurchaseDetails? purchaseDetails;
  final Map<String, dynamic>? metadata;

  PurchaseEvent({
    required this.type,
    required this.productId,
    required this.basePlanId,
    this.message,
    this.purchaseDetails,
    this.metadata,
  });
}

class GooglePlayBillingService {
  // 单例模式
  static final GooglePlayBillingService _instance = GooglePlayBillingService._internal();
  factory GooglePlayBillingService() => _instance;
  static GooglePlayBillingService get instance => _instance;
  GooglePlayBillingService._internal();
  
  final InAppPurchase _inAppPurchase = InAppPurchase.instance;
  
  StreamSubscription<List<PurchaseDetails>>? _subscription;
  bool _isInitialized = false;
  
  // 购买事件流控制器
  final StreamController<PurchaseEvent> _purchaseEventController = StreamController<PurchaseEvent>.broadcast();
  
  // 对外暴露的购买事件流
  Stream<PurchaseEvent> get purchaseEventStream => _purchaseEventController.stream;
  
  // 存储每个产品对应的basePlanId，用于验证时传递
  final Map<String, String> _productBasePlanIds = {};
  
  // 初始化服务
  Future<bool> initialize() async {
    // 如果已经初始化过，直接返回成功
    if (_isInitialized) {
      debugPrint('Google Play Billing已经初始化，跳过重复初始化');
      return true;
    }
    
    try {
      // 初始化错误处理器
      await BillingErrorHandler().initialize();
      
      // 检查平台支持
      final bool available = await _inAppPurchase.isAvailable();
      if (!available) {
        debugPrint('Google Play Billing不可用');
        BillingErrorHandler().logDeviceSpecificError(
          'Google Play Billing not available',
          {'platform_available': available},
        );
        return false;
      }
      
      // 先取消之前的订阅（如果存在）
      await _subscription?.cancel();
      
      // 监听购买更新
      _subscription = _inAppPurchase.purchaseStream.listen(
        _handlePurchaseUpdates,
        onDone: () => debugPrint('购买流监听结束'),
        onError: (error) => debugPrint('购买流监听错误: $error'),
      );
      
      _isInitialized = true;
      debugPrint('Google Play Billing初始化成功');
      return true;
    } catch (e) {
      debugPrint('Google Play Billing初始化失败: $e');
      
      // 记录设备特定的初始化错误
      BillingErrorHandler().logDeviceSpecificError(
        'Billing initialization failed: $e',
        {
          'error_type': 'initialization_error',
          'stack_trace': e.toString(),
        },
      );
      
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
  
  // 购买产品 - 发送事件到Stream，不再返回Future
  Future<bool> purchaseProduct(String basePlanId, {String? offerToken, String? offerId}) async {
    // 这些变量需在 try 块之外声明，便于在 onTimeout/catch 中访问
    Product? targetProduct;
    BasePlan? targetBasePlan;
    String? productId;

    try {
      // 验证服务是否已初始化
      if (!_isInitialized) {
        debugPrint('❌ Google Play Billing 服务未初始化');
        _emitPurchaseEvent(PurchaseEvent(
          type: PurchaseEventType.purchaseError,
          productId: 'unknown',
          basePlanId: basePlanId,
          message: 'Billing service not initialized',
        ));
        return false;
      }

      // 从SubscribePrivilegeManager获取商品信息
      final productData = await SubscribePrivilegeManager.instance.getProductData();
      if (productData == null) {
        debugPrint('❌ 无法获取商品数据');
        _emitPurchaseEvent(PurchaseEvent(
          type: PurchaseEventType.purchaseError,
          productId: 'unknown',
          basePlanId: basePlanId,
          message: 'Can not get product data',
        ));
        return false;
      }
      
      // 根据basePlanId查找对应的产品和基础计划
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
        _emitPurchaseEvent(PurchaseEvent(
          type: PurchaseEventType.purchaseError,
          productId: 'unknown',
          basePlanId: basePlanId,
          message: 'Can not find product or base plan',
        ));
        return false;
      }

      // 在此时 targetProduct 一定非空，提取产品ID
      productId = targetProduct.googlePlayProductId;

      // 预检：验证 Base Plan 在 Google Play 中确实存在且包含可用的优惠
      final isConfigValid = await validateBasePlanConfiguration(basePlanId);
      if (!isConfigValid) {
        BillingErrorHandler().logDeviceSpecificError(
          'Invalid base plan configuration',
          {
            'base_plan_id': basePlanId,
            'google_play_product_id': targetProduct.googlePlayProductId,
          },
        );
        _emitPurchaseEvent(PurchaseEvent(
          type: PurchaseEventType.purchaseError,
          productId: productId,
          basePlanId: basePlanId,
          message: 'Invalid base plan configuration',
        ));
        return false;
      }
      
      // 查询Google Play产品详情
      final ProductDetailsResponse response = await _inAppPurchase.queryProductDetails({targetProduct.googlePlayProductId});
  
      if (response.error != null) {
        _emitPurchaseEvent(PurchaseEvent(
          type: PurchaseEventType.purchaseError,
          productId: productId,
          basePlanId: basePlanId,
          message: 'Can not query product details',
        ));
        return false;
      }
      
      if (response.productDetails.isEmpty) {
        _emitPurchaseEvent(PurchaseEvent(
          type: PurchaseEventType.purchaseError,
          productId: productId,
          basePlanId: basePlanId,
          message: 'Can not find product details',
        ));
        return false;
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
              _emitPurchaseEvent(PurchaseEvent(
                type: PurchaseEventType.purchaseError,
                productId: productId,
                basePlanId: basePlanId,
                message: 'Has no available offer',
              ));
              return false;
            }

            // 使用找到的优惠Token创建购买参数
            // 额外防御：确保 offerIdToken 非空
            if (targetOffer.offerIdToken.isEmpty) {
              BillingErrorHandler().logDeviceSpecificError(
                'Empty offer token for subscription',
                {
                  'base_plan_id': basePlanId,
                  'offer_id': targetOffer.offerId,
                },
              );
              _emitPurchaseEvent(PurchaseEvent(
                type: PurchaseEventType.purchaseError,
                productId: productId,
                basePlanId: basePlanId,
                message: 'Invalid offer token',
              ));
              return false;
            }

            purchaseParam = GooglePlayPurchaseParam(
              productDetails: productDetails,
              offerToken: targetOffer.offerIdToken,
              applicationUserName: null,
              changeSubscriptionParam: null,
            );
            
          } else {
            _emitPurchaseEvent(PurchaseEvent(
              type: PurchaseEventType.purchaseError,
              productId: productId,
              basePlanId: basePlanId,
              message: 'Has no available offer',
            ));
            return false;
          }
        } else {
          _emitPurchaseEvent(PurchaseEvent(
            type: PurchaseEventType.purchaseError,
            productId: productId,
            basePlanId: basePlanId,
            message: 'Product type is not subscription',
          ));
          return false;
        }
      } else {
        // 处理一次性购买
        purchaseParam = PurchaseParam(productDetails: productDetails);
      }
      
      // 存储basePlanId，用于验证时传递
      _productBasePlanIds[productId] = basePlanId;
      
      // 使用 buyNonConsumable 购买订阅
      debugPrint('🛒 开始启动购买流程...');
      debugPrint('  - 产品ID: $productId');
      debugPrint('  - 基础计划ID: $basePlanId');
      debugPrint('  - 优惠Token: ${(purchaseParam as GooglePlayPurchaseParam?)?.offerToken ?? 'N/A'}');

      // 设备特定防御：拦截在高风险设备上的购买流程，避免 PendingIntent NPE 崩溃
      if (BillingErrorHandler().isHighRiskConfiguration) {
        debugPrint('⚠️ 检测到高风险设备配置，使用替代购买方案');
        BillingErrorHandler().logDeviceSpecificError(
          'High-risk device detected, using alternative purchase flow',
          {
            'product_id': productId,
            'base_plan_id': basePlanId,
            'manufacturer': BillingErrorHandler().deviceInfo?.manufacturer,
             'model': BillingErrorHandler().deviceInfo?.model,
          },
        );
        
        // 对于高风险设备，我们仍然尝试购买，但增加额外的错误处理
        try {
          // 添加延迟，给系统更多时间准备
          await Future.delayed(const Duration(milliseconds: 500));
          
          // 发送购买开始事件
          _emitPurchaseEvent(PurchaseEvent(
            type: PurchaseEventType.purchaseStarted,
            productId: productId,
            basePlanId: basePlanId,
            message: 'Purchase started (high-risk device)',
            metadata: {
              'offer_token': (purchaseParam as GooglePlayPurchaseParam?)?.offerToken,
              'is_high_risk_device': true,
            },
          ));
          
          final success = await _inAppPurchase.buyNonConsumable(purchaseParam: purchaseParam);
          
          if (!success) {
            debugPrint('❌ 高风险设备购买流程启动失败');
            _productBasePlanIds.remove(productId);
            _emitPurchaseEvent(PurchaseEvent(
              type: PurchaseEventType.purchaseError,
              productId: productId,
              basePlanId: basePlanId,
              message: 'Failed to launch billing flow on high-risk device',
            ));
            return false;
          }
          
          debugPrint('✅ 高风险设备购买流程已启动，等待用户操作...');
          return true;
          
        } catch (e) {
          debugPrint('❌ 高风险设备购买流程异常: $e');
          BillingErrorHandler().logDeviceSpecificError(
            'High-risk device purchase failed: $e',
            {
              'product_id': productId,
              'base_plan_id': basePlanId,
              'error': e.toString(),
            },
          );
          
          _emitPurchaseEvent(PurchaseEvent(
            type: PurchaseEventType.purchaseError,
            productId: productId,
            basePlanId: basePlanId,
            message: 'Purchase unavailable on this device configuration',
          ));
          return false;
        }
      }

      // 发送购买开始事件
      _emitPurchaseEvent(PurchaseEvent(
        type: PurchaseEventType.purchaseStarted,
        productId: productId,
        basePlanId: basePlanId,
        message: 'Purchase started',
        metadata: {
          'offer_token': (purchaseParam as GooglePlayPurchaseParam?)?.offerToken,
        },
      ));
      
      final success = await _inAppPurchase.buyNonConsumable(purchaseParam: purchaseParam);
      
      if (!success) {
        debugPrint('❌ 购买流程启动失败');
        _productBasePlanIds.remove(productId);
        _emitPurchaseEvent(PurchaseEvent(
          type: PurchaseEventType.purchaseError,
          productId: productId,
          basePlanId: basePlanId,
          message: 'Failed to launch billing flow',
        ));
        return false;
      }
      
      debugPrint('✅ 购买流程已启动，等待用户操作...');
      return true;
      
    } catch (e) {
      debugPrint('❌ 购买流程异常: $e');
      // 清理可能残留的 basePlanId
      if (productId != null) {
        _productBasePlanIds.remove(productId);
      }
      _emitPurchaseEvent(PurchaseEvent(
        type: PurchaseEventType.purchaseError,
        productId: productId ?? 'unknown',
        basePlanId: basePlanId,
        message: 'Purchase failed: $e',
      ));
      return false;
    }
  }

  // 发送购买事件的辅助方法
  void _emitPurchaseEvent(PurchaseEvent event) {
    if (!_purchaseEventController.isClosed) {
      _purchaseEventController.add(event);
    }
  }
  
  // 处理购买更新 - 通过Stream发送事件
  void _handlePurchaseUpdates(List<PurchaseDetails> purchaseDetailsList) {
    debugPrint('📦 收到购买状态更新，共 ${purchaseDetailsList.length} 个项目');
    
    for (final PurchaseDetails purchaseDetails in purchaseDetailsList) {
      debugPrint('[GooglePlayBillingService] 购买状态更新: ${purchaseDetails.status}');
      // 记录调试信息
      debugPrint('[GooglePlayBillingService]  - 产品ID: ${purchaseDetails.productID}');
      debugPrint('[GooglePlayBillingService]  - 购买令牌: ${purchaseDetails.verificationData.localVerificationData}');
      debugPrint('[GooglePlayBillingService]  - 购买时间: ${purchaseDetails.transactionDate}');
      
      // 检查是否存在错误信息
      if (purchaseDetails.error != null) {
        debugPrint('[GooglePlayBillingService]  - 错误信息: ${purchaseDetails.error}');
      }
      
      // 获取存储的basePlanId
      final basePlanId = _productBasePlanIds[purchaseDetails.productID] ?? '';
      
      switch (purchaseDetails.status) {
        case PurchaseStatus.pending:
          // 记录调试信息
          debugPrint('[GooglePlayBillingService]  - 购买状态: ${purchaseDetails.status}');
          _handlePendingPurchase(purchaseDetails);
          
          // 发送pending事件
          _emitPurchaseEvent(PurchaseEvent(
            type: PurchaseEventType.purchasePending,
            productId: purchaseDetails.productID,
            basePlanId: basePlanId,
            message: 'Purchase pending',
            purchaseDetails: purchaseDetails,
          ));
          break;
          
        case PurchaseStatus.purchased:
          debugPrint('[GooglePlayBillingService] ✅ 购买成功: ${purchaseDetails.productID}');
          // 异步处理购买成功，不在这里直接完成 completer
          _handlePurchaseWithVerification(purchaseDetails, 'Purchase success');
          break;
          
        case PurchaseStatus.error:
          debugPrint('[GooglePlayBillingService] ❌ 购买失败: ${purchaseDetails.error}');
          
          // 记录设备特定的购买错误
          BillingErrorHandler().logDeviceSpecificError(
            'Purchase failed: ${purchaseDetails.error}',
            {
              'product_id': purchaseDetails.productID,
              'error_code': purchaseDetails.error?.code,
              'error_message': purchaseDetails.error?.message,
              'purchase_status': purchaseDetails.status.toString(),
            },
          );
          
          _handleFailedPurchase(purchaseDetails);
          
          // 发送error事件
          final errorMessage = BillingErrorHandler().getDeviceSpecificErrorAdvice(
            purchaseDetails.error?.message ?? 'Unknown error'
          );
          _emitPurchaseEvent(PurchaseEvent(
            type: PurchaseEventType.purchaseError,
            productId: purchaseDetails.productID,
            basePlanId: basePlanId,
            message: errorMessage,
            purchaseDetails: purchaseDetails,
            metadata: {
              'error_code': purchaseDetails.error?.code,
              'error_message': purchaseDetails.error?.message,
            },
          ));
          break;
          
        case PurchaseStatus.canceled:
          debugPrint('[GooglePlayBillingService] ❌ 购买已取消: ${purchaseDetails.productID}');
          _handleCanceledPurchase(purchaseDetails);
          
          // 发送canceled事件
          _emitPurchaseEvent(PurchaseEvent(
            type: PurchaseEventType.purchaseCanceled,
            productId: purchaseDetails.productID,
            basePlanId: basePlanId,
            message: 'Purchase canceled',
            purchaseDetails: purchaseDetails,
          ));
          break;
          
        case PurchaseStatus.restored:
          debugPrint('[GooglePlayBillingService] ✅ 购买已恢复: ${purchaseDetails.productID}');
          // 异步处理购买恢复，不在这里直接完成 completer
          _handleRestoredPurchase(purchaseDetails);
          
          // 发送restored事件（可以复用success类型或新增restored类型）
          _emitPurchaseEvent(PurchaseEvent(
            type: PurchaseEventType.purchaseSuccess,
            productId: purchaseDetails.productID,
            basePlanId: basePlanId,
            message: 'Purchase restored',
            purchaseDetails: purchaseDetails,
            metadata: {
              'is_restored': true,
            },
          ));
          break;
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
  
  // 处理成功的购买或恢复的购买 - 通过Stream发送事件
  Future<void> _handlePurchaseWithVerification(PurchaseDetails purchaseDetails, String actionType) async {
    debugPrint('$actionType: ${purchaseDetails.productID}');
    
    // 获取存储的basePlanId
    final basePlanId = _productBasePlanIds[purchaseDetails.productID] ?? '';
    
    // 验证购买
    final verifyResult = await _verifyPurchase(purchaseDetails, basePlanId);
    
    if (verifyResult) {
      SubscribePrivilegeManager.instance.updateSubscribePrivilege();

      // 验证成功，发送成功事件
      _emitPurchaseEvent(PurchaseEvent(
        type: PurchaseEventType.purchaseSuccess,
        productId: purchaseDetails.productID,
        basePlanId: basePlanId,
        message: '$actionType and verified',
        purchaseDetails: purchaseDetails,
      ));
    } else {
      // 验证失败，发送失败事件
      _emitPurchaseEvent(PurchaseEvent(
        type: PurchaseEventType.purchaseFailed,
        productId: purchaseDetails.productID,
        basePlanId: basePlanId,
        message: '${actionType.toLowerCase()} verification failed',
        purchaseDetails: purchaseDetails,
      ));
    }
    
    // 清理basePlanId
    _productBasePlanIds.remove(purchaseDetails.productID);
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
  Future<bool> _verifyPurchase(PurchaseDetails purchaseDetails, String basePlanId) async {
    try {
      debugPrint('开始验证购买: ${purchaseDetails.productID}');
      debugPrint('使用传入的 basePlanId: $basePlanId');
      
      // 验证传入的 basePlanId 是否有效
      if (basePlanId.isEmpty) {
        debugPrint('验证购买失败: basePlanId 为空');
        return false;
      }
      
      debugPrint('验证购买: 产品 ${purchaseDetails.productID} 基础计划 $basePlanId');
      debugPrint('验证购买: 购买令牌 ${purchaseDetails.verificationData.serverVerificationData}');

      // 使用 SubscribeService 在业务服务器 验证购买并创建订阅记录
      final result = await SubscribeService.createGooglePlaySubscribe(
        productId: purchaseDetails.productID,
        basePlanId: basePlanId, // 使用找到的basePlanId
        purchaseToken: purchaseDetails.verificationData.serverVerificationData,
      );
      
      // 检查服务端返回的结果
      if (result.data == true) {
        debugPrint('✅ 购买验证成功: ${purchaseDetails.productID}');
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
    _subscription = null;
    _isInitialized = false;
    _purchaseEventController.close();
    _productBasePlanIds.clear();
    debugPrint('Google Play Billing服务已释放资源');
  }
}