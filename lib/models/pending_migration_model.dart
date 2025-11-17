class PendingMigrationInfo {
  final bool hasPendingOrders;
  final int pendingOrderCount;
  final int pendingSubscriptionCount;
  final String deviceId;
  final String message;

  PendingMigrationInfo({
    required this.hasPendingOrders,
    required this.pendingOrderCount,
    required this.pendingSubscriptionCount,
    required this.deviceId,
    required this.message,
  });

  factory PendingMigrationInfo.fromMap(Map<String, dynamic> map) {
    return PendingMigrationInfo(
      hasPendingOrders: map['has_pending_orders'] ?? false,
      pendingOrderCount: map['pending_order_count'] ?? 0,
      pendingSubscriptionCount: map['pending_subscription_count'] ?? 0,
      deviceId: map['device_id'] ?? '',
      message: map['message'] ?? '',
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'has_pending_orders': hasPendingOrders,
      'pending_order_count': pendingOrderCount,
      'pending_subscription_count': pendingSubscriptionCount,
      'device_id': deviceId,
      'message': message,
    };
  }
}