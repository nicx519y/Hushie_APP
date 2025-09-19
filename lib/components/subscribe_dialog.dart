import 'package:flutter/material.dart';
import '../components/notification_dialog.dart';
import 'package:pay/pay.dart';
import 'dart:async';
import 'slide_up_overlay.dart';
import '../utils/custom_icons.dart';
import '../utils/currency_formatter.dart';
import '../models/product_model.dart';
import '../services/dialog_state_manager.dart';
import '../services/google_pay_service.dart';
import '../services/api/subscription_service.dart';
import '../utils/toast_helper.dart';

class SubscribeDialog extends StatefulWidget {
  final Product product;
  final VoidCallback? onSubscribe;

  const SubscribeDialog({
    super.key,
    required this.product,
    this.onSubscribe,
  });

  @override
  State<SubscribeDialog> createState() => _SubscribeDialogState();
}

class _SubscribeDialogState extends State<SubscribeDialog> {
  int _selectedPlan = 0; // 0: First Month, 1: Per year

  void _closeDialog() {
    Navigator.of(context, rootNavigator: true).pop();
  }

  @override
  void dispose() {
    // 清除弹窗状态标志
    DialogStateManager.instance.closeDialog(DialogStateManager.subscribeDialog);
    super.dispose();
  }

  void _onSubscribe() {

    debugPrint('SubscribeDialog _onSubscribe selectedPlan: $_selectedPlan');
    // 不可用 就是不能降级 已经订阅了更高级的计划
    if (!_isSelectedPlanAvailable) {
      _closeDialog();
      showNotificationDialog(
        context,
        title: 'Notification',
        message: 'Hushie Pro is active in your subscription and does not support downgrades.',
        buttonText: 'Got It',
      );
      return;
    }

    // 已经在订阅中，不能重复订阅
    if (_isSelectedPlanSubscribing) {
      ToastHelper.showInfo('You have subscribed to this plan.');
      return;
    }

    // 启动Google Pay支付流程
    _initiateGooglePayPayment();
  }

  /// 启动Google Pay支付流程
  Future<void> _initiateGooglePayPayment() async {
    try {
      // 显示加载状态
      ToastHelper.showInfo('Initializing payment...');
      
      // 检查Google Pay是否可用
      final canPay = await GooglePayService.canUserPay();
      if (!canPay) {
        ToastHelper.showError('Google Pay is not available on this device.');
        return;
      }

      // 构建支付数据
      final paymentItems = buildGooglePayPaymentItems();
      final subscriptionData = buildGooglePaySubscriptionData();
      
      // 验证支付数据
      if (paymentItems.isEmpty) {
        ToastHelper.showError('Google Pay payment data build failed, please try again.');
        return;
      }
      
      // 显示Google Pay支付界面
      await _showGooglePayButton(paymentItems, subscriptionData);
      
    } catch (e) {
      debugPrint('启动Google Pay支付失败: $e');
      String errorMessage = 'Payment initialization failed';
      
      // 根据错误类型提供更具体的错误信息
      if (e.toString().contains('network')) {
        errorMessage = 'Network connection failed, please check network and try again.';
      } else if (e.toString().contains('permission')) {
        errorMessage = 'Insufficient permissions, please check app permissions.';
      } else if (e.toString().contains('configuration')) {
        errorMessage = 'Pay configuration error, please contact customer service.';
      }
      
      ToastHelper.showError(errorMessage);
    }
  }

  /// 显示Google Pay支付按钮
  Future<void> _showGooglePayButton(
    List<Map<String, dynamic>> paymentItems, 
    Map<String, dynamic> subscriptionData
  ) async {
    try {
      // 转换为PaymentItem格式
      final List<PaymentItem> items = paymentItems.map((item) => PaymentItem(
        label: item['label'],
        amount: item['amount'],
        status: PaymentItemStatus.final_price,
      )).toList();

      // 创建支付配置
      final paymentConfiguration = await PaymentConfiguration.fromAsset('assets/configs/google_pay_config.json');
      
      // 创建支付客户端
      final payClient = Pay({PayProvider.google_pay: paymentConfiguration});
      
      // 执行支付
      final result = await payClient.showPaymentSelector(
        PayProvider.google_pay,
        items,
      );
      
      // 处理支付结果
      await _handleGooglePayResult(result, subscriptionData);
      
    } catch (e) {
      debugPrint('Google Pay failure: $e');
      
      String errorMessage = 'Pay failure: $e';
      
      // 根据错误信息提供更具体的错误信息
      if (e.toString().contains('cancelled') || e.toString().contains('user_cancelled')) {
        errorMessage = 'Pay cancelled by user';
      } else if (e.toString().contains('not_available') || e.toString().contains('unavailable')) {
        errorMessage = 'Google Pay service not available';
      } else if (e.toString().contains('developer') || e.toString().contains('configuration')) {
        errorMessage = 'Pay configuration error, please contact customer service';
      } else if (e.toString().contains('network')) {
        errorMessage = 'Network error, please check network connection';
      }
      
      ToastHelper.showError(errorMessage);
    }
  }

  /// 处理Google Pay支付结果
  Future<void> _handleGooglePayResult(
    Map<String, dynamic> paymentResult,
    Map<String, dynamic> subscriptionData,
  ) async {
    try {
      debugPrint('Google Pay payment result: $paymentResult');
      
      // 显示处理状态
      ToastHelper.showInfo('Processing payment result...');
      
      // 验证支付结果数据结构
      if (paymentResult['paymentMethodData'] == null) {
        ToastHelper.showError('Pay payment data format error');
        return;
      }
      
      // 提取支付令牌
      final paymentMethodData = paymentResult['paymentMethodData'];
      final tokenizationData = paymentMethodData['tokenizationData'];
      final token = tokenizationData?['token'];
      
      if (token == null || token.toString().isEmpty) {
        ToastHelper.showError('Pay payment token error, please retry.');
        return;
      }

      // 调用后端API创建订阅
      final response = await SubscribeService.createGooglePlaySubscribe(
        productId: subscriptionData['google_play_product_id'],
        basePlanId: subscriptionData['google_play_base_plan_id'],
        purchaseToken: token,
      );

      if (response.errNo == 0 && response.data != null) {
        // 支付成功
        _closeDialog();
        ToastHelper.showSuccess('Pay subscription success! Thank you for your support.');
        
        // 调用成功回调
        if (widget.onSubscribe != null) {
          widget.onSubscribe!();
        }
      } else {
        // 支付失败，提供更详细的错误信息
        String errorMessage = 'Pay subscription create failed.';
        
        // 根据错误码提供更具体的错误信息
        if (response.errNo == -2) {
          errorMessage = 'Pay subscription already exists. Error code: ${response.errNo}';
        } else if (response.errNo == -3) {
          errorMessage = 'Pay payment token invalid, please pay again. Error code: ${response.errNo}';
        } else if (response.errNo == -4) {
          errorMessage = 'Pay network connection error, please check network and try again. Error code: ${response.errNo}';
        } else if (response.errNo == -5) {
          errorMessage = 'Pay server error, please try again later. Error code: ${response.errNo}';
        }
        
        ToastHelper.showError(errorMessage);
      }
      
    } on FormatException catch (e) {
      debugPrint('Pay payment result data format error: $e');
      ToastHelper.showError('Pay payment data format error, please retry.');
    } on TimeoutException catch (e) {
      debugPrint('Pay handle payment result timeout: $e');
      ToastHelper.showError('Pay handle timeout, please check network connection and try again.');
    } catch (e) {
      debugPrint('Pay handle Google Pay result error: $e');
      
      String errorMessage = 'Pay subscription handle failed.';
      
      // 根据错误类型提供更具体的错误信息
      if (e.toString().contains('network') || e.toString().contains('connection')) {
        errorMessage = 'Pay network connection error, please check network and try again.';
      } else if (e.toString().contains('timeout')) {
        errorMessage = 'Pay request timeout, please retry.';
      } else if (e.toString().contains('unauthorized')) {
        errorMessage = 'Pay authentication failed, please login again.';
      }
      
      ToastHelper.showError('$errorMessage, please contact customer service if the problem persists.');
    }
  }

  bool get _isSelectedPlanSubscribing {
    return widget.product.basePlans[_selectedPlan].isSubscribing;
  }

  bool get _isSelectedPlanAvailable {
    return widget.product.basePlans[_selectedPlan].isAvailable;
  }

  /// 获取选中计划的可用Offer，如果没有可用Offer则返回null
  Offer? get _selectedPlanAvailableOffer {
    final basePlan = widget.product.basePlans[_selectedPlan];
    try {
      return basePlan.offers.firstWhere((offer) => offer.isAvailable);
    } catch (e) {
      return null;
    }
  }

  /// 构建Google Pay需要的订阅数据
  Map<String, dynamic> buildGooglePaySubscriptionData() {
    final basePlan = widget.product.basePlans[_selectedPlan];
    final availableOffer = _selectedPlanAvailableOffer;
    
    // 决定使用的价格和货币信息
    final displayPrice = availableOffer?.price ?? basePlan.price;
    final displayCurrency = availableOffer?.currency ?? basePlan.currency;
    final displayName = availableOffer?.name ?? basePlan.name;
    
    return {
      'google_play_product_id': widget.product.googlePlayProductId,
      'google_play_base_plan_id': basePlan.googlePlayBasePlanId,
      'offer_id': availableOffer?.offerId,
      'product_name': widget.product.name,
      'plan_name': displayName,
      'price': displayPrice,
      'currency': displayCurrency,
      'billing_period': basePlan.billingPeriod,
      'duration_days': basePlan.durationDays,
    };
  }

  /// 构建Google Pay PaymentItem列表
  List<Map<String, dynamic>> buildGooglePayPaymentItems() {
    final basePlan = widget.product.basePlans[_selectedPlan];
    final availableOffer = _selectedPlanAvailableOffer;
    
    final displayPrice = availableOffer?.price ?? basePlan.price;
    final displayName = availableOffer?.name ?? basePlan.name;
    
    return [
      {
        'label': '${widget.product.name} - $displayName',
        'amount': displayPrice.toStringAsFixed(2),
        'status': 'FINAL',
      }
    ];
  }

  /// 获取Google Pay支付配置数据
  Map<String, dynamic> buildGooglePayTransactionInfo() {
    final basePlan = widget.product.basePlans[_selectedPlan];
    final availableOffer = _selectedPlanAvailableOffer;
    
    final displayPrice = availableOffer?.price ?? basePlan.price;
    final displayCurrency = availableOffer?.currency ?? basePlan.currency;
    
    return {
      'totalPriceStatus': 'FINAL',
      'totalPrice': displayPrice.toStringAsFixed(2),
      'currencyCode': displayCurrency,
      'countryCode': 'US', // 可以根据需要调整
    };
  }

  

  @override
  Widget build(BuildContext context) {
    return SlideUpContainer(
      maxHeight: MediaQuery.of(context).size.height * 0.9,
      backgroundImage: 'assets/images/dailog_bg.png',
      backgroundImageAlignment: Alignment(0.2, 0.55), // 控制背景图坐标位置
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
                      widget.product.name,
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
                children: widget.product.basePlans
                    .asMap()
                    .entries
                    .expand(
                      (entry) => [
                        _buildPriceOption(
                          planIndex: entry.key,
                          basePlan: entry.value,
                        ),
                        if (entry.key < widget.product.basePlans.length - 1)
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
                      backgroundColor: _isSelectedPlanSubscribing 
                          ? const Color(0xFFCCCCCC) 
                          : const Color(0xFFFFDE69),
                      foregroundColor: Colors.black,
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(28),
                      ),
                    ),
                    child: Text(
                      _isSelectedPlanSubscribing ? 'Subscribing' : 'Subscribe',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w700,
                        color: _isSelectedPlanSubscribing 
                            ? const Color(0xFF999999) 
                            : const Color(0xFF502D19),
                      ),
                    ),
                  ),
                ),
              ),

              const SizedBox(height: 13),

              // 自动续费说明
              Text(
                'Auto-renews monthly. Cancel anytime.',
                style: TextStyle(fontSize: 14, color: Color(0xFF666666)),
              ),

              const SizedBox(height: 16),

              // 底部链接
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  InkWell(
                    // onTap: () { },
                    child: Text(
                      'Privacy Policy',
                      style: TextStyle(
                        fontSize: 14,
                        color: const Color(0xFF666666),
                      ),
                    ),
                  ),
                  InkWell(
                    // onTap: () { },
                    child: Text(
                      'Terms of Use',
                      style: TextStyle(
                        fontSize: 14,
                        color: const Color(0xFF666666),
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
      availableOffer = basePlan.offers.firstWhere(
        (offer) => offer.isAvailable,
      );
    } catch (e) {
      availableOffer = null;
    }

    debugPrint('planIndex: $planIndex, basePlan: ${basePlan.name}, availableOffer: ${availableOffer?.name}');

    // 决定显示的名称和价格信息
    final displayName = availableOffer?.name ?? basePlan.name;
    final displayPrice = availableOffer?.price ?? basePlan.price;
    final displayOriginalPrice = availableOffer?.originalPrice ?? basePlan.originalPrice;
    final displayCurrency = availableOffer?.currency ?? basePlan.currency;

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
              child: (isSelected && basePlan.isShowDiscount && getDiscountText() != null)
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
                      CurrencyFormatter.formatPrice(displayPrice, displayCurrency),
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
                    CurrencyFormatter.formatPrice(displayOriginalPrice, displayCurrency),
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

// 示例数据 - 创建一个示例Product
final sampleProduct = Product(
  googlePlayProductId: 'hushie_premium',
  name: 'Pro',
  description: 'Premium subscription with full access',
  productType: 'subscription',
  basePlans: [
    BasePlan(
      googlePlayBasePlanId: 'monthly_plan',
      name: 'Monthly',
      price: 9.99,
      originalPrice: 12.99,
      currency: 'USD',
      billingPeriod: 'monthly',
      durationDays: 30,
      isAvailable: true,
      isSubscribing: false,
      isShowDiscount: true,
      offers: [
        Offer.fromJson({
          'offer_id': 'monthly_plan',
          'name': 'First Month',
          'price': 3.99,
          'original_price': 12.99,
          'currency': 'USD',
          'description': 'Monthly subscription',
          'is_available': true,
        }),
      ],
    ),
    BasePlan(
      googlePlayBasePlanId: 'yearly_plan',
      name: 'Yearly',
      price: 99.99,
      originalPrice: 119.99,
      currency: 'USD',
      billingPeriod: 'yearly',
      durationDays: 365,
      isAvailable: false,
      isSubscribing: true,
      isShowDiscount: false,
      offers: [],
    ),
  ],
);

// 显示订阅对话框的便捷方法
Future<void> showSubscribeDialog(
  BuildContext context, {
  Product? product,
}) async {
  // 检查是否已有弹窗打开
  if (!DialogStateManager.instance.tryOpenDialog(DialogStateManager.subscribeDialog)) {
    return; // 已有其他弹窗打开，直接返回
  }
  
  return SlideUpOverlay.show(
    context: context,
    child: SubscribeDialog(
      product: product ?? sampleProduct,
    ),
  );
}
