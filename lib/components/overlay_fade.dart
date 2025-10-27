import 'dart:async';
import 'package:flutter/material.dart';

typedef OverlayFadeBuilder = Widget Function(VoidCallback requestClose);

/// 通用的 OverlayEntry 居中淡入淡出弹层
class OverlayFade {
  /// 显示居中淡入淡出弹层
  static Future<void> show(
    BuildContext context, {
    required OverlayFadeBuilder builder,
    Duration duration = const Duration(milliseconds: 250),
    Color barrierColor = const Color(0x80000000), // 半透明黑色
    bool barrierDismissible = false,
    VoidCallback? onClosed,
  }) async {
    final overlayState = Navigator.of(context, rootNavigator: true).overlay ??
        Overlay.of(context, rootOverlay: true);

    final completer = Completer<void>();
    final ValueNotifier<double> barrierOpacity = ValueNotifier<double>(0.0);
    final ValueNotifier<double> contentOpacity = ValueNotifier<double>(0.0);
    final ValueNotifier<bool> isClosing = ValueNotifier<bool>(false);

    late OverlayEntry entry;
    void close() {
      isClosing.value = true;
      barrierOpacity.value = 0.0;
      contentOpacity.value = 0.0;
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
              // 背景遮罩淡入淡出
              Positioned.fill(
                child: GestureDetector(
                  onTap: barrierDismissible ? close : null,
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
              // 居中内容淡入淡出
              Center(
                child: ValueListenableBuilder<bool>(
                  valueListenable: isClosing,
                  builder: (ctx, closing, _) {
                    return ValueListenableBuilder<double>(
                      valueListenable: contentOpacity,
                      builder: (ctx, val, child) {
                        return AnimatedOpacity(
                          opacity: val,
                          duration: duration,
                          curve: closing ? Curves.easeInCubic : Curves.easeOutCubic,
                          child: builder(close),
                        );
                      },
                    );
                  },
                ),
              ),
            ],
          ),
        );
      },
    );

    overlayState.insert(entry);
    // 启动显示动画
    WidgetsBinding.instance.addPostFrameCallback((_) {
      isClosing.value = false; // 打开阶段
      barrierOpacity.value = 1.0;
      contentOpacity.value = 1.0;
    });

    await completer.future;
  }
}