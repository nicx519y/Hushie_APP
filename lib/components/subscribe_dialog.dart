import 'package:flutter/material.dart';
import 'package:hushie_app/services/auth_manager.dart';
import '../components/notification_dialog.dart';
import 'dart:async';
import 'slide_up_overlay.dart';
import '../utils/custom_icons.dart';
import '../utils/currency_formatter.dart';
import '../models/product_model.dart';
import '../services/dialog_state_manager.dart';
import '../services/google_play_billing_service.dart';
import '../services/subscribe_privilege_manager.dart';
import '../utils/toast_helper.dart';
import '../utils/toast_messages.dart';
import '../router/navigation_utils.dart';
import '../utils/webview_navigator.dart';
import 'package:firebase_analytics/firebase_analytics.dart';
import '../services/analytics_service.dart';
import '../services/api/tracking_service.dart';

class SubscribeDialog extends StatefulWidget {
  final VoidCallback? onSubscribe;

  const SubscribeDialog({super.key, this.onSubscribe});

  @override
  State<SubscribeDialog> createState() => _SubscribeDialogState();
}

class _SubscribeDialogState extends State<SubscribeDialog> {
  int _selectedPlan = 0; // 0: First Month, 1: Per year
  Product? _product; // 从服务获取的商品数据
  bool _isLoading = true; // 数据加载状态
  bool _isPurchasing = false; // 购买进行中状态

  @override
  void initState() {
    super.initState();
    _sendOpenTracking();
    _loadProductData();
  }

  /// 订阅弹窗打开时上报一次打点
  void _sendOpenTracking() {
    try {
      TrackingService.track(actionType: 'subscribe_dialog_open');
      debugPrint('📍 [TRACKING] subscribe_dialog_open');
    } catch (e) {
      debugPrint('📍 [TRACKING] subscribe_dialog_open error: $e');
    }
  }

  /// 从 SubscribePrivilegeManager 获取商品数据
  Future<void> _loadProductData() async {
    try {
      final productData = await SubscribePrivilegeManager.instance
          .getProductData(forceRefresh: false); // 不强制刷新，使用缓存数据
      if (productData != null && productData.products.isNotEmpty) {
        // 获取第一个订阅类型的商品，或者使用第一个商品
        final subscriptionProducts = productData.products
            .where((product) => product.productType == 'subscription')
            .toList();

        if (subscriptionProducts.isNotEmpty) {
          _product = subscriptionProducts.first;
        } else if (productData.products.isNotEmpty) {
          _product = productData.products.first;
        }
      }

      // 如果没有获取到商品数据，使用默认的 sampleProduct
    } catch (e) {
      debugPrint('🏆 [SUBSCRIBE_DIALOG] 获取商品数据失败: $e');
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  void _closeDialog() {
    Navigator.of(context, rootNavigator: true).pop();
  }

  // 打开成功提示框
  void _openSuccessNotification() {
    showNotificationDialog(
      context,
      title: 'Congratulations！',
      message: 'You have successfully activated Hushie Pro Membership.',
      buttonText: 'Enjoy It',
    );
  }


  @override
  void dispose() {
    // 清除弹窗状态标志
    DialogStateManager.instance.closeDialog(DialogStateManager.subscribeDialog);
    super.dispose();
  }

  void _onSubscribe() async {
    debugPrint('SubscribeDialog _onSubscribe selectedPlan: $_selectedPlan');
    
    final isLogin = await AuthManager.instance.isSignedIn();

    if (!isLogin) {
      NavigationUtils.navigateToLogin(context);
      return;
    }

    // 已经在订阅中，不能重复订阅
    if (_isSelectedPlanSubscribing) {
      // _closeDialog();
      ToastHelper.showInfo(ToastMessages.subscribingPleaseDonRepeat);
      return;
    }

    // 不可用 就是不能降级 已经订阅了更高级的计划
    if (!_isSelectedPlanAvailable) {
      _closeDialog();
      showNotificationDialog(
        context,
        title: 'Notification',
        message:
            'Hushie Pro is active in your subscription and does not support downgrades.',
        buttonText: 'Got It',
      );
      return;
    }

    

    // 启动Google Play Billing支付流程
    await _initiateGooglePlayBillingPurchase();
  }

  /// 启动Google Play Billing购买流程
  Future<void> _initiateGooglePlayBillingPurchase() async {
    // 基本防御：商品或选中计划不可用则直接提示并返回
    if (_product == null) {
      ToastHelper.showError(ToastMessages.productConfigError);
      return;
    }
    if (_selectedPlan < 0 || _selectedPlan >= (_product!.basePlans.length)) {
      ToastHelper.showError(ToastMessages.productConfigError);
      return;
    }

    // 设置购买状态为进行中，禁用订阅按钮
    if (mounted) {
      setState(() {
        _isPurchasing = true;
      });
    }

    try {

      // 显示加载状态
      ToastHelper.showInfo(ToastMessages.subscriptionInitializing);

      // 获取Google Play Billing服务实例
      final billingService = GooglePlayBillingService();

      // 初始化服务
      final isInitialized = await billingService.initialize();
      if (!isInitialized) {
        ToastHelper.showError(ToastMessages.billingServiceUnavailable);
        return;
      }

      // 获取产品信息（加固空值与越界）
      final basePlans = _product?.basePlans ?? const <BasePlan>[];
      final BasePlan? basePlan =
          (_selectedPlan >= 0 && _selectedPlan < basePlans.length)
              ? basePlans[_selectedPlan]
              : null;
      final String basePlanId = basePlan?.googlePlayBasePlanId ?? '';

      debugPrint('📦 [SUBSCRIBE_DIALOG] product=${_product?.googlePlayProductId}, selectedPlan=$_selectedPlan, basePlans=${basePlans.length}, basePlanId=$basePlanId');

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

        final purchaseResult = await billingService.purchaseProduct(
          basePlanId,
          offerToken: offerToken,
        );

        // 根据购买结果处理不同情况
        switch (purchaseResult.result) {
          case PurchaseResult.success:
            // 手动上报 in_app_purchase 事件（Android 手动补充）
            try {
              final purchaseDetails = purchaseResult.purchaseDetails;
              // 原始字段
              final rawProductId = _product?.googlePlayProductId ?? '';
              final rawCurrency = _selectedPlanAvailableOffer?.currency ?? _product?.basePlans[_selectedPlan].currency;
              final rawValue = _selectedPlanAvailableOffer?.price ?? _product?.basePlans[_selectedPlan].price ?? 0.0;
              final offerId = _selectedPlanAvailableOffer?.offerId;
              final purchaseToken = purchaseDetails?.verificationData.serverVerificationData;

              // 规范化：确保 GA4 所需类型与格式
              final String productId = rawProductId.isNotEmpty ? rawProductId : 'unknown_product';
              final String currency = (rawCurrency != null && rawCurrency.length == 3)
                  ? rawCurrency
                  : 'USD';
              final double value = (rawValue is num)
                  ? (rawValue as num).toDouble()
                  : double.tryParse('$rawValue') ?? 0.0;
              final String itemName = _selectedPlanAvailableOffer?.name ?? _product?.basePlans[_selectedPlan].name ?? _product?.name ?? 'subscription';
              const int quantity = 1;

              // 使用 FirebaseAnalytics 的标准 purchase 事件
              await FirebaseAnalytics.instance.logPurchase(
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
              await AnalyticsService().logCustomEvent(
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
                  'base_plan_id': basePlanId,
                  if (offerId != null) 'offer_id': offerId,
                  'source': 'client_manual',
                },
              );

              // 直接用 Firebase 实例调用，跳过自定义的 AnalyticsService
              // await FirebaseAnalytics.instance.logEvent(
              //   name: 'in_app_purchase',
              //   parameters: {
              //     'transaction_id': 'test_trans_${DateTime.now().microsecondsSinceEpoch}', // 绝对唯一
              //     'value': 19.99, // 合理数值
              //     'currency': 'USD', // 标准货币码
              //     'items': [
              //       {
              //         'item_id': 'test_item_001',
              //         'item_name': 'Test Product',
              //         'price': 19.99, // 与 value 一致（单商品）
              //         'quantity': 1, // int 类型
              //       }
              //     ],
              //   },
              // );


            } catch (e) {
              debugPrint('📊 [ANALYTICS] 手动上报 in_app_purchase 失败: $e');
            }

            // ToastHelper.showSuccess(ToastMessages.subscriptionSuccess);
            // 购买成功，关闭对话框
            _closeDialog();
            _openSuccessNotification();
            
            break;
          case PurchaseResult.pending:
            ToastHelper.showInfo(ToastMessages.subscriptionPending);
            break;
          case PurchaseResult.canceled:
            ToastHelper.showInfo(ToastMessages.subscriptionCanceled);
            break;
          case PurchaseResult.error:
          case PurchaseResult.failed:
            ToastHelper.showError(
              purchaseResult.message ?? ToastMessages.subscriptionFailed,
            );
            break;
        }
      } catch (e) {
        debugPrint('Google Play Billing购买异常: $e');
        ToastHelper.showError(ToastMessages.subscriptionException);
      }
    } catch (e) {
      debugPrint('Google Play Billing购买失败: $e');

      // 使用统一的错误消息处理
      final errorMessage = ToastMessages.getBillingErrorMessage(e);
      ToastHelper.showError(errorMessage);
    } finally {
      // 恢复订阅按钮状态
      if (mounted) {
        setState(() {
          _isPurchasing = false;
        });
      }
    }
  }

  bool get _isSelectedPlanSubscribing {
    return _product?.basePlans[_selectedPlan].isSubscribing ?? false;
  }

  bool get _isSelectedPlanAvailable {
    return _product?.basePlans[_selectedPlan].isAvailable ?? false;
  }

  /// 获取选中计划的可用Offer，如果没有可用Offer则返回null
  Offer? get _selectedPlanAvailableOffer {
    final basePlan = _product?.basePlans[_selectedPlan];
    if (basePlan == null) return null;
    try {
      return basePlan.offers.firstWhere((offer) => offer.isAvailable);
    } catch (e) {
      return null;
    }
  }

  @override
  Widget build(BuildContext context) {
    // 如果正在加载数据，显示加载指示器
    if (_isLoading || _product == null) {
      return SlideUpContainer(
        maxHeight: MediaQuery.of(context).size.height * 0.5,
        backgroundImage: 'assets/images/products_bg.png',
        backgroundImageAlignment: Alignment.topCenter,
        padding: EdgeInsets.only(
          top: 16,
          bottom: MediaQuery.of(context).padding.bottom + 36,
          left: 16,
          right: 16,
        ),
        child: const Center(child: CircularProgressIndicator()),
      );
    }

    return SlideUpContainer(
      maxHeight: MediaQuery.of(context).size.height * 0.9,
      backgroundImage: 'assets/images/products_bg.png',
      backgroundImageAlignment: Alignment.topCenter,
      padding: EdgeInsets.only(
        top: 16,
        bottom: MediaQuery.of(context).padding.bottom + 36,
        left: 16,
        right: 16,
      ),
      child: Stack(
        children: [
          // 主要内容
          Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              SizedBox(height: 32),
              // 标题
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  SizedBox(
                    width: 96,
                    child: Image.asset('assets/images/logo.png'),
                  ),
                  const SizedBox(width: 6),
                  Transform.translate(
                    offset: const Offset(0, 3),
                    child: Text(
                      'Pro',
                      style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.w600,
                        color: Colors.black,
                      ),
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 16),

              // 功能特性列表
              Center(
                child: IntrinsicWidth(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      _buildFeatureItem('Full Access to All Creations'),
                      const SizedBox(height: 13),
                      _buildFeatureItem('Unlock Search Results'),
                      const SizedBox(height: 13),
                      _buildFeatureItem('Long History Record'),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 25),

              // 价格选项
              Column(
                children: (_product?.basePlans ?? const <BasePlan>[])
                    .asMap()
                    .entries
                    .expand(
                      (entry) => [
                        _buildPriceOption(
                          planIndex: entry.key,
                          basePlan: entry.value,
                        ),
                        if (entry.key < ((_product?.basePlans.length ?? 0) - 1))
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
                    onPressed: _onSubscribe,
                    style: ElevatedButton.styleFrom(
                      backgroundColor:
                          /*(_isPurchasing)
                          ? const Color(0xFFCCCCCC)
                          : */const Color(0xFFFFDE69),
                      foregroundColor: Colors.black,
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(28),
                      ),
                    ),
                    child: Text(
                      /*_isPurchasing
                          ? 'Processing...'
                          : */(_isSelectedPlanSubscribing
                                ? 'Subscribing'
                                : 'Subscribe'),
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w700,
                        color: /*(_isPurchasing)
                            ? const Color(0xFF999999)
                            : */const Color(0xFF502D19),
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
          ),

          // 关闭按钮 - 使用Positioned脱离布局
          Positioned(
            top: -4,
            left: -4,
            child: IconButton(
              onPressed: _closeDialog,
              iconSize: 24,
              icon: const Icon(Icons.close, color: Colors.white),
              style: IconButton.styleFrom(
                backgroundColor: Color(0xFF979797).withAlpha(128),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(20),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFeatureItem(String text) {
    return Row(
      children: [
        const Icon(CustomIcons.check, color: Color(0xFFFF6B35), size: 16),
        const SizedBox(width: 12),
        Text(
          text,
          style: const TextStyle(
            fontSize: 14,
            height: 1,
            fontWeight: FontWeight.w500,
            color: Color(0xFF333333),
          ),
        ),
      ],
    );
  }

  Widget _buildPriceOption({
    required int planIndex,
    required BasePlan basePlan,
  }) {
    final bool isSelected = _selectedPlan == planIndex;

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
      onTap: () => setState(() => _selectedPlan = planIndex),
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
                  (/*isSelected &&*/
                      basePlan.isShowDiscount &&
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

// // 示例数据 - 创建一个示例Product
// final sampleProduct = Product(
//   googlePlayProductId: 'hushie_premium',
//   name: 'Pro',
//   description: 'Premium subscription with full access',
//   productType: 'subscription',
//   basePlans: [
//     BasePlan(
//       googlePlayBasePlanId: 'monthly_plan',
//       name: 'Monthly',
//       price: 9.99,
//       originalPrice: 12.99,
//       currency: 'USD',
//       billingPeriod: 'monthly',
//       durationDays: 30,
//       isAvailable: true,
//       isSubscribing: false,
//       isShowDiscount: true,
//       offers: [
//         Offer.fromJson({
//           'offer_id': 'monthly_plan',
//           'name': 'First Month',
//           'price': 3.99,
//           'original_price': 12.99,
//           'currency': 'USD',
//           'description': 'Monthly subscription',
//           'is_available': true,
//         }),
//       ],
//     ),
//     BasePlan(
//       googlePlayBasePlanId: 'yearly_plan',
//       name: 'Yearly',
//       price: 99.99,
//       originalPrice: 119.99,
//       currency: 'USD',
//       billingPeriod: 'yearly',
//       durationDays: 365,
//       isAvailable: false,
//       isSubscribing: true,
//       isShowDiscount: false,
//       offers: [],
//     ),
//   ],
// );

// 显示订阅对话框的便捷方法
Future<void> showSubscribeDialog(BuildContext context) async {
  // 检查是否已有弹窗打开
  if (!DialogStateManager.instance.tryOpenDialog(
    DialogStateManager.subscribeDialog,
  )) {
    return; // 已有其他弹窗打开，直接返回
  }

  return SlideUpOverlay.show(context: context, child: const SubscribeDialog());
}
