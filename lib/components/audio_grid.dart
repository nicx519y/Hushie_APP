import 'package:flutter/material.dart';
import 'package:flutter_staggered_grid_view/flutter_staggered_grid_view.dart';
import 'audio_card.dart';

class AudioGrid extends StatelessWidget {
  final List<Map<String, dynamic>> dataList;
  final bool isLoading;
  final Future<void> Function()? onRefresh;
  final Function(Map<String, dynamic>)? onItemTap;
  final Function(Map<String, dynamic>)? onPlayTap;
  final Function(Map<String, dynamic>)? onLikeTap;

  const AudioGrid({
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

    // 如果数据为空，显示空状态
    if (dataList.isEmpty) {
      return const Center(
        child: Text('暂无数据', style: TextStyle(color: Colors.grey, fontSize: 16)),
      );
    }

    return RefreshIndicator(
      onRefresh: onRefresh ?? () async {},
      child: LayoutBuilder(
        builder: (context, constraints) {
          // 确保有足够的宽度约束
          if (constraints.maxWidth <= 0 || constraints.maxHeight <= 0) {
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

          return MasonryGridView.count(
            crossAxisCount: 2,
            mainAxisSpacing: 8,
            crossAxisSpacing: 5,
            padding: const EdgeInsets.symmetric(horizontal: 13),
            itemCount: dataList.length,
            itemBuilder: (context, index) {
              final item = dataList[index];
              return AudioCard(
                item: item,
                onTap: () => onItemTap?.call(item),
                onPlayTap: () => onPlayTap?.call(item),
                onLikeTap: () => onLikeTap?.call(item),
              );
            },
          );
        },
      ),
    );
  }
}
