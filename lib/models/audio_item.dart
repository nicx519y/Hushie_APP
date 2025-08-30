class AudioItem {
  final String id;
  final String cover;
  final String title;
  final String desc;
  final String author;
  final String avatar;
  final int playTimes;
  final int likesCount;

  AudioItem({
    required this.id,
    required this.cover,
    required this.title,
    required this.desc,
    required this.author,
    required this.avatar,
    required this.playTimes,
    required this.likesCount,
  });

  factory AudioItem.fromMap(Map<String, dynamic> map) {
    return AudioItem(
      id: map['id'] ?? '',
      cover: map['cover'] ?? '',
      title: map['title'] ?? '',
      desc: map['desc'] ?? '',
      author: map['author'] ?? '',
      avatar: map['avatar'] ?? '',
      playTimes: map['play_times'] ?? 0,
      likesCount: map['likes_count'] ?? 0,
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
    };
  }
}
