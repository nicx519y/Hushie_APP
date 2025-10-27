import 'package:flutter/material.dart';
import 'package:hushie_app/services/auth_manager.dart';
import '../components/notification_dialog.dart';
import '../utils/custom_icons.dart';
import '../utils/currency_formatter.dart';
import '../models/product_model.dart';
import '../services/google_play_billing_service.dart';
import '../utils/toast_helper.dart';
import '../utils/toast_messages.dart';
import '../router/navigation_utils.dart';
import '../utils/webview_navigator.dart';
import 'package:firebase_analytics/firebase_analytics.dart';
import '../services/analytics_service.dart';
import '../services/api/tracking_service.dart';
import 'dart:async';

// 订阅成功提示的复用方法
void openSubscribeSuccessNotification(BuildContext context) {
  showNotificationDialog(
    context,
    title: 'Congratulations！',
    message: 'You have successfully activated Hushie Pro Membership.',
    buttonText: 'Enjoy It',
  );
}

class SubscribeOptions extends StatefulWidget {
  final Product? product;
  final int selectedPlan;
  final Function(int) onPlanSelected;
  final VoidCallback onSubscribeSuccess;
  final String? scene;

  const SubscribeOptions({
    super.key,
    required this.product,
    required this.selectedPlan,
    required this.onPlanSelected,
    required this.onSubscribeSuccess,
    this.scene,
  });

  @override
  State<SubscribeOptions> createState() => _SubscribeOptionsState();
}

class _SubscribeOptionsState extends State<SubscribeOptions> with WidgetsBindingObserver {
  bool _isPurchasing = false;
  bool _isInPaymentProcess = false; // 明确标识是否在支付进程中
  StreamSubscription<PurchaseEvent>? _purchaseEventSubscription;

  @override
  void initState() {
    super.initState();
    // 添加应用生命周期监听
    WidgetsBinding.instance.addObserver(this);
    
    // 监听购买事件流
    _purchaseEventSubscription = GooglePlayBillingService.instance.purchaseEventStream.listen(
      _handlePurchaseEvent,
      onError: (error) {
        debugPrint('❌ 购买事件流监听错误: $error');
      },
    );
  }

  @override
  void dispose() {
    // 移除应用生命周期监听
    WidgetsBinding.instance.removeObserver(this);
    // 取消购买事件流监听
    _purchaseEventSubscription?.cancel();
    super.dispose();
  }

  // 处理购买事件
  void _handlePurchaseEvent(PurchaseEvent event) {
    debugPrint('📦 收到购买事件: ${event.type} - ${event.productId}');
    
    // 只处理当前产品的事件
    if (event.productId != widget.product?.googlePlayProductId) {
      return;
    }
    
    switch (event.type) {
      case PurchaseEventType.purchaseStarted:
        debugPrint('🛒 购买开始: ${event.productId}');
        // 显示加载状态
        ToastHelper.showInfo(ToastMessages.subscriptionProcessing);
        
        // 标记进入支付进程和购买状态
        if (mounted) {
          setState(() {
            _isInPaymentProcess = true;
            _isPurchasing = true;
          });
        }
        
        // 打点统计 - 购买流程开始
        try {
          TrackingService.trackSubscribeFlowStart(
            productId: event.productId,
            basePlanId: event.basePlanId,
            scene: widget.scene ?? 'unknown',
          );
        } catch (e) {
          debugPrint('📍 [TRACKING] subscribe_flow_start error: $e');
        }
        break;
        
      case PurchaseEventType.purchasePending:
        debugPrint('⏳ 购买待处理: ${event.productId}');
        ToastHelper.showInfo(ToastMessages.subscriptionPending);
        
        // 支付进程结束，但保持购买状态
        if (mounted) {
          setState(() {
            _isInPaymentProcess = false;
            // _isPurchasing 保持 true，因为还在等待最终结果
          });
        }
        break;
        
      case PurchaseEventType.purchaseSuccess:
        debugPrint('✅ 购买成功: ${event.productId}');
        _handlePurchaseSuccess(event);
        break;
        
      case PurchaseEventType.purchaseFailed:
        debugPrint('❌ 购买失败: ${event.productId} - ${event.message}');
        _handlePurchaseFailure(event);
        break;
        
      case PurchaseEventType.purchaseCanceled:
        debugPrint('❌ 购买取消: ${event.productId}');
        _handlePurchaseCanceled(event);
        break;
        
      case PurchaseEventType.purchaseError:
        debugPrint('❌ 购买错误: ${event.productId} - ${event.message}');
        _handlePurchaseError(event);
        break;
    }
  }
  
  // 处理购买成功
  void _handlePurchaseSuccess(PurchaseEvent event) {
    // 支付进程结束，重置状态
    if (mounted) {
      setState(() {
        _isInPaymentProcess = false;
        _isPurchasing = false;
      });
    }
    
    try {
      // 手动上报 in_app_purchase 事件（Android 手动补充）
      final purchaseDetails = event.purchaseDetails;
      // 原始字段
      final rawProductId = widget.product?.googlePlayProductId ?? '';
      final rawCurrency = _selectedPlanAvailableOffer?.currency ?? widget.product?.basePlans[widget.selectedPlan].currency;
      final rawValue = _selectedPlanAvailableOffer?.price ?? widget.product?.basePlans[widget.selectedPlan].price ?? 0.0;
      final offerId = _selectedPlanAvailableOffer?.offerId;
      final purchaseToken = purchaseDetails?.verificationData.serverVerificationData;

      // 规范化：确保 GA4 所需类型与格式
      final String productId = rawProductId.isNotEmpty ? rawProductId : 'unknown_product';
      final String currency = (rawCurrency != null && rawCurrency.length == 3)
          ? rawCurrency
          : 'USD';
      final double value = double.tryParse('$rawValue') ?? 0.0;
      final String itemName = _selectedPlanAvailableOffer?.name ?? widget.product?.basePlans[widget.selectedPlan].name ?? widget.product?.name ?? 'subscription';
      const int quantity = 1;

      // 使用 FirebaseAnalytics 的标准 purchase 事件
      FirebaseAnalytics.instance.logPurchase(
        currency: currency,
        value: value,
        transactionId: (purchaseToken != null && purchaseToken.isNotEmpty)
            ? purchaseToken
            : null,
        items: [
          AnalyticsEventItem(
            itemId: productId,
            itemName: itemName,
            price: value,
            quantity: quantity,
          ),
        ],
      );

      // 保留自定义 in_app_purchase 事件的手动上报（用于 DebugView 可见性与核对）
      AnalyticsService().logCustomEvent(
        eventName: 'in_app_purchase',
        parameters: {
          'value': value,
          'currency': currency,
          'price': value,
          'quantity': quantity,
          if (purchaseToken != null && purchaseToken.isNotEmpty)
            'transaction_id': purchaseToken,
          'items': [
            {
              'item_id': productId,
              'item_name': itemName,
              'price': value,
              'quantity': quantity,
            }
          ],
          'product_id': productId,
          'base_plan_id': event.basePlanId,
          if (offerId != null) 'offer_id': offerId,
          'source': 'client_manual',
        },
      );

      // 订阅结果打点（成功）
      try {
        TrackingService.trackSubscribeResult(
          status: 'success',
          productId: productId,
          basePlanId: event.basePlanId,
          offerId: offerId,
          purchaseToken: purchaseToken,
          currency: currency,
          price: '$value',
        );
      } catch (e) {
        debugPrint('📍 [TRACKING] subscribe_result success error: $e');
      }
    } catch (e) {
      debugPrint('📊 [ANALYTICS] 手动上报 in_app_purchase 失败: $e');
    }

    // 购买成功，调用成功回调
    widget.onSubscribeSuccess();
  }
  
  // 处理购买失败
  void _handlePurchaseFailure(PurchaseEvent event) {
    // 支付进程结束，重置状态
    if (mounted) {
      setState(() {
        _isInPaymentProcess = false;
        _isPurchasing = false;
      });
    }
    
    ToastHelper.showError(event.message ?? ToastMessages.subscriptionFailed);
    
    // 订阅结果打点（失败）
    try {
      TrackingService.trackSubscribeResult(
        status: 'failed',
        productId: event.productId,
        basePlanId: event.basePlanId,
        offerId: _selectedPlanAvailableOffer?.offerId,
        errorMessage: event.message,
      );
    } catch (e) {
      debugPrint('📍 [TRACKING] subscribe_result failed error: $e');
    }
  }
  
  // 处理购买取消
  void _handlePurchaseCanceled(PurchaseEvent event) {
    // 支付进程结束，重置状态
    if (mounted) {
      setState(() {
        _isInPaymentProcess = false;
        _isPurchasing = false;
      });
    }
    
    ToastHelper.showInfo(ToastMessages.subscriptionCanceled);
    
    // 订阅结果打点（取消）
    try {
      TrackingService.trackSubscribeResult(
        status: 'canceled',
        productId: event.productId,
        basePlanId: event.basePlanId,
        offerId: _selectedPlanAvailableOffer?.offerId,
      );
    } catch (e) {
      debugPrint('📍 [TRACKING] subscribe_result canceled error: $e');
    }
  }
  
  // 处理购买错误
  void _handlePurchaseError(PurchaseEvent event) {
    // 支付进程结束，重置状态
    if (mounted) {
      setState(() {
        _isInPaymentProcess = false;
        _isPurchasing = false;
      });
    }
    
    ToastHelper.showError(event.message ?? ToastMessages.subscriptionFailed);
    
    // 订阅结果打点（错误归为失败）
    try {
      TrackingService.trackSubscribeResult(
        status: 'failed',
        productId: event.productId,
        basePlanId: event.basePlanId,
        offerId: _selectedPlanAvailableOffer?.offerId,
        errorMessage: event.message,
      );
    } catch (e) {
      debugPrint('📍 [TRACKING] subscribe_result error error: $e');
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);
    
    // 当应用从后台恢复到前台时，只有在非支付进程中才重置购买状态
    if (state == AppLifecycleState.resumed && _isPurchasing && !_isInPaymentProcess) {
      debugPrint('🔄 应用恢复到前台，用户可能取消了支付，重置购买状态');
      if (mounted) {
        setState(() {
          _isPurchasing = false;
        });
      }
    }
  }

  void _onSubscribe() async {
    debugPrint('SubscribeOptions _onSubscribe selectedPlan: ${widget.selectedPlan}');

    final bool isLogin = await AuthManager.instance.isSignedIn();
    if (!isLogin) {
      try {
        TrackingService.trackSubscribeClickLogin(scene: widget.scene ?? 'unknown');
      } catch (e) {
        debugPrint('📍 [TRACKING] subscribe_click_login error: $e');
      }
      if (mounted) {
        NavigationUtils.navigateToLogin(context);
      }
      return;
    }

    // 已经在订阅中，不能重复订阅
    if (_isSelectedPlanSubscribing) {
      ToastHelper.showInfo(ToastMessages.subscribingPleaseDonRepeat);
      return;
    }

    // 不可用 就是不能降级 已经订阅了更高级的计划
    if (!_isSelectedPlanAvailable) {
      if (mounted) {
        showNotificationDialog(
          context,
          title: 'Notification',
          message:
              'Hushie Pro is active in your subscription and does not support downgrades.',
          buttonText: 'Got It',
        );
      }
      return;
    }

    try {
      TrackingService.trackSubscribeClickPay(scene: widget.scene ?? 'unknown');
    } catch (e) {
      debugPrint('📍 [TRACKING] subscribe_click_pay error: $e');
    }

    // 启动Google Play Billing支付流程
    await _initiateGooglePlayBillingPurchase();
  }

  /// 启动Google Play Billing购买流程
  Future<void> _initiateGooglePlayBillingPurchase() async {
    // 基本防御：商品或选中计划不可用则直接提示并返回
    if (widget.product == null) {
      ToastHelper.showError(ToastMessages.productConfigError);
      return;
    }
    if (widget.selectedPlan < 0 || widget.selectedPlan >= (widget.product!.basePlans.length)) {
      ToastHelper.showError(ToastMessages.productConfigError);
      return;
    }

    try {
      // 显示加载状态
      ToastHelper.showInfo(ToastMessages.subscriptionInitializing);

      // 获取Google Play Billing服务实例
      final billingService = GooglePlayBillingService.instance;

      // 初始化服务
      final isInitialized = await billingService.initialize();
      if (!isInitialized) {
        ToastHelper.showError(ToastMessages.billingServiceUnavailable);
        return;
      }

      // 获取产品信息（加固空值与越界）
      final basePlans = widget.product?.basePlans ?? const <BasePlan>[];
      final BasePlan? basePlan =
          (widget.selectedPlan >= 0 && widget.selectedPlan < basePlans.length)
              ? basePlans[widget.selectedPlan]
              : null;
      final String basePlanId = basePlan?.googlePlayBasePlanId ?? '';

      debugPrint('📦 [SUBSCRIBE_OPTIONS] product=${widget.product?.googlePlayProductId}, selectedPlan=${widget.selectedPlan}, basePlans=${basePlans.length}, basePlanId=$basePlanId');

      if (basePlanId.isEmpty) {
        ToastHelper.showError(ToastMessages.productConfigError);
        return;
      }

      // 获取可用优惠
      final availableOffer = _selectedPlanAvailableOffer;
      String? offerToken;

      if (availableOffer != null) {
        offerToken = availableOffer.offerId;
        debugPrint(
          '  - 可用优惠: ${availableOffer.name} (${availableOffer.offerId})',
        );
      } else {
        debugPrint('  - 无可用优惠');
      }

      if (basePlanId.isEmpty) {
        ToastHelper.showError(ToastMessages.productConfigError);
        return;
      }



      try {
        // 显示加载状态
        ToastHelper.showInfo(ToastMessages.subscriptionProcessing);

        // 发起购买 - 修复：使用basePlanId作为第一个参数
        debugPrint(
          '  - 最终购买参数: basePlanId="$basePlanId", offerToken="$offerToken"',
        );

        final purchaseStarted = await billingService.purchaseProduct(
          basePlanId,
          offerToken: offerToken,
        );

        if (!purchaseStarted) {
          debugPrint('❌ 购买流程启动失败');
          // 如果购买流程启动失败，重置状态
          if (mounted) {
            setState(() {
              _isInPaymentProcess = false;
              _isPurchasing = false;
            });
          }
        }
        // 注意：购买结果现在通过 Stream 事件处理，不需要在这里处理结果
      } catch (e) {
        debugPrint('Google Play Billing购买异常: $e');
        // 支付进程结束，重置状态
        // 如果购买流程启动失败，重置状态
        if (mounted) {
          setState(() {
            _isInPaymentProcess = false;
            _isPurchasing = false;
          });
        }
        ToastHelper.showError(ToastMessages.subscriptionException);
        // 订阅结果打点（异常归为失败）
        try {
          TrackingService.trackSubscribeResult(
            status: 'failed',
            productId: widget.product?.googlePlayProductId ?? 'unknown_product',
            basePlanId: basePlanId,
            offerId: _selectedPlanAvailableOffer?.offerId,
            errorMessage: e.toString(),
          );
        } catch (e) {
          debugPrint('📍 [TRACKING] subscribe_result exception error: $e');
        }
      }
    } catch (e) {
      debugPrint('Google Play Billing购买失败: $e');

      // 如果购买流程启动失败，重置状态
      if (mounted) {
        setState(() {
          _isInPaymentProcess = false;
          _isPurchasing = false;
        });
      }

      // 使用统一的错误消息处理
      final errorMessage = ToastMessages.getBillingErrorMessage(e);
      ToastHelper.showError(errorMessage);
      
    }
  }

  bool get _isSelectedPlanSubscribing {
    return widget.product?.basePlans[widget.selectedPlan].isSubscribing ?? false;
  }

  bool get _isSelectedPlanAvailable {
    return widget.product?.basePlans[widget.selectedPlan].isAvailable ?? false;
  }

  /// 获取选中计划的可用Offer，如果没有可用Offer则返回null
  Offer? get _selectedPlanAvailableOffer {
    final basePlan = widget.product?.basePlans[widget.selectedPlan];
    if (basePlan == null) return null;
    try {
      return basePlan.offers.firstWhere((offer) => offer.isAvailable);
    } catch (e) {
      return null;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // 价格选项
        Column(
          children: (widget.product?.basePlans ?? const <BasePlan>[])
              .asMap()
              .entries
              .expand(
                (entry) => [
                  _buildPriceOption(
                    planIndex: entry.key,
                    basePlan: entry.value,
                  ),
                  if (entry.key < ((widget.product?.basePlans.length ?? 0) - 1))
                    const SizedBox(height: 18),
                ],
              )
              .toList(),
        ),

        const SizedBox(height: 17),

        // 订阅按钮
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 0),
          child: SizedBox(
            width: double.infinity,
            height: 44,
            child: ElevatedButton(
              onPressed: _isPurchasing ? null : _onSubscribe,
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFFFDE69),
                foregroundColor: Colors.black,
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(28),
                ),
              ),
              child: Text(
                (_isPurchasing || _isSelectedPlanSubscribing
                      ? 'Subscribing'
                      : 'Subscribe'),
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w700,
                  color: const Color(0xFF502D19),
                ),
              ),
            ),
          ),
        ),

        const SizedBox(height: 13),

        // 自动续费说明
        InkWell(
          onTap: () => WebViewNavigator.showAutoRenewInfo(context, clearCache: true), 
          child: Text(
            'Auto-renews monthly. Cancel anytime.',
            style: TextStyle(
              fontSize: 14, 
              color: Color(0xFF666666),
              decoration: TextDecoration.none,
            ),
          ),
        ),

        const SizedBox(height: 16),

        // 底部链接
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            InkWell(
              onTap: () => WebViewNavigator.showPrivacyPolicy(context, clearCache: true),
              child: Text(
                'Privacy Policy',
                style: TextStyle(
                  fontSize: 14,
                  color: const Color(0xFF666666),
                  decoration: TextDecoration.none,
                ),
              ),
            ),
            InkWell(
              onTap: () => WebViewNavigator.showTermsOfUse(context, clearCache: true),
              child: Text(
                'Terms of Use',
                style: TextStyle(
                  fontSize: 14,
                  color: const Color(0xFF666666),
                  decoration: TextDecoration.none,
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildPriceOption({
    required int planIndex,
    required BasePlan basePlan,
  }) {
    final bool isSelected = widget.selectedPlan == planIndex;

    // 查找可用的 offer
    Offer? availableOffer;
    try {
      availableOffer = basePlan.offers.firstWhere((offer) => offer.isAvailable);
    } catch (e) {
      availableOffer = null;
    }

    debugPrint(
      'planIndex: $planIndex, basePlan: ${basePlan.name}, availableOffer: ${availableOffer?.name}',
    );

    // 决定显示的名称和价格信息
    final String displayName;
    final double displayPrice;
    final double displayOriginalPrice;
    final String displayCurrency;

    if (availableOffer != null) {
      // 使用 offer 的情况
      displayName = availableOffer.name;
      displayPrice = availableOffer.price;
      displayOriginalPrice = availableOffer.originalPrice <= displayPrice
          ? basePlan.originalPrice
          : availableOffer
                .originalPrice; // 如果 offer 的 originalPrice 不正确 则显示basePlan的originalPrice
      displayCurrency = availableOffer.currency;
    } else {
      // 使用基础计划的情况
      displayName = basePlan.name;
      displayPrice = basePlan.price;
      displayOriginalPrice = basePlan.originalPrice;
      displayCurrency = basePlan.currency;
    }

    String? getDiscountText() {
      if (basePlan.isShowDiscount && displayOriginalPrice > displayPrice) {
        return '${((displayOriginalPrice - displayPrice) / displayOriginalPrice * 100).toStringAsFixed(0)}% OFF';
      }
      return null;
    }

    return GestureDetector(
      onTap: () => widget.onPlanSelected(planIndex),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        height: 60,
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFFFAF1D8) : Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isSelected
                ? const Color(0xFFFFAA00)
                : const Color(0xFFCCCCCC),
            width: 1,
          ),
        ),
        child: Row(
          children: [
            Icon(
              CustomIcons.checked,
              color: isSelected
                  ? const Color(0xFF934A06)
                  : const Color(0xFFCCCCCC),
              size: 16,
            ),

            const SizedBox(width: 8),

            Text(
              displayName,
              style: const TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w700,
                color: Colors.black,
              ),
            ),
            Expanded(
              child:
                  (basePlan.isShowDiscount &&
                      getDiscountText() != null)
                  ? Center(
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: const Color(0xFFFF5712),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(
                          getDiscountText() ?? '',
                          maxLines: 1,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 14,
                            fontWeight: FontWeight.w400,
                          ),
                        ),
                      ),
                    )
                  : Container(),
            ),

            const SizedBox(width: 8),

            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.start,
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    const SizedBox(width: 1.6),
                    Text(
                      CurrencyFormatter.formatPrice(
                        displayPrice,
                        displayCurrency,
                      ),
                      style: const TextStyle(
                        fontSize: 20,
                        height: 1,
                        fontWeight: FontWeight.w700,
                        color: Colors.black,
                      ),
                    ),
                  ],
                ),
                Text(
                  CurrencyFormatter.formatPrice(
                    displayOriginalPrice,
                    displayCurrency,
                  ),
                  style: TextStyle(
                    fontSize: 14,
                    height: 1.6,
                    color: const Color(0xFF999999),
                    decoration: TextDecoration.lineThrough,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}