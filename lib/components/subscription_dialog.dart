import 'package:flutter/material.dart';
import 'slide_up_overlay.dart';

class SubscriptionDialog extends StatefulWidget {
  final VoidCallback? onSubscribe;
  final VoidCallback? onClose;

  const SubscriptionDialog({super.key, this.onSubscribe, this.onClose});

  @override
  State<SubscriptionDialog> createState() => _SubscriptionDialogState();
}

class _SubscriptionDialogState extends State<SubscriptionDialog> {
  int _selectedPlan = 0; // 0: First Month, 1: Per year

  void _closeDialog() {
    Navigator.of(context, rootNavigator: true).pop();
    if (widget.onClose != null) {
      widget.onClose!();
    }
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
      height: MediaQuery.of(context).size.height * 0.7,
      child: Column(
        children: [
          // 关闭按钮
          Align(
            alignment: Alignment.topLeft,
            child: Padding(
              padding: const EdgeInsets.only(top: 8, left: 8),
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

          const SizedBox(height: 20),

          // Hushie Pro 标题
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              SizedBox(
                width: 132,
                child: Image.asset('assets/images/logo.png'),
              ),
              const SizedBox(width: 8),
              Text(
                'Pro',
                style: TextStyle(
                  fontSize: 32,
                  fontWeight: FontWeight.bold,
                  color: Colors.black,
                ),
              ),
            ],
          ),

          const SizedBox(height: 40),

          // 功能特性列表
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 32),
            child: Column(
              children: [
                _buildFeatureItem('Full Access to All Creations'),
                const SizedBox(height: 16),
                _buildFeatureItem('Unlock Search Results'),
                const SizedBox(height: 16),
                _buildFeatureItem('Long History Record'),
              ],
            ),
          ),

          const SizedBox(height: 40),

          // 价格选项
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Column(
              children: [
                // First Month 选项
                GestureDetector(
                  onTap: () => setState(() => _selectedPlan = 0),
                  child: Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: _selectedPlan == 0
                          ? const Color(0xFFFFF4E6)
                          : Colors.grey.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: _selectedPlan == 0
                            ? const Color(0xFF4A90E2)
                            : Colors.transparent,
                        width: 2,
                      ),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          _selectedPlan == 0
                              ? Icons.check_circle
                              : Icons.radio_button_unchecked,
                          color: _selectedPlan == 0
                              ? const Color(0xFF8B4513)
                              : Colors.grey,
                          size: 24,
                        ),
                        const SizedBox(width: 12),
                        const Text(
                          'First Month',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w600,
                            color: Colors.black,
                          ),
                        ),
                        const Spacer(),
                        if (_selectedPlan == 0)
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: const Color(0xFFFF6B35),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: const Text(
                              '84% OFF',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        const SizedBox(width: 8),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            const Text(
                              '\$8.9',
                              style: TextStyle(
                                fontSize: 24,
                                fontWeight: FontWeight.bold,
                                color: Colors.black,
                              ),
                            ),
                            Text(
                              '\$49.9',
                              style: TextStyle(
                                fontSize: 14,
                                color: Colors.grey,
                                decoration: TextDecoration.lineThrough,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),

                const SizedBox(height: 16),

                // Per year 选项
                GestureDetector(
                  onTap: () => setState(() => _selectedPlan = 1),
                  child: Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: _selectedPlan == 1
                          ? const Color(0xFFFFF4E6)
                          : Colors.grey.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: _selectedPlan == 1
                            ? const Color(0xFF4A90E2)
                            : Colors.transparent,
                        width: 2,
                      ),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          _selectedPlan == 1
                              ? Icons.check_circle
                              : Icons.radio_button_unchecked,
                          color: _selectedPlan == 1
                              ? const Color(0xFF8B4513)
                              : Colors.grey,
                          size: 24,
                        ),
                        const SizedBox(width: 12),
                        const Text(
                          'Per year',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w600,
                            color: Colors.black,
                          ),
                        ),
                        const Spacer(),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            const Text(
                              '\$99',
                              style: TextStyle(
                                fontSize: 24,
                                fontWeight: FontWeight.bold,
                                color: Colors.black,
                              ),
                            ),
                            Text(
                              '\$598',
                              style: TextStyle(
                                fontSize: 14,
                                color: Colors.grey,
                                decoration: TextDecoration.lineThrough,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 32),

          // 订阅按钮
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: SizedBox(
              width: double.infinity,
              height: 56,
              child: ElevatedButton(
                onPressed: _onSubscribe,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFE6D35A),
                  foregroundColor: Colors.black,
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(28),
                  ),
                ),
                child: const Text(
                  'Subscribe',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
                ),
              ),
            ),
          ),

          const SizedBox(height: 16),

          // 自动续费说明
          const Text(
            'Auto-renews monthly. Cancel anytime.',
            style: TextStyle(fontSize: 14, color: Colors.grey),
          ),

          const SizedBox(height: 24),

          // 底部链接
          const Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              Text(
                'Privacy Policy',
                style: TextStyle(
                  fontSize: 14,
                  color: Colors.grey,
                  decoration: TextDecoration.underline,
                ),
              ),
              Text(
                'Terms of Use',
                style: TextStyle(
                  fontSize: 14,
                  color: Colors.grey,
                  decoration: TextDecoration.underline,
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
        const Icon(Icons.check, color: Color(0xFFFF6B35), size: 24),
        const SizedBox(width: 16),
        Text(
          text,
          style: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w500,
            color: Colors.black,
          ),
        ),
      ],
    );
  }
}

// 显示订阅对话框的便捷方法
Future<void> showSubscriptionDialog(
  BuildContext context, {
  VoidCallback? onSubscribe,
  VoidCallback? onClose,
}) async {
  return SlideUpOverlay.show(
    context: context,
    child: SubscriptionDialog(onSubscribe: onSubscribe, onClose: onClose),
  );
}
