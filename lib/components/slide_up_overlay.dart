import 'package:flutter/material.dart';

/// 从底部滑出的半透明浮层组件
/// 提供统一的动画效果和背景遮罩
class SlideUpOverlay {
  /// 显示从底部滑出的浮层
  /// 
  /// [context] - 上下文
  /// [child] - 要显示的子组件
  /// [barrierColor] - 背景遮罩颜色，默认为半透明黑色
  /// [barrierDismissible] - 点击背景是否可关闭，默认为true
  /// [animationDuration] - 动画持续时间，默认300毫秒
  /// [curve] - 动画曲线，默认为easeOutCubic
  static Future<T?> show<T>({
    required BuildContext context,
    required Widget child,
    Color? barrierColor,
    bool barrierDismissible = true,
    Duration animationDuration = const Duration(milliseconds: 300),
    Curve curve = Curves.easeOutCubic,
  }) {
    return Navigator.of(context, rootNavigator: true).push<T>(
      PageRouteBuilder<T>(
        opaque: false, // 设置为非不透明，允许背景透明
        barrierColor: barrierColor ?? Colors.black.withAlpha(128), // 设置半透明黑色背景
        barrierDismissible: barrierDismissible,
        transitionDuration: animationDuration,
        pageBuilder: (context, animation, secondaryAnimation) => child,
        transitionsBuilder: (context, animation, secondaryAnimation, child) {
          // 从下往上滑动的动画
          const begin = Offset(0.0, 1.0); // 从底部开始
          const end = Offset.zero; // 到正常位置

          var slideTween = Tween(
            begin: begin,
            end: end,
          ).chain(CurveTween(curve: curve));

          return SlideTransition(
            position: animation.drive(slideTween),
            child: child,
          );
        },
      ),
    );
  }

  /// 显示历史记录列表的便捷方法
  /// 
  /// [context] - 上下文
  /// [onItemTap] - 项目点击回调
  /// [onClose] - 关闭回调
  static Future<void> showHistoryList(
    BuildContext context, {
    void Function(dynamic)? onItemTap,
    VoidCallback? onClose,
  }) async {
    // 动态导入HistoryList组件以避免循环依赖
    return show(
      context: context,
      child: Builder(
        builder: (context) {
          // 这里需要根据实际的HistoryList组件进行调整
          return Container(
            child: Text('HistoryList placeholder'),
          );
        },
      ),
    );
  }
}

/// 可复用的底部滑出容器组件
class SlideUpContainer extends StatelessWidget {
  final Widget child;
  final EdgeInsets? padding;
  final Color? backgroundColor;
  final BorderRadius? borderRadius;
  final double? height;
  final double? maxHeight;

  const SlideUpContainer({
    super.key,
    required this.child,
    this.padding,
    this.backgroundColor,
    this.borderRadius,
    this.height,
    this.maxHeight,
  });

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.bottomCenter,
      child: Material(
        color: Colors.transparent,
        child: Container(
          width: double.infinity,
          height: height,
          constraints: maxHeight != null
              ? BoxConstraints(maxHeight: maxHeight!)
              : null,
          padding: padding ?? const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: backgroundColor ?? Colors.white,
            borderRadius: borderRadius ??
                const BorderRadius.only(
                  topLeft: Radius.circular(20),
                  topRight: Radius.circular(20),
                ),
          ),
          child: child,
        ),
      ),
    );
  }
}