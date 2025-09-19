import 'dart:convert';
import '../../config/api_config.dart';
import '../../models/api_response.dart';
import '../../models/subscribe_model.dart';
import '../../models/payment_method.dart';
import '../http_client_service.dart';
import '../auth_service.dart';

/// Google Play订阅服务
class SubscribeService {
  static Duration get _defaultTimeout => ApiConfig.defaultTimeout;

  /// 创建新的Google Play订阅
  /// 
  /// [request] 创建订阅请求参数
  /// 返回创建的订阅信息
  static Future<ApiResponse<SubscribeModel>> createSubscribe(CreateSubscribeRequest request) async {
    try {
      // 获取访问令牌
      final accessToken = await AuthService.getAccessToken();
      if (accessToken == null || accessToken.isEmpty) {
        return ApiResponse.error(errNo: -1);
      }

      // 构建请求URI
      final uri = Uri.parse(ApiConfig.getFullUrl(ApiEndpoints.subscribeCreate));

      // 发送POST请求，使用公共请求头
      final response = await HttpClientService.postJson(
        uri,
        body: request.toJson(),
        timeout: _defaultTimeout,
        headers: ApiConfig.getAuthHeaders(token: accessToken),
      );

      final Map<String, dynamic> jsonData = json.decode(response.body);

      // 使用统一的ApiResponse处理响应
      return ApiResponse.fromJson(
        jsonData,
        (dataJson) => SubscribeModel.fromJson(dataJson),
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
  static Future<ApiResponse<SubscribeModel>> createGooglePlaySubscribe({
    required String productId,
    required String basePlanId,
    required String purchaseToken,
  }) async {
    final request = CreateSubscribeRequest(
      googlePlayProductId: productId,
      googlePlayBasePlanId: basePlanId,
      paymentMethod: PaymentMethod.googlePay,
      googlePlayPurchaseToken: purchaseToken,
    );

    return createSubscribe(request);
  }
}