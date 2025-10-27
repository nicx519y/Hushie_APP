import 'package:flutter/material.dart';

/// 通用的上滑页面路由，提供从底部滑入的动画效果
class SlideUpPageRoute<T> extends PageRouteBuilder<T> {
  final Widget page;

  SlideUpPageRoute({required this.page})
    : super(
        pageBuilder: (context, animation, secondaryAnimation) => page,
        transitionDuration: const Duration(milliseconds: 300),
        reverseTransitionDuration: const Duration(milliseconds: 300),
        maintainState: true,
        fullscreenDialog: true,
        opaque: false,
        transitionsBuilder: (context, animation, secondaryAnimation, child) {
          const begin = Offset(0.0, 1.0); // 从底部开始
          const end = Offset.zero; // 到正常位置
          const curve = Curves.easeInOut;

          var tween = Tween(
            begin: begin,
            end: end,
          ).chain(CurveTween(curve: curve));

          return SlideTransition(
            position: animation.drive(tween),
            child: child,
          );
        },
      );

  @override
  bool get popGestureEnabled => false;

  @override
  Future<RoutePopDisposition> willPop() async {
    return RoutePopDisposition.pop;
  }
}