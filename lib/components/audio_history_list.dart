import 'package:flutter/material.dart';
import '../models/audio_item.dart';
import '../services/audio_history_manager.dart';
import '../components/audio_list.dart';

/// 历史记录列表组件
/// 封装了历史记录列表的UI渲染和数据管理逻辑
class AudioHistoryList extends StatefulWidget {
  /// 音频项点击回调
  final void Function(AudioItem) onItemTap;
  
  /// 列表内边距
  final EdgeInsets? padding;

  const AudioHistoryList({
    super.key,
    required this.onItemTap,
    this.padding,
  });

  @override
  State<AudioHistoryList> createState() => _AudioHistoryListState();
}

class _AudioHistoryListState extends State<AudioHistoryList> {
  bool _isLoading = false;
  List<AudioItem> _currentHistory = [];

  @override
  void initState() {
    super.initState();
    _initializeHistory();
  }

  /// 初始化历史记录数据
  Future<void> _initializeHistory() async {
    setState(() {
      _isLoading = true;
    });

    try {
      // 先获取当前缓存的历史记录数据
      final historyList = await AudioHistoryManager.instance.getAudioHistory();
      if (mounted) {
        setState(() {
          _currentHistory = historyList;
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint('🎵 [AUDIO_HISTORY_LIST] 初始化历史记录数据失败: $e');
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  /// 刷新历史记录列表
  Future<void> _refreshHistory() async {
    if (_isLoading) return;

    setState(() {
      _isLoading = true;
    });

    try {
      await AudioHistoryManager.instance.refreshHistory();
    } catch (e) {
      debugPrint('刷新历史记录数据失败: $e');
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  /// 构建空状态组件
  Widget _buildEmptyWidget() {
    return Column(
      children: [
        Expanded(
          child: Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  'No listening history',
                  style: TextStyle(color: Colors.grey, fontSize: 14),
                ),
                SizedBox(height: 8),
                Text(
                  'Your recently played audio will appear here',
                  style: TextStyle(color: Colors.grey, fontSize: 12),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 180),
      ],
    );
  }

  /// 构建加载状态组件
  Widget _buildLoadingWidget() {
    return Column(
      children: [
        Expanded(child: Center(child: CircularProgressIndicator())),
        const SizedBox(height: 180),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    // 显示加载状态（仅在初始加载且列表为空时）
    if (_isLoading && _currentHistory.isEmpty) {
      return _buildLoadingWidget();
    }

    // 显示空状态
    if (_currentHistory.isEmpty) {
      return _buildEmptyWidget();
    }

    // 显示历史记录列表，使用 StreamBuilder 监听更新
    return StreamBuilder<List<AudioItem>>(
      stream: AudioHistoryManager.instance.historyStream,
      initialData: _currentHistory,
      builder: (context, snapshot) {
        // 优先使用 stream 数据，如果没有则使用本地缓存
        final historyList = snapshot.hasData ? snapshot.data! : _currentHistory;
        
        // 如果 stream 有新数据，更新本地缓存
        if (snapshot.hasData && snapshot.data != _currentHistory) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted) {
              setState(() {
                _currentHistory = snapshot.data!;
              });
            }
          });
        }

        return AudioList(
          audios: historyList,
          padding: widget.padding ?? const EdgeInsets.only(bottom: 120),
          emptyWidget: _buildEmptyWidget(),
          onRefresh: _refreshHistory,
          hasMoreData: false, // 历史记录通常不需要分页加载
          onItemTap: widget.onItemTap,
        );
      },
    );
  }
}