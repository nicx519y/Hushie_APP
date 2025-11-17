import 'dart:async';
import 'package:flutter/material.dart';
import '../models/product_model.dart';
import '../services/auth_manager.dart';
import '../services/google_play_billing_service.dart';
import '../utils/toast_helper.dart';
import '../utils/toast_messages.dart';
import '../router/navigation_utils.dart';
import 'notification_dialog.dart';
import 'package:firebase_analytics/firebase_analytics.dart';
import '../services/analytics_service.dart';
import '../services/api/tracking_service.dart';

/// 基础订阅组件定义（用于逻辑复用）
abstract class SubscribeOptionsBase extends StatefulWidget {
  final Product? product;
  final int selectedPlan;
  final Function(int) onPlanSelected;
  final VoidCallback onSubscribeSuccess;
  final String? scene;

  const SubscribeOptionsBase({
    super.key,
    required this.product,
    required this.selectedPlan,
    required this.onPlanSelected,
    required this.onSubscribeSuccess,
    this.scene,
  });
}

/// 订阅成功提示的复用方法
void openSubscribeSuccessNotification(BuildContext context) {
  showNotificationDialog(
    context,
    title: 'Congratulations！',
    message: 'You have successfully activated Hushie Pro Membership.',
    buttonText: 'Enjoy It',
  );
}

/// SubscribeOptions 逻辑抽离为 mixin，供多个样式组件复用
mixin SubscribeOptionsLogic<T extends SubscribeOptionsBase> on State<T>, WidgetsBindingObserver {
  bool _isPurchasing = false;
  bool _isInPaymentProcess = false;
  StreamSubscription<PurchaseEvent>? _purchaseEventSubscription;

  // 对外公开的只读状态
  bool get isPurchasing => _isPurchasing;
  bool get isSelectedPlanSubscribing => widget.product?.basePlans[widget.selectedPlan].isSubscribing ?? false;
  bool get isSelectedPlanAvailable => widget.product?.basePlans[widget.selectedPlan].isAvailable ?? false;

  /// 获取选中计划的可用Offer，如果没有可用Offer则返回null
  Offer? get selectedPlanAvailableOffer {
    final basePlan = widget.product?.basePlans[widget.selectedPlan];
    if (basePlan == null) return null;
    try {
      return basePlan.offers.firstWhere((offer) => offer.isAvailable);
    } catch (_) {
      return null;
    }
  }

  /// 初始化逻辑（需在组件 initState 中调用）
  void initSubscribeOptionsLogic() {
    WidgetsBinding.instance.addObserver(this);
    _purchaseEventSubscription = GooglePlayBillingService.instance.purchaseEventStream.listen(
      _handlePurchaseEvent,
      onError: (error) => debugPrint('❌ 购买事件流监听错误: $error'),
    );
  }

  /// 销毁逻辑（需在组件 dispose 中调用）
  void disposeSubscribeOptionsLogic() {
    WidgetsBinding.instance.removeObserver(this);
    _purchaseEventSubscription?.cancel();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
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

  /// 对外方法：点击订阅入口
  Future<void> onSubscribe() async {
    debugPrint('SubscribeOptions onSubscribe selectedPlan: ${widget.selectedPlan}');

    try {
      TrackingService.trackSubscribeClickPay(scene: widget.scene ?? 'unknown');
    } catch (e) {
      debugPrint('📍 [TRACKING] subscribe_click_pay error: $e');
    }

    // 改成非登录状态下也能订阅 2025.11.17
    // final bool isLogin = await AuthManager.instance.isSignedIn();
    // if (!isLogin) {
    //   try {
    //     TrackingService.trackSubscribeClickLogin(scene: widget.scene ?? 'unknown');
    //   } catch (e) {
    //     debugPrint('📍 [TRACKING] subscribe_click_login error: $e');
    //   }
    //   if (mounted) {
    //     NavigationUtils.navigateToLogin(context);
    //   }
    //   return;
    // }

    // 已经在订阅中，不能重复订阅
    if (isSelectedPlanSubscribing) {
      ToastHelper.showInfo(ToastMessages.subscribingPleaseDonRepeat);
      return;
    }

    // 不可用 就是不能降级 已经订阅了更高级的计划
    if (!isSelectedPlanAvailable) {
      if (mounted) {
        showNotificationDialog(
          context,
          title: 'Notification',
          message: 'Hushie Pro is active in your subscription and does not support downgrades.',
          buttonText: 'Got It',
        );
      }
      return;
    }

    await _initiateGooglePlayBillingPurchase();
  }

  // 处理购买事件
  void _handlePurchaseEvent(PurchaseEvent event) {
    debugPrint('📦 收到购买事件: ${event.type} - ${event.productId}');

    switch (event.type) {
      case PurchaseEventType.purchaseStarted:
        debugPrint('🛒 购买开始: ${event.productId}');
        ToastHelper.showInfo(ToastMessages.subscriptionProcessing);
        if (mounted) {
          setState(() {
            _isInPaymentProcess = true;
            _isPurchasing = true;
          });
        }
        try {
          TrackingService.trackSubscribeFlowStart(
            productId: event.productId,
            basePlanId: event.basePlanId,
            scene: widget.scene ?? 'unknown',
          );
          // 自定义事件：订阅流程开始
          AnalyticsService().logCustomEvent(
            eventName: 'subscribe_flow_start',
            parameters: {
              'product_id': event.productId,
              if (event.basePlanId != null) 'base_plan_id': event.basePlanId!,
              if (widget.scene != null) 'scene': widget.scene!,
              'timestamp': DateTime.now().millisecondsSinceEpoch,
            },
          );
        } catch (e) {
          debugPrint('📍 [TRACKING] subscribe_flow_start error: $e');
        }
        break;

      case PurchaseEventType.purchasePending:
        debugPrint('⏳ 购买待处理: ${event.productId}');
        ToastHelper.showInfo(ToastMessages.subscriptionPending);
        if (mounted) {
          setState(() {
            _isInPaymentProcess = false;
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
    if (mounted) {
      setState(() {
        _isInPaymentProcess = false;
        _isPurchasing = false;
      });
    }

    try {
      final purchaseDetails = event.purchaseDetails;
      final rawProductId = widget.product?.googlePlayProductId ?? '';
      final rawCurrency = selectedPlanAvailableOffer?.currency ?? widget.product?.basePlans[widget.selectedPlan].currency;
      final rawValue = selectedPlanAvailableOffer?.price ?? widget.product?.basePlans[widget.selectedPlan].price ?? 0.0;
      final offerId = selectedPlanAvailableOffer?.offerId;
      final purchaseToken = purchaseDetails?.verificationData.serverVerificationData;

      final String productId = rawProductId.isNotEmpty ? rawProductId : 'unknown_product';
      final String currency = (rawCurrency != null && rawCurrency.length == 3) ? rawCurrency : 'USD';
      final double value = double.tryParse('$rawValue') ?? 0.0;
      final String itemName = selectedPlanAvailableOffer?.name ?? widget.product?.basePlans[widget.selectedPlan].name ?? widget.product?.name ?? 'subscription';
      const int quantity = 1;

      FirebaseAnalytics.instance.logPurchase(
        currency: currency,
        value: value,
        transactionId: (purchaseToken != null && purchaseToken.isNotEmpty) ? purchaseToken : null,
        items: [
          AnalyticsEventItem(
            itemId: productId,
            itemName: itemName,
            price: value,
            quantity: quantity,
          ),
        ],
      );

      AnalyticsService().logCustomEvent(
        eventName: 'in_app_purchase',
        parameters: {
          'value': value,
          'currency': currency,
          'price': value,
          'quantity': quantity,
          if (purchaseToken != null && purchaseToken.isNotEmpty) 'transaction_id': purchaseToken,
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
        // 自定义事件：订阅成功
        AnalyticsService().logCustomEvent(
          eventName: 'subscribe_result_success',
          parameters: {
            'status': 'success',
            'product_id': productId,
            if (event.basePlanId != null) 'base_plan_id': event.basePlanId!,
            if (offerId != null) 'offer_id': offerId,
            if (purchaseToken != null && purchaseToken.isNotEmpty) 'purchase_token': purchaseToken,
            'currency': currency,
            'price': value,
            'timestamp': DateTime.now().millisecondsSinceEpoch,
          },
        );
      } catch (e) {
        debugPrint('📍 [TRACKING] subscribe_result success error: $e');
      }
    } catch (e) {
      debugPrint('📊 [ANALYTICS] 手动上报 in_app_purchase 失败: $e');
    }

    widget.onSubscribeSuccess();
  }

  // 处理购买失败
  void _handlePurchaseFailure(PurchaseEvent event) {
    if (mounted) {
      setState(() {
        _isInPaymentProcess = false;
        _isPurchasing = false;
      });
    }

    ToastHelper.showError(event.message ?? ToastMessages.subscriptionFailed);

    try {
      TrackingService.trackSubscribeResult(
        status: 'failed',
        productId: event.productId,
        basePlanId: event.basePlanId,
        offerId: selectedPlanAvailableOffer?.offerId,
        errorMessage: event.message,
      );
      // 自定义事件：订阅失败
      AnalyticsService().logCustomEvent(
        eventName: 'subscribe_result_failed',
        parameters: {
          'status': 'failed',
          'product_id': event.productId,
          if (event.basePlanId != null) 'base_plan_id': event.basePlanId!,
          if (selectedPlanAvailableOffer?.offerId != null) 'offer_id': selectedPlanAvailableOffer!.offerId,
          if (event.message != null) 'error_message': event.message!,
          'timestamp': DateTime.now().millisecondsSinceEpoch,
        },
      );
    } catch (e) {
      debugPrint('📍 [TRACKING] subscribe_result failed error: $e');
    }
  }

  // 处理购买取消
  void _handlePurchaseCanceled(PurchaseEvent event) {
    if (mounted) {
      setState(() {
        _isInPaymentProcess = false;
        _isPurchasing = false;
      });
    }

    ToastHelper.showInfo(ToastMessages.subscriptionCanceled);

    try {
      TrackingService.trackSubscribeResult(
        status: 'canceled',
        productId: event.productId,
        basePlanId: event.basePlanId,
        offerId: selectedPlanAvailableOffer?.offerId,
      );
      // 自定义事件：订阅取消
      AnalyticsService().logCustomEvent(
        eventName: 'subscribe_result_canceled',
        parameters: {
          'status': 'canceled',
          'product_id': event.productId,
          if (event.basePlanId != null) 'base_plan_id': event.basePlanId!,
          if (selectedPlanAvailableOffer?.offerId != null) 'offer_id': selectedPlanAvailableOffer!.offerId,
          'timestamp': DateTime.now().millisecondsSinceEpoch,
        },
      );
    } catch (e) {
      debugPrint('📍 [TRACKING] subscribe_result canceled error: $e');
    }
  }

  // 处理购买错误
  void _handlePurchaseError(PurchaseEvent event) {
    if (mounted) {
      setState(() {
        _isInPaymentProcess = false;
        _isPurchasing = false;
      });
    }

    ToastHelper.showError(event.message ?? ToastMessages.subscriptionFailed);

    try {
      TrackingService.trackSubscribeResult(
        status: 'failed',
        productId: event.productId,
        basePlanId: event.basePlanId,
        offerId: selectedPlanAvailableOffer?.offerId,
        errorMessage: event.message,
      );
      // 自定义事件：订阅错误（按失败归类）
      AnalyticsService().logCustomEvent(
        eventName: 'subscribe_result_failed',
        parameters: {
          'status': 'failed',
          'product_id': event.productId,
          if (event.basePlanId != null) 'base_plan_id': event.basePlanId!,
          if (selectedPlanAvailableOffer?.offerId != null) 'offer_id': selectedPlanAvailableOffer!.offerId,
          if (event.message != null) 'error_message': event.message!,
          'timestamp': DateTime.now().millisecondsSinceEpoch,
        },
      );
    } catch (e) {
      debugPrint('📍 [TRACKING] subscribe_result error error: $e');
    }
  }

  /// 启动Google Play Billing购买流程
  Future<void> _initiateGooglePlayBillingPurchase() async {
    if (widget.product == null) {
      ToastHelper.showError(ToastMessages.productConfigError);
      return;
    }
    if (widget.selectedPlan < 0 || widget.selectedPlan >= (widget.product!.basePlans.length)) {
      ToastHelper.showError(ToastMessages.productConfigError);
      return;
    }

    try {
      ToastHelper.showInfo(ToastMessages.subscriptionInitializing);

      final billingService = GooglePlayBillingService.instance;
      final isInitialized = await billingService.initialize();
      if (!isInitialized) {
        ToastHelper.showError(ToastMessages.billingServiceUnavailable);
        return;
      }

      final basePlans = widget.product?.basePlans ?? const <BasePlan>[];
      final BasePlan? basePlan =
          (widget.selectedPlan >= 0 && widget.selectedPlan < basePlans.length)
              ? basePlans[widget.selectedPlan]
              : null;
      final String basePlanId = basePlan?.googlePlayBasePlanId ?? '';

      debugPrint('📦 [SUBSCRIBE_LOGIC] product=${widget.product?.googlePlayProductId}, selectedPlan=${widget.selectedPlan}, basePlans=${basePlans.length}, basePlanId=$basePlanId');

      if (basePlanId.isEmpty) {
        ToastHelper.showError(ToastMessages.productConfigError);
        return;
      }

      final availableOffer = selectedPlanAvailableOffer;
      String? offerToken;
      if (availableOffer != null) {
        offerToken = availableOffer.offerId;
        debugPrint('  - 可用优惠: ${availableOffer.name} (${availableOffer.offerId})');
      } else {
        debugPrint('  - 无可用优惠');
      }

      try {
        ToastHelper.showInfo(ToastMessages.subscriptionProcessing);
        debugPrint('  - 最终购买参数: basePlanId="$basePlanId", offerToken="$offerToken"');

        final purchaseStarted = await billingService.purchaseProduct(
          basePlanId,
          offerToken: offerToken,
        );

        if (!purchaseStarted) {
          debugPrint('❌ 购买流程启动失败');
          if (mounted) {
            setState(() {
              _isInPaymentProcess = false;
              _isPurchasing = false;
            });
          }
        }
      } catch (e) {
        debugPrint('Google Play Billing购买异常: $e');
        if (mounted) {
          setState(() {
            _isInPaymentProcess = false;
            _isPurchasing = false;
          });
        }
        ToastHelper.showError(ToastMessages.subscriptionException);
        try {
          TrackingService.trackSubscribeResult(
            status: 'failed',
            productId: widget.product?.googlePlayProductId ?? 'unknown_product',
            basePlanId: basePlanId,
            offerId: selectedPlanAvailableOffer?.offerId,
            errorMessage: e.toString(),
          );
          // 自定义事件：订阅异常（按失败归类）
          AnalyticsService().logCustomEvent(
            eventName: 'subscribe_result_failed',
            parameters: {
              'status': 'failed',
              'product_id': widget.product?.googlePlayProductId ?? 'unknown_product',
              if (basePlanId.isNotEmpty) 'base_plan_id': basePlanId,
              if (selectedPlanAvailableOffer?.offerId != null) 'offer_id': selectedPlanAvailableOffer!.offerId,
              'error_message': e.toString(),
              'timestamp': DateTime.now().millisecondsSinceEpoch,
            },
          );
        } catch (e) {
          debugPrint('📍 [TRACKING] subscribe_result exception error: $e');
        }
      }
    } catch (e) {
      debugPrint('Google Play Billing购买失败: $e');
      if (mounted) {
        setState(() {
          _isInPaymentProcess = false;
          _isPurchasing = false;
        });
      }
      final errorMessage = ToastMessages.getBillingErrorMessage(e);
      ToastHelper.showError(errorMessage);
    }
  }
}