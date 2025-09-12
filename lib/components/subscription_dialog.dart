import 'package:flutter/material.dart';
import 'slide_up_overlay.dart';
import '../utils/custom_icons.dart';
import '../models/subscribe_model.dart';

class SubscriptionDialog extends StatefulWidget {
  final SubscribeModel subscribeModel;
  final VoidCallback? onSubscribe;
  final VoidCallback? onClose;

  const SubscriptionDialog({
    super.key,
    required this.subscribeModel,
    this.onSubscribe,
    this.onClose,
  });

  @override
  State<SubscriptionDialog> createState() => _SubscriptionDialogState();
}

class _SubscriptionDialogState extends State<SubscriptionDialog> {
  int _selectedPlan = 0; // 0: First Month, 1: Per year

  void _closeDialog() {
    Navigator.of(context, rootNavigator: true).pop();
  }

  @override
  void dispose() {
    if (widget.onClose != null) {
      widget.onClose!();
    }
    super.dispose();
  }

  void _onSubscribe() {
    if (widget.onSubscribe != null) {
      widget.onSubscribe!();
    }
    _closeDialog();
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
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // 关闭按钮
          Align(
            alignment: Alignment.topLeft,
            child: Transform.translate(
              offset: const Offset(-4, -4),
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
          ),

          const SizedBox(height: 16),

          // 标题
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              SizedBox(
                width: 120,
                child: Image.asset('assets/images/logo.png'),
              ),
              const SizedBox(width: 10),
              Transform.translate(
                offset: const Offset(0, 3),
                child: Text(
                  widget.subscribeModel.name ?? 'Pro',
                  style: TextStyle(
                    fontSize: 32,
                    fontWeight: FontWeight.w900,
                    color: Colors.black,
                  ),
                ),
              ),
            ],
          ),

          const SizedBox(height: 30),

          // 功能特性列表
          Center(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              width: 290,
              child: Column(
                children: widget.subscribeModel.featureList
                    .asMap()
                    .entries
                    .expand((entry) => [
                          _buildFeatureItem(entry.value),
                          if (entry.key < widget.subscribeModel.featureList.length - 1)
                            const SizedBox(height: 13),
                        ])
                    .toList(),
              ),
            ),
          ),

          const SizedBox(height: 36),

          // 价格选项
          Column(
            children: widget.subscribeModel.optionList
                .asMap()
                .entries
                .expand((entry) => [
                      _buildPriceOption(
                        planIndex: entry.value.planIndex,
                        title: entry.value.title,
                        price: entry.value.price,
                        originalPrice: entry.value.originalPrice,
                      ),
                      if (entry.key < widget.subscribeModel.optionList.length - 1)
                        const SizedBox(height: 12),
                    ])
                .toList(),
          ),

          const SizedBox(height: 13),

          // 订阅按钮
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: SizedBox(
              width: double.infinity,
              height: 56,
              child: ElevatedButton(
                onPressed: _onSubscribe,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFFFDE69),
                  foregroundColor: Colors.black,
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(28),
                  ),
                ),
                child: const Text(
                  'Subscribe',
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF502D19),
                  ),
                ),
              ),
            ),
          ),

          const SizedBox(height: 13),

          // 自动续费说明
          const Text(
            'Auto-renews monthly. Cancel anytime.',
            style: TextStyle(fontSize: 14, color: const Color(0xFF666666)),
          ),

          const SizedBox(height: 16),

          // 底部链接
          const Row(
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
            fontSize: 16,
            height: 1,
            fontWeight: FontWeight.w600,
            color: Color(0xFF333333),
          ),
        ),
      ],
    );
  }

  Widget _buildPriceOption({
    required int planIndex,
    required String title,
    required String price,
    required String? originalPrice,
  }) {
    final bool isSelected = _selectedPlan == planIndex;

    String? getDiscountText() {
      if (originalPrice != null) {
        final double originalPriceValue = double.tryParse(originalPrice!) ?? 0;
        final double priceValue = double.tryParse(price) ?? 0;
        if (originalPriceValue > priceValue && originalPriceValue > 0) {
          return '${((originalPriceValue - priceValue) / originalPriceValue * 100).toStringAsFixed(0)}% OFF';
        }
      }
      return null;
    }

    return GestureDetector(
      onTap: () => setState(() => _selectedPlan = planIndex),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        height: 72,
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
              title,
              style: const TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.w700,
                color: Colors.black,
              ),
            ),
            Expanded(
              child: isSelected
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
                    const Text(
                      '\$',
                      style: TextStyle(
                        fontSize: 20,
                        height: 1.1,
                        fontWeight: FontWeight.w700,
                        color: Colors.black,
                      ),
                    ),
                    const SizedBox(width: 1.6),
                    Text(
                      price,
                      style: const TextStyle(
                        fontSize: 24,
                        height: 1,
                        fontWeight: FontWeight.w700,
                        color: Colors.black,
                      ),
                    ),
                  ],
                ),
                if (originalPrice != null)
                  Text(
                    '\$$originalPrice',
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

// 假数据
final subscribeModel = SubscribeModel(
  name: 'Pro',
  featureList: [
    'Full Access to All Creations',
    'Unlock Search Results',
    'Long History Record',
  ],
  optionList: [
    SubscriptionOption(
      title: 'First Month',
      price: '9.9',
      originalPrice: '19.9',
      planIndex: 0,
    ),
    SubscriptionOption(
      title: 'Per year',
      price: '99',
      originalPrice: '199',
      planIndex: 1,
    ),
  ],
);

// 显示订阅对话框的便捷方法
Future<void> showSubscriptionDialog(
  BuildContext context, {
  VoidCallback? onSubscribe,
  VoidCallback? onClose,
}) async {
  return SlideUpOverlay.show(
    context: context,
    child: SubscriptionDialog(
      subscribeModel: subscribeModel,
      onSubscribe: onSubscribe,
      onClose: onClose,
    ),
  );
}
