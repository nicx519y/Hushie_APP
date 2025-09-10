import 'package:flutter/material.dart';
import 'package:hushie_app/components/fallback_image.dart';
// import 'fallback_image.dart';
import '../utils/number_formatter.dart';
import '../utils/custom_icons.dart';
import '../models/image_model.dart';
import 'package:cached_network_image/cached_network_image.dart';

class AudioCard extends StatelessWidget {
  final Map<String, dynamic> item;
  final double imageWidth;
  final VoidCallback? onTap;
  final VoidCallback? onPlayTap;
  final VoidCallback? onLikeTap;

  const AudioCard({
    super.key,
    required this.item,
    this.imageWidth = 200,
    this.onTap,
    this.onPlayTap,
    this.onLikeTap,
  });

  /// 获取图片URL，支持ImageModel和字符串类型
  String _getImageUrl(dynamic cover, double width) {
    if (cover is Map<String, dynamic>) {
      // 如果是ImageModel格式，获取最佳URL
      try {
        final imageModel = ImageModel.fromJson(cover);
        return imageModel.getBestResolution(width).url; // 假设卡片宽度为200px
      } catch (e) {
        // 如果解析失败，尝试获取x1 URL
        final urls = cover['urls'];
        if (urls != null && urls['x1'] != null) {
          return urls['x1']['url'] ?? '';
        }
      }
    }
    // 如果是字符串，直接返回
    return cover?.toString() ?? '';
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Card(
        elevation: 0,
        color: Colors.transparent,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 图片区域
            Stack(
              children: [
                // 图片
                AspectRatio(
                  aspectRatio: 0.9, // 0.9 的宽高比，确保合适的显示比例
                    child: FallbackImage(
                      fit: BoxFit.cover,
                      width: imageWidth,
                      imageResource: item['cover'],
                      fallbackImage: 'assets/images/backup.png',
                      borderRadius: 8.0,
                    ),
                ),
                // 播放按钮和统计信息覆盖层
                Positioned(
                  bottom: 10,
                  left: 10,
                  right: 10,
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.start,
                    children: [
                      // 播放次数
                      GestureDetector(
                        onTap: onPlayTap,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.black.withAlpha(153),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Row(
                            children: [
                              Icon(
                                CustomIcons.play_arrow,
                                color: Colors.white,
                                size: 12,
                              ),
                              const SizedBox(width: 4),
                              Text(
                                NumberFormatter.countNumFilter(
                                  item['play_times'] ?? 0,
                                ),
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 12,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      // 点赞按钮和数量
                      GestureDetector(
                        onTap: onLikeTap,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.black.withAlpha(153),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                CustomIcons.likes,
                                color: Colors.white,
                                size: 12,
                              ),
                              const SizedBox(width: 6),
                              Text(
                                NumberFormatter.countNumFilter(
                                  item['likes_count'] ?? 0,
                                ),
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 12,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            // 文本内容区域
            Padding(
              padding: const EdgeInsets.only(
                left: 0,
                right: 0,
                top: 8,
                bottom: 8,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // 标题
                  Text(
                    item['title'] ?? '',
                    style: const TextStyle(
                      fontWeight: FontWeight.w500,
                      fontSize: 14,
                      height: 1.5,
                      color: Color(0xff333333),
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 2),
                  // 描述
                  Text(
                    item['tags'].join(', ') ?? '',
                    style: const TextStyle(
                      color: Color(0xff666666),
                      fontSize: 12,
                      height: 1.4,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 6),
                  // 作者信息
                  Row(
                    children: [
                      // 头像
                      Icon(
                        CustomIcons.user,
                        color: Color(0xff666666),
                        size: 12,
                      ),
                      const SizedBox(width: 8),
                      // 作者名
                      Expanded(
                        child: Text(
                          item['author'] ?? '',
                          style: const TextStyle(
                            fontSize: 12,
                            height: 1.4,
                            color: Color(0xff666666),
                            fontWeight: FontWeight.w500,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
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
