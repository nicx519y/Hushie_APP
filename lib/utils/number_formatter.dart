/// 数字格式化工具类
class NumberFormatter {
  /// 格式化数字显示
  ///
  /// 规则：
  /// 1. 大于0，小于1000的，显示实际数字
  /// 2. 大于等于1000，小于100万的，除以1000，后缀单位"K"
  /// 3. 大于等于100万，除以1000000，后缀单位"M"
  /// 4. 所有的换算后，只有在整数位只有1位的时候，才显示小数点后1位，
  ///    如果整数位大于1位，则不显示小数点和小数位。四舍五入
  ///
  /// 示例：
  /// - 999 -> "999"
  /// - 1000 -> "1.0K"
  /// - 1500 -> "1.5K"
  /// - 12000 -> "12K"
  /// - 1000000 -> "1.0M"
  /// - 1500000 -> "1.5M"
  /// - 12000000 -> "12M"
  static String countNumFilter(int number) {
    if (number < 0) {
      return "0";
    }

    if (number < 1000) {
      // 大于0，小于1000的，显示实际数字
      return number.toString();
    } else if (number < 1000000) {
      // 大于等于1000，小于100万的，除以1000，后缀单位"K"
      double result = number / 1000.0;
      return _formatWithSuffix(result, "K");
    } else {
      // 大于等于100万，除以1000000，后缀单位"M"
      double result = number / 1000000.0;
      return _formatWithSuffix(result, "M");
    }
  }

  /// 格式化数字并添加后缀
  /// 只有在整数位只有1位的时候，才显示小数点后1位
  /// 如果整数位大于1位，则不显示小数点和小数位
  static String _formatWithSuffix(double value, String suffix) {
    // 四舍五入到1位小数
    double rounded = (value * 10).round() / 10;

    // 检查整数位数
    int integerPart = rounded.floor();

    if (integerPart < 10) {
      // 整数位只有1位，显示1位小数
      if (rounded == integerPart) {
        // 如果小数部分为0，显示 .0
        return "${integerPart.toString()}.0$suffix";
      } else {
        // 显示1位小数
        return "${rounded.toStringAsFixed(1)}$suffix";
      }
    } else {
      // 整数位大于1位，不显示小数点和小数位
      return "${integerPart.toString()}$suffix";
    }
  }
}
