import 'dart:async';
import 'package:flutter/foundation.dart';
import '../models/audio_item.dart';
import '../services/api/user_history_service.dart';
import 'auth_service.dart';
import 'audio_service.dart';

/// 音频播放历史管理器
/// 整合本地内存缓存和服务端数据同步，提供统一的历史管理接口
class AudioHistoryManager {
  static final AudioHistoryManager _instance = AudioHistoryManager._internal();
  static AudioHistoryManager get instance => _instance;

  List<AudioItem> _historyCache = []; // 本地内存缓存
  bool _isInitialized = false;
  StreamSubscription<AuthStatusChangeEvent>? _authSubscription;

  // ValueNotifier 用于状态变更通知
  final ValueNotifier<List<AudioItem>> _historyNotifier =
      ValueNotifier<List<AudioItem>>([]);

  // 音频播放监听相关
  AudioPlayerService? _audioService;
  StreamSubscription<bool>? _playingSubscription;
  StreamSubscription<AudioItem?>? _currentAudioSubscription;
  StreamSubscription<Duration>? _positionSubscription;

  // 播放记录相关状态
  AudioItem? _currentPlayingAudio;
  bool _isCurrentlyPlaying = false;
  Duration _lastRecordedPosition = Duration.zero;
  DateTime? _lastProgressRecordTime;
  bool _isRecordingProgress = false; // 防止并发记录进度

  static const int progressUpdateIntervalS = 30; // 30秒更新一次

  AudioHistoryManager._internal();

  /// 获取历史缓存状态通知器
  ValueNotifier<List<AudioItem>> get historyNotifier => _historyNotifier;

  /// 设置音频播放服务并开始监听
  void setAudioService(AudioPlayerService audioService) {
    _audioService = audioService;
    _startPlaybackListening();
  }

  /// 开始监听播放状态变化
  void _startPlaybackListening() {
    if (_audioService == null) return;

    // 取消之前的监听
    _stopPlaybackListening();

    debugPrint('🎵 [HISTORY] 开始监听音频播放状态变化');

    // 监听当前播放音频变化
    _currentAudioSubscription = _audioService!.currentAudioStream.listen((
      audio,
    ) {
      _onCurrentAudioChanged(audio);
    });

    // 监听播放状态变化
    _playingSubscription = _audioService!.isPlayingStream.listen((isPlaying) {
      _onPlayingStateChanged(isPlaying);
    });

    // 监听播放位置变化
    _positionSubscription = _audioService!.positionStream.listen((position) {
      _onPositionChanged(position);
    });
  }

  /// 停止监听播放状态变化
  void _stopPlaybackListening() {
    _currentAudioSubscription?.cancel();
    _currentAudioSubscription = null;

    _playingSubscription?.cancel();
    _playingSubscription = null;

    _positionSubscription?.cancel();
    _positionSubscription = null;

    debugPrint('🎵 [HISTORY] 已停止监听音频播放状态变化');
  }

  /// 当前播放音频变化回调
  void _onCurrentAudioChanged(AudioItem? audio) {
    debugPrint('🎵 [HISTORY] 当前播放音频变化: ${audio?.id ?? 'null'}');

    _currentPlayingAudio = audio;
    _lastRecordedPosition = Duration.zero;
    _lastProgressRecordTime = null;

    _recordPlayStart(); // 记录首次播放
    
  }

  /// 播放状态变化回调
  void _onPlayingStateChanged(bool isPlaying) {
    debugPrint('🎵 [HISTORY] 播放状态变化: $isPlaying');

    final wasPlaying = _isCurrentlyPlaying;
    _isCurrentlyPlaying = isPlaying;

    if (_currentPlayingAudio != null) {
      if (!isPlaying && wasPlaying) {
        // 停止播放
        _recordPlayStop();
      }
    }
  }

  /// 播放位置变化回调
  void _onPositionChanged(Duration position) {
  _lastRecordedPosition = position;

    // 检查是否需要记录进度（基于时间间隔）
    if (_currentPlayingAudio != null && _isCurrentlyPlaying) {
      _checkAndRecordProgress();
    }
  }

  /// 检查并记录播放进度（基于时间间隔）
  Future<void> _checkAndRecordProgress() async {
    // 防止并发执行
    if (_isRecordingProgress) {
      return;
    }

    final now = DateTime.now();

    // 必须有上次记录时间才能进行间隔检查
    if (_lastProgressRecordTime == null) {
      return; // 没有基准时间，不进行定时上报
    }

    // 检查是否需要记录（距离上次记录是否超过间隔时间）
    final timeSinceLastRecord = now
        .difference(_lastProgressRecordTime!)
        .inSeconds;
    if (timeSinceLastRecord < progressUpdateIntervalS) {
      return; // 还没到记录间隔
    }

    _isRecordingProgress = true; // 设置标志，防止并发

    try {
      final bool isLogin = await AuthService.isSignedIn();
      if (!isLogin) return;

      debugPrint(
        '🎵 [HISTORY] 定时记录播放进度(${timeSinceLastRecord}秒): ${_currentPlayingAudio!.title} -> ${_formatDuration(_lastRecordedPosition)}',
      );

      final updatedHistory = await UserHistoryService.submitPlayProgress(
        audioId: _currentPlayingAudio!.id,
        playDuration: Duration.zero,
        playProgress: _lastRecordedPosition,
      );

      _updateLocalCache(updatedHistory);
      _lastProgressRecordTime = now;
    } catch (e) {
      debugPrint('🎵 [HISTORY] 记录播放进度失败: $e');
    } finally {
      _isRecordingProgress = false; // 无论成功失败都要重置标志
    }
  }

  /// 记录首次播放开始
  Future<void> _recordPlayStart() async {
    if (_currentPlayingAudio == null) return;

    try {
      final bool isLogin = await AuthService.isSignedIn();
      if (!isLogin) return;

      debugPrint('🎵 [HISTORY] 记录播放开始: ${_currentPlayingAudio!.title}  id: ${_currentPlayingAudio!.id}');

      final updatedHistory = await UserHistoryService.submitPlayProgress(
        audioId: _currentPlayingAudio!.id,
        isFirst: true,    // 首次播放
        playDuration: Duration.zero,
        playProgress: _lastRecordedPosition,
      );

      _updateLocalCache(updatedHistory);
      // 重置进度记录时间，确保30秒后才开始定时上报
      _lastProgressRecordTime = DateTime.now();
    } catch (e) {
      debugPrint('🎵 [HISTORY] 记录播放开始失败: $e');
    }
  }

  /// 记录播放停止
  Future<void> _recordPlayStop() async {
    if (_currentPlayingAudio == null) return;

    try {
      final bool isLogin = await AuthService.isSignedIn();
      if (!isLogin) return;

      debugPrint('🎵 [HISTORY] 记录播放停止: ${_currentPlayingAudio!.title}');

      final updatedHistory = await UserHistoryService.submitPlayProgress(
        audioId: _currentPlayingAudio!.id,
        playDuration: Duration.zero, // 这里可以计算实际播放时长
        playProgress: _lastRecordedPosition,
      );

      _updateLocalCache(updatedHistory);
      // 停止播放时清除进度记录时间
      _lastProgressRecordTime = null;
    } catch (e) {
      debugPrint('🎵 [HISTORY] 记录播放停止失败: $e');
    }
  }

  /// 初始化历史管理器 - 从服务端拉取历史列表并缓存到本地内存
  Future<void> initialize() async {
    if (_isInitialized) return;

    try {
      debugPrint('🎵 [HISTORY] 开始初始化音频历史管理器');

      // 订阅认证状态变化事件
      _subscribeToAuthChanges();

      // 检查用户登录状态
      final bool isLogin = await AuthService.isSignedIn();
      if (!isLogin) {
        _clearCacheAfterLogout();
        return;
      }

      await _reinitializeAfterLogin();
      _isInitialized = true;

      debugPrint('🎵 [HISTORY] 初始化完成，缓存了 ${_historyCache.length} 条历史记录');
    } catch (e) {
      debugPrint('🎵 [HISTORY] 初始化失败: $e');
      _historyCache = [];
      _historyNotifier.value = [];
      _isInitialized = true; // 即使失败也标记为已初始化
    }
  }

  Future<void> refreshHistory() async {
    final bool isLogin = await AuthService.isSignedIn();
    if (!isLogin) {
      _clearCacheAfterLogout();
      return;
    }

    await _reinitializeAfterLogin();
  }

  /// 订阅认证状态变化事件
  void _subscribeToAuthChanges() {
    _authSubscription?.cancel(); // 取消之前的订阅

    _authSubscription = AuthService.authStatusChanges.listen((event) {
      debugPrint('🎵 [HISTORY] 收到认证状态变化事件: ${event.status}');

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

    debugPrint('🎵 [HISTORY] 已订阅认证状态变化事件');
  }

  /// 登录后重新初始化
  Future<void> _reinitializeAfterLogin() async {
    try {
      debugPrint('🎵 [HISTORY] 用户已登录，重新初始化历史数据');

      // 从服务端拉取最新的历史列表
      final historyList = await UserHistoryService.getUserHistoryList();
      _updateLocalCache(historyList);

      debugPrint('🎵 [HISTORY] 登录后重新初始化完成，缓存了 ${_historyCache.length} 条历史记录');
    } catch (e) {
      debugPrint('🎵 [HISTORY] 登录后重新初始化失败: $e');
      // 初始化失败，清空缓存
      _historyCache = [];
      _historyNotifier.value = [];
    }
  }

  /// 登出后清空缓存并停止追踪
  void _clearCacheAfterLogout() {
    debugPrint('🎵 [HISTORY] 用户已登出，清空历史缓存并停止进度追踪');

    // 清空缓存
    _historyCache.clear();
    _historyNotifier.value = [];
  }

  /// 获取音频播放历史（优先从缓存，缓存为空时从服务端拉取）
  Future<List<AudioItem>> getAudioHistory({bool forceRefresh = false}) async {
    try {
      // 如果强制刷新或缓存为空，从服务端拉取
      if (forceRefresh || _historyCache.isEmpty) {
        debugPrint('🎵 [HISTORY] 从服务端拉取历史数据');
        final historyList = await UserHistoryService.getUserHistoryList();
        _updateLocalCache(historyList);
        return _historyCache;
      }

      // 返回缓存数据
      debugPrint('🎵 [HISTORY] 返回缓存历史数据: ${_historyCache.length} 条');
      return _historyCache;
    } catch (e) {
      debugPrint('🎵 [HISTORY] 获取音频历史失败: $e');
      return _historyCache; // 返回缓存数据作为降级方案
    }
  }

  /// 获取当前播放记录状态
  Map<String, dynamic> getPlaybackRecordStatus() {
    return {
      'isListening': _audioService != null,
      'currentPlayingAudio': _currentPlayingAudio?.toMap(),
      'isCurrentlyPlaying': _isCurrentlyPlaying,
      'lastRecordedPosition': _lastRecordedPosition.inMilliseconds,
      'lastProgressRecordTime': _lastProgressRecordTime?.toIso8601String(),
      'recordingMethod': 'position_stream_based',
    };
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
        debugPrint('🎵 [HISTORY] 在历史记录中未找到音频: $audioId');
        return null;
      }
    } catch (e) {
      debugPrint('🎵 [HISTORY] 搜索播放历史失败: $e');
      return null;
    }
  }

  /// 更新本地内存缓存
  void _updateLocalCache(List<AudioItem> newHistory) {
    _historyCache = List.from(newHistory);
    // 通知状态变更
    _historyNotifier.value = List.from(_historyCache);
    debugPrint('🎵 [HISTORY] 本地缓存已更新: ${_historyCache.length} 条记录');
  }

  /// 获取音频的初始播放位置
  /// 根据历史记录中的播放进度确定初始位置
  Duration getPlaybackPosition(String audioId) {
    try {
      // 在历史缓存中查找对应的音频
      final historyAudio = _historyCache.firstWhere(
        (item) => item.id == audioId,
        orElse: () => throw StateError('Audio not found'),
      );
      
      // 获取播放进度和总时长
      final playProgress = historyAudio.playProgress;
      final duration = historyAudio.duration;
      
      // 如果没有播放进度或总时长，返回零位置
      if (playProgress == null || duration == null) {
        return Duration.zero;
      }
      
      // 如果播放进度大于等于总时长，说明已播放完毕，从头开始
      if (playProgress >= duration) {
        return Duration.zero;
      }
      
      // 返回历史播放进度
      return playProgress;
    } catch (e) {
      // 历史记录中没有找到该音频，返回零位置
      return Duration.zero;
    }
  }

  /// 格式化时长为字符串
  String _formatDuration(Duration duration) {
    final minutes = duration.inMinutes;
    final seconds = duration.inSeconds.remainder(60);
    return '${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
  }

  /// 清理资源
  Future<void> dispose() async {
    // 停止播放监听
    _stopPlaybackListening();

    // 取消认证状态订阅
    _authSubscription?.cancel();
    _authSubscription = null;

    // 清空缓存和通知器
    _historyCache.clear();
    _historyNotifier.value = [];
    _historyNotifier.dispose();
    _isInitialized = false;

    // 清空播放状态
    _currentPlayingAudio = null;
    _isCurrentlyPlaying = false;
    _audioService = null;

    debugPrint('🎵 [HISTORY] 音频历史管理器资源已清理');
  }
}
