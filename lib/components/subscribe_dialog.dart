import 'package:flutter/material.dart';
import 'dart:async';
import 'slide_up_overlay.dart';
import 'subscribe_options.dart';
import '../utils/custom_icons.dart';
import '../models/product_model.dart';
import '../services/dialog_state_manager.dart';
import '../services/subscribe_privilege_manager.dart';
import '../services/api/tracking_service.dart';

class SubscribeDialog extends StatefulWidget {
  final VoidCallback? onSubscribe;
  final String? scene;

  const SubscribeDialog({super.key, this.onSubscribe, this.scene});

  @override
  State<SubscribeDialog> createState() => _SubscribeDialogState();
}

class _SubscribeDialogState extends State<SubscribeDialog> {
  int _selectedPlan = 0; // 0: First Month, 1: Per year
  Product? _product; // 从服务获取的商品数据
  bool _isLoading = true; // 数据加载状态

  @override
  void initState() {
    super.initState();
    _sendOpenTracking();
    _loadProductData();
  }

  /// 订阅弹窗打开时上报一次打点（分场景）
  void _sendOpenTracking() {
    try {
      TrackingService.trackMembershipOverlay(scene: widget.scene ?? 'unknown');
      debugPrint('📍 [TRACKING] membership_overlay_show scene=${widget.scene ?? 'unknown'}');
    } catch (e) {
      debugPrint('📍 [TRACKING] membership_overlay_show error: $e');
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


  @override
  void dispose() {
    // 清除弹窗状态标志
    DialogStateManager.instance.closeDialog(DialogStateManager.subscribeDialog);
    super.dispose();
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
                      _buildFeatureItem('Unlimited Creations'),
                      const SizedBox(height: 13),
                      _buildFeatureItem('Real-time Al Captions'),
                      const SizedBox(height: 13),
                      _buildFeatureItem('Customized Suggestions'),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 25),

              // 使用新的订阅选项组件
              SubscribeOptions(
                product: _product,
                selectedPlan: _selectedPlan,
                onPlanSelected: (planIndex) {
                  setState(() {
                    _selectedPlan = planIndex;
                  });
                },
                onSubscribeSuccess: () {
                  _closeDialog();
                  openSubscribeSuccessNotification(context);
                },
                scene: widget.scene,
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


}

// 显示订阅对话框的便捷方法
Future<void> showSubscribeDialog(BuildContext context, {String? scene}) async {
  // 检查是否已有弹窗打开
  if (!DialogStateManager.instance.tryOpenDialog(
    DialogStateManager.subscribeDialog,
  )) {
    return; // 已有其他弹窗打开，直接返回
  }

  return SlideUpOverlay.show(context: context, child: SubscribeDialog(scene: scene));
}
