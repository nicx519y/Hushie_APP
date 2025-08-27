import 'package:flutter/material.dart';
import 'package:flutter_staggered_grid_view/flutter_staggered_grid_view.dart';
import 'video_card.dart';

class VideoGrid extends StatelessWidget {
  final List<Map<String, dynamic>> dataList;
  final bool isLoading;
  final Future<void> Function()? onRefresh;
  final Function(Map<String, dynamic>)? onItemTap;
  final Function(Map<String, dynamic>)? onPlayTap;
  final Function(Map<String, dynamic>)? onLikeTap;

  const VideoGrid({
    super.key,
    required this.dataList,
    this.isLoading = false,
    this.onRefresh,
    this.onItemTap,
    this.onPlayTap,
    this.onLikeTap,
  });

  @override
  Widget build(BuildContext context) {
    if (isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    return RefreshIndicator(
      onRefresh: onRefresh ?? () async {},
      child: MasonryGridView.count(
        crossAxisCount: 2,
        mainAxisSpacing: 11,
        crossAxisSpacing: 11,
        padding: const EdgeInsets.symmetric(horizontal: 13),
        itemCount: dataList.length,
        itemBuilder: (context, index) {
          final item = dataList[index];
          return VideoCard(
            item: item,
            onTap: () => onItemTap?.call(item),
            onPlayTap: () => onPlayTap?.call(item),
            onLikeTap: () => onLikeTap?.call(item),
          );
        },
      ),
    );
  }
}
