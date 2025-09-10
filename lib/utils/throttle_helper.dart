/// 节流控制工具类
/// 用于控制函数执行频率，避免过于频繁的调用
class ThrottleHelper {
  DateTime? _lastExecuteTime;
  final Duration _interval;

  /// 创建节流控制器
  /// [interval] 执行间隔时间
  ThrottleHelper({required Duration interval}) : _interval = interval;

  /// 尝试执行函数
  /// 如果距离上次执行时间超过设定间隔，则执行函数并返回true
  /// 否则跳过执行并返回false
  bool tryExecute(Function() callback) {
    final now = DateTime.now();
    
    if (_lastExecuteTime == null || 
        now.difference(_lastExecuteTime!).compareTo(_interval) >= 0) {
      _lastExecuteTime = now;
      callback();
      return true;
    }
    
    return false;
  }

  /// 检查是否可以执行（不执行回调函数）
  bool canExecute() {
    final now = DateTime.now();
    return _lastExecuteTime == null || 
           now.difference(_lastExecuteTime!).compareTo(_interval) >= 0;
  }

  /// 重置执行时间
  void reset() {
    _lastExecuteTime = null;
  }

  /// 创建一个1秒间隔的节流控制器
  static ThrottleHelper oneSecond() {
    return ThrottleHelper(interval: const Duration(seconds: 1));
  }

  /// 创建一个500毫秒间隔的节流控制器
  static ThrottleHelper halfSecond() {
    return ThrottleHelper(interval: const Duration(milliseconds: 500));
  }

  /// 创建一个200毫秒间隔的节流控制器
  static ThrottleHelper twoHundredMs() {
    return ThrottleHelper(interval: const Duration(milliseconds: 200));
  }
}