import 'package:flutter/material.dart';
import '../models/audio_item.dart';
import 'audio_list.dart';
import '../services/audio_history_manager.dart';
import 'slide_up_overlay.dart';

class HistoryList extends StatefulWidget {
  final void Function(AudioItem)? onItemTap;
  final VoidCallback? onClose;

  const HistoryList({super.key, this.onItemTap, this.onClose});

  @override
  State<HistoryList> createState() => _HistoryListState();
}

class _HistoryListState extends State<HistoryList> {
  void _closeDialog() {
    Navigator.of(context, rootNavigator: true).pop();
  }

  @override
  void dispose() {
    // 在组件销毁时调用 onClose 回调
    if (widget.onClose != null) {
      widget.onClose!();
    }
    super.dispose();
  }

  Future<void> _refreshHistory() async {
    try {
      await AudioHistoryManager.instance.refreshHistory();
    } catch (e) {
      debugPrint('刷新历史记录失败: $e');
    }
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
                          top: 5,
                          bottom: 5,
                          left: 16,
                          right: 5,
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
                  child: ValueListenableBuilder<List<AudioItem>>(
                    valueListenable:
                        AudioHistoryManager.instance.historyNotifier,
                    builder: (context, historyList, child) {
                      return AudioList(
                        audios: historyList,
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        emptyWidget: _buildEmptyWidget(),
                        onRefresh: _refreshHistory,
                        onItemTap: (audio) {
                          if (widget.onItemTap != null) {
                            widget.onItemTap!(audio);
                            _closeDialog();
                          }
                        },
                        hasMoreData: false,
                      );
                    },
                  ),
                ),
              ],
            ),
    );
  }
}

Widget _buildEmptyWidget() {
  return const Center(
    child: Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Text(
      'No listening history',
          style: TextStyle(fontSize: 14, color: Colors.grey),
        ),
        SizedBox(height: 8),
        Text(
          'Your recently played audio will appear here',
          style: TextStyle(fontSize: 12, color: Colors.grey),
        ),
      ],
    ),
  );
}

Future<void> showHistoryListWithAnimation(
  BuildContext context, {
  void Function(AudioItem)? onItemTap,
  VoidCallback? onClose,
}) async {
  return SlideUpOverlay.show(
    context: context,
    child: HistoryList(
      onItemTap: onItemTap,
      onClose: onClose,
    ),
  );
}
