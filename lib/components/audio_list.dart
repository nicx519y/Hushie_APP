import 'package:flutter/material.dart';
import '../models/audio_item.dart';
import 'audio_stats.dart';
import 'package:flutter_svg/flutter_svg.dart';

class AudioList extends StatelessWidget {
  final List<AudioItem> audios;
  final EdgeInsetsGeometry? padding;
  final ScrollPhysics? physics;
  final bool shrinkWrap;
  final Widget? emptyWidget;

  const AudioList({
    super.key,
    required this.audios,
    this.padding = const EdgeInsets.all(0),
    this.physics,
    this.shrinkWrap = false,
    this.emptyWidget,
  });

  @override
  Widget build(BuildContext context) {
    if (audios.isEmpty) {
      return emptyWidget ??
          const Center(
            child: Text(
              '暂无数据',
              style: TextStyle(color: Colors.grey, fontSize: 16),
            ),
          );
    }

    return ListView.builder(
      padding: padding,
      physics: physics,
      shrinkWrap: shrinkWrap,
      itemCount: audios.length,
      itemBuilder: (context, index) {
        return _buildAudioItem(audios[index]);
      },
    );
  }

  Widget _buildAudioItem(AudioItem audio) {
    return Container(
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
              child: audio.cover.isNotEmpty
                  ? Image.network(
                      audio.cover,
                      fit: BoxFit.cover,
                      errorBuilder: (context, error, stackTrace) {
                        return const Icon(Icons.play_arrow, size: 30);
                      },
                    )
                  : const Icon(Icons.play_arrow, size: 30),
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
                    color: const Color(0xFF333333),
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 6),
                // 描述
                Text(
                  audio.desc,
                  style: TextStyle(
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
    );
  }
}
