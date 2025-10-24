import 'package:flutter/material.dart';
import 'package:hushie_app/components/wide_image_showcase.dart';
import '../components/subscribe_options.dart';
import '../models/product_model.dart';
import '../services/subscribe_privilege_manager.dart';
import '../utils/toast_helper.dart';
import '../pages/app_root.dart';

/// 订阅页面
/// 展示订阅选项，用户可以选择订阅计划
class SubscribePage extends StatefulWidget {
  final String? bannerPreference; // 'M' | 'F' | 'F&M'
  const SubscribePage({super.key, this.bannerPreference});

  @override
  State<SubscribePage> createState() => _SubscribePageState();
}

class _SubscribePageState extends State<SubscribePage> {
  int _selectedPlan = 0; // 默认选择第一个计划
  Product? _product; // 从服务获取的商品数据
  bool _isLoading = true; // 数据加载状态

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

      // 如果没有获取到商品数据，显示错误信息
      if (_product == null) {
        debugPrint('🏆 [SUBSCRIBE_PAGE] 未获取到商品数据');
      }
    } catch (e) {
      debugPrint('🏆 [SUBSCRIBE_PAGE] 获取商品数据失败: $e');
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  /// 订阅成功回调
  void _onSubscribeSuccess() {
    ToastHelper.showSuccess('订阅成功！');

    // 跳转到主应用
    _closePage();
  }

  /// 关闭页面
  void _closePage() {
    if (mounted) {
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(
          builder: (context) => const MainApp(),
          settings: const RouteSettings(name: '/main'),
        ),
      );
    }
  }

  Widget _buildCloseButton() {
    return IconButton(
      alignment: Alignment.center,
      style: IconButton.styleFrom(
        // tapTargetSize: MaterialTapTargetSize.shrinkWrap,
        backgroundColor: const Color(0xFF000000).withAlpha(102),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        minimumSize: const Size(40, 40),
      ),
      onPressed: () => _closePage(),
      icon: Icon(Icons.close, color: Colors.white, size: 24),
    );
  }

  Widget _buildUnlockFullAccessTitle() {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 40,
          height: 40,
          padding: EdgeInsets.all(6),
          decoration: BoxDecoration(
            color: Color(0xFF502D19),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Image.asset(
            'assets/images/crown_mini.png', //皇冠
            fit: BoxFit.contain,
          ),
        ),
        const SizedBox(width: 8),
        Text(
          'Unlock Full Access',
          style: TextStyle(
            fontSize: 20,
            height: 1,
            fontWeight: FontWeight.w700,
            color: Color(0xFF502D19),
          ),
        ),
      ],
    );
  }

  String _bannerAssetByPreference(String? pref) {
    switch (pref) {
      case 'M':
        return 'assets/images/banner_M.jpg';
      case 'F&M':
        return 'assets/images/banner_F&M.jpg';
      case 'F':
      default:
        return 'assets/images/banner_F.jpg';
    }
  }

  @override
  Widget build(BuildContext context) {
    final AssetImage bannerImage = AssetImage(_bannerAssetByPreference(widget.bannerPreference));

    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        top: false,
        child: _isLoading
            ? const Center(child: CircularProgressIndicator())
            : Stack(
                children: [
                  
                  Column(
                    children: [
                      // 顶部区域
                      Expanded(child: WideImageShowcase(image: bannerImage)),
                      // 底部订阅选项区域（贴底放置）
                      Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 24,
                        ),
                        child: Column(
                          children: [
                            _buildUnlockFullAccessTitle(),
                            const SizedBox(height: 30),
                            _product != null
                                ? SubscribeOptions(
                                    product: _product,
                                    selectedPlan: _selectedPlan,
                                    onPlanSelected: (planIndex) {
                                      setState(() {
                                        _selectedPlan = planIndex;
                                      });
                                    },
                                    onSubscribeSuccess: _onSubscribeSuccess,
                                  )
                                : const Center(
                                    child: Text(
                                      'Unable to load subscription options',
                                      style: TextStyle(
                                        fontSize: 16,
                                        color: Color(0xFF999999),
                                      ),
                                    ),
                                  ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  Positioned(top: MediaQuery.of(context).padding.top + 20, left: 16, child: _buildCloseButton()),
                ],
              ),
      ),
    );
  }

  
}
