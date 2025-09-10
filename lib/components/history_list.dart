import 'package:flutter/material.dart';
import '../models/audio_item.dart';
import 'audio_list.dart';
import '../services/audio_history_manager.dart';

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
    return Scaffold(
      backgroundColor: Colors.transparent, // 设置背景透明
      body: Align(
        alignment: Alignment.bottomCenter,
        child: Material(
          color: Colors.white,
          child: SizedBox(
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
          ),
        ),
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
  Navigator.of(context, rootNavigator: true).push(
    PageRouteBuilder(
      opaque: false, // 设置为非不透明，允许背景透明
      barrierColor: Colors.black.withAlpha(128), // 设置半透明黑色背景
      pageBuilder: (context, animation, secondaryAnimation) => HistoryList(
        onItemTap: onItemTap,
        onClose: onClose,
      ),
      transitionsBuilder: (context, animation, secondaryAnimation, child) {
        // 从下往上滑动的动画
        const begin = Offset(0.0, 1.0); // 从底部开始
        const end = Offset.zero; // 到正常位置
        const curve = Curves.easeOutCubic;

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
