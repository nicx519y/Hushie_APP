import '../models/audio_item.dart';
import '../models/audio_model.dart';

/// 音频数据池管理器
/// 负责缓存音频数据，提供通过 ID 查找音频的功能
class AudioDataPool {
  static final AudioDataPool _instance = AudioDataPool._internal();
  static AudioDataPool get instance => _instance;

  // 音频数据缓存池
  final Map<String, AudioItem> _audioCache = {};

  AudioDataPool._internal();

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
