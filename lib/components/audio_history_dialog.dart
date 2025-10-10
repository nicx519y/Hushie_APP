import 'dart:async';
import 'package:flutter/material.dart';
import '../models/audio_item.dart';
import 'audio_history_list.dart';
import '../services/dialog_state_manager.dart';
import 'slide_up_overlay.dart';
import '../services/analytics_service.dart';

class AudioHistoryDialog extends StatefulWidget {
  final void Function(AudioItem)? onItemTap;
  final VoidCallback? onClose;

  const AudioHistoryDialog({super.key, this.onItemTap, this.onClose});

  @override
  State<AudioHistoryDialog> createState() => _AudioHistoryDialogState();
}

class _AudioHistoryDialogState extends State<AudioHistoryDialog> {
  void _closeDialog() {
    Navigator.of(context, rootNavigator: true).pop();
  }

  @override
  void dispose() {
    // 清除弹窗状态标志
    DialogStateManager.instance.closeDialog(DialogStateManager.historyList);
    
    // 在组件销毁时调用 onClose 回调
    final onClose = widget.onClose;
    if (onClose != null) {
      onClose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SlideUpContainer(
      height: MediaQuery.of(context).size.height * 0.7,
      child: Column(
        children: [
          // 顶部拖拽指示器和标题
          Container(
            padding: const EdgeInsets.symmetric(vertical: 0),
            child: Column(
              children: [
                // 标题和关闭按钮
                Padding(
                  padding: const EdgeInsets.only(
                    top: 0,
                    bottom: 5,
                    left: 0,
                    right: 0,
                  ),
                  child: Row(
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
                ),
              ],
            ),
          ),

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
    );
  }
}

Future<void> showAudioHistoryDialog(
  BuildContext context, {
  void Function(AudioItem)? onItemTap,
  VoidCallback? onClose,
}) async {
  // 检查是否已有弹窗打开
  if (!DialogStateManager.instance.tryOpenDialog(DialogStateManager.historyList)) {
    return; // 已有其他弹窗打开，直接返回
  }
  
  return SlideUpOverlay.show(
    context: context,
    child: AudioHistoryDialog(
      onItemTap: onItemTap,
      onClose: onClose,
    ),
  );
}