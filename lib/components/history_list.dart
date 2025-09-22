import 'dart:async';
import 'package:flutter/material.dart';
import '../models/audio_item.dart';
import 'audio_list.dart';
import '../services/audio_history_manager.dart';
import '../services/dialog_state_manager.dart';
import '../services/audio_manager.dart';
import 'slide_up_overlay.dart';

class HistoryList extends StatefulWidget {
  final void Function(AudioItem)? onItemTap;
  final VoidCallback? onClose;

  const HistoryList({super.key, this.onItemTap, this.onClose});

  @override
  State<HistoryList> createState() => _HistoryListState();
}

class _HistoryListState extends State<HistoryList> {
  List<AudioItem> _historyList = [];
  StreamSubscription<List<AudioItem>>? _historyStreamSubscription;
  StreamSubscription? _audioStateSubscription;
  bool _isLoading = true;
  String _currentAudioId = '';

  @override
  void initState() {
    super.initState();
    _initializeHistory();
    _setupAudioStateListener();
  }

  /// 设置音频状态监听器
  void _setupAudioStateListener() {
    try {
      // 监听AudioManager的音频状态流
      _audioStateSubscription = AudioManager.instance.audioStateStream.listen((audioState) {
        final currentAudio = audioState.currentAudio;
        final newAudioId = currentAudio?.id ?? '';
        
        if (mounted && _currentAudioId != newAudioId) {
          setState(() {
            _currentAudioId = newAudioId;
          });
        }
      });
    } catch (e) {
      debugPrint('设置音频状态监听器失败: $e');
    }
  }

  /// 初始化历史记录数据
  Future<void> _initializeHistory() async {
    try {
      // 获取初始历史记录数据
      final historyList = await AudioHistoryManager.instance.getAudioHistory();
      if (mounted) {
        setState(() {
          _historyList = historyList;
          _isLoading = false;
        });
      }

      // 监听历史记录变更事件流
      _historyStreamSubscription = AudioHistoryManager.instance.historyStream.listen((updatedHistory) {
        if (mounted) {
          setState(() {
            _historyList = updatedHistory;
          });
        }
      });
    } catch (e) {
      debugPrint('初始化历史记录失败: $e');
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  void _closeDialog() {
    Navigator.of(context, rootNavigator: true).pop();
  }

  @override
  void dispose() {
    // 清除弹窗状态标志
    DialogStateManager.instance.closeDialog(DialogStateManager.historyList);
    
    // 取消历史记录事件流监听
    _historyStreamSubscription?.cancel();
    
    // 取消音频状态事件流监听
    _audioStateSubscription?.cancel();
    
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
                  child: _isLoading
                      ? const Center(
                          child: CircularProgressIndicator(),
                        )
                      : AudioList(
                          audios: _historyList,
                          padding: const EdgeInsets.only(
                            top: 0,
                            bottom: 40,
                            left: 0,
                            right: 0,
                          ),
                          emptyWidget: _buildEmptyWidget(),
                          onRefresh: _refreshHistory,
                          onItemTap: (audio) {
                            if (widget.onItemTap != null) {
                              widget.onItemTap!(audio);
                              _closeDialog();
                            }
                          },
                          hasMoreData: false,
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
  // 检查是否已有弹窗打开
  if (!DialogStateManager.instance.tryOpenDialog(DialogStateManager.historyList)) {
    return; // 已有其他弹窗打开，直接返回
  }
  
  return SlideUpOverlay.show(
    context: context,
    child: HistoryList(
      onItemTap: onItemTap,
      onClose: onClose,
    ),
  );
}
