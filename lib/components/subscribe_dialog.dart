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
    _loadProductData();
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
      _product ??= sampleProduct;
    } catch (e) {
      debugPrint('🏆 [SUBSCRIBE_DIALOG] 获取商品数据失败: $e');
      // 使用默认的 sampleProduct
      _product = sampleProduct;
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
      _closeDialog();
      showNotificationDialog(
        context,
        title: 'Notification',
        message:
            'Subscribing. Please don\'t repeat.',
        buttonText: 'Got It',
      );
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
    _initiateGooglePlayBillingPurchase();
  }

  /// 启动Google Play Billing购买流程
  Future<void> _initiateGooglePlayBillingPurchase() async {
    // 设置购买状态为进行中，禁用订阅按钮
    setState(() {
      _isPurchasing = true;
    });

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

      // 获取产品信息
      final basePlan = _product?.basePlans[_selectedPlan];
      final basePlanId = basePlan?.googlePlayBasePlanId ?? '';

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
            ToastHelper.showSuccess(ToastMessages.subscriptionSuccess);
            // 购买成功，关闭对话框
            _closeDialog();
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
      setState(() {
        _isPurchasing = false;
      });
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
        backgroundImage: 'assets/images/dailog_bg.png',
        backgroundImageAlignment: Alignment(0.2, 0.55),
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
                children: _product!.basePlans
                    .asMap()
                    .entries
                    .expand(
                      (entry) => [
                        _buildPriceOption(
                          planIndex: entry.key,
                          basePlan: entry.value,
                        ),
                        if (entry.key < _product!.basePlans.length - 1)
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
                  (isSelected &&
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
Future<void> showSubscribeDialog(BuildContext context) async {
  // 检查是否已有弹窗打开
  if (!DialogStateManager.instance.tryOpenDialog(
    DialogStateManager.subscribeDialog,
  )) {
    return; // 已有其他弹窗打开，直接返回
  }

  return SlideUpOverlay.show(context: context, child: const SubscribeDialog());
}
