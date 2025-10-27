import 'dart:async';
import 'package:flutter/material.dart';
import '../models/audio_item.dart';
import '../services/dialog_state_manager.dart';
import '../services/analytics_service.dart';
import '../router/slide_up_page_route.dart';
import 'overlay_sheet.dart';
import 'audio_history_list.dart';

class AudioHistoryDialog extends StatefulWidget {
  final void Function(AudioItem)? onItemTap;
  final VoidCallback? onClose;
  final VoidCallback? onRequestClose;

  const AudioHistoryDialog({super.key, this.onItemTap, this.onClose, this.onRequestClose});

  /// 显示历史弹窗的 Overlay 方法（统一动画方案）
  static void showOverlay(
    BuildContext context, {
    void Function(AudioItem)? onItemTap,
    VoidCallback? onClose,
  }) {
    // 检查是否已有弹窗打开
    if (!DialogStateManager.instance.tryOpenDialog(DialogStateManager.historyList)) {
      return; // 已有其他弹窗打开，直接返回
    }

    OverlaySheet.show(
      context,
      builder: (requestClose) => AudioHistoryDialog(
        onItemTap: onItemTap,
        onClose: () {
          requestClose();
          DialogStateManager.instance.closeDialog(DialogStateManager.historyList);
        },
        onRequestClose: () {
          requestClose();
          DialogStateManager.instance.closeDialog(DialogStateManager.historyList);
        },
      ),
      onClosed: () {
        DialogStateManager.instance.closeDialog(DialogStateManager.historyList);
        onClose?.call();
      },
    );
  }

  @override
  State<AudioHistoryDialog> createState() => _AudioHistoryDialogState();
}

class _AudioHistoryDialogState extends State<AudioHistoryDialog> {
  void _closeDialog() {
    DialogStateManager.instance.closeDialog(DialogStateManager.historyList);
    if (mounted) {
      Navigator.of(context).pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    return WillPopScope(
      onWillPop: () async {
        _closeDialog();
        return false; // 阻止默认的返回行为，由 _closeDialog 处理
      },
      child: Scaffold(
        backgroundColor: Colors.white,
        body: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              children: [
                // 标题和关闭按钮
                Row(
                  children: [
                    const Text(
                      'History',
                      style: TextStyle(
                        fontSize: 20,
                        height: 1,
                        fontWeight: FontWeight.w500,
                        color: Color(0xFF333333),
                      ),
                    ),
                    const Spacer(),
                    IconButton(
                      onPressed: _closeDialog,
                      icon: const Icon(
                        Icons.close,
                        size: 28,
                        color: Color(0xFF999999),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),

                // 历史记录列表
                Expanded(
                  child: AudioHistoryList(
                    onItemTap: (audio) {
                      // 记录历史弹窗内的音频点击事件
                      AnalyticsService().logCustomEvent(
                        eventName: 'player_histroy_audio_tap',
                        parameters: {
                          'audio_id': audio.id,
                        },
                      );
                      final onItemTap = widget.onItemTap;
                      if (onItemTap != null) {
                        onItemTap(audio);
                        _closeDialog();
                      }
                    },
                    padding: const EdgeInsets.only(
                      top: 0,
                      bottom: 40,
                      left: 0,
                      right: 0,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// 显示音频历史对话框的函数 - 使用 SlideUpPageRoute
void showAudioHistoryDialog(
  BuildContext context, {
  void Function(AudioItem)? onItemTap,
  VoidCallback? onClose,
}) {
  if (!DialogStateManager.instance.tryOpenDialog(DialogStateManager.historyList)) {
    return; // 已有其他弹窗打开，直接返回
  }
  
  Navigator.of(context).push(
    SlideUpPageRoute(
      page: AudioHistoryDialog(
        onItemTap: onItemTap,
        onClose: onClose,
      ),
    ),
  );
}