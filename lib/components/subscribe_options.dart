import 'package:flutter/material.dart';
import '../utils/custom_icons.dart';
import '../utils/currency_formatter.dart';
import '../models/product_model.dart';
import '../utils/webview_navigator.dart';
import 'subscribe_options_logic.dart';

// 提示方法已在 subscribe_options_logic.dart 中提供，避免重复定义

class SubscribeOptions extends SubscribeOptionsBase {
  const SubscribeOptions({
    super.key,
    required super.product,
    required super.selectedPlan,
    required super.onPlanSelected,
    required super.onSubscribeSuccess,
    super.scene,
  });

  @override
  State<SubscribeOptions> createState() => _SubscribeOptionsState();
}

class _SubscribeOptionsState extends State<SubscribeOptions> with WidgetsBindingObserver, SubscribeOptionsLogic<SubscribeOptions> {
  @override
  void initState() {
    super.initState();
    initSubscribeOptionsLogic();
  }

  @override
  void dispose() {
    disposeSubscribeOptionsLogic();
    super.dispose();
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
                (isPurchasing || isSelectedPlanSubscribing
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