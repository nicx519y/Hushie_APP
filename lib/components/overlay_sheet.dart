import 'dart:async';
import 'package:flutter/material.dart';

typedef OverlaySheetBuilder = Widget Function(VoidCallback requestClose);

/// 通用的 OverlayEntry 底部弹层，统一打开/关闭动画
class OverlaySheet {
  /// 显示底部弹层
  static Future<void> show(
    BuildContext context, {
    required OverlaySheetBuilder builder,
    Duration duration = const Duration(milliseconds: 300),
    Color barrierColor = const Color(0x80000000), // 黑色半透明（Alpha 128）
    VoidCallback? onClosed,
  }) async {
    final overlayState = Navigator.of(context, rootNavigator: true).overlay ??
        Overlay.of(context, rootOverlay: true);

    final completer = Completer<void>();
    final ValueNotifier<Offset> offset = ValueNotifier<Offset>(const Offset(0, 1));
    final ValueNotifier<double> barrierOpacity = ValueNotifier<double>(0.0);
    final ValueNotifier<bool> isClosing = ValueNotifier<bool>(false);

    late OverlayEntry entry;
    void close() {
      // 统一关闭动画：背景淡出 + 底部滑出
      isClosing.value = true;
      offset.value = const Offset(0, 1);
      barrierOpacity.value = 0.0;
      Future.delayed(duration, () {
        entry.remove();
        onClosed?.call();
        if (!completer.isCompleted) {
          completer.complete();
        }
      });
    }

    entry = OverlayEntry(
      builder: (ctx) {
        return Material(
          color: Colors.transparent,
          child: Stack(
            children: [
              // 半透明遮罩，点击关闭（淡入用 easeOut，淡出用 easeIn）
              Positioned.fill(
                child: GestureDetector(
                  onTap: close,
                  child: ValueListenableBuilder<double>(
                    valueListenable: barrierOpacity,
                    builder: (ctx, val, child) {
                      return AnimatedOpacity(
                        opacity: val,
                        duration: duration,
                        curve: val > 0.0 ? Curves.easeOutCubic : Curves.easeInCubic,
                        child: Container(color: barrierColor),
                      );
                    },
                  ),
                ),
              ),
              // 底部滑入/滑出容器：打开用 easeOut，关闭用 easeIn
              ValueListenableBuilder<bool>(
                valueListenable: isClosing,
                builder: (ctx, closing, _) {
                  return ValueListenableBuilder<Offset>(
                    valueListenable: offset,
                    builder: (ctx, val, child) {
                      return AnimatedSlide(
                        offset: val,
                        duration: duration,
                        curve: closing ? Curves.easeInCubic : Curves.easeOutCubic,
                        child: Align(
                          alignment: Alignment.bottomCenter,
                          child: builder(close),
                        ),
                      );
                    },
                  );
                },
              ),
            ],
          ),
        );
      },
    );

    overlayState.insert(entry);
    // 启动显示动画（确保首帧在屏幕外，再上滑进入）
    WidgetsBinding.instance.addPostFrameCallback((_) {
      isClosing.value = false; // 打开阶段
      offset.value = Offset.zero;
      barrierOpacity.value = 1.0;
    });

    await completer.future;
  }
}