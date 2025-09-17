import 'dart:convert';
import 'package:flutter/foundation.dart';
import '../models/product_model.dart';
import '../config/api_config.dart';
import 'http_client_service.dart';

class ProductService {
  static final ProductService _instance = ProductService._internal();
  factory ProductService() => _instance;
  ProductService._internal();

  static ProductService get instance => _instance;

  /// 获取商品列表
  /// 
  /// 返回所有可用商品的列表
  /// 自动包含设备ID、访问令牌和签名验证
  Future<ProductListResponse> getProducts() async {
    try {
      debugPrint('🛒 [PRODUCT_SERVICE] 开始获取商品列表');
      
      // 构建请求URL
      final url = Uri.parse('${ApiConfig.baseUrl}/api/v1/products');
      debugPrint('🛒 [PRODUCT_SERVICE] 请求URL: $url');
      
      // 使用HttpClientService发送GET请求（自动处理请求头、签名等）
      final response = await HttpClientService.get(
        url,
        timeout: const Duration(seconds: 30),
      );
      
      debugPrint('🛒 [PRODUCT_SERVICE] 响应状态码: ${response.statusCode}');
      debugPrint('🛒 [PRODUCT_SERVICE] 响应内容: ${response.body}');
      
      // 检查HTTP状态码
      if (response.statusCode == 200) {
        // 解析JSON响应
        final jsonData = json.decode(response.body) as Map<String, dynamic>;
        final productResponse = ProductListResponse.fromJson(jsonData);
        
        if (productResponse.isSuccess) {
          debugPrint('🛒 [PRODUCT_SERVICE] 成功获取 ${productResponse.data.products.length} 个商品');
          return productResponse;
        } else {
          debugPrint('🛒 [PRODUCT_SERVICE] API返回错误: ${productResponse.errMsg}');
          throw Exception('获取商品列表失败: ${productResponse.errMsg}');
        }
      } else {
        debugPrint('🛒 [PRODUCT_SERVICE] HTTP请求失败: ${response.statusCode}');
        throw Exception('网络请求失败: HTTP ${response.statusCode}');
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
      final response = await getProducts();
      return response.data.products
          .where((product) => product.productType == productType)
          .toList();
    } catch (e) {
      debugPrint('🛒 [PRODUCT_SERVICE] 根据类型筛选商品失败: $e');
      rethrow;
    }
  }
  
  /// 根据商品ID获取单个商品
  /// 
  /// [productId] 商品ID
  Future<Product?> getProductById(int productId) async {
    try {
      final response = await getProducts();
      final products = response.data.products
          .where((product) => product.id == productId)
          .toList();
      
      return products.isNotEmpty ? products.first : null;
    } catch (e) {
      debugPrint('🛒 [PRODUCT_SERVICE] 根据ID获取商品失败: $e');
      rethrow;
    }
  }
  
  /// 获取订阅类型商品
  Future<List<Product>> getSubscriptionProducts() async {
    return getProductsByType('subscription');
  }
  
  /// 格式化商品价格显示
  /// 
  /// [product] 商品对象
  /// 返回格式化的价格字符串，如 "$9.99 USD"
  String formatProductPrice(Product product) {
    final currencySymbol = _getCurrencySymbol(product.currency);
    return '$currencySymbol${product.price.toStringAsFixed(2)} ${product.currency}';
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
  
  /// 获取商品持续时间描述
  /// 
  /// [product] 商品对象
  /// 返回持续时间的友好描述，如 "30天", "1个月", "1年"
  String getProductDurationDescription(Product product) {
    final days = product.durationDays;
    
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
}