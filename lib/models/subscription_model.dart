import 'payment_method.dart';

/// Google Play订阅数据模型
class SubscriptionModel {
  final int id;
  final int userId;
  final String googlePlayProductId;
  final String googlePlayBasePlanId;
  final String subscriptionType;
  final String status;
  final PaymentMethod paymentMethod;
  final double amount;
  final String currency;
  final DateTime startDate;
  final DateTime currentPeriodStart;
  final DateTime currentPeriodEnd;
  final DateTime nextBillingDate;
  final String googlePlayPurchaseToken;
  final String googlePlayOrderId;
  final DateTime createdAt;

  SubscriptionModel({
    required this.id,
    required this.userId,
    required this.googlePlayProductId,
    required this.googlePlayBasePlanId,
    required this.subscriptionType,
    required this.status,
    required this.paymentMethod,
    required this.amount,
    required this.currency,
    required this.startDate,
    required this.currentPeriodStart,
    required this.currentPeriodEnd,
    required this.nextBillingDate,
    required this.googlePlayPurchaseToken,
    required this.googlePlayOrderId,
    required this.createdAt,
  });

  /// 从JSON创建SubscriptionModel实例
  factory SubscriptionModel.fromJson(Map<String, dynamic> json) {
    return SubscriptionModel(
      id: json['id'] ?? 0,
      userId: json['user_id'] ?? 0,
      googlePlayProductId: json['google_play_product_id'] ?? '',
      googlePlayBasePlanId: json['google_play_base_plan_id'] ?? '',
      subscriptionType: json['subscription_type'] ?? '',
      status: json['status'] ?? '',
      paymentMethod: PaymentMethod.fromValue(json['payment_method'] ?? 'google_play'),
      amount: (json['amount'] ?? 0.0).toDouble(),
      currency: json['currency'] ?? 'USD',
      startDate: DateTime.parse(json['start_date'] ?? DateTime.now().toIso8601String()),
      currentPeriodStart: DateTime.parse(json['current_period_start'] ?? DateTime.now().toIso8601String()),
      currentPeriodEnd: DateTime.parse(json['current_period_end'] ?? DateTime.now().toIso8601String()),
      nextBillingDate: DateTime.parse(json['next_billing_date'] ?? DateTime.now().toIso8601String()),
      googlePlayPurchaseToken: json['google_play_purchase_token'] ?? '',
      googlePlayOrderId: json['google_play_order_id'] ?? '',
      createdAt: DateTime.parse(json['created_at'] ?? DateTime.now().toIso8601String()),
    );
  }

  /// 转换为JSON
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'user_id': userId,
      'google_play_product_id': googlePlayProductId,
      'google_play_base_plan_id': googlePlayBasePlanId,
      'subscription_type': subscriptionType,
      'status': status,
      'payment_method': paymentMethod.value,
      'amount': amount,
      'currency': currency,
      'start_date': startDate.toIso8601String(),
      'current_period_start': currentPeriodStart.toIso8601String(),
      'current_period_end': currentPeriodEnd.toIso8601String(),
      'next_billing_date': nextBillingDate.toIso8601String(),
      'google_play_purchase_token': googlePlayPurchaseToken,
      'google_play_order_id': googlePlayOrderId,
      'created_at': createdAt.toIso8601String(),
    };
  }

  @override
  String toString() {
    return 'SubscriptionModel(id: $id, userId: $userId, productId: $googlePlayProductId, status: $status, amount: $amount $currency)';
  }
}

/// 创建订阅请求数据模型
class CreateSubscriptionRequest {
  final String googlePlayProductId;
  final String googlePlayBasePlanId;
  final PaymentMethod paymentMethod;
  final String googlePlayPurchaseToken;

  CreateSubscriptionRequest({
    required this.googlePlayProductId,
    required this.googlePlayBasePlanId,
    required this.paymentMethod,
    required this.googlePlayPurchaseToken,
  });

  /// 转换为JSON
  Map<String, dynamic> toJson() {
    return {
      'google_play_product_id': googlePlayProductId,
      'google_play_base_plan_id': googlePlayBasePlanId,
      'payment_method': paymentMethod.value,
      'google_play_purchase_token': googlePlayPurchaseToken,
    };
  }

  @override
  String toString() {
    return 'CreateSubscriptionRequest(productId: $googlePlayProductId, basePlanId: $googlePlayBasePlanId, paymentMethod: ${paymentMethod.value})';
  }
}