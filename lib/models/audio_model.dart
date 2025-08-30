class AudioModel {
  final String id;
  final String title;
  final String artist;
  final String artistAvatar;
  final String description;
  final String audioUrl;
  final String coverUrl;
  final Duration duration;
  final int likesCount;

  const AudioModel({
    required this.id,
    required this.title,
    required this.artist,
    required this.artistAvatar,
    required this.description,
    required this.audioUrl,
    required this.coverUrl,
    required this.duration,
    required this.likesCount,
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
      'coverUrl': coverUrl,
      'duration': duration.inMilliseconds,
      'likesCount': likesCount,
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
      coverUrl: json['coverUrl'],
      duration: Duration(milliseconds: json['duration']),
      likesCount: json['likesCount'],
    );
  }

  AudioModel copyWith({
    String? id,
    String? title,
    String? artist,
    String? artistAvatar,
    String? description,
    String? audioUrl,
    String? coverUrl,
    Duration? duration,
    int? likesCount,
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
    );
  }
}
