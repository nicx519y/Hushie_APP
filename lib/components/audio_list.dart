import 'package:flutter/material.dart';
import '../models/audio_item.dart';
import 'audio_stats.dart';

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
    this.onItemTap,
  });

  @override
  State<AudioList> createState() => _AudioListState();
}

class _AudioListState extends State<AudioList> {
  final ScrollController _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
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

  @override
  Widget build(BuildContext context) {
    if (widget.audios.isEmpty) {
      return widget.emptyWidget ??
          const Center(
            child: Text(
              '暂无数据',
              style: TextStyle(color: Colors.grey, fontSize: 16),
            ),
          );
    }

    return RefreshIndicator(
      onRefresh: widget.onRefresh ?? () async {},
      child: ListView.builder(
        controller: _scrollController,
        padding: widget.padding,
        physics: widget.physics,
        shrinkWrap: widget.shrinkWrap,
        itemCount: widget.audios.length + (widget.hasMoreData ? 1 : 0),
        itemBuilder: (context, index) {
          if (index == widget.audios.length) {
            // 加载更多指示器
            return _buildLoadMoreIndicator();
          }
          return _buildAudioItem(widget.audios[index]);
        },
      ),
    );
  }

  Widget _buildLoadMoreIndicator() {
    if (widget.loadingMoreWidget != null) {
      return widget.loadingMoreWidget!;
    }

    return Container(
      padding: const EdgeInsets.all(16),
      child: Center(
        child: widget.isLoadingMore
            ? const Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                  SizedBox(width: 8),
                  Text('加载中...', style: TextStyle(color: Colors.grey)),
                ],
              )
            : const Text('上拉加载更多', style: TextStyle(color: Colors.grey)),
      ),
    );
  }

  Widget _buildAudioItem(AudioItem audio) {
    return GestureDetector(
      onTap: widget.onItemTap != null ? () => widget.onItemTap!(audio) : null,
      child: Container(
        margin: const EdgeInsets.only(bottom: 18),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 视频封面
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: Container(
                width: 70,
                height: 78,
                color: const Color(0xFFF5F5F5),
                child: Builder(
                  builder: (context) {
                    String? imageUrl;
                    try {
                      imageUrl = audio.cover.getBestResolution(70).url;
                    } catch (e) {
                      print('获取封面图片失败: $e');
                      imageUrl = null;
                    }

                    if (imageUrl != null && imageUrl.isNotEmpty) {
                      return Image.network(
                        imageUrl,
                        fit: BoxFit.cover,
                        errorBuilder: (context, error, stackTrace) {
                          return const Icon(Icons.play_arrow, size: 30);
                        },
                      );
                    } else {
                      return const Icon(Icons.play_arrow, size: 30);
                    }
                  },
                ),
              ),
            ),
            const SizedBox(width: 12),
            // 视频信息
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // 标题
                  Text(
                    audio.title,
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                      height: 1.5,
                      color: Color(0xFF333333),
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 6),
                  // 描述
                  Text(
                    audio.desc,
                    style: const TextStyle(
                      fontSize: 12,
                      color: Color(0xFF666666),
                      height: 1.2,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 15),
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
      ),
    );
  }
}
