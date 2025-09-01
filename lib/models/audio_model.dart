import 'image_model.dart';

class AudioModel {
  final String id;
  final String title;
  final String artist;
  final String artistAvatar;
  final String description;
  final String audioUrl;
  final ImageModel coverUrl;
  final Duration duration;
  final int likesCount;
  final ImageModel? bgImage; // 背景图片

  // 预览相关字段
  final Duration? previewStart; // 可预览开始时间点
  final Duration? previewDuration; // 可预览时长

  const AudioModel({
    required this.id, // id
    required this.title, // 标题
    required this.artist, // 艺术家
    required this.artistAvatar, // 艺术家头像
    required this.description, // 描述
    required this.audioUrl, // 音频URL
    required this.coverUrl, // 封面URL
    required this.duration, // 时长 单位：毫秒
    required this.likesCount, // 点赞数
    this.bgImage, // 背景图片
    this.previewStart, // 可预览开始时间点 单位：毫秒
    this.previewDuration, // 可预览时长 单位：毫秒
  });

  // 转换为MediaItem用于audio_service
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'artist': artist,
      'artistAvatar': artistAvatar,
      'description': description,
      'audioUrl': audioUrl,
      'coverUrl': coverUrl.toJson(),
      'duration': duration.inMilliseconds,
      'likesCount': likesCount,
      'bgImage': bgImage?.toJson(),
      'previewStart': previewStart?.inMilliseconds,
      'previewDuration': previewDuration?.inMilliseconds,
    };
  }

  factory AudioModel.fromJson(Map<String, dynamic> json) {
    return AudioModel(
      id: json['id'],
      title: json['title'],
      artist: json['artist'],
      artistAvatar: json['artistAvatar'],
      description: json['description'],
      audioUrl: json['audioUrl'],
      coverUrl: ImageModel.fromJson(json['coverUrl'] ?? {}),
      duration: Duration(milliseconds: json['duration']),
      likesCount: json['likesCount'],
      bgImage: json['bgImage'] != null
          ? ImageModel.fromJson(json['bgImage'])
          : null,
      previewStart: json['previewStart'] != null
          ? Duration(milliseconds: json['previewStart'])
          : null,
      previewDuration: json['previewDuration'] != null
          ? Duration(milliseconds: json['previewDuration'])
          : null,
    );
  }

  AudioModel copyWith({
    String? id,
    String? title,
    String? artist,
    String? artistAvatar,
    String? description,
    String? audioUrl,
    ImageModel? coverUrl,
    Duration? duration,
    int? likesCount,
    ImageModel? bgImage,
    Duration? previewStart,
    Duration? previewDuration,
  }) {
    return AudioModel(
      id: id ?? this.id,
      title: title ?? this.title,
      artist: artist ?? this.artist,
      artistAvatar: artistAvatar ?? this.artistAvatar,
      description: description ?? this.description,
      audioUrl: audioUrl ?? this.audioUrl,
      coverUrl: coverUrl ?? this.coverUrl,
      duration: duration ?? this.duration,
      likesCount: likesCount ?? this.likesCount,
      bgImage: bgImage ?? this.bgImage,
      previewStart: previewStart ?? this.previewStart,
      previewDuration: previewDuration ?? this.previewDuration,
    );
  }
}
