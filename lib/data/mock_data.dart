import '../models/audio_item.dart';

class MockData {
  static final List<Map<String, dynamic>> _audioItems = [
    {
      'id': '1',
      'cover': 'https://picsum.photos/400/600?random=1',
      'title': 'Sticky Situation',
      'desc':
          'Quiet and reserved, she doesn\'t say much but is quite intriguing...',
      'author': 'Buddah Bless',
      'avatar': 'https://picsum.photos/50/50?random=101',
      'play_times': 1234,
      'likes_count': 689,
      'audio_url':
          'https://www.soundhelix.com/examples/mp3/SoundHelix-Song-1.mp3',
      'duration': '3:24',
      'created_at': '2024-01-15T10:30:00Z',
      'tags': ['pop', 'trending', 'M/F'],
      'preview_start_ms': 30000, // 从30秒开始预览
      'preview_duration_ms': 15000, // 预览15秒
    },
    {
      'id': '2',
      'cover': 'https://picsum.photos/400/500?random=2',
      'title': 'Midnight Dreams',
      'desc': 'A soulful journey through the night with ambient sounds...',
      'author': 'Luna Waves',
      'avatar': 'https://picsum.photos/50/50?random=102',
      'play_times': 2567,
      'likes_count': 1203,
      'audio_url':
          'https://www.soundhelix.com/examples/mp3/SoundHelix-Song-2.mp3',
      'duration': '4:12',
      'created_at': '2024-01-14T15:45:00Z',
      'tags': ['ambient', 'chill', 'F/M'],
      'preview_start_ms': 45000, // 从45秒开始预览
      'preview_duration_ms': 20000, // 预览20秒
    },
    {
      'id': '3',
      'cover': 'https://picsum.photos/400/700?random=3',
      'title': 'Electric Pulse',
      'desc': 'High energy electronic beats that will get you moving...',
      'author': 'DJ Voltage',
      'avatar': 'https://picsum.photos/50/50?random=103',
      'play_times': 5678,
      'likes_count': 2341,
      'audio_url':
          'https://www.soundhelix.com/examples/mp3/SoundHelix-Song-3.mp3',
      'duration': '2:56',
      'created_at': '2024-01-13T09:20:00Z',
      'tags': ['electronic', 'dance', 'ASMR'],
      'preview_start_ms': 20000, // 从20秒开始预览
      'preview_duration_ms': 12000, // 预览12秒
    },
    {
      'id': '4',
      'cover': 'https://picsum.photos/400/450?random=4',
      'title': 'Ocean Breeze',
      'desc': 'Relaxing waves and gentle melodies for peaceful moments...',
      'author': 'Nature Sounds',
      'avatar': 'https://picsum.photos/50/50?random=104',
      'play_times': 3456,
      'likes_count': 1876,
      'audio_url':
          'https://www.soundhelix.com/examples/mp3/SoundHelix-Song-4.mp3',
      'duration': '5:33',
      'created_at': '2024-01-12T18:15:00Z',
      'tags': ['nature', 'relaxing', 'NSFW'],
      'preview_start_ms': 60000, // 从1分钟开始预览
      'preview_duration_ms': 25000, // 预览25秒
    },
    {
      'id': '5',
      'cover': 'https://picsum.photos/400/550?random=5',
      'title': 'Urban Rhythms',
      'desc': 'Street beats with a modern twist and urban flavor...',
      'author': 'City Beats',
      'avatar': 'https://picsum.photos/50/50?random=105',
      'play_times': 8901,
      'likes_count': 4567,
      'audio_url':
          'https://www.soundhelix.com/examples/mp3/SoundHelix-Song-5.mp3',
      'duration': '3:45',
      'created_at': '2024-01-11T12:00:00Z',
      'tags': ['hip-hop', 'urban', 'M/F'],
      'preview_start_ms': 25000, // 从25秒开始预览
      'preview_duration_ms': 18000, // 预览18秒
    },
    {
      'id': '6',
      'cover': 'https://picsum.photos/400/620?random=6',
      'title': 'Classical Sunrise',
      'desc': 'Beautiful classical composition to start your day right...',
      'author': 'Symphony Orchestra',
      'avatar': 'https://picsum.photos/50/50?random=106',
      'play_times': 1890,
      'likes_count': 923,
      'audio_url':
          'https://www.soundhelix.com/examples/mp3/SoundHelix-Song-6.mp3',
      'duration': '6:18',
      'created_at': '2024-01-10T07:30:00Z',
      'tags': ['classical', 'morning', 'M/F'],
      'preview_start_ms': 90000, // 从1分30秒开始预览
      'preview_duration_ms': 30000, // 预览30秒
    },
    {
      'id': '7',
      'cover': 'https://picsum.photos/400/480?random=7',
      'title': 'Jazz Cafe',
      'desc': 'Smooth jazz vibes perfect for a cozy evening...',
      'author': 'Smooth Jazz Ensemble',
      'avatar': 'https://picsum.photos/50/50?random=107',
      'play_times': 4321,
      'likes_count': 2187,
      'audio_url':
          'https://www.soundhelix.com/examples/mp3/SoundHelix-Song-7.mp3',
      'duration': '4:42',
      'created_at': '2024-01-09T20:15:00Z',
      'tags': ['jazz', 'evening', 'F/M'],
      'preview_start_ms': 35000, // 从35秒开始预览
      'preview_duration_ms': 22000, // 预览22秒
    },
    {
      'id': '8',
      'cover': 'https://picsum.photos/400/580?random=8',
      'title': 'Rock Anthem',
      'desc': 'Powerful rock anthem with driving guitars and vocals...',
      'author': 'Thunder Strike',
      'avatar': 'https://picsum.photos/50/50?random=108',
      'play_times': 7654,
      'likes_count': 3821,
      'audio_url':
          'https://www.soundhelix.com/examples/mp3/SoundHelix-Song-8.mp3',
      'duration': '4:05',
      'created_at': '2024-01-08T16:45:00Z',
      'tags': ['rock', 'energetic', 'ASMR'],
      'preview_start_ms': 15000, // 从15秒开始预览
      'preview_duration_ms': 16000, // 预览16秒
    },
  ];

  /// 获取所有音频数据
  static List<AudioItem> getAllAudioItems() {
    return _audioItems.map((item) => AudioItem.fromMap(item)).toList();
  }

  /// 获取分页音频数据
  static List<AudioItem> getAudioItems({
    int page = 1,
    int pageSize = 10,
    String? searchQuery,
    List<String>? tags,
  }) {
    List<Map<String, dynamic>> filteredItems = List.from(_audioItems);

    // 搜索过滤
    if (searchQuery != null && searchQuery.isNotEmpty) {
      filteredItems = filteredItems.where((item) {
        final title = item['title']?.toString().toLowerCase() ?? '';
        final author = item['author']?.toString().toLowerCase() ?? '';
        final desc = item['desc']?.toString().toLowerCase() ?? '';
        final query = searchQuery.toLowerCase();

        return title.contains(query) ||
            author.contains(query) ||
            desc.contains(query);
      }).toList();
    }

    // 标签过滤
    if (tags != null && tags.isNotEmpty) {
      filteredItems = filteredItems.where((item) {
        final itemTags = List<String>.from(item['tags'] ?? []);
        return tags.any((tag) => itemTags.contains(tag));
      }).toList();
    }

    // 分页处理
    final startIndex = (page - 1) * pageSize;
    final endIndex = startIndex + pageSize;

    if (startIndex >= filteredItems.length) {
      return [];
    }

    final paginatedItems = filteredItems.sublist(
      startIndex,
      endIndex > filteredItems.length ? filteredItems.length : endIndex,
    );

    return paginatedItems.map((item) => AudioItem.fromMap(item)).toList();
  }

  /// 根据 ID 获取单个音频项
  static AudioItem? getAudioItemById(String id) {
    try {
      final item = _audioItems.firstWhere((item) => item['id'] == id);
      return AudioItem.fromMap(item);
    } catch (e) {
      return null;
    }
  }

  /// 获取热门音频
  static List<AudioItem> getPopularAudioItems({int limit = 5}) {
    final sortedItems = List<Map<String, dynamic>>.from(_audioItems);
    sortedItems.sort(
      (a, b) => (b['play_times'] ?? 0).compareTo(a['play_times'] ?? 0),
    );

    final limitedItems = sortedItems.take(limit).toList();
    return limitedItems.map((item) => AudioItem.fromMap(item)).toList();
  }

  /// 获取最新音频
  static List<AudioItem> getLatestAudioItems({int limit = 5}) {
    final sortedItems = List<Map<String, dynamic>>.from(_audioItems);
    sortedItems.sort((a, b) {
      final aDate = DateTime.tryParse(a['created_at'] ?? '') ?? DateTime(2000);
      final bDate = DateTime.tryParse(b['created_at'] ?? '') ?? DateTime(2000);
      return bDate.compareTo(aDate);
    });

    final limitedItems = sortedItems.take(limit).toList();
    return limitedItems.map((item) => AudioItem.fromMap(item)).toList();
  }

  /// 获取所有可用标签
  static List<String> getAllTags() {
    final Set<String> allTags = {};
    for (final item in _audioItems) {
      final tags = List<String>.from(item['tags'] ?? []);
      allTags.addAll(tags);
    }
    return allTags.toList()..sort();
  }

  /// 模拟网络延迟
  static Future<void> simulateNetworkDelay([int milliseconds = 1000]) {
    return Future.delayed(Duration(milliseconds: milliseconds));
  }
}
