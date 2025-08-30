import '../models/audio_item.dart';
import '../models/audio_model.dart';
import 'audio_history_database.dart';

/// 音频数据池管理器
/// 负责缓存音频数据，提供通过 ID 查找音频的功能
class AudioDataPool {
  static final AudioDataPool _instance = AudioDataPool._internal();
  static AudioDataPool get instance => _instance;

  // 音频数据缓存池
  final Map<String, AudioItem> _audioCache = {};

  AudioDataPool._internal();

  /// 初始化数据池
  /// 加载历史数据作为原始数据源
  Future<void> initialize() async {
    try {
      print('正在初始化音频数据池...');

      // 加载历史数据到数据池
      await _loadHistoryToDataPool();

      print('音频数据池初始化完成，当前缓存: $_audioCache.length 个音频');
    } catch (e) {
      print('音频数据池初始化失败: $e');
    }
  }

  /// 从历史数据库加载数据到数据池
  Future<void> _loadHistoryToDataPool() async {
    try {
      final database = AudioHistoryDatabase.instance;

      final historyList = await database.getAllHistory();
      print('从历史数据库加载了 ${historyList.length} 条记录');

      // 将历史记录转换为 AudioItem 并添加到数据池
      for (final history in historyList) {
        final audioItem = AudioItem(
          id: history.id,
          cover: history.coverUrl,
          title: history.title,
          desc: history.description,
          author: history.artist,
          avatar: '', // 历史记录中没有头像信息
          playTimes: 0, // 历史记录中没有播放次数
          likesCount: history.likesCount,
          audioUrl: history.audioUrl,
          duration: _formatDuration(history.duration),
          createdAt: history.createdAt,
          tags: [], // 历史记录中没有标签信息
          playbackPosition: history.playbackPosition, // 保存播放进度
          lastPlayedAt: history.lastPlayedAt, // 保存最后播放时间
        );

        _audioCache[audioItem.id] = audioItem;
      }

      print('已将 ${historyList.length} 条历史数据加载到数据池');
    } catch (e) {
      print('加载历史数据到数据池失败: $e');
      // 不抛出异常，允许数据池在没有历史数据的情况下正常工作
    }
  }

  /// 格式化时长为字符串
  String _formatDuration(Duration duration) {
    final minutes = duration.inMinutes;
    final seconds = duration.inSeconds.remainder(60);
    return '${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
  }

  /// 添加音频数据到缓存池
  void addAudio(AudioItem audio) {
    _audioCache[audio.id] = audio;
  }

  /// 批量添加音频数据到缓存池
  void addAudioList(List<AudioItem> audioList) {
    for (final audio in audioList) {
      _audioCache[audio.id] = audio;
    }
  }

  /// 通过 ID 获取音频数据
  AudioItem? getAudioById(String id) {
    return _audioCache[id];
  }

  /// 通过 ID 获取 AudioModel（用于播放）
  AudioModel? getAudioModelById(String id) {
    final audioItem = _audioCache[id];
    if (audioItem == null) return null;

    return AudioModel(
      id: audioItem.id,
      title: audioItem.title,
      artist: audioItem.author,
      artistAvatar: audioItem.avatar,
      description: audioItem.desc,
      audioUrl:
          audioItem.audioUrl ??
          'https://www.soundhelix.com/examples/mp3/SoundHelix-Song-1.mp3',
      coverUrl: audioItem.cover,
      duration: audioItem.duration != null
          ? _parseDuration(audioItem.duration!)
          : Duration.zero,
      likesCount: audioItem.likesCount,
    );
  }

  /// 通过 ID 获取播放进度
  Duration? getPlaybackProgress(String id) {
    final audioItem = _audioCache[id];
    return audioItem?.playbackPosition;
  }

  /// 更新播放进度
  void updatePlaybackProgress(String id, Duration progress) {
    final audioItem = _audioCache[id];
    if (audioItem != null) {
      final updatedItem = audioItem.copyWith(
        playbackPosition: progress,
        lastPlayedAt: DateTime.now(),
      );
      _audioCache[id] = updatedItem;
    }
  }

  /// 获取所有播放进度信息
  Map<String, Duration> getAllPlaybackProgress() {
    final progressMap = <String, Duration>{};
    for (final entry in _audioCache.entries) {
      if (entry.value.playbackPosition != null) {
        progressMap[entry.key] = entry.value.playbackPosition!;
      }
    }
    return progressMap;
  }

  /// 检查音频是否存在于缓存中
  bool hasAudio(String id) {
    return _audioCache.containsKey(id);
  }

  /// 获取缓存中的所有音频 ID
  List<String> getAllAudioIds() {
    return _audioCache.keys.toList();
  }

  /// 获取缓存中的所有音频数据
  List<AudioItem> getAllAudio() {
    return _audioCache.values.toList();
  }

  /// 清空缓存
  void clear() {
    _audioCache.clear();
  }

  /// 获取缓存大小
  int get cacheSize => _audioCache.length;

  /// 移除指定音频
  void removeAudio(String id) {
    _audioCache.remove(id);
  }

  /// 更新音频数据
  void updateAudio(AudioItem audio) {
    if (_audioCache.containsKey(audio.id)) {
      _audioCache[audio.id] = audio;
    }
  }

  /// 解析时长字符串为 Duration
  Duration _parseDuration(String durationStr) {
    try {
      // 支持格式: "3:24", "1:23:45", "120" (秒)
      final parts = durationStr.split(':');

      if (parts.length == 1) {
        // 只有秒数
        return Duration(seconds: int.parse(parts[0]));
      } else if (parts.length == 2) {
        // 分钟:秒钟
        final minutes = int.parse(parts[0]);
        final seconds = int.parse(parts[1]);
        return Duration(minutes: minutes, seconds: seconds);
      } else if (parts.length == 3) {
        // 小时:分钟:秒钟
        final hours = int.parse(parts[0]);
        final minutes = int.parse(parts[1]);
        final seconds = int.parse(parts[2]);
        return Duration(hours: hours, minutes: minutes, seconds: seconds);
      }
    } catch (e) {
      print('解析时长失败: $durationStr, 错误: $e');
    }

    return Duration.zero;
  }

  /// 获取缓存统计信息
  Map<String, dynamic> getCacheStats() {
    return {
      'total_count': _audioCache.length,
      'audio_ids': _audioCache.keys.toList(),
      'memory_usage': '${(_audioCache.length * 100)}KB', // 粗略估算
    };
  }

  /// 调试信息
  void printCacheInfo() {
    print('=== 音频数据池信息 ===');
    print('缓存数量: ${_audioCache.length}');
    print('音频列表: ${_audioCache.keys.join(', ')}');
    print('==================');
  }
}
