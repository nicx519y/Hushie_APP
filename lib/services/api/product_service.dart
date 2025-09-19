import 'dart:convert';
import 'package:flutter/foundation.dart';
import '../../models/product_model.dart';
import '../../models/api_response.dart';
import '../../config/api_config.dart';
import '../http_client_service.dart';

class ProductService {
  static final ProductService _instance = ProductService._internal();
  factory ProductService() => _instance;
  ProductService._internal();

  static ProductService get instance => _instance;

  /// 获取商品列表
  /// 
  /// 返回所有可用商品的列表
  /// 自动包含设备ID、访问令牌和签名验证
  Future<ProductData> getProducts() async {
    try {
      debugPrint('🛒 [PRODUCT_SERVICE] 开始获取商品列表');
      
      // 构建请求URL
      final url = Uri.parse('${ApiConfig.baseUrl}${ApiEndpoints.productList}');
      debugPrint('🛒 [PRODUCT_SERVICE] 请求URL: $url');
      
      // 使用HttpClientService发送GET请求（自动处理请求头、签名等）
      final response = await HttpClientService.get(
        url,
        timeout: const Duration(seconds: 30),
      );
      
      debugPrint('🛒 [PRODUCT_SERVICE] 响应状态码: ${response.statusCode}');
      debugPrint('🛒 [PRODUCT_SERVICE] 响应内容: ${response.body}');
      
      // 解析JSON响应并使用ApiResponse统一处理
      final jsonData = json.decode(response.body) as Map<String, dynamic>;
      final apiResponse = ApiResponse.fromJson<ProductData>(
        jsonData,
        (data) => ProductData.fromJson(data),
      );
      
      if (apiResponse.data != null) {
        debugPrint('🛒 [PRODUCT_SERVICE] 成功获取 ${apiResponse.data!.products.length} 个商品');
        return apiResponse.data!;
      } else {
        debugPrint('🛒 [PRODUCT_SERVICE] API返回错误: errNo=${apiResponse.errNo}');
        throw Exception('获取商品列表失败: errNo=${apiResponse.errNo}');
      }
      
    } catch (e) {
      debugPrint('🛒 [PRODUCT_SERVICE] 获取商品列表异常: $e');
      rethrow;
    }
  }
  
  /// 根据商品类型筛选商品
  /// 
  /// [productType] 商品类型，如 'subscription'
  Future<List<Product>> getProductsByType(String productType) async {
    try {
      final productData = await getProducts();
      return productData.products
          .where((product) => product.productType == productType)
          .toList();
    } catch (e) {
      debugPrint('🛒 [PRODUCT_SERVICE] 根据类型筛选商品失败: $e');
      rethrow;
    }
  }
  
  /// 根据Google Play产品ID获取单个商品
  /// 
  /// [googlePlayProductId] Google Play产品ID
  Future<Product?> getProductByGooglePlayId(String googlePlayProductId) async {
    try {
      final productData = await getProducts();
      final products = productData.products
          .where((product) => product.googlePlayProductId == googlePlayProductId)
          .toList();
      
      return products.isNotEmpty ? products.first : null;
    } catch (e) {
      debugPrint('🛒 [PRODUCT_SERVICE] 根据Google Play ID获取商品失败: $e');
      rethrow;
    }
  }
  
  /// 获取订阅类型商品
  Future<List<Product>> getSubscriptionProducts() async {
    return getProductsByType('subscription');
  }
  
  /// 根据基础计划ID获取基础计划
  /// 
  /// [googlePlayBasePlanId] Google Play基础计划ID
  Future<BasePlan?> getBasePlanById(String googlePlayBasePlanId) async {
    try {
      final productData = await getProducts();
      for (final product in productData.products) {
        for (final basePlan in product.basePlans) {
          if (basePlan.googlePlayBasePlanId == googlePlayBasePlanId) {
            return basePlan;
          }
        }
      }
      return null;
    } catch (e) {
      debugPrint('🛒 [PRODUCT_SERVICE] 根据基础计划ID获取计划失败: $e');
      rethrow;
    }
  }
  
  /// 获取产品的所有基础计划
  /// 
  /// [googlePlayProductId] Google Play产品ID
  Future<List<BasePlan>> getBasePlansForProduct(String googlePlayProductId) async {
    try {
      final product = await getProductByGooglePlayId(googlePlayProductId);
      return product?.basePlans ?? [];
    } catch (e) {
      debugPrint('🛒 [PRODUCT_SERVICE] 获取产品基础计划失败: $e');
      rethrow;
    }
  }
  
  /// 格式化基础计划价格显示
  /// 
  /// [basePlan] 基础计划对象
  /// 返回格式化的价格字符串，如 "$9.99 USD"
  String formatBasePlanPrice(BasePlan basePlan) {
    final currencySymbol = _getCurrencySymbol(basePlan.currency);
    return '$currencySymbol${basePlan.price.toStringAsFixed(2)} ${basePlan.currency}';
  }
  
  /// 格式化优惠价格显示
  /// 
  /// [offer] 优惠对象
  /// 返回格式化的价格字符串，如 "$4.99 USD"
  String formatOfferPrice(Offer offer) {
    final currencySymbol = _getCurrencySymbol(offer.currency);
    return '$currencySymbol${offer.price.toStringAsFixed(2)} ${offer.currency}';
  }
  
  /// 获取货币符号
  String _getCurrencySymbol(String currency) {
    switch (currency.toUpperCase()) {
      case 'USD':
        return '\$';
      case 'EUR':
        return '€';
      case 'GBP':
        return '£';
      case 'JPY':
        return '¥';
      case 'CNY':
        return '¥';
      default:
        return '';
    }
  }
  
  /// 获取基础计划持续时间描述
  /// 
  /// [basePlan] 基础计划对象
  /// 返回持续时间的友好描述，如 "30天", "1个月", "1年"
  String getBasePlanDurationDescription(BasePlan basePlan) {
    final days = basePlan.durationDays;
    
    if (days == 1) {
      return '1天';
    } else if (days == 7) {
      return '1周';
    } else if (days == 30) {
      return '1个月';
    } else if (days == 90) {
      return '3个月';
    } else if (days == 365) {
      return '1年';
    } else if (days % 30 == 0) {
      return '${days ~/ 30}个月';
    } else if (days % 7 == 0) {
      return '${days ~/ 7}周';
    } else {
      return '$days天';
    }
  }
  
  /// 获取计费周期的友好描述
  /// 
  /// [billingPeriod] 计费周期
  /// 返回计费周期的中文描述
  String getBillingPeriodDescription(String billingPeriod) {
    switch (billingPeriod.toLowerCase()) {
      case 'monthly':
        return '按月计费';
      case 'yearly':
        return '按年计费';
      case 'weekly':
        return '按周计费';
      case 'daily':
        return '按日计费';
      default:
        return billingPeriod;
    }
  }
  
  /// 检查基础计划是否有优惠
  /// 
  /// [basePlan] 基础计划对象
  /// 返回是否有可用优惠
  bool hasOffers(BasePlan basePlan) {
    return basePlan.offers.isNotEmpty;
  }
  
  /// 获取基础计划的最佳优惠（价格最低的优惠）
  /// 
  /// [basePlan] 基础计划对象
  /// 返回价格最低的优惠，如果没有优惠则返回null
  Offer? getBestOffer(BasePlan basePlan) {
    if (basePlan.offers.isEmpty) return null;
    
    return basePlan.offers.reduce((current, next) => 
        current.price < next.price ? current : next);
  }
  
  /// 计算优惠折扣百分比
  /// 
  /// [basePlan] 基础计划对象
  /// [offer] 优惠对象
  /// 返回折扣百分比（0-100）
  double calculateDiscountPercentage(BasePlan basePlan, Offer offer) {
    if (basePlan.price <= 0) return 0;
    return ((basePlan.price - offer.price) / basePlan.price * 100);
  }
}