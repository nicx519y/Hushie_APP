import 'package:flutter/material.dart';
import '../models/audio_item.dart';
import 'audio_stats.dart';
import '../utils/custom_icons.dart';
import '../components/fallback_image.dart';
import '../services/audio_manager.dart';
import '../services/audio_service.dart';
import 'dart:async';

class AudioList extends StatefulWidget {
  final List<AudioItem> audios;
  final EdgeInsetsGeometry? padding;
  final ScrollPhysics? physics;
  final bool shrinkWrap;
  final Widget? emptyWidget;

  // 新增的刷新相关参数
  final Future<void> Function()? onRefresh;
  final Future<void> Function()? onLoadMore;
  final bool hasMoreData;
  final bool isLoadingMore;
  final Widget? loadingMoreWidget;
  final bool enableRefresh; // 控制是否启用下拉刷新

  // 新增的点击回调参数
  final void Function(AudioItem)? onItemTap;

  const AudioList({
    super.key,
    required this.audios,
    this.padding = const EdgeInsets.all(0),
    this.physics,
    this.shrinkWrap = false,
    this.emptyWidget,
    this.onRefresh,
    this.onLoadMore,
    this.hasMoreData = false,
    this.isLoadingMore = false,
    this.loadingMoreWidget,
    this.enableRefresh = true, // 默认禁用下拉刷新
    this.onItemTap,
  });

  @override
  State<AudioList> createState() => _AudioListState();
}

class _AudioListState extends State<AudioList> {
  final ScrollController _scrollController = ScrollController();
  String _activeId = '';
  StreamSubscription<AudioPlayerState>? _audioStateSubscription;

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
    _initializeActiveId();
    _setupAudioStateListener();
  }

  @override
  void dispose() {
    _scrollController.dispose();
    _audioStateSubscription?.cancel();
    super.dispose();
  }

  void _initializeActiveId() {
    final currentAudio = AudioManager.instance.currentAudio;
    if (currentAudio != null) {
      setState(() {
        _activeId = currentAudio.id;
      });
    }
  }

  void _setupAudioStateListener() {
    _audioStateSubscription = AudioManager.instance.audioStateStream.listen((audioState) {
      final currentAudioId = audioState.currentAudio?.id ?? '';
      if (_activeId != currentAudioId) {
        setState(() {
          _activeId = currentAudioId;
        });
      }
    });
  }

  void _onScroll() {
    if (widget.onLoadMore != null &&
        widget.hasMoreData &&
        !widget.isLoadingMore &&
        _scrollController.position.pixels >=
            _scrollController.position.maxScrollExtent - 200) {
      // 当滚动到距离底部200像素时触发加载更多
      widget.onLoadMore!();
    }
  }

  bool _isActive(AudioItem item) {
    return _activeId == item.id;
  }

  @override
  Widget build(BuildContext context) {
    if (widget.audios.isEmpty) {
      return widget.emptyWidget ??
          const Center(
            child: Text(
              'No audio found',
              style: TextStyle(color: Colors.grey, fontSize: 16),
            ),
          );
    }

    // 当启用下拉刷新时，确保使用 AlwaysScrollableScrollPhysics
    ScrollPhysics? effectivePhysics = widget.physics;
    if (widget.enableRefresh && widget.onRefresh != null) {
      effectivePhysics = widget.physics != null 
          ? AlwaysScrollableScrollPhysics(parent: widget.physics)
          : const AlwaysScrollableScrollPhysics();
    }

    Widget listView = ListView.separated(
        controller: _scrollController,
        padding: widget.padding,
        physics: effectivePhysics,
        shrinkWrap: widget.shrinkWrap,
        itemCount: widget.audios.length + (widget.hasMoreData ? 1 : 0),
        itemBuilder: (context, index) {
          if (index == widget.audios.length) {
            // 加载更多指示器
            return _buildLoadMoreIndicator();
          }
          return _buildAudioItem(widget.audios[index]);
        },
        separatorBuilder: (context, index) {
          // 如果是最后一个音频项之后（即加载更多指示器之前），不添加分隔符
          if (index == widget.audios.length - 1 && widget.hasMoreData) {
            return const SizedBox.shrink();
          }
          // 添加间隔
          return const SizedBox(height: 18.0);
        },
      );

    // 根据enableRefresh参数决定是否包装RefreshIndicator
    if (widget.enableRefresh && widget.onRefresh != null) {
      return RefreshIndicator(
        onRefresh: widget.onRefresh!,
        child: listView,
      );
    } else {
      return listView;
    }
  }

  Widget _buildLoadMoreIndicator() {
    if (widget.loadingMoreWidget != null) {
      return widget.loadingMoreWidget!;
    }

    return Container(
      padding: const EdgeInsets.all(16),
      child: Center(
        child: widget.isLoadingMore
            ? const SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
            : const SizedBox.shrink(),
      ),
    );
  }

  Widget _buildItemTitle(AudioItem audio) {
    final isActive = _isActive(audio);

    if (isActive) {
      return Row(
        children: [
          Icon(CustomIcons.playing, color: Color(0xFFFF2050), size: 14),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              audio.title,
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w500,
                height: 1.5,
                color: Color(0xFFFF2050),
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      );
    } else {
      return Text(
        audio.title,
        style: const TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.w400,
          height: 1.5,
          color: Color(0xFF333333),
        ),
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      );
    }
  }

  Widget _buildAudioItem(AudioItem audio) {
    return InkWell(
      onTap: widget.onItemTap != null ? () => widget.onItemTap!(audio) : null,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 视频封面
          FallbackImage(
            fit: BoxFit.cover,
            width: 70,
            height: 78,
            imageResource: audio.cover,
            fallbackImage: 'assets/images/cover_mini_backup.jpg',
            borderRadius: 8,
          ),
          const SizedBox(width: 12),
          // 视频信息
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // 标题
                _buildItemTitle(audio),

                const SizedBox(height: 8),
                // 描述
                Text(
                  audio.tags?.join(', ') ?? '',
                  style: const TextStyle(
                    fontSize: 12,
                    color: Color(0xFF666666),
                    height: 1.2,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 13),
                // 视频统计信息
                AudioStats(
                  playTimes: audio.playTimes,
                  likesCount: audio.likesCount,
                  author: audio.author,
                  iconSize: 12,
                  fontSize: 10,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
