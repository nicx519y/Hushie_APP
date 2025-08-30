/// 音频播放历史数据模型
/// 继承 AudioModel 的所有字段，并添加播放进度和时间信息
class AudioHistory {
  final String id;
  final String title;
  final String artist;
  final String description;
  final String audioUrl;
  final String coverUrl;
  final Duration duration;
  final int likesCount;

  // 历史记录特有字段
  final Duration playbackPosition; // 上次播放的进度位置
  final DateTime lastPlayedAt; // 最后播放时间
  final DateTime createdAt; // 首次播放时间

  AudioHistory({
    required this.id,
    required this.title,
    required this.artist,
    required this.description,
    required this.audioUrl,
    required this.coverUrl,
    required this.duration,
    required this.likesCount,
    required this.playbackPosition,
    required this.lastPlayedAt,
    required this.createdAt,
  });

  /// 从 Map 创建 AudioHistory
  factory AudioHistory.fromMap(Map<String, dynamic> map) {
    return AudioHistory(
      id: map['id'] ?? '',
      title: map['title'] ?? '',
      artist: map['artist'] ?? '',
      description: map['description'] ?? '',
      audioUrl: map['audio_url'] ?? '',
      coverUrl: map['cover_url'] ?? '',
      duration: Duration(milliseconds: map['duration_ms'] ?? 0),
      likesCount: map['likes_count'] ?? 0,
      playbackPosition: Duration(
        milliseconds: map['playback_position_ms'] ?? 0,
      ),
      lastPlayedAt: DateTime.fromMillisecondsSinceEpoch(
        map['last_played_at'] ?? DateTime.now().millisecondsSinceEpoch,
      ),
      createdAt: DateTime.fromMillisecondsSinceEpoch(
        map['created_at'] ?? DateTime.now().millisecondsSinceEpoch,
      ),
    );
  }

  /// 转换为 Map 用于数据库存储
  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'title': title,
      'artist': artist,
      'description': description,
      'audio_url': audioUrl,
      'cover_url': coverUrl,
      'duration_ms': duration.inMilliseconds,
      'likes_count': likesCount,
      'playback_position_ms': playbackPosition.inMilliseconds,
      'last_played_at': lastPlayedAt.millisecondsSinceEpoch,
      'created_at': createdAt.millisecondsSinceEpoch,
    };
  }

  /// 从 AudioModel 创建 AudioHistory（用于新记录）
  factory AudioHistory.fromAudioModel(
    Map<String, dynamic> audioModel, {
    Duration playbackPosition = Duration.zero,
    DateTime? lastPlayedAt,
    DateTime? createdAt,
  }) {
    final now = DateTime.now();
    return AudioHistory(
      id: audioModel['id'] ?? '',
      title: audioModel['title'] ?? '',
      artist: audioModel['artist'] ?? '',
      description: audioModel['description'] ?? '',
      audioUrl: audioModel['audioUrl'] ?? '',
      coverUrl: audioModel['coverUrl'] ?? '',
      duration: audioModel['duration'] ?? Duration.zero,
      likesCount: audioModel['likesCount'] ?? 0,
      playbackPosition: playbackPosition,
      lastPlayedAt: lastPlayedAt ?? now,
      createdAt: createdAt ?? now,
    );
  }

  /// 转换为 AudioModel（用于播放）
  Map<String, dynamic> toAudioModel() {
    return {
      'id': id,
      'title': title,
      'artist': artist,
      'description': description,
      'audioUrl': audioUrl,
      'coverUrl': coverUrl,
      'duration': duration,
      'likesCount': likesCount,
    };
  }

  /// 创建副本并更新播放进度
  AudioHistory copyWithProgress({
    Duration? playbackPosition,
    DateTime? lastPlayedAt,
  }) {
    return AudioHistory(
      id: id,
      title: title,
      artist: artist,
      description: description,
      audioUrl: audioUrl,
      coverUrl: coverUrl,
      duration: duration,
      likesCount: likesCount,
      playbackPosition: playbackPosition ?? this.playbackPosition,
      lastPlayedAt: lastPlayedAt ?? this.lastPlayedAt,
      createdAt: createdAt,
    );
  }

  /// 判断是否播放完成
  bool get isCompleted {
    return playbackPosition.inMilliseconds >=
        duration.inMilliseconds * 0.95; // 95% 算完成
  }

  /// 获取播放进度百分比
  double get progressPercentage {
    if (duration.inMilliseconds == 0) return 0.0;
    return (playbackPosition.inMilliseconds / duration.inMilliseconds).clamp(
      0.0,
      1.0,
    );
  }

  /// 格式化播放进度显示
  String get formattedProgress {
    final current = _formatDuration(playbackPosition);
    final total = _formatDuration(duration);
    return '$current / $total';
  }

  /// 格式化时长
  String _formatDuration(Duration duration) {
    final hours = duration.inHours;
    final minutes = duration.inMinutes.remainder(60);
    final seconds = duration.inSeconds.remainder(60);

    if (hours > 0) {
      return '${hours.toString().padLeft(2, '0')}:${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
    } else {
      return '${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
    }
  }

  @override
  String toString() {
    return 'AudioHistory(id: $id, title: $title, progress: ${formattedProgress}, lastPlayed: $lastPlayedAt)';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is AudioHistory && other.id == id;
  }

  @override
  int get hashCode => id.hashCode;
}
