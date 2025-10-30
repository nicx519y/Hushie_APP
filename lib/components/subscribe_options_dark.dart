import 'package:flutter/material.dart';
import '../utils/custom_icons.dart';
import '../utils/currency_formatter.dart';
import '../models/product_model.dart';
import '../utils/webview_navigator.dart';
import 'subscribe_options_logic.dart';

// 提示方法已在 subscribe_options_logic.dart 中提供，避免重复定义

class SubscribeOptionsDark extends SubscribeOptionsBase {
  const SubscribeOptionsDark({
    super.key,
    required super.product,
    required super.selectedPlan,
    required super.onPlanSelected,
    required super.onSubscribeSuccess,
    super.scene,
  });

  @override
  State<SubscribeOptionsDark> createState() => _SubscribeOptionsDarkState();
}

class _SubscribeOptionsDarkState extends State<SubscribeOptionsDark> with WidgetsBindingObserver, SubscribeOptionsLogic<SubscribeOptionsDark> {
  @override
  void initState() {
    super.initState();
    initSubscribeOptionsLogic();
    // 仅展示第一个 BasePlan，确保选中为索引 0
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if ((widget.product?.basePlans.length ?? 0) > 0 && widget.selectedPlan != 0) {
        widget.onPlanSelected(0);
      }
    });
  }

  @override
  void dispose() {
    disposeSubscribeOptionsLogic();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final BasePlan? basePlan = (widget.product?.basePlans.isNotEmpty ?? false)
        ? widget.product!.basePlans.first
        : null;

    // 兜底：无配置时不渲染
    if (basePlan == null) {
      return const SizedBox.shrink();
    }

    // 计算显示信息（若存在可用 offer 优先使用）
    Offer? availableOffer;
    try {
      availableOffer = basePlan.offers.firstWhere((offer) => offer.isAvailable);
    } catch (_) {
      availableOffer = null;
    }

    final String displayName = availableOffer?.name ?? basePlan.name;
    final double displayPrice = availableOffer?.price ?? basePlan.price;
    final double displayOriginalPrice = (availableOffer != null && availableOffer.originalPrice > displayPrice)
        ? availableOffer.originalPrice
        : basePlan.originalPrice;
    final String displayCurrency = availableOffer?.currency ?? basePlan.currency;

    String? getDiscountText() {
      if (basePlan.isShowDiscount && displayOriginalPrice > displayPrice) {
        final percent = ((displayOriginalPrice - displayPrice) / displayOriginalPrice * 100).round();
        return '$percent% off from ${CurrencyFormatter.formatPrice(displayOriginalPrice, displayCurrency)}';
      }
      return null;
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        // 标题：如 “First month $4.9”
        Text(
          '${displayName} ${CurrencyFormatter.formatPrice(displayPrice, displayCurrency)}',
          textAlign: TextAlign.center,
          style: const TextStyle(
            fontSize: 26,
            fontWeight: FontWeight.w900,
            color: Color(0xFFF5D770), // 淡金色标题
            height: 1,
          ),
        ),

        const SizedBox(height: 8),

        // 折扣说明：如 “90% off from $49.9”
        if (getDiscountText() != null)
          Text(
            getDiscountText()!,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 12,
              height: 1,
              color: Color(0xFF999999),
              decoration: TextDecoration.none,
            ),
          ),

        const SizedBox(height: 20),

        // 订阅按钮
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 0),
          child: SizedBox(
            width: double.infinity,
            height: 48,
            child: ElevatedButton(
              onPressed: isPurchasing ? null : onSubscribe,
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFFFDE69),
                foregroundColor: Colors.black,
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(28),
                ),
              ),
              child: Text(
                (isPurchasing || isSelectedPlanSubscribing ? 'Subscribing' : 'Subscribe'),
                style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF502D19),
                ),
              ),
            ),
          ),
        ),

        const SizedBox(height: 13),

        // 自动续费说明
        InkWell(
          onTap: () => WebViewNavigator.showAutoRenewInfo(context, clearCache: true),
          child: const Text(
            'Auto-renews monthly. Cancel anytime.',
            style: TextStyle(
              fontSize: 14,
              color: Color(0xFF999999),
              decoration: TextDecoration.none,
            ),
          ),
        ),

        const SizedBox(height: 16),

        // 底部链接
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: const [
            Text(
              'Privacy Policy',
              style: TextStyle(
                fontSize: 14,
                color: Color(0xFF999999),
                decoration: TextDecoration.none,
              ),
            ),
            Text(
              'Terms of Use',
              style: TextStyle(
                fontSize: 14,
                color: Color(0xFF999999),
                decoration: TextDecoration.none,
              ),
            ),
          ],
        ),
      ],
    );
  }
  
}