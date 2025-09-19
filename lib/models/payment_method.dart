/// 支付方式枚举
/// 
/// 定义应用支持的支付方式类型
enum PaymentMethod {
  /// Google Play Billing支付
  googlePlayBilling('google_play_billing');

  const PaymentMethod(this.value);

  /// 枚举值对应的字符串
  final String value;

  /// 从字符串值创建枚举
  /// 
  /// [value] 字符串值
  /// 返回对应的PaymentMethod枚举，如果不匹配则抛出异常
  static PaymentMethod fromValue(String value) {
    for (PaymentMethod method in PaymentMethod.values) {
      if (method.value == value) {
        return method;
      }
    }
    throw ArgumentError('Unknown payment method: $value');
  }

  /// 获取所有支持的支付方式值
  /// 返回所有支付方式的字符串值列表
  static List<String> get supportedValues {
    return PaymentMethod.values.map((method) => method.value).toList();
  }

  @override
  String toString() => value;
}