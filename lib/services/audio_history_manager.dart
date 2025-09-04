import 'dart:async';
import '../models/audio_item.dart';
import '../services/api/user_history_service.dart';
import 'auth_service.dart';

/// 音频播放历史管理器
/// 整合本地内存缓存和服务端数据同步，提供统一的历史管理接口
class AudioHistoryManager {
  static final AudioHistoryManager _instance = AudioHistoryManager._internal();
  static AudioHistoryManager get instance => _instance;

  Timer? _progressUpdateTimer;
  DateTime? _lastProgressUpdate;
  String? _currentTrackingAudioId;
  Duration? _currentPlayPosition;
  List<AudioItem> _historyCache = []; // 本地内存缓存
  bool _isInitialized = false;
  StreamSubscription<AuthStatusChangeEvent>? _authSubscription;

  static const int progressUpdateIntervalS = 30; // 30秒更新一次

  AudioHistoryManager._internal();

  /// 初始化历史管理器 - 从服务端拉取历史列表并缓存到本地内存
  Future<void> initialize() async {
    if (_isInitialized) return;

    try {
      print('🎵 [HISTORY] 开始初始化音频历史管理器');

      // 订阅认证状态变化事件
      _subscribeToAuthChanges();

      // 检查用户登录状态
      final bool isLogin = await AuthService.isSignedIn();
      if (!isLogin) {
        print('🎵 [HISTORY] 用户未登录，跳过历史数据初始化');
        _historyCache = [];
        _isInitialized = true;
        return;
      }

      // 从服务端拉取历史列表
      final historyList = await UserHistoryService.getUserHistoryList();

      // 缓存到本地内存
      _historyCache = historyList;
      _isInitialized = true;

      print('🎵 [HISTORY] 初始化完成，缓存了 ${_historyCache.length} 条历史记录');
    } catch (e) {
      print('🎵 [HISTORY] 初始化失败: $e');
      _historyCache = [];
      _isInitialized = true; // 即使失败也标记为已初始化
    }
  }

  /// 订阅认证状态变化事件
  void _subscribeToAuthChanges() {
    _authSubscription?.cancel(); // 取消之前的订阅

    _authSubscription = AuthService.authStatusChanges.listen((event) {
      print('🎵 [HISTORY] 收到认证状态变化事件: ${event.status}');

      switch (event.status) {
        case AuthStatus.authenticated:
          // 用户登录，重新初始化历史数据
          _reinitializeAfterLogin();
          break;
        case AuthStatus.unauthenticated:
          // 用户登出，清空缓存并停止追踪
          _clearCacheAfterLogout();
          break;
        case AuthStatus.unknown:
          // 状态未知，暂不处理
          break;
      }
    });

    print('🎵 [HISTORY] 已订阅认证状态变化事件');
  }

  /// 登录后重新初始化
  Future<void> _reinitializeAfterLogin() async {
    try {
      print('🎵 [HISTORY] 用户已登录，重新初始化历史数据');

      // 从服务端拉取最新的历史列表
      final historyList = await UserHistoryService.getUserHistoryList();
      _updateLocalCache(historyList);

      print('🎵 [HISTORY] 登录后重新初始化完成，缓存了 ${_historyCache.length} 条历史记录');
    } catch (e) {
      print('🎵 [HISTORY] 登录后重新初始化失败: $e');
      // 初始化失败，清空缓存
      _historyCache = [];
    }
  }

  /// 登出后清空缓存并停止追踪
  void _clearCacheAfterLogout() {
    print('🎵 [HISTORY] 用户已登出，清空历史缓存并停止进度追踪');

    // 停止当前的进度追踪
    _stopProgressTracking();

    // 清空缓存
    _historyCache.clear();
  }

  /// 记录音频开始播放
  Future<void> recordPlayStart(AudioItem audioItem, int progressMs) async {
    final bool isLogin = await AuthService.isSignedIn();

    if (!isLogin) {
      throw Exception('User not login');
    }

    try {
      print('🎵 [HISTORY] 记录播放开始: ${audioItem.title}');

      // 提交播放开始到服务端
      final updatedHistory = await UserHistoryService.submitPlayProgress(
        audioId: audioItem.id,
        playDurationMs: 0,
        playProgressMs: progressMs,
      );

      // 更新本地内存缓存
      _updateLocalCache(updatedHistory);

      // 启动定时轮询更新进度
      _startProgressTracking(audioItem.id, Duration(milliseconds: progressMs));

      print('🎵 [HISTORY] 播放开始记录成功，已启动进度追踪');
    } catch (e) {
      print('🎵 [HISTORY] 记录播放开始失败: $e');
      rethrow;
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
      print(
        '🎵 [HISTORY] 记录播放停止: $audioId, 进度: ${playProgressMs}ms, 时长: ${playDurationMs}ms',
      );

      // 停止定时轮询
      _stopProgressTracking();

      // 提交最终播放进度到服务端
      final updatedHistory = await UserHistoryService.submitPlayProgress(
        audioId: audioId,
        playDurationMs: playDurationMs,
        playProgressMs: playProgressMs,
      );

      // 更新本地内存缓存
      _updateLocalCache(updatedHistory);

      print('🎵 [HISTORY] 播放停止记录成功');
    } catch (e) {
      print('🎵 [HISTORY] 记录播放停止失败: $e');
      rethrow;
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

      print(
        '🎵 [HISTORY] 更新播放进度: $audioId -> ${_formatDuration(currentPosition)}',
      );

      // 提交进度到服务端
      final updatedHistory = await UserHistoryService.submitPlayProgress(
        audioId: audioId,
        playDurationMs: 0,
        playProgressMs: currentPosition.inMilliseconds,
      );

      // 更新本地内存缓存
      _updateLocalCache(updatedHistory);

      _lastProgressUpdate = now;
      _currentPlayPosition = currentPosition;

      if (forceUpdate) {
        print('🎵 [HISTORY] 强制更新播放进度完成');
      }
    } catch (e) {
      print('🎵 [HISTORY] 更新播放进度失败: $e');
      rethrow;
    }
  }

  /// 启动定时轮询更新进度
  void _startProgressTracking(String audioId, Duration initialPosition) {
    // 如果已经在追踪同一个音频，不需要重新启动
    if (_currentTrackingAudioId == audioId && _progressUpdateTimer != null) {
      return;
    }

    // 停止之前的追踪
    _stopProgressTracking();

    // 记录当前追踪的音频ID和初始位置
    _currentTrackingAudioId = audioId;
    _currentPlayPosition = initialPosition;

    print('🎵 [HISTORY] 开始追踪音频播放进度: $audioId，每${progressUpdateIntervalS}秒更新一次');

    // 启动定时器，定期更新进度
    _progressUpdateTimer = Timer.periodic(
      Duration(seconds: progressUpdateIntervalS),
      (timer) async {
        if (_currentTrackingAudioId == audioId &&
            _currentPlayPosition != null) {
          try {
            // 这里可以通过AudioManager获取实时播放位置
            // 暂时使用缓存的位置，外部需要调用updateCurrentPosition来更新
            await updateProgress(
              audioId,
              _currentPlayPosition!,
              forceUpdate: false,
            );
          } catch (e) {
            print('🎵 [HISTORY] 定时器更新进度失败: $e');
          }
        }
      },
    );
  }

  /// 停止定时轮询
  void _stopProgressTracking() {
    if (_currentTrackingAudioId != null) {
      print('🎵 [HISTORY] 停止追踪音频播放进度: $_currentTrackingAudioId');
    }

    // 安全地取消定时器
    if (_progressUpdateTimer != null) {
      _progressUpdateTimer!.cancel();
      _progressUpdateTimer = null;
    }

    _currentTrackingAudioId = null;
    _currentPlayPosition = null;
    _lastProgressUpdate = null;
  }

  /// 公共方法：停止进度追踪（供外部调用）
  void stopProgressTracking() {
    _stopProgressTracking();
  }

  /// 更新当前播放位置（供外部AudioManager调用）
  void updateCurrentPosition(Duration position) {
    if (_currentTrackingAudioId != null) {
      _currentPlayPosition = position;
    }
  }

  /// 获取音频播放历史（优先从缓存，缓存为空时从服务端拉取）
  Future<List<AudioItem>> getAudioHistory({bool forceRefresh = false}) async {
    try {
      // 如果强制刷新或缓存为空，从服务端拉取
      if (forceRefresh || _historyCache.isEmpty) {
        print('🎵 [HISTORY] 从服务端拉取历史数据');
        final historyList = await UserHistoryService.getUserHistoryList();
        _updateLocalCache(historyList);
        return _historyCache;
      }

      // 返回缓存数据
      print('🎵 [HISTORY] 返回缓存历史数据: ${_historyCache.length} 条');
      return _historyCache;
    } catch (e) {
      print('🎵 [HISTORY] 获取音频历史失败: $e');
      return _historyCache; // 返回缓存数据作为降级方案
    }
  }

  /// 刷新历史数据
  Future<List<AudioItem>> refreshHistory() async {
    return await getAudioHistory(forceRefresh: true);
  }

  /// 搜索历史记录中的音频
  Future<AudioItem?> searchHistory(String audioId) async {
    try {
      // 先在缓存中查找
      if (_historyCache.isNotEmpty) {
        try {
          return _historyCache.firstWhere((item) => item.id == audioId);
        } catch (e) {
          // 缓存中没找到
        }
      }

      // 缓存中没找到，尝试刷新缓存后再查找
      await getAudioHistory(forceRefresh: true);
      try {
        return _historyCache.firstWhere((item) => item.id == audioId);
      } catch (e) {
        print('🎵 [HISTORY] 在历史记录中未找到音频: $audioId');
        return null;
      }
    } catch (e) {
      print('🎵 [HISTORY] 搜索播放历史失败: $e');
      return null;
    }
  }

  /// 获取缓存的历史记录（不触发网络请求）
  List<AudioItem> getCachedHistory() {
    return List.from(_historyCache);
  }

  /// 更新本地内存缓存
  void _updateLocalCache(List<AudioItem> newHistory) {
    _historyCache = List.from(newHistory);
    print('🎵 [HISTORY] 本地缓存已更新: ${_historyCache.length} 条记录');
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

  /// 获取当前追踪状态信息
  Map<String, dynamic> getTrackingStatus() {
    return {
      'isTracking': _progressUpdateTimer != null,
      'currentAudioId': _currentTrackingAudioId,
      'currentPosition': _currentPlayPosition?.inMilliseconds,
      'lastUpdate': _lastProgressUpdate?.toIso8601String(),
      'cacheSize': _historyCache.length,
      'isInitialized': _isInitialized,
    };
  }

  /// 清理资源
  Future<void> dispose() async {
    // 取消认证状态订阅
    _authSubscription?.cancel();
    _authSubscription = null;

    // 停止进度追踪
    _stopProgressTracking();

    // 清空缓存
    _historyCache.clear();
    _isInitialized = false;

    print('🎵 [HISTORY] 音频历史管理器资源已清理');
  }
}
