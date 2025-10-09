import 'package:flutter/foundation.dart';
import 'package:hushie_app/models/highlight_model.dart';
import 'image_model.dart';

class AudioItem {
  final String id;
  final ImageModel cover;
  final ImageModel? bgImage; // 背景图片
  final String title;
  final String desc;
  final String author;
  final String avatar;
  final int playTimes;
  final int likesCount;
  final String? audioUrl;
  final Duration? duration;  
  final DateTime? createdAt;
  final List<String>? tags;
  final bool isLiked;
  final DateTime? lastPlayedAt; // 最后播放时间 单位：秒
  final Duration? playDuration; // 播放时长
  final Duration? playProgress; // 播放进度

  // 预览相关字段
  final Duration? previewStart; // 可预览开始时间点
  final Duration? previewDuration; // 可预览时长

  // 高亮
  HighlightModel? highlight; // 高亮信息  

  // 解析duration的静态方法，包含容错处理和数值验证
  static int _parseDurationMs(dynamic duration) {
    try {
      if (duration == null) return 0;
      
      double seconds = 0;
      
      // 如果已经是数字类型
      if (duration is num) {
        seconds = duration.toDouble();
      }
      // 如果是字符串，尝试解析
      else if (duration is String) {
        final parsed = double.tryParse(duration);
        if (parsed != null) {
          seconds = parsed;
        } else {
          return 0;
        }
      }
      // 其他类型直接返回0
      else {
        return 0;
      }
      
      // 添加合理性检查：音频时长应在合理范围内
      // 最小值：0秒，最大值：24小时（86400秒）
      if (seconds < 0) {
        // debugPrint('警告：检测到负数音频时长: ${seconds}秒，已重置为0');
        return 0;
      }
      
      if (seconds > 86400) {
        // debugPrint('警告：检测到异常大的音频时长: ${seconds}秒（${(seconds/3600).toStringAsFixed(1)}小时），已重置为0');
        return 0;
      }
      
      return (seconds * 1000).round();
    } catch (e) {
      debugPrint('解析音频时长时出错: $e');
      return 0;
    }
  }

  static List<String> parseTagsValue(dynamic tags) {
    if (tags == null || tags is! String ||  tags == '') return [];
    return tags.split(',').map((tag) => tag.trim()).toList();
  }

  AudioItem({
    required this.id, // id
    required this.cover, // 封面
    required this.title, // 标题
    required this.desc, // 描述
    required this.author, // 作者
    required this.avatar, // 头像
    required this.playTimes, // 播放次数
    required this.likesCount, // 点赞数
    this.audioUrl, // 音频URL
    this.duration, // 时长
    this.createdAt, // 创建时间
    this.tags, // 标签
    this.bgImage, // 背景图片
    this.lastPlayedAt, // 最后播放时间
    this.previewStart, // 可预览开始时间点
    this.previewDuration, // 可预览时长
    this.isLiked = false, // 是否点赞
    this.playDuration, // 播放时长
    this.playProgress, // 播放进度
    this.highlight, // 高亮信息
  });

  factory AudioItem.fromMap(Map<String, dynamic> map) {
    return AudioItem(
      id: map['id'].toString(),
      cover: _parseImageModel(map['cover']) ?? _getDefaultImageModel(),
      title: map['title'] ?? '',
      desc: map['desc'] ?? '',
      author: map['author'] ?? '',
      avatar: map['avatar'] ?? '',
      playTimes: map['play_times'] ?? 0,
      likesCount: map['likes_count'] ?? 0,
      audioUrl: map['audio_url'],
      duration: map['duration'] != null ? Duration(milliseconds: _parseDurationMs(map['duration'])) : null, // response 是秒，需要转换为毫秒
      createdAt: map['created_at'] != null
          ? DateTime.tryParse(map['created_at'].toString())
          : null,
      tags: (parseTagsValue(map['tags_gender']) + parseTagsValue(map['tags'])).toSet().toList(),
      bgImage: _parseImageModel(map['bg_image'] ?? map['bgImage']),
      lastPlayedAt: map['last_played_at_s'] != null
          ? DateTime.fromMillisecondsSinceEpoch(map['last_played_at_s'] * 1000) 
          : null,
      previewStart: map['preview_start_ms'] != null
          ? Duration(milliseconds: map['preview_start_ms'])
          : null,
      previewDuration: map['preview_duration_ms'] != null
          ? Duration(milliseconds: map['preview_duration_ms'])
          : null,
      isLiked: map['is_liked'] ?? false,
      playDuration: map['play_duration_ms'] != null ? Duration(milliseconds: map['play_duration_ms']) : null,
      playProgress: map['play_progress_ms'] != null ? Duration(milliseconds: map['play_progress_ms']) : null,
      highlight: map['highlight'] != null ? HighlightModel.fromMap(map['highlight']) : null,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'cover': cover.toJson(),
      'title': title,
      'desc': desc,
      'author': author,
      'avatar': avatar,
      'play_times': playTimes,
      'likes_count': likesCount,
      'audio_url': audioUrl,
      'duration': duration?.inMilliseconds,
      'created_at': createdAt?.toIso8601String(),
      'tags': tags?.join(',') ?? '',
      'tags_gender': '', // 保持与fromMap一致的字段结构
      'bg_image': bgImage?.toJson(),
      'last_played_at': lastPlayedAt?.millisecondsSinceEpoch,
      'preview_start_ms': previewStart?.inMilliseconds,
      'preview_duration_ms': previewDuration?.inMilliseconds,
      'is_liked': isLiked,
      'last_play_at_s': lastPlayedAt != null ? (lastPlayedAt!.millisecondsSinceEpoch / 1000) : 0,
      'play_duration_ms': playDuration?.inMilliseconds,
      'play_progress_ms': playProgress?.inMilliseconds,
      'highlight': highlight, // 高亮信息
    };
  }

  AudioItem copyWith({
    String? id,
    String? cid,
    ImageModel? cover,
    String? title,
    String? desc,
    String? author,
    String? avatar,
    int? playTimes,
    int? likesCount,
    String? audioUrl,
    Duration? duration,
    DateTime? createdAt,
    List<String>? tags,
    ImageModel? bgImage,
    DateTime? lastPlayedAt,
    Duration? previewStart,
    Duration? previewDuration,
    bool? isLiked,
    int? lastPlayedAtS,
    Duration? playDuration,
    Duration? playProgress,
    Map<String, List<String>>? highlight, // 高亮信息
  }) {
    return AudioItem(
      id: id ?? this.id,
      cover: cover ?? this.cover,
      title: title ?? this.title,
      desc: desc ?? this.desc,
      author: author ?? this.author,
      avatar: avatar ?? this.avatar,
      playTimes: playTimes ?? this.playTimes,
      likesCount: likesCount ?? this.likesCount,
      audioUrl: audioUrl ?? this.audioUrl,
      duration: duration ?? this.duration,
      createdAt: createdAt ?? this.createdAt,
      tags: tags ?? this.tags,
      bgImage: bgImage ?? this.bgImage,
      lastPlayedAt: lastPlayedAt ?? this.lastPlayedAt,
      previewStart: previewStart ?? this.previewStart,
      previewDuration: previewDuration ?? this.previewDuration,
      isLiked: isLiked ?? this.isLiked,
      playDuration: playDuration ?? this.playDuration,
      playProgress: playProgress ?? this.playProgress,
      highlight: highlight != null ? HighlightModel.fromMap(highlight) : this.highlight, // 高亮信息
    );
  }

  @override
  String toString() {
    return 'AudioItem(id: $id, title: $title, author: $author, tags: $tags)';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is AudioItem && other.id == id;
  }

  @override
  int get hashCode => id.hashCode;

  /// 安全地解析ImageModel，避免类型转换错误
  static ImageModel? _parseImageModel(dynamic data) {
    if (data == null) return null;
    
    try {
      if (data is Map<String, dynamic>) {
        return ImageModel.fromJson(data);
      }
      // 如果不是Map类型，返回null
      return null;
    } catch (e) {
      // 解析失败时返回null
      debugPrint('ImageModel解析失败: $e');
      return null;
    }
  }

  /// 获取默认的ImageModel
  static ImageModel _getDefaultImageModel() {
    return ImageModel(
      id: 'default',
      urls: ImageResolutions(
        x1: ImageResolution(
          url: 'assets/images/logo.png',
          width: 400,
          height: 600,
        ),
      ),
    );
  }
}
