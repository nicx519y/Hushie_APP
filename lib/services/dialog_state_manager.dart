/// 全局弹窗状态管理器
/// 确保同时只能打开一个弹窗组件
class DialogStateManager {
  static final DialogStateManager _instance = DialogStateManager._internal();
  static DialogStateManager get instance => _instance;
  
  DialogStateManager._internal();
  
  // 当前打开的弹窗类型
  String? _currentOpenDialog;
  
  /// 弹窗类型常量
  static const String subscribeDialog = 'subscribe_dialog';
  static const String historyList = 'history_list';
  
  /// 尝试打开弹窗
  /// 返回true表示可以打开，false表示已有其他弹窗打开
  bool tryOpenDialog(String dialogType) {
    if (_currentOpenDialog != null) {
      return false; // 已有弹窗打开
    }
    _currentOpenDialog = dialogType;
    return true;
  }
  
  /// 关闭弹窗
  void closeDialog(String dialogType) {
    if (_currentOpenDialog == dialogType) {
      _currentOpenDialog = null;
    }
  }
  
  /// 检查是否有弹窗打开
  bool get hasDialogOpen => _currentOpenDialog != null;
  
  /// 获取当前打开的弹窗类型
  String? get currentOpenDialog => _currentOpenDialog;
  
  /// 强制关闭所有弹窗（紧急情况使用）
  void forceCloseAll() {
    _currentOpenDialog = null;
  }
}