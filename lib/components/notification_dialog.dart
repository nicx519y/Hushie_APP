import 'package:flutter/material.dart';

class NotificationDialog extends StatelessWidget {
  final String title;
  final String message;
  final String buttonText;
  final VoidCallback? onConfirm;
  final double? width; // 添加宽度控制参数

  const NotificationDialog({
    super.key,
    this.title = 'Notification',
    required this.message,
    this.buttonText = 'Got It',
    this.onConfirm,
    this.width = 287, // 可选的宽度参数
  });

  void _handleConfirm(BuildContext context) {
    if (onConfirm != null) {
      onConfirm!();
    }
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.transparent,
      child: Container(
        width: width, // 应用宽度约束
        padding: const EdgeInsets.only(
          left: 22,
          right: 22,
          top: 38,
          bottom: 20,
        ),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(32),
          image: const DecorationImage(
            image: AssetImage('assets/images/dailog_bg.png'),
            fit: BoxFit.none,
            alignment: Alignment(0.2, 0.1),
          ),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // 标题
            Text(
              title,
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: Color(0xFF333333),
              ),
              textAlign: TextAlign.center,
            ),

            const SizedBox(height: 12),

            // 消息内容
            Text(
              message,
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w400,
                color: Color(0xFF666666),
                height: 1.67,
              ),
              textAlign: TextAlign.center,
            ),

            const SizedBox(height: 18),

            // 确认按钮
            SizedBox(
              width: double.infinity,
              height: 44,
              child: ElevatedButton(
                onPressed: () => _handleConfirm(context),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFFFDE69),
                  foregroundColor: const Color(0xFF502D19),
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(24),
                  ),
                ),
                child: Text(
                  buttonText,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// 显示通知对话框的便捷方法
Future<void> showNotificationDialog(
  BuildContext context, {
  String title = 'Notification',
  required String message,
  String buttonText = 'Got It',
  VoidCallback? onConfirm,
  double? width, // 添加宽度参数
}) async {
  return showDialog<void>(
    context: context,
    barrierDismissible: false,
    builder: (BuildContext context) {
      return NotificationDialog(
        title: title,
        message: message,
        buttonText: buttonText,
        onConfirm: onConfirm,
        width: width, // 传递宽度参数
      );
    },
  );
}