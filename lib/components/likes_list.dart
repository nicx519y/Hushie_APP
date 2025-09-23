import 'dart:async';
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
  StreamSubscription<List<AudioItem>>? _likesStreamSubscription;

  @override
  void initState() {
    super.initState();
    _initializeLikes();
    _subscribeToLikesStream();
  }

  @override
  void dispose() {
    _likesStreamSubscription?.cancel();
    super.dispose();
  }

  /// 订阅点赞数据变更事件流
  void _subscribeToLikesStream() {
    _likesStreamSubscription = AudioLikesManager.instance.likesStream.listen(
      (likedAudios) {
        debugPrint('🎵 [LIKES_LIST] 收到点赞数据变更事件，共 ${likedAudios.length} 条');
        
        // ValueListenableBuilder 会自动响应 likesNotifier 的变化进行 UI 更新
        // 这里可以添加额外的 UI 反馈，比如：
        
        // 1. 显示提示消息（可选）
        // if (mounted) {
        //   ScaffoldMessenger.of(context).showSnackBar(
        //     SnackBar(
        //       content: Text('点赞列表已更新'),
        //       duration: Duration(milliseconds: 500),
        //     ),
        //   );
        // }
        
        // 2. 触发额外的状态更新（如果需要）
        // if (mounted) {
        //   setState(() {
        //     // 可以在这里更新其他状态变量
        //   });
        // }
      },
      onError: (error) {
        debugPrint('🎵 [LIKES_LIST] 点赞数据事件流错误: $error');
      },
    );
    debugPrint('🎵 [LIKES_LIST] 已订阅点赞数据变更事件流');
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
    debugPrint('🎵 [LIKES_LIST] build 方法被调用');
    
    // 显示加载状态（仅在初始加载且列表为空时）
    if (_isLoading && AudioLikesManager.instance.likesNotifier.value.isEmpty) {
      debugPrint('🎵 [LIKES_LIST] 显示加载状态');
      return _buildLoadingWidget();
    }

    // 显示空状态
    if (AudioLikesManager.instance.likesNotifier.value.isEmpty) {
      debugPrint('🎵 [LIKES_LIST] 显示空状态');
      return _buildEmptyWidget();
    }

    // 显示点赞列表，使用 StreamBuilder 监听更新
    return StreamBuilder<List<AudioItem>>(
      stream: AudioLikesManager.instance.likesStream,
      initialData: AudioLikesManager.instance.likesNotifier.value,
      builder: (context, snapshot) {
        debugPrint('🎵 [LIKES_LIST] StreamBuilder 重建，音频数量: ${snapshot.data?.length ?? 0}');
        
        // 优先使用 stream 数据，如果没有则使用当前缓存
        final likedAudios = snapshot.hasData ? snapshot.data! : AudioLikesManager.instance.likesNotifier.value;
        
        // 显示加载状态（仅在初始加载且列表为空时）
        if (_isLoading && likedAudios.isEmpty) {
          debugPrint('🎵 [LIKES_LIST] 显示加载状态');
          return _buildLoadingWidget();
        }

        // 显示空状态
        if (likedAudios.isEmpty) {
          debugPrint('🎵 [LIKES_LIST] 显示空状态');
          return _buildEmptyWidget();
        }

        // 显示点赞列表
        debugPrint('🎵 [LIKES_LIST] 显示点赞列表，音频数量: ${likedAudios.length}');
        return AudioList(
          key: ValueKey('likes_list_${likedAudios.length}_${likedAudios.map((e) => e.id).join('_')}'),
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