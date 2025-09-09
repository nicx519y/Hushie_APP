import 'package:flutter/material.dart';
import 'package:infinite_scroll_pagination/infinite_scroll_pagination.dart';
import 'package:hushie_app/services/api/audio_list_service.dart';
import '../models/audio_item.dart';
import 'audio_card.dart';

/// PagedAudioGrid - 支持无限滚动和虚拟化的音频网格组件
///
/// 功能特性：
/// - 自动下滑无限加载
/// - 上拉刷新数据
/// - 瀑布流布局
/// - 错误处理和重试
/// - 支持外部数据获取方法
///
/// 使用示例：
/// ```dart
/// // 定义三个数据获取方法
/// Future<List<AudioItem>> initData({String? tag}) async {
///   // 初始化数据逻辑
///   return await AudioListService.getAudioList(tag: tag, cid: null, count: 20);
/// }
///
/// Future<List<AudioItem>> refreshData({String? tag}) async {
///   // 刷新数据逻辑（上拉刷新）
///   return await AudioListService.getAudioList(tag: tag, cid: null, count: 20);
/// }
///
/// Future<List<AudioItem>> loadMoreData({
///   String? tag,
///   String? pageKey,
///   int? count,
/// }) async {
///   // 加载更多数据逻辑（下滑加载）
///   return await AudioListService.getAudioList(tag: tag, cid: pageKey, count: count);
/// }
///
/// // 在Widget中使用
/// PagedAudioGrid(
///   tag: 'music',
///   initDataFetcher: initData,
///   refreshDataFetcher: refreshData,
///   loadMoreDataFetcher: loadMoreData,
///   onItemTap: (item) => debugPrint('点击了: ${item.title}'),
/// )
/// ```
// 数据获取函数类型定义
typedef InitDataFetcher = Future<List<AudioItem>> Function({String? tag});
typedef RefreshDataFetcher = Future<List<AudioItem>> Function({String? tag});
typedef LoadMoreDataFetcher =
    Future<List<AudioItem>> Function({
      String? tag,
      String? pageKey,
      int? count,
    });

class PagedAudioGrid extends StatefulWidget {
  final String? tag;
  final Function(AudioItem)? onItemTap;
  final Function(AudioItem)? onPlayTap;
  final Function(AudioItem)? onLikeTap;

  // 外部传入的数据获取方法
  final InitDataFetcher? initDataFetcher; // 初始化数据
  final RefreshDataFetcher? refreshDataFetcher; // 上拉刷新数据
  final LoadMoreDataFetcher? loadMoreDataFetcher; // 下拉加载更多数据

  const PagedAudioGrid({
    super.key,
    this.tag,
    this.onItemTap,
    this.onPlayTap,
    this.onLikeTap,
    this.initDataFetcher,
    this.refreshDataFetcher,
    this.loadMoreDataFetcher,
  });

  @override
  State<PagedAudioGrid> createState() => _PagedAudioGridState();
}

class _PagedAudioGridState extends State<PagedAudioGrid>
    with AutomaticKeepAliveClientMixin {
  static const int _pageSize = 20;
  late final PagingController<String?, AudioItem> _pagingController;
  bool _isRefreshing = false; // 添加刷新标志

  @override
  bool get wantKeepAlive => true; // 保持组件状态，防止UI被回收

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
    // 如果正在刷新，跳过自动获取
    if (_isRefreshing && pageKey == null) {
      return;
    }

    try {
      List<AudioItem> newItems;

      if (pageKey == null) {
        // 初始化数据（第一页）
        if (widget.initDataFetcher != null) {
          newItems = await widget.initDataFetcher!(tag: widget.tag);
        } else {
          // 使用默认的API服务
          final response = await AudioListService.getAudioList(
            tag: widget.tag,
            cid: null,
            count: _pageSize,
          );

          if (response.isNotEmpty) {
            newItems = response;
          } else {
            _pagingController.error = '加载失败';
            return;
          }
        }
      } else {
        // 加载更多数据（分页）
        if (widget.loadMoreDataFetcher != null) {
          newItems = await widget.loadMoreDataFetcher!(
            tag: widget.tag,
            pageKey: pageKey,
            count: _pageSize,
          );
        } else {
          // 使用默认的API服务
          final response = await AudioListService.getAudioList(
            tag: widget.tag,
            cid: pageKey,
            count: _pageSize,
          );

          if (response.isNotEmpty) {
            newItems = response;
          } else {
            _pagingController.error = '加载失败';
            return;
          }
        }
      }

      if(newItems.isEmpty){
        _pagingController.appendLastPage([]);
        return;
      }
      
      final isLastPage = newItems.length < _pageSize;

      if (isLastPage) {
        _pagingController.appendLastPage(newItems);
      } else {
        // 使用最后一个item的ID作为下一页的key
        final nextPageKey = newItems.isNotEmpty ? newItems.last.id : null;
        _pagingController.appendPage(newItems, nextPageKey);
      }
    } catch (error) {
      _pagingController.error = error;
    }
  }

  @override
  Widget build(BuildContext context) {
    super.build(context); // 必须调用，用于AutomaticKeepAliveClientMixin

    return RefreshIndicator(
      onRefresh: () async {
        _isRefreshing = true; // 开始刷新
        try {
          if (widget.refreshDataFetcher != null) {
            // 使用外部传入的刷新方法
            final newItems = await widget.refreshDataFetcher!(tag: widget.tag);

            // 直接设置新数据，避免重复调用 _fetchPage
            if (newItems.isNotEmpty) {
              // 有数据时，清空现有数据并设置新数据
              _pagingController.refresh();
              _pagingController.appendPage(newItems, null);
            } else {
              // 没有数据时，清空现有数据并设置为空状态
              _pagingController.refresh();
              // 重要：设置为最后一页，避免loading状态
              _pagingController.appendLastPage([]);
            }
          } else {
            // 使用默认的刷新方法
            _pagingController.refresh();
          }
        } catch (error) {
          _pagingController.error = error;
        } finally {
          _isRefreshing = false; // 结束刷新
        }
      },
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
              child: Text(
                'width is too small',
                style: TextStyle(color: Colors.grey),
              ),
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
                      'No audio data',
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
