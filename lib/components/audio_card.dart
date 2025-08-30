import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter_svg/flutter_svg.dart';

class AudioCard extends StatelessWidget {
  final Map<String, dynamic> item;
  final VoidCallback? onTap;
  final VoidCallback? onPlayTap;
  final VoidCallback? onLikeTap;

  const AudioCard({
    super.key,
    required this.item,
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
                ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: AspectRatio(
                    aspectRatio: 3 / 4, // 3:4 的宽高比，确保合适的显示比例
                    child: CachedNetworkImage(
                      imageUrl: item['cover'],
                      placeholder: (context, url) => Container(
                        color: Colors.grey[300],
                        child: const Center(child: CircularProgressIndicator()),
                      ),
                      errorWidget: (context, url, error) => Container(
                        color: Colors.grey[300],
                        child: const Icon(Icons.error),
                      ),
                      fit: BoxFit.cover,
                    ),
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
                            color: Colors.black.withOpacity(0.6),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Row(
                            children: [
                              SvgPicture.asset(
                                'assets/icons/play.svg',
                                width: 10,
                                height: 11,
                                colorFilter: const ColorFilter.mode(
                                  Colors.white,
                                  BlendMode.srcIn,
                                ),
                              ),
                              const SizedBox(width: 4),
                              Text(
                                _formatPlayCount(item['play_times']),
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
                            color: Colors.black.withOpacity(0.6),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              SvgPicture.asset(
                                'assets/icons/likes.svg',
                                width: 12,
                                height: 11,
                                colorFilter: const ColorFilter.mode(
                                  Colors.white,
                                  BlendMode.srcIn,
                                ),
                              ),
                              const SizedBox(width: 4),
                              Text(
                                _formatLikeCount(item['likes_count']),
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
                    item['title'],
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
                    item['desc'],
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
                      SvgPicture.asset(
                        'assets/icons/author.svg',
                        width: 10,
                        height: 11,
                        colorFilter: const ColorFilter.mode(
                          Color(0xff333333),
                          BlendMode.srcIn,
                        ),
                      ),
                      const SizedBox(width: 8),
                      // 作者名
                      Expanded(
                        child: Text(
                          item['author'],
                          style: const TextStyle(
                            fontSize: 12,
                            height: 1.4,
                            color: Color(0xff333333),
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

  // 格式化播放次数
  String _formatPlayCount(int count) {
    if (count >= 10000) {
      return '${(count / 10000).toStringAsFixed(1)}W';
    } else if (count >= 1000) {
      return '${(count / 1000).toStringAsFixed(1)}K';
    } else {
      return count.toString();
    }
  }

  // 格式化点赞数
  String _formatLikeCount(int count) {
    if (count >= 10000) {
      return '${(count / 10000).toStringAsFixed(1)}W';
    } else if (count >= 1000) {
      return '${(count / 1000).toStringAsFixed(1)}K';
    } else {
      return count.toString();
    }
  }
}
