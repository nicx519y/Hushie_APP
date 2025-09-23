import 'dart:convert';
import '../../config/api_config.dart';
import '../../models/api_response.dart';
import '../../models/subscribe_model.dart';
import '../../models/payment_method.dart';
import '../http_client_service.dart';

/// Google Play订阅服务
class SubscribeService {
  static Duration get _defaultTimeout => ApiConfig.defaultTimeout;

  /// 创建新的Google Play订阅
  /// 
  /// [request] 创建订阅请求参数
  /// 返回创建的订阅信息
  static Future<ApiResponse<bool>> createSubscribe(CreateSubscribeRequest request) async {
    try {
      // 构建请求URI
      final uri = Uri.parse(ApiConfig.getFullUrl(ApiEndpoints.subscribeCreate));

      // 发送POST请求，HttpClientService会自动处理请求头（包括Authorization、设备ID、签名等）
      final response = await HttpClientService.postJson(
        uri,
        body: request.toJson(),
        timeout: _defaultTimeout,
      );

      final Map<String, dynamic> jsonData = json.decode(response.body);

      // 使用统一的ApiResponse处理响应
      return ApiResponse.fromJson(
        jsonData, 
        (dataJson) => true,
      );
    } catch (e) {
      return ApiResponse.error(errNo: -1);
    }
  }

  /// 创建Google Play订阅
  /// 
  /// [productId] Google Play商品ID
  /// [basePlanId] Google Play基础方案ID
  /// [purchaseToken] Google Play购买凭证
  /// 返回创建的订阅信息
  static Future<ApiResponse<bool>> createGooglePlaySubscribe({
    required String productId,
    required String basePlanId,
    required String purchaseToken,
  }) async {
    final request = CreateSubscribeRequest(
      googlePlayProductId: productId,
      googlePlayBasePlanId: basePlanId,
      paymentMethod: PaymentMethod.googlePlayBilling,
      googlePlayPurchaseToken: purchaseToken,
    );

    return createSubscribe(request);
  }
}