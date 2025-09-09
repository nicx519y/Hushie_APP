import 'dart:ffi';

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
  final int? lastPlayedAtS; // 最后播放时间 单位：秒
  final Duration? playDuration; // 播放时长
  final Duration? playProgress; // 播放进度

  // 播放进度相关字段
  final DateTime? lastPlayedAt; // 最后播放时间

  // 预览相关字段
  final Duration? previewStart; // 可预览开始时间点
  final Duration? previewDuration; // 可预览时长

  // 解析duration的静态方法，包含容错处理
  static int _parseDurationMs(dynamic duration) {
    try {
      if (duration == null) return 0;
      
      // 如果已经是数字类型
      if (duration is num) {
        return (duration.toDouble() * 1000).round();
      }
      
      // 如果是字符串，尝试解析
      if (duration is String) {
        final parsed = double.tryParse(duration);
        if (parsed != null) {
          return (parsed * 1000).round();
        }
      }
      
      // 解析失败，返回默认值
      return 0;
    } catch (e) {
      // 捕获任何异常，返回默认值
      return 0;
    }
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
    this.lastPlayedAtS, // 最后播放时间 单位：秒
    this.playDuration, // 播放时长
    this.playProgress, // 播放进度
  });

  factory AudioItem.fromMap(Map<String, dynamic> map) {
    return AudioItem(
      id: map['id'].toString(),
      cover: ImageModel.fromJson(map['cover'] ?? {}),
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
      tags: map['tags'] != null ? List<String>.from(map['tags']) : null,
      bgImage: map['bg_image'] != null
          ? ImageModel.fromJson(map['bg_image'])
          : null,
      lastPlayedAt: map['last_played_at'] != null
          ? DateTime.fromMillisecondsSinceEpoch(map['last_played_at'])
          : null,
      previewStart: map['preview_start_ms'] != null
          ? Duration(milliseconds: map['preview_start_ms'])
          : null,
      previewDuration: map['preview_duration_ms'] != null
          ? Duration(milliseconds: map['preview_duration_ms'])
          : null,
      isLiked: map['is_liked'] ?? false,
      lastPlayedAtS: map['last_play_at_s'] ?? 0,
      playDuration: map['play_duration_ms'] != null ? Duration(milliseconds: map['play_duration_ms']) : null,
      playProgress: map['play_progress_ms'] != null ? Duration(milliseconds: map['play_progress_ms']) : null,
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
      'tags': tags,
      'bg_image': bgImage?.toJson(),
      'last_played_at': lastPlayedAt?.millisecondsSinceEpoch,
      'preview_start_ms': previewStart?.inMilliseconds,
      'preview_duration_ms': previewDuration?.inMilliseconds,
      'is_liked': isLiked,
      'last_play_at_s': lastPlayedAtS,
      'play_duration_ms': playDuration?.inMilliseconds,
      'play_progress_ms': playProgress?.inMilliseconds,
    };
  }

  AudioItem copyWith({
    Int32? id,
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
  }) {
    return AudioItem(
      id: id as String,
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
      lastPlayedAtS: lastPlayedAtS ?? this.lastPlayedAtS,
      playDuration: playDuration ?? this.playDuration,
      playProgress: playProgress ?? this.playProgress,
    );
  }

  @override
  String toString() {
    return 'AudioItem(id: $id, title: $title, author: $author)';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is AudioItem && other.id == id;
  }

  @override
  int get hashCode => id.hashCode;
}
