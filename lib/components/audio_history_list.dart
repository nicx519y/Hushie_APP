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

  const AudioHistoryList({super.key, required this.onItemTap, this.padding});

  @override
  State<AudioHistoryList> createState() => _AudioHistoryListState();
}

class _AudioHistoryListState extends State<AudioHistoryList> {
  bool _isLoading = false;
  List<AudioItem> _currentHistory = [];

  @override
  void initState() {
    _initializeHistory().then((_) {
      super.initState();
    });
  }

  /// 初始化历史记录数据
  Future<void> _initializeHistory() async {
    _isLoading = true;
    try {
      // 先获取当前缓存的历史记录数据
      final historyList = await AudioHistoryManager.instance.getAudioHistory();
      _currentHistory = historyList;
      _isLoading = false;
    } catch (e) {
      debugPrint('🎵 [AUDIO_HISTORY_LIST] 初始化历史记录数据失败: $e');
      _isLoading = false;
    } finally {
      if (mounted) {
        setState(() {});
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
    return RefreshIndicator(
      onRefresh: _refreshHistory,
      child: SingleChildScrollView(
        physics: AlwaysScrollableScrollPhysics(),
        child: SizedBox(
          height: 350, // 确保有足够高度触发下拉刷新
          child: Column(
            children: [
              Expanded(
                child: Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        'No History yet.',
                        style: TextStyle(color: Colors.grey, fontSize: 14),
                      ),
                      SizedBox(height: 8),
                      Text(
                        'Pull down to refresh',
                        style: TextStyle(color: Colors.grey, fontSize: 10),
                      ),
                    ],
                  ),
                ),
              ),
              // const SizedBox(height: 180),
            ],
          ),
        ),
      ),
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
    // 使用 ValueListenableBuilder 监听可重放的数据源，避免错过最新值
    return ValueListenableBuilder<List<AudioItem>>(
      valueListenable: AudioHistoryManager.instance.historyNotifier,
      builder: (context, historyList, _) {
        // 显示加载状态（仅在初始加载且列表为空时）
        if (_isLoading && historyList.isEmpty) {
          return _buildLoadingWidget();
        }

        // 显示空状态
        if (historyList.isEmpty) {
          return _buildEmptyWidget();
        }

        // 显示历史记录列表
        return AudioList(
          audios: historyList,
          padding: widget.padding ?? const EdgeInsets.only(bottom: 120),
          onRefresh: _refreshHistory,
          hasMoreData: false,
          onItemTap: widget.onItemTap,
        );
      },
    );
  }
}
