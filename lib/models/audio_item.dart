class AudioItem {
  final String id;
  final String cover;
  final String title;
  final String desc;
  final String author;
  final String avatar;
  final int playTimes;
  final int likesCount;
  final String? audioUrl;
  final String? duration;
  final DateTime? createdAt;
  final List<String>? tags;

  // 播放进度相关字段
  final Duration? playbackPosition; // 上次播放的进度位置
  final DateTime? lastPlayedAt; // 最后播放时间

  AudioItem({
    required this.id,
    required this.cover,
    required this.title,
    required this.desc,
    required this.author,
    required this.avatar,
    required this.playTimes,
    required this.likesCount,
    this.audioUrl,
    this.duration,
    this.createdAt,
    this.tags,
    this.playbackPosition,
    this.lastPlayedAt,
  });

  factory AudioItem.fromMap(Map<String, dynamic> map) {
    return AudioItem(
      id: map['id']?.toString() ?? '',
      cover: map['cover'] ?? '',
      title: map['title'] ?? '',
      desc: map['desc'] ?? '',
      author: map['author'] ?? '',
      avatar: map['avatar'] ?? '',
      playTimes: map['play_times'] ?? 0,
      likesCount: map['likes_count'] ?? 0,
      audioUrl: map['audio_url'],
      duration: map['duration'],
      createdAt: map['created_at'] != null
          ? DateTime.tryParse(map['created_at'].toString())
          : null,
      tags: map['tags'] != null ? List<String>.from(map['tags']) : null,
      playbackPosition: map['playback_position_ms'] != null
          ? Duration(milliseconds: map['playback_position_ms'])
          : null,
      lastPlayedAt: map['last_played_at'] != null
          ? DateTime.fromMillisecondsSinceEpoch(map['last_played_at'])
          : null,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'cover': cover,
      'title': title,
      'desc': desc,
      'author': author,
      'avatar': avatar,
      'play_times': playTimes,
      'likes_count': likesCount,
      'audio_url': audioUrl,
      'duration': duration,
      'created_at': createdAt?.toIso8601String(),
      'tags': tags,
      'playback_position_ms': playbackPosition?.inMilliseconds,
      'last_played_at': lastPlayedAt?.millisecondsSinceEpoch,
    };
  }

  AudioItem copyWith({
    String? id,
    String? cover,
    String? title,
    String? desc,
    String? author,
    String? avatar,
    int? playTimes,
    int? likesCount,
    String? audioUrl,
    String? duration,
    DateTime? createdAt,
    List<String>? tags,
    Duration? playbackPosition,
    DateTime? lastPlayedAt,
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
      playbackPosition: playbackPosition ?? this.playbackPosition,
      lastPlayedAt: lastPlayedAt ?? this.lastPlayedAt,
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
