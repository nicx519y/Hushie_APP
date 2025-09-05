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

class _HistoryListState extends State<HistoryList>
    with SingleTickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<double> _slideAnimation;
  late Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();

    _animationController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );

    _slideAnimation = Tween<double>(begin: 1.0, end: 0.0).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeOutCubic),
    );

    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeOut),
    );

    // 启动动画
    _animationController.forward();
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  Future<void> _closeWithAnimation() async {
    await _animationController.reverse();
    if (widget.onClose != null) {
      widget.onClose!();
    }
  }

  Future<void> _refreshHistory() async {
    try {
      await AudioHistoryManager.instance.refreshHistory();
    } catch (e) {
      print('刷新历史记录失败: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _animationController,
      builder: (context, child) {
        return Stack(
          children: [
            // 从底部滑上来的内容区域
            Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              child: Transform.translate(
                offset: Offset(
                  0,
                  MediaQuery.of(context).size.height *
                      (0.7 + MediaQuery.of(context).padding.bottom) *
                      _slideAnimation.value,
                ),
                child: Material(
                  color: Colors.white,
                  child: Container(
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
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 16,
                                  vertical: 5,
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
                                      onPressed: _closeWithAnimation,
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
                                padding: const EdgeInsets.all(20),
                                emptyWidget: _buildEmptyWidget(),
                                onRefresh: _refreshHistory,
                                onItemTap: widget.onItemTap,
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
            ),
          ],
        );
      },
    );
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
}

Future<void> showHistoryListWithAnimation(
  BuildContext context, {
  void Function(AudioItem)? onItemTap,
}) async {
  Navigator.of(context).push(
    PageRouteBuilder(
      pageBuilder: (context, animation, secondaryAnimation) => HistoryList(
        onItemTap: onItemTap,
        onClose: () => Navigator.of(context).pop(),
      ),
      transitionsBuilder: (context, animation, secondaryAnimation, child) {
        final opacityAnimation = Tween<double>(
          begin: 0,
          end: 0.5,
        ).animate(CurvedAnimation(parent: animation, curve: Curves.easeInOut));

        return Stack(
          children: [
            // 半透明黑色蒙层
            FadeTransition(
              opacity: opacityAnimation,
              child: Container(color: Colors.black),
            ),
            // 页面内容（淡入动画）
            FadeTransition(opacity: animation, child: child),
          ],
        );
      },
    ),
  );
}
