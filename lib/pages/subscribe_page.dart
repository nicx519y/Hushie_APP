import 'package:flutter/material.dart';
import 'package:hushie_app/components/wide_image_showcase.dart';
import '../components/subscribe_options_dark.dart';
import '../models/product_model.dart';
import '../services/subscribe_privilege_manager.dart';
import '../pages/app_root.dart';
import 'package:flutter_svg/flutter_svg.dart';
import '../utils/custom_icons.dart';

/// 订阅页面
/// 展示订阅选项，用户可以选择订阅计划
class SubscribePage extends StatefulWidget {
  final String? bannerPreference; // 'M' | 'F' | 'F&M'
  final String? scene; // 来源场景，用于打点
  final String? onboardingEnterSource; // 引导进入主页来源透传
  const SubscribePage({super.key, this.bannerPreference, this.scene, this.onboardingEnterSource});

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
    // 跳转到主应用
    _closePage();
  }

  /// 关闭页面
  void _closePage() {
    if (mounted) {
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(
          builder: (context) => MainApp(onboardingEnterSource: widget.onboardingEnterSource),
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
        SvgPicture.asset('assets/icons/flower.svg', width: 46, height: 83,),
        const SizedBox(width: 8),
        Text(
          'Members\nEnjoy Full Access',
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 26,
            height: 1.4,
            fontWeight: FontWeight.w700,
            color: Color(0xFFFFFFFF),
          ),
        ),
        const SizedBox(width: 8),
        Transform.scale(
          scaleX: -1,
          child: SvgPicture.asset('assets/icons/flower.svg', width: 46, height: 83,),
        ),
      ],
    );
  }

  Widget _buildFeatureItem(String text) {
    return Row(
      children: [
        Container(
          width: 16,
          height: 16,
          decoration: BoxDecoration(
            color: Color(0xFFF05621),
            borderRadius: BorderRadius.circular(8),
          ),
          child: const Icon(CustomIcons.check, color: Color(0xFFFFFFFF), size: 10),
        ),
        const SizedBox(width: 8),
        Text(
          text,
          style: const TextStyle(
            fontSize: 14,
            height: 1,
            fontWeight: FontWeight.w500,
            color: Color(0xFFFFFFFF),
          ),
        ),
      ],
    );
  }

  String _bannerAssetByPreference(String? pref) {
    switch (pref) {
      case 'M':
        return 'assets/images/banner_M.webp';
      case 'F&M':
        return 'assets/images/banner_F&M.webp';
      case 'F':
      default:
        return 'assets/images/banner_F.webp';
    }
  }

  @override
  Widget build(BuildContext context) {
    final AssetImage bannerImage = AssetImage(_bannerAssetByPreference(widget.bannerPreference));

    return Scaffold(
      backgroundColor: Color(0xFF000103),
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
                            Center(
                              child: IntrinsicWidth(
                                child: Column(
                                  mainAxisSize: MainAxisSize.min,
                                  crossAxisAlignment: CrossAxisAlignment.stretch,
                                  children: [
                                    _buildFeatureItem('Unlimited Creations'),
                                    const SizedBox(height: 11),
                                    _buildFeatureItem('Real-time Al Captions'),
                                    const SizedBox(height: 11),
                                    _buildFeatureItem('Customized Suggestions'),
                                  ],
                                ),
                              ),
                            ),
                            const SizedBox(height: 30),
                            _product != null
                                ? SubscribeOptionsDark(
                                    product: _product,
                                    selectedPlan: _selectedPlan,
                                    scene: widget.scene,
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
