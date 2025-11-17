import 'package:flutter/material.dart';

class ConfirmDialog extends StatefulWidget {
  final String title;
  final String? message;
  final String confirmText;
  final String cancelText;
  final VoidCallback onConfirm;
  final VoidCallback? onCancel;
  final bool isLoading;
  final Color confirmButtonColor;
  final Color cancelButtonColor;
  final Color confirmTextColor;
  final Color cancelTextColor;

  const ConfirmDialog({
    super.key,
    required this.title,
    this.message,
    this.confirmText = 'Confirm',
    this.cancelText = 'Cancel',
    required this.onConfirm,
    this.onCancel,
    this.isLoading = false,
    this.confirmButtonColor = const Color(0xFFFF2050),
    this.cancelButtonColor = Colors.grey,
    this.confirmTextColor = const Color(0xFFFF2050),
    this.cancelTextColor = Colors.black54,
  });

  @override
  State<ConfirmDialog> createState() => _ConfirmDialogState();

  /// 显示确认对话框的静态方法
  static Future<bool?> show({
    required BuildContext context,
    required String title,
    String? message,
    String confirmText = 'Confirm',
    String cancelText = 'Cancel',
    Color confirmButtonColor = const Color(0xFFFF2050),
    Color cancelButtonColor = Colors.grey,
    Color confirmTextColor = const Color(0xFFFF2050),
    Color cancelTextColor = Colors.black54,
  }) {
    return showDialog<bool>(
      context: context,
      barrierDismissible: false,
      barrierColor: Colors.black.withAlpha(128),
      useRootNavigator: true,
      builder: (BuildContext context) {
        return ConfirmDialog(
          title: title,
          message: message,
          confirmText: confirmText,
          cancelText: cancelText,
          confirmButtonColor: confirmButtonColor,
          cancelButtonColor: cancelButtonColor,
          confirmTextColor: confirmTextColor,
          cancelTextColor: cancelTextColor,
          onConfirm: () => Navigator.of(context).pop(true),
          onCancel: () => Navigator.of(context).pop(false),
        );
      },
    );
  }

  /// 显示带有loading状态的确认对话框
  static Future<void> showWithLoading({
    required BuildContext context,
    required String title,
    String? message,
    String confirmText = 'Confirm',
    String cancelText = 'Cancel',
    required Future<void> Function() onConfirm,
    Color confirmButtonColor = const Color(0xFFFF2050),
    Color cancelButtonColor = Colors.grey,
    Color confirmTextColor = const Color(0xFFFF2050),
    Color cancelTextColor = Colors.black54,
  }) async {
    bool isLoading = false;

    return showDialog<void>(
      context: context,
      barrierDismissible: false,
      barrierColor: Colors.black.withAlpha(128),
      useRootNavigator: true,
      builder: (BuildContext dialogContext) {
        return StatefulBuilder(
          builder: (context, setState) {
            return ConfirmDialog(
              title: title,
              message: message,
              confirmText: confirmText,
              cancelText: cancelText,
              isLoading: isLoading,
              confirmButtonColor: confirmButtonColor,
              cancelButtonColor: cancelButtonColor,
              confirmTextColor: confirmTextColor,
              cancelTextColor: cancelTextColor,
              onConfirm: () async {
                setState(() {
                  isLoading = true;
                });

                try {
                  await onConfirm();
                  if (context.mounted) {
                    Navigator.of(dialogContext).pop();
                  }
                } catch (e) {
                  setState(() {
                    isLoading = false;
                  });
                  rethrow;
                }
              },
              onCancel: isLoading
                  ? null
                  : () => Navigator.of(dialogContext).pop(),
            );
          },
        );
      },
    );
  }
}

class _ConfirmDialogState extends State<ConfirmDialog> {
  @override
  void initState() {
    super.initState();
    // 隐藏系统UI，实现全屏
    // SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
  }

  @override
  void dispose() {
    // 恢复系统UI
    // SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: Center(
        child: Container(
          width: 240,
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(32),
          ),
          child: Padding(
            padding: const EdgeInsets.all(0),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // 标题
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.only(
                    top: 35,
                    bottom: 24,
                    left: 10,
                    right: 10,
                  ),
                  child: Text(
                    widget.title,
                    style: const TextStyle(
                      fontSize: 14,
                      height: 1.5,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFF333333),
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),

                // 按钮区域
                Column(
                  children: [
                    // 确认按钮
                    if (widget.confirmText.isNotEmpty) ...[
                      _buildButton(
                        widget.confirmText,
                        const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          color: Color(0xFFFF2050),
                        ),
                        widget.onConfirm,
                        true,
                      ),
                    ],
                    if (widget.cancelText.isNotEmpty) ...[
                      _buildButton(
                        widget.cancelText,
                        const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w400,
                          color: Color(0xFF000000),
                        ),
                        widget.onCancel ?? () => Navigator.of(context).pop(),
                        false,
                      ),
                    ],
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildButton(
    String label,
    TextStyle? textStyle,
    VoidCallback? onPressed,
    bool? showLoading,
  ) {
    final bool _showLoading = showLoading ?? false;
    final VoidCallback _onPressed = onPressed ?? () {};

    return InkWell(
      onTap: widget.isLoading ? null : _onPressed, // 如果显示loading，则不响应点击事件
      child: SizedBox(
        width: double.infinity,
        height: 48,
        child: Container(
          alignment: Alignment.center,
          padding: const EdgeInsets.symmetric(vertical: 12),
          decoration: BoxDecoration(
            color: Colors.transparent,
            border: Border(top: BorderSide(color: Color(0xFFD8D8D8))),
          ),
          child: (widget.isLoading && _showLoading)
              ? SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    valueColor: AlwaysStoppedAnimation<Color>(
                      widget.confirmButtonColor,
                    ),
                  ),
                )
              : Text(
                  label,
                  style:
                      textStyle ??
                      const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w500,
                        color: Color(0xFF333333),
                      ),
                ),
        ),
      ),
    );
  }
}
