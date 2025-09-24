import 'dart:async';
import '../models/audio_item.dart';
import 'package:flutter/foundation.dart';

/// 音频播放列表管理器
/// 负责管理有序的音频播放列表，提供通过 ID 查找音频的功能
class AudioPlaylist {
  static final AudioPlaylist _instance = AudioPlaylist._internal();
  static AudioPlaylist get instance => _instance;

  // 音频播放列表（有序）
  final List<AudioItem> _playlist = [];
  final Map<String, int> _audioIndexMap = {}; // ID到索引的映射
  int _currentIndex = -1; // 当前播放的索引

  AudioPlaylist._internal();

  /// 初始化播放列表
  /// 从历史记录获取最后一条记录并加载到播放列表
  Future<void> initialize() async {}

  /// 获取最后加载的音频（供AudioManager调用）
  AudioItem? getLastLoadedAudio() {
    return _playlist.isNotEmpty ? _playlist[0] : null;
  }

  /// 添加音频数据到播放列表
  void addAudio(AudioItem audio) {
    // 检查是否已存在同ID的音频
    final existingIndex = _playlist.indexWhere((item) => item.id == audio.id);

    if (existingIndex != -1) {
      // 如果存在同ID的音频，先删除它
      _playlist.removeAt(existingIndex);

      // 如果删除的是当前播放的音频，需要调整当前索引
      if (_currentIndex == existingIndex) {
        // 如果删除的是当前播放的音频，将当前索引设为-1（无效）
        _currentIndex = -1;
      } else if (_currentIndex > existingIndex) {
        // 如果删除的音频在当前播放音频之前，需要调整当前索引
        _currentIndex--;
      }

      // 重建索引映射
      _rebuildIndexMap();

      debugPrint('播放列表中已存在同ID音频，已删除: ${audio.id}');
    }

    // 从后面添加新的音频
    final newIndex = _playlist.length;
    _playlist.add(audio);
    _audioIndexMap[audio.id] = newIndex;

  }

  /// 批量添加音频数据到播放列表
  void addAudioList(List<AudioItem> audioList) {
    for (final audio in audioList) {
      addAudio(audio);
    }
  }

  /// 通过 ID 获取音频数据
  AudioItem? getAudioItemById(String id) {
    final index = _audioIndexMap[id];
    return index != null ? _playlist[index] : null;
  }

  /// 通过 ID 获取 AudioItem（用于播放）
  AudioItem? getAudioModelById(String id) {
    final audioItem = getAudioItemById(id);
    if (audioItem == null) return null;

    return audioItem;
  }

  /// 清空播放列表
  void clear() {
    _playlist.clear();
    _audioIndexMap.clear();
    _currentIndex = -1;
  }

  /// 获取播放列表大小
  int get playlistSize => _playlist.length;

  /// 移除指定音频
  void removeAudio(String id) {
    final index = _audioIndexMap[id];
    if (index != null) {
      _playlist.removeAt(index);

      // 重建索引映射
      _rebuildIndexMap();

      // 调整当前索引
      if (_currentIndex > index) {
        _currentIndex--;
      } else if (_currentIndex == index) {
        _currentIndex = -1;
      }
    }
  }

  /// 重建索引映射
  void _rebuildIndexMap() {
    _audioIndexMap.clear();
    for (int i = 0; i < _playlist.length; i++) {
      _audioIndexMap[_playlist[i].id] = i;
    }
  }

  /// 清理当前音频之前的所有数据
  void clearBeforeCurrent(String currentAudioId) {
    final currentIndex = _audioIndexMap[currentAudioId];
    if (currentIndex != null && currentIndex > 0) {
      // 移除当前音频之前的所有音频
      _playlist.removeRange(0, currentIndex);

      // 重建索引映射
      _rebuildIndexMap();

      // 更新当前索引
      _currentIndex = 0;

      debugPrint('已清理播放列表中当前音频之前的 $currentIndex 个音频');
    }
  }

  /// 检查是否是最后一条音频
  bool isLastAudio(String audioId) {
    final index = _audioIndexMap[audioId];
    return index != null && index == _playlist.length - 1;
  }

  /// 获取下一个音频
  AudioItem? getNextAudio(String currentAudioId) {
    final currentIndex = _audioIndexMap[currentAudioId];
    debugPrint(
      "getNextAudio: currentIndex: $currentIndex; length: ${_playlist.length}",
    );
    if (currentIndex != null && currentIndex < _playlist.length - 1) {
      return _playlist[currentIndex + 1];
    } else {
      debugPrint(
        'currentAudioId: $currentAudioId, all audio: ${_playlist.map((audio) => audio.id).join(', ')}',
      );
    }
    return null;
  }

  AudioItem? getFirstAudio() {
    return _playlist.isNotEmpty ? _playlist.first : null;
  }

  /// 获取当前音频
  AudioItem? getCurrentAudio() {
    if (_playlist.isEmpty ||
        _currentIndex < 0 ||
        _currentIndex >= _playlist.length) {
      return null;
    }
    return _playlist[_currentIndex];
  }

  /// 设置当前播放索引
  void setCurrentIndex(String audioId) {
    final index = _audioIndexMap[audioId];
    if (index != null) {
      _currentIndex = index;
    }
  }

  /// 获取播放列表统计信息
  Map<String, dynamic> getPlaylistStats() {
    return {
      'total_count': _playlist.length,
      'current_index': _currentIndex,
      'audio_ids': _playlist.map((audio) => audio.id).toList(),
      'memory_usage': '${(_playlist.length * 100)}KB', // 粗略估算
    };
  }

  /// 调试信息
  void printPlaylistInfo() {
    debugPrint('=== 音频播放列表信息 ===');
    debugPrint('播放列表数量: ${_playlist.length}');
    debugPrint('当前播放索引: $_currentIndex');
    debugPrint('音频列表: ${_playlist.map((audio) => audio.title).join(', ')}');
    debugPrint('==================');
  }
}
