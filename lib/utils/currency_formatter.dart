/// 货币格式化工具类
class CurrencyFormatter {
  /// 根据货币代码格式化价格显示
  /// 
  /// [price] 价格数值
  /// [currency] 货币代码 (如: USD, EUR, GBP, JPY, CNY, KRW)
  /// 
  /// 返回格式化后的价格字符串，包含相应的货币符号
  static String formatPrice(double price, String currency) {
    String symbol;
    switch (currency.toUpperCase()) {
      case 'USD':
        symbol = '\$';
        break;
      case 'EUR':
        symbol = '€';
        break;
      case 'GBP':
        symbol = '£';
        break;
      case 'JPY':
        symbol = '¥';
        break;
      case 'CNY':
        symbol = '¥';
        break;
      case 'KRW':
        symbol = '₩';
        break;
      default:
        symbol = currency;
    }
    return '$symbol${price.toStringAsFixed(2)}';
  }

  /// 获取货币符号
  /// 
  /// [currency] 货币代码
  /// 
  /// 返回对应的货币符号字符串
  static String getCurrencySymbol(String currency) {
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
      case 'KRW':
        return '₩';
      default:
        return currency;
    }
  }
}