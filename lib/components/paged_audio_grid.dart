import 'package:flutter/material.dart';
import 'package:infinite_scroll_pagination/infinite_scroll_pagination.dart';
import 'package:flutter_staggered_grid_view/flutter_staggered_grid_view.dart';
import '../models/audio_item.dart';
import '../services/api_service.dart';
import 'audio_card.dart';

class PagedAudioGrid extends StatefulWidget {
  final String? tag;
  final Function(AudioItem)? onItemTap;
  final Function(AudioItem)? onPlayTap;
  final Function(AudioItem)? onLikeTap;

  const PagedAudioGrid({
    super.key,
    this.tag,
    this.onItemTap,
    this.onPlayTap,
    this.onLikeTap,
  });

  @override
  State<PagedAudioGrid> createState() => _PagedAudioGridState();
}

class _PagedAudioGridState extends State<PagedAudioGrid> {
  static const int _pageSize = 20;
  late final PagingController<String?, AudioItem> _pagingController;

  @override
  void initState() {
    super.initState();
    _pagingController = PagingController(firstPageKey: null);
    _pagingController.addPageRequestListener(_fetchPage);
  }

  @override
  void dispose() {
    _pagingController.dispose();
    super.dispose();
  }

  // 重置分页控制器，用于切换Tab时重新加载数据
  void reset() {
    _pagingController.refresh();
  }

  Future<void> _fetchPage(String? pageKey) async {
    try {
      final response = await ApiService.getAudioList(
        tag: widget.tag,
        cid: pageKey, // 使用cid作为分页参数
        count: _pageSize,
      );

      if (response.errNo == 0 && response.data != null) {
        final newItems = response.data!.items;
        final isLastPage = newItems.length < _pageSize;

        if (isLastPage) {
          _pagingController.appendLastPage(newItems);
        } else {
          // 使用最后一个item的ID作为下一页的key
          final nextPageKey = newItems.isNotEmpty ? newItems.last.id : null;
          _pagingController.appendPage(newItems, nextPageKey);
        }
      } else {
        _pagingController.error = '加载失败: 错误码 ${response.errNo}';
      }
    } catch (error) {
      _pagingController.error = error;
    }
  }

  @override
  Widget build(BuildContext context) {
    return RefreshIndicator(
      onRefresh: () => Future.sync(() => _pagingController.refresh()),
      child: LayoutBuilder(
        builder: (context, constraints) {
          // 确保有足够的宽度约束
          if (constraints.maxWidth <= 0) {
            return const SizedBox.shrink();
          }

          // 计算实际可用宽度（减去水平 padding）
          final availableWidth = constraints.maxWidth - 26; // 13 * 2 padding

          // 确保有足够的空间至少显示一列
          if (availableWidth < 100) {
            return const Center(
              child: Text('屏幕宽度不足', style: TextStyle(color: Colors.grey)),
            );
          }

          return PagedMasonryGridView<String?, AudioItem>.count(
            pagingController: _pagingController,
            crossAxisCount: 2,
            mainAxisSpacing: 4,
            crossAxisSpacing: 8,
            padding: const EdgeInsets.only(left: 13, right: 13, bottom: 60),
            builderDelegate: PagedChildBuilderDelegate<AudioItem>(
              itemBuilder: (context, item, index) {
                final itemMap = item.toMap();
                return AudioCard(
                  item: itemMap,
                  imageWidth: availableWidth / 2,
                  onTap: () => widget.onItemTap?.call(item),
                  onPlayTap: () => widget.onPlayTap?.call(item),
                  onLikeTap: () => widget.onLikeTap?.call(item),
                );
              },
              firstPageErrorIndicatorBuilder: (context) => _buildErrorWidget(
                _pagingController.error.toString(),
                () => _pagingController.refresh(),
              ),
              newPageErrorIndicatorBuilder: (context) => _buildErrorWidget(
                _pagingController.error.toString(),
                () => _pagingController.retryLastFailedRequest(),
              ),
              firstPageProgressIndicatorBuilder: (context) =>
                  const Center(child: CircularProgressIndicator()),
              newPageProgressIndicatorBuilder: (context) => const Padding(
                padding: EdgeInsets.all(16.0),
                child: Center(child: CircularProgressIndicator()),
              ),
              noItemsFoundIndicatorBuilder: (context) => const Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.music_note, size: 64, color: Colors.grey),
                    SizedBox(height: 16),
                    Text(
                      '暂无音频数据',
                      style: TextStyle(color: Colors.grey, fontSize: 16),
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildErrorWidget(String error, VoidCallback onRetry) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.error_outline, size: 64, color: Colors.grey[400]),
            const SizedBox(height: 16),
            Text(
              error,
              style: const TextStyle(color: Colors.grey, fontSize: 16),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            ElevatedButton(onPressed: onRetry, child: const Text('重试')),
          ],
        ),
      ),
    );
  }
}
