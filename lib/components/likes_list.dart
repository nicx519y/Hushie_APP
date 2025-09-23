import 'package:flutter/material.dart';
import '../models/audio_item.dart';
import '../services/audio_likes_manager.dart';
import '../components/audio_list.dart';

/// 点赞列表组件
/// 封装了点赞列表的UI渲染和数据管理逻辑
class LikesList extends StatefulWidget {
  /// 音频项点击回调
  final void Function(AudioItem) onItemTap;
  
  /// 列表内边距
  final EdgeInsets? padding;

  const LikesList({
    super.key,
    required this.onItemTap,
    this.padding,
  });

  @override
  State<LikesList> createState() => _LikesListState();
}

class _LikesListState extends State<LikesList> {
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _initializeLikes();
  }

  /// 初始化点赞数据
  Future<void> _initializeLikes() async {
    setState(() {
      _isLoading = true;
    });

    try {
      // 触发点赞数据加载
      await AudioLikesManager.instance.getLikedAudios();
    } catch (e) {
      debugPrint('初始化点赞数据失败: $e');
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  /// 刷新点赞列表
  Future<void> _refreshLikes() async {
    if (_isLoading) return;

    setState(() {
      _isLoading = true;
    });

    try {
      await AudioLikesManager.instance.refresh();
    } catch (e) {
      debugPrint('刷新点赞数据失败: $e');
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  /// 加载更多点赞数据
  Future<void> _loadMoreLikes() async {
    if (_isLoading) return;

    setState(() {
      _isLoading = true;
    });

    try {
      await AudioLikesManager.instance.loadMore();
    } catch (e) {
      debugPrint('加载更多点赞数据失败: $e');
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
            child: Text(
              'No liked content',
              style: TextStyle(color: Colors.grey, fontSize: 14),
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
    return ValueListenableBuilder<List<AudioItem>>(
      valueListenable: AudioLikesManager.instance.likesNotifier,
      builder: (context, likedAudios, child) {
        // 显示加载状态（仅在初始加载且列表为空时）
        if (_isLoading && likedAudios.isEmpty) {
          return _buildLoadingWidget();
        }

        // 显示空状态
        if (likedAudios.isEmpty) {
          return _buildEmptyWidget();
        }

        // 显示点赞列表
        return AudioList(
          audios: likedAudios,
          padding: widget.padding ?? const EdgeInsets.only(bottom: 120),
          emptyWidget: _buildEmptyWidget(),
          onRefresh: _refreshLikes,
          onLoadMore: _loadMoreLikes,
          hasMoreData: AudioLikesManager.instance.hasMoreData,
          isLoadingMore: AudioLikesManager.instance.isLoadingMore,
          onItemTap: widget.onItemTap,
        );
      },
    );
  }
}