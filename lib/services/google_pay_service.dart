import 'package:flutter/material.dart';
import 'package:pay/pay.dart';

class GooglePayService {
  static const String _googlePayConfigAsset = 'assets/google_pay_config.json';
  
  // 支付项目列表
  static const List<PaymentItem> _paymentItems = [
    PaymentItem(
      label: 'Total',
      amount: '1.00',
      status: PaymentItemStatus.final_price,
    )
  ];
  
  // 创建支付配置
  static Future<PaymentConfiguration> _getPaymentConfiguration() async {
    return PaymentConfiguration.fromAsset(_googlePayConfigAsset);
  }
  
  // 检查用户是否可以使用Google Pay
  static Future<bool> canUserPay() async {
    try {
      final paymentConfiguration = await _getPaymentConfiguration();
      final payClient = Pay({PayProvider.google_pay: paymentConfiguration});
      return await payClient.userCanPay(PayProvider.google_pay);
    } catch (e) {
      debugPrint('检查Google Pay可用性时出错: $e');
      return false;
    }
  }
  
  // 创建Google Pay按钮
  static Widget buildGooglePayButton({
    required Function(Map<String, dynamic>) onPaymentResult,
    List<PaymentItem>? paymentItems,
    GooglePayButtonType type = GooglePayButtonType.buy,
    EdgeInsets margin = const EdgeInsets.all(8.0),
  }) {
    return FutureBuilder<PaymentConfiguration>(
      future: _getPaymentConfiguration(),
      builder: (context, snapshot) {
        if (snapshot.hasData) {
          return GooglePayButton(
            paymentConfiguration: snapshot.data!,
            paymentItems: paymentItems ?? _paymentItems,
            type: type,
            margin: margin,
            onPaymentResult: onPaymentResult,
            loadingIndicator: const Center(
              child: CircularProgressIndicator(),
            ),
          );
        } else if (snapshot.hasError) {
          return Container(
            margin: margin,
            child: Text('加载Google Pay配置失败: ${snapshot.error}'),
          );
        } else {
          return Container(
            margin: margin,
            child: const CircularProgressIndicator(),
          );
        }
      },
    );
  }
  
  // 处理支付结果
  static void handlePaymentResult(Map<String, dynamic> paymentResult) {
    debugPrint('Google Pay支付结果: $paymentResult');
    
    // 这里可以添加将支付令牌发送到后端的逻辑
    // 例如：
    // final paymentToken = paymentResult['paymentMethodData']['tokenizationData']['token'];
    // await sendPaymentTokenToBackend(paymentToken);
  }
  
  // 创建自定义支付项目
  static List<PaymentItem> createPaymentItems({
    required String amount,
    required String currency,
    String label = 'Total',
  }) {
    return [
      PaymentItem(
        label: label,
        amount: amount,
        status: PaymentItemStatus.final_price,
      )
    ];
  }
  
  // 更新支付配置（用于生产环境）
  static PaymentConfiguration createProductionConfig({
    required String merchantId,
    required String merchantName,
    required String gateway,
    required String gatewayMerchantId,
  }) {
    final config = {
      "provider": "google_pay",
      "data": {
        "environment": "PRODUCTION",
        "apiVersion": 2,
        "apiVersionMinor": 0,
        "allowedPaymentMethods": [
          {
            "type": "CARD",
            "parameters": {
              "allowedAuthMethods": ["PAN_ONLY", "CRYPTOGRAM_3DS"],
              "allowedCardNetworks": ["AMEX", "DISCOVER", "JCB", "MASTERCARD", "VISA"]
            },
            "tokenizationSpecification": {
              "type": "PAYMENT_GATEWAY",
              "parameters": {
                "gateway": gateway,
                "gatewayMerchantId": gatewayMerchantId
              }
            }
          }
        ],
        "merchantInfo": {
          "merchantId": merchantId,
          "merchantName": merchantName
        }
      }
    };
    
    return PaymentConfiguration.fromJsonString(config.toString());
  }
}