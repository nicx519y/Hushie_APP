import 'dart:async';
import '../models/audio_history.dart';
import '../models/audio_model.dart';
import 'audio_history_database.dart';

/// 音频播放历史管理器
/// 整合本地数据库存储和内存数据池，提供统一的历史管理接口
class AudioHistoryManager {
  static final AudioHistoryManager _instance = AudioHistoryManager._internal();
  static AudioHistoryManager get instance => _instance;

  final AudioHistoryDatabase _database = AudioHistoryDatabase.instance;
  late Timer? _progressUpdateTimer;
  DateTime? _lastProgressUpdate;
  String? _currentTrackingAudioId;

  AudioHistoryManager._internal();

  /// 初始化历史管理器
  Future<void> initialize() async {
    try {
      print('正在初始化音频历史管理器...');

      // 初始化数据库
      await _database.database;

      print('音频历史管理器初始化完成');
    } catch (e) {
      print('音频历史管理器初始化失败: $e');

      // 如果数据库初始化失败，尝试重建数据库
      try {
        print('尝试重建数据库...');
        await _database.rebuildDatabase();
        print('数据库重建成功');
      } catch (rebuildError) {
        print('数据库重建也失败: $rebuildError');
      }
    }
  }

  /// 记录音频开始播放
  Future<void> recordPlayStart(AudioModel audioModel) async {
    try {
      // 创建或更新历史记录，进度设为0
      final history = AudioHistory(
        id: audioModel.id,
        title: audioModel.title,
        artist: audioModel.artist,
        artistAvatar: audioModel.artistAvatar,
        description: audioModel.description,
        audioUrl: audioModel.audioUrl,
        coverUrl: audioModel.coverUrl,
        duration: audioModel.duration,
        likesCount: audioModel.likesCount,
        playbackPosition: Duration.zero, // 开始播放，进度为0
        lastPlayedAt: DateTime.now(),
        createdAt: DateTime.now(),
      );

      // 存储到数据库
      await _database.addOrUpdateHistory(history);

      // 启动进度追踪
      _startProgressTracking(audioModel.id);

      print('记录播放开始: ${audioModel.title}');
    } catch (e) {
      print('记录播放开始失败: $e');
    }
  }

  /// 记录音频停止播放
  Future<void> recordPlayStop(
    String audioId,
    Duration currentPosition,
    Duration totalDuration,
  ) async {
    try {
      // 停止进度追踪
      _stopProgressTracking();

      // 如果播放完成（播放进度 >= 95%），将进度设为0
      final isCompleted =
          currentPosition.inMilliseconds >= totalDuration.inMilliseconds * 0.95;
      final finalPosition = isCompleted ? Duration.zero : currentPosition;

      // 更新数据库中的播放进度
      await _database.updatePlaybackProgress(audioId, finalPosition);

      print(
        '记录播放停止: $audioId, 进度: ${_formatDuration(finalPosition)} ${isCompleted ? '(已完成)' : ''}',
      );
    } catch (e) {
      print('记录播放停止失败: $e');
    }
  }

  /// 手动更新播放进度
  Future<void> updateProgress(
    String audioId,
    Duration currentPosition, {
    bool forceUpdate = false,
  }) async {
    try {
      final now = DateTime.now();

      // 检查是否需要更新（距离上次更新是否超过间隔时间）
      if (!forceUpdate && _lastProgressUpdate != null) {
        final timeSinceLastUpdate = now
            .difference(_lastProgressUpdate!)
            .inSeconds;
        if (timeSinceLastUpdate < AudioHistoryDatabase.progressUpdateInterval) {
          return; // 还没到更新间隔
        }
      }

      // 更新数据库中的进度
      await _database.updatePlaybackProgress(audioId, currentPosition);

      _lastProgressUpdate = now;

      if (forceUpdate) {
        print('强制更新播放进度: $audioId -> ${_formatDuration(currentPosition)}');
      }
      // print('更新播放进度: $audioId -> ${_formatDuration(currentPosition)}');
    } catch (e) {
      print('更新播放进度失败: $e');
    }
  }

  /// 启动定期进度更新追踪
  void _startProgressTracking(String audioId) {
    // 如果已经在追踪同一个音频，不需要重新启动
    if (_currentTrackingAudioId == audioId && _progressUpdateTimer != null) {
      return;
    }

    // 停止之前的追踪
    _stopProgressTracking();

    // 记录当前追踪的音频ID
    _currentTrackingAudioId = audioId;

    // 立即更新一次进度
    updateProgress(audioId, Duration.zero, forceUpdate: true);

    // 启动定时器，使用配置的间隔时间
    _progressUpdateTimer = Timer.periodic(
      Duration(seconds: AudioHistoryDatabase.progressUpdateInterval),
      (timer) async {
        try {
          // 这里需要从外部获取当前播放位置
          // 由于我们没有直接访问 AudioManager 的权限，
          // 我们通过回调或者外部调用来更新进度
          print('定时器触发，等待外部进度更新: $audioId');
        } catch (e) {
          print('定时器执行失败: $e');
        }
      },
    );

    print(
      '开始追踪音频播放进度: $audioId，每${AudioHistoryDatabase.progressUpdateInterval}秒更新一次',
    );
  }

  /// 停止进度追踪
  void _stopProgressTracking() {
    // 在停止追踪前，记录一次当前进度（如果外部提供了的话）
    if (_currentTrackingAudioId != null) {
      print('停止追踪音频播放进度: $_currentTrackingAudioId');
    }

    _progressUpdateTimer?.cancel();
    _progressUpdateTimer = null;
    _currentTrackingAudioId = null;
  }

  /// 公共方法：停止进度追踪（供外部调用）
  void stopProgressTracking() {
    _stopProgressTracking();
  }

  /// 获取音频的播放历史
  Future<AudioHistory?> getAudioHistory(String audioId) async {
    try {
      return await _database.getHistoryById(audioId);
    } catch (e) {
      print('获取音频历史失败: $e');
      return null;
    }
  }

  /// 获取最近播放的音频列表
  Future<List<AudioHistory>> getRecentHistory({int limit = 10}) async {
    try {
      return await _database.getRecentHistory(limit: limit);
    } catch (e) {
      print('获取最近播放列表失败: $e');
      return [];
    }
  }

  /// 获取所有播放历史
  Future<List<AudioHistory>> getAllHistory() async {
    try {
      return await _database.getAllHistory();
    } catch (e) {
      print('获取所有播放历史失败: $e');
      return [];
    }
  }

  /// 搜索播放历史
  Future<List<AudioHistory>> searchHistory(String keyword) async {
    try {
      return await _database.searchHistory(keyword);
    } catch (e) {
      print('搜索播放历史失败: $e');
      return [];
    }
  }

  /// 删除指定音频的历史记录
  Future<bool> deleteHistory(String audioId) async {
    try {
      final success = await _database.deleteHistory(audioId);
      return success;
    } catch (e) {
      print('删除播放历史失败: $e');
      return false;
    }
  }

  /// 清空所有播放历史
  Future<bool> clearAllHistory() async {
    try {
      final success = await _database.clearAllHistory();
      if (success) {
        // 注意：这里不清空数据池，因为数据池可能包含其他来源的数据
        print('已清空所有播放历史（数据池保持不变）');
      }
      return success;
    } catch (e) {
      print('清空播放历史失败: $e');
      return false;
    }
  }

  /// 获取播放历史统计信息
  Future<Map<String, dynamic>> getHistoryStats() async {
    try {
      return await _database.getHistoryStats();
    } catch (e) {
      print('获取历史统计失败: $e');
      return {};
    }
  }

  /// 配置历史记录设置
  void configureSettings({int? maxHistoryCount, int? progressUpdateInterval}) {
    if (maxHistoryCount != null) {
      AudioHistoryDatabase.setMaxHistoryCount(maxHistoryCount);
    }

    if (progressUpdateInterval != null) {
      AudioHistoryDatabase.setProgressUpdateInterval(progressUpdateInterval);
    }
  }

  /// 格式化时长为字符串
  String _formatDuration(Duration duration) {
    final minutes = duration.inMinutes;
    final seconds = duration.inSeconds.remainder(60);
    return '${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
  }

  /// 打印调试信息
  Future<void> printDebugInfo() async {
    // 数据库统计
    await _database.printDebugInfo();
  }

  /// 清理资源
  Future<void> dispose() async {
    // 停止进度追踪
    _stopProgressTracking();

    await _database.close();
    print('音频历史管理器资源已清理');
  }
}
