import 'dart:async';
import '../models/audio_item.dart';
import '../services/api/user_history_service.dart';
import 'auth_service.dart';

/// 音频播放历史管理器
/// 整合本地数据库存储和内存数据池，提供统一的历史管理接口
class AudioHistoryManager {
  static final AudioHistoryManager _instance = AudioHistoryManager._internal();
  static AudioHistoryManager get instance => _instance;

  Timer? _progressUpdateTimer; // 移除 late 关键字
  DateTime? _lastProgressUpdate;
  String? _currentTrackingAudioId;
  List<AudioItem> _historyCache = []; // 播放历史

  static const int progressUpdateIntervalS = 30; // 30秒更新一次

  AudioHistoryManager._internal();

  /// 初始化历史管理器
  Future<void> initialize() async {
    await getAudioHistory(); // 初始化历史记录
  }

  /// 记录音频开始播放
  Future<void> recordPlayStart(AudioItem audioItem, int progressMs) async {
    final bool isLogin = await AuthService.isSignedIn();

    if (!isLogin) {
      throw Exception('User not login');
    }

    try {
      // 存储到数据库
      final response = await UserHistoryService.submitPlayProgress(
        audioId: audioItem.id,
        playDurationMs: 0,
        playProgressMs: progressMs,
      );

      if (response.isNotEmpty) {
        _historyCache = response;
      }

      // 启动进度追踪
      _startProgressTracking(audioItem.id);

      print('记录播放开始: ${audioItem.title}');
    } catch (e) {
      print('记录播放开始失败: $e');
    }
  }

  /// 记录音频停止播放
  Future<void> recordPlayStop(
    String audioId,
    int playProgressMs,
    int playDurationMs,
  ) async {
    final bool isLogin = await AuthService.isSignedIn();

    if (!isLogin) {
      throw Exception('User not login');
    }

    try {
      // 停止进度追踪
      _stopProgressTracking();

      // 更新数据库中的播放进度
      await UserHistoryService.submitPlayProgress(
        audioId: audioId,
        playDurationMs: playDurationMs,
        playProgressMs: playProgressMs,
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
    final isLogin = await AuthService.isSignedIn();

    if (!isLogin) {
      throw Exception('User not login');
    }

    try {
      final now = DateTime.now();

      // 检查是否需要更新（距离上次更新是否超过间隔时间）
      if (!forceUpdate && _lastProgressUpdate != null) {
        final timeSinceLastUpdate = now
            .difference(_lastProgressUpdate!)
            .inSeconds;
        if (timeSinceLastUpdate < progressUpdateIntervalS) {
          return; // 还没到更新间隔
        }
      }

      // 更新数据库中的进度
      await UserHistoryService.submitPlayProgress(
        audioId: audioId,
        playDurationMs: 0,
        playProgressMs: currentPosition.inMilliseconds,
      );

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
      Duration(seconds: progressUpdateIntervalS),
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

    print('开始追踪音频播放进度: $audioId，每${progressUpdateIntervalS}秒更新一次');
  }

  /// 停止进度追踪
  void _stopProgressTracking() {
    // 在停止追踪前，记录一次当前进度（如果外部提供了的话）
    if (_currentTrackingAudioId != null) {
      print('停止追踪音频播放进度: $_currentTrackingAudioId');
    }

    // 安全地取消定时器
    if (_progressUpdateTimer != null) {
      _progressUpdateTimer!.cancel();
      _progressUpdateTimer = null;
    }
    _currentTrackingAudioId = null;
  }

  /// 公共方法：停止进度追踪（供外部调用）
  void stopProgressTracking() {
    _stopProgressTracking();
  }

  /// 获取音频的播放历史
  Future<List<AudioItem>> getAudioHistory() async {
    try {
      final response = await UserHistoryService.getUserHistoryList();
      _historyCache = response; // cache
      return response;
    } catch (e) {
      print('获取音频历史失败: $e');
      return [];
    }
  }

  // 先搜索缓存，无缓存时获取历史再搜索
  Future<AudioItem> searchHistory(String audioId) async {
    try {
      if (_historyCache.isNotEmpty) {
        return _historyCache.firstWhere((item) => item.id == audioId);
      } else {
        final history = await getAudioHistory();
        return history.firstWhere((item) => item.id == audioId);
      }
    } catch (e) {
      print('搜索播放历史失败: $e');
      rethrow;
    }
  }

  /// 格式化时长为字符串
  String _formatDuration(Duration duration) {
    final minutes = duration.inMinutes;
    final seconds = duration.inSeconds.remainder(60);
    return '${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
  }

  /// 解析时长字符串为Duration
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

  /// 清理资源
  Future<void> dispose() async {
    // 停止进度追踪
    _stopProgressTracking();
    print('音频历史管理器资源已清理');
  }
}
