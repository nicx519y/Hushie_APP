import 'package:flutter/material.dart';
import 'package:hushie_app/components/fallback_image.dart';
import '../utils/number_formatter.dart';
import '../utils/custom_icons.dart';
import '../models/audio_item.dart';

class AudioCard extends StatelessWidget {
  final AudioItem item;
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
                      imageResource: item.cover,
                      fallbackImage: 'assets/images/cover_backup.jpg',
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
                            vertical: 2,
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
                              const SizedBox(width: 6),
                              Text(
                                NumberFormatter.countNumFilter(
                                  item.playTimes,
                                ),
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 14,
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
                            vertical: 2,
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
                              const SizedBox(width: 8),
                              Text(
                                NumberFormatter.countNumFilter(
                                  item.likesCount,
                                ),
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 14,
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
                top: 6,
                bottom: 0,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // 标题
                  Text(
                    item.title,
                    style: const TextStyle(
                      fontWeight: FontWeight.w500,
                      fontSize: 14,
                      height: 1.2,
                      color: Color(0xff333333),
                    ),
                    maxLines: 3,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 6),
                  // 标签
                  if (item.tags != null && item.tags!.isNotEmpty)
                    Wrap(
                      spacing: 4,
                      runSpacing: 4,
                      children: item.tags!.map((tag) => Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: const Color(0xFFD8D8D8),
                          borderRadius: BorderRadius.circular(0),
                        ),
                        child: Text(
                          tag,
                          style: const TextStyle(
                            color: Color(0xff666666),
                            fontSize: 10,
                            height: 1.2,
                            fontWeight: FontWeight.w400,
                          ),
                        ),
                      )).toList(),
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
                          item.author,
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
