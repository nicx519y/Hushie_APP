import 'package:flutter/material.dart';
import 'overlay_fade.dart';

class NotificationDialog extends StatelessWidget {
  final String title;
  final String message;
  final String buttonText;
  final VoidCallback? onConfirm;
  final double? width; // 添加宽度控制参数
  final VoidCallback? onRequestClose; // 新增：请求关闭以走淡出动画

  const NotificationDialog({
    super.key,
    this.title = 'Notification',
    required this.message,
    this.buttonText = 'Got It',
    this.onConfirm,
    this.width = 254, // 可选的宽度参数
    this.onRequestClose,
  });

  void _handleConfirm(BuildContext context) {
    final onConfirm = this.onConfirm;
    if (onConfirm != null) {
      onConfirm();
    }
    // 使用统一的淡出动画关闭
    final requestClose = onRequestClose;
    if (requestClose != null) {
      requestClose();
    } else {
      // 兜底：如果没有传入关闭函数，仍然关闭路由
      Navigator.of(context, rootNavigator: true).pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    // 改为普通容器，由 OverlayFade 负责蒙层和动画
    return Container(
      width: width ?? 254, // 应用宽度约束
      padding: const EdgeInsets.only(
        left: 19.4,
        right: 19.4,
        top: 30,
        bottom: 16.4,
      ),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(26),
        image: const DecorationImage(
          image: AssetImage('assets/images/products_bg.png'),
          fit: BoxFit.fitWidth,
          alignment: Alignment.topCenter,
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
              height: 1,
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
              color: Color(0xFF333333),
              height: 1.67,
            ),
            textAlign: TextAlign.center,
          ),

          const SizedBox(height: 16),

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
                  color: Color(0xFF333333),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// 显示通知对话框的便捷方法（改为 Overlay 弹层，淡入淡出动画）
Future<void> showNotificationDialog(
  BuildContext context, {
  String title = 'Notification',
  required String message,
  String buttonText = 'Got It',
  VoidCallback? onConfirm,
  double? width, // 添加宽度参数
}) async {
  return OverlayFade.show(
    context,
    barrierDismissible: false, // 保持与原来一致：禁用蒙层点击关闭
    builder: (requestClose) => NotificationDialog(
      title: title,
      message: message,
      buttonText: buttonText,
      onConfirm: onConfirm,
      width: width,
      onRequestClose: requestClose,
    ),
  );
}