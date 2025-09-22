import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/audio_item.dart';
import '../services/api/user_history_service.dart';
import 'auth_manager.dart';
import 'audio_manager.dart';
import 'audio_service.dart'; // 需要AudioPlayerState类型定义

/// 音频播放历史管理器
/// 整合本地内存缓存和服务端数据同步，提供统一的历史管理接口
class AudioHistoryManager {
  static final AudioHistoryManager _instance = AudioHistoryManager._internal();
  static AudioHistoryManager get instance => _instance;

  List<AudioItem> _historyCache = []; // 本地内存缓存
  bool _isInitialized = false;
  StreamSubscription<AuthStatusChangeEvent>? _authSubscription;
  SharedPreferences? _prefs; // 本地存储实例

  // ValueNotifier 用于状态变更通知
  final ValueNotifier<List<AudioItem>> _historyNotifier =
      ValueNotifier<List<AudioItem>>([]);

  // 历史记录事件流控制器
  final StreamController<List<AudioItem>> _historyStreamController =
      StreamController<List<AudioItem>>.broadcast();

  // 音频播放监听相关 - 通过AudioManager订阅
  StreamSubscription<AudioPlayerState>? _audioStateSubscription;

  // 播放记录相关状态
  AudioItem? _currentPlayingAudio;
  bool _isCurrentlyPlaying = false;
  Duration _lastRecordedPosition = Duration.zero;
  DateTime? _lastProgressRecordTime;
  bool _isRecordingProgress = false; // 防止并发记录进度
  
  // 本地状态缓存，用于差异对比
  AudioPlayerState? _lastAudioState;
  
  // 防止重复请求历史数据的状态标识
  bool _isLoadingHistoryFromServer = false;

  static const int progressUpdateIntervalS = 30; // 30秒更新一次
  static const String _historyCacheKey = 'audio_history_cache'; // 本地存储键名

  AudioHistoryManager._internal();

  /// 获取历史缓存状态通知器
  ValueNotifier<List<AudioItem>> get historyNotifier => _historyNotifier;

  /// 获取历史记录事件流
  Stream<List<AudioItem>> get historyStream => _historyStreamController.stream;

  /// 初始化历史管理器 - 从服务端拉取历史列表并缓存到本地内存
  Future<void> initialize() async {
    if (_isInitialized) return;

    try {
      debugPrint('🎵 [HISTORY] 开始初始化音频历史管理器');

      // 初始化本地存储
      _prefs = await SharedPreferences.getInstance();

      // 订阅认证状态变化事件
      _subscribeToAuthChanges();

      // 先从本地存储加载缓存（无论是否登录都加载）
      await _loadCachedHistory();

      // 检查用户登录状态
      final bool isLogin = await AuthManager.instance.isSignedIn();
      if (!isLogin) {
        _clearCacheAfterLogout();
        _isInitialized = true;
        return;
      }

      // 刷新服务端数据
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

  /// 开始监听音频播放状态（通过AudioManager）
  void startListening() {
    _startPlaybackListening();
  }

  /// 开始监听播放状态变化
  void _startPlaybackListening() {
    // 取消之前的监听
    _stopPlaybackListening();

    debugPrint('🎵 [HISTORY] 开始监听音频播放状态变化（通过AudioManager）');

    // 监听AudioManager的统一音频状态流
    _audioStateSubscription = AudioManager.instance.audioStateStream.listen((audioState) {
      // 如果是第一次接收状态或状态发生变化，才进行处理
      if (_lastAudioState == null || _hasStateChanged(_lastAudioState!, audioState)) {
        // 检查当前音频是否变化
        if (_lastAudioState?.currentAudio?.id != audioState.currentAudio?.id) {
          _onCurrentAudioChanged(audioState.currentAudio);
        }
        
        // 检查播放状态是否变化
        if (_lastAudioState?.isPlaying != audioState.isPlaying) {
          _onPlayingStateChanged(audioState.isPlaying);
        }
        
        // 检查播放位置是否变化（避免频繁的位置更新）
        if (_lastAudioState?.position != audioState.position) {
          _onPositionChanged(audioState.position);
        }
        
        // 更新本地状态缓存
        _lastAudioState = audioState;
      }
    });
  }

  /// 停止监听播放状态变化
  void _stopPlaybackListening() {
    _audioStateSubscription?.cancel();
    _audioStateSubscription = null;
    _lastAudioState = null; // 清空状态缓存

    debugPrint('🎵 [HISTORY] 已停止监听音频播放状态变化');
  }
  
  /// 检查音频状态是否发生实质性变化
  bool _hasStateChanged(AudioPlayerState oldState, AudioPlayerState newState) {
    return oldState.currentAudio?.id != newState.currentAudio?.id ||
           oldState.isPlaying != newState.isPlaying ||
           oldState.position != newState.position ||
           oldState.duration != newState.duration ||
           oldState.speed != newState.speed ||
           oldState.playerState.processingState != newState.playerState.processingState ||
           oldState.renderPreviewStart != newState.renderPreviewStart ||
           oldState.renderPreviewEnd != newState.renderPreviewEnd;
  }

  /// 当前播放音频变化回调
  void _onCurrentAudioChanged(AudioItem? audio) {
    debugPrint('🎵 [HISTORY] 当前播放音频变化: ${audio?.id ?? 'null'}');

    // 保存旧的音频ID用于比较
    final oldAudioId = _currentPlayingAudio?.id;
    final newAudioId = audio?.id;
    
    // 音频切换时不记录停止，因为这不是用户主动停止
    // 只有在播放状态变化时才记录停止
    
    _currentPlayingAudio = audio;
    
    // 只有在音频真正变化时才重置位置和时间
    if (oldAudioId != newAudioId) {
      _lastRecordedPosition = Duration.zero;
      _lastProgressRecordTime = null;
    }

    // 记录新音频开始播放（只在正在播放时记录）
    if (audio != null && _isCurrentlyPlaying) {
      _recordPlayStart(isFirst: true);
    }
  }

  /// 播放状态变化回调
  void _onPlayingStateChanged(bool isPlaying) {
    debugPrint('🎵 [HISTORY] 播放状态变化: $isPlaying');

    final wasPlaying = _isCurrentlyPlaying;
    _isCurrentlyPlaying = isPlaying;

    if (_currentPlayingAudio != null) {
      if (isPlaying && !wasPlaying) {
        // 开始播放（从暂停恢复或首次播放）
        _recordPlayStart();
      } else if (!isPlaying && wasPlaying) {
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

  /// 通用的播放进度记录辅助函数
  Future<void> _recordPlayProgressHelper({
    required String logMessage,
    required String errorMessage,
    bool isFirst = false,
    Function()? onSuccess,
    Function()? onError,
  }) async {
    if (_currentPlayingAudio == null) return;

    try {
      debugPrint(logMessage);

      final updatedHistory = await UserHistoryService.submitPlayProgress(
        audioId: _currentPlayingAudio!.id,
        isFirst: isFirst,
        playDuration: Duration.zero,
        playProgress: _lastRecordedPosition,
      );

      final bool isLogin = await AuthManager.instance.isSignedIn();
      if (isLogin) {
        await _updateLocalCache(updatedHistory);
      }
      
      // 执行成功回调
      onSuccess?.call();
    } catch (e) {
      debugPrint('$errorMessage: $e');
      // 执行错误回调
      onError?.call();
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

    await _recordPlayProgressHelper(
      logMessage: '🎵 [HISTORY] 定时记录播放进度(${timeSinceLastRecord}秒): ${_currentPlayingAudio!.title} -> ${_formatDuration(_lastRecordedPosition)}',
      errorMessage: '🎵 [HISTORY] 记录播放进度失败',
      onSuccess: () {
        _lastProgressRecordTime = now;
      },
    );
    
    _isRecordingProgress = false; // 无论成功失败都要重置标志
  }

  /// 记录播放开始
  Future<void> _recordPlayStart({bool isFirst = false}) async {
    await _recordPlayProgressHelper(
      logMessage: '🎵 [HISTORY] 记录播放开始${isFirst ? '(首次)' : '(恢复)'}: ${_currentPlayingAudio?.title}  id: ${_currentPlayingAudio?.id}',
      errorMessage: '🎵 [HISTORY] 记录播放开始失败',
      isFirst: isFirst,
      onSuccess: () {
        // 重置进度记录时间，确保30秒后才开始定时上报
        _lastProgressRecordTime = DateTime.now();
      },
    );
  }

  /// 记录播放停止
  Future<void> _recordPlayStop() async {
    await _recordPlayProgressHelper(
      logMessage: '🎵 [HISTORY] 记录播放停止: ${_currentPlayingAudio?.title}  id: ${_currentPlayingAudio?.id}',
      errorMessage: '🎵 [HISTORY] 记录播放停止失败',
      onSuccess: () {
        // 停止播放时清除进度记录时间
        _lastProgressRecordTime = null;
      },
    );
  }

  

  Future<void> refreshHistory() async {
    final bool isLogin = await AuthManager.instance.isSignedIn();
    if (!isLogin) {
      _clearCacheAfterLogout();
      return;
    }

    await _reinitializeAfterLogin();
  }

  /// 订阅认证状态变化事件
  void _subscribeToAuthChanges() {
    _authSubscription?.cancel(); // 取消之前的订阅

    _authSubscription = AuthManager.instance.authStatusChanges.listen((event) {
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
    // 防止重复请求
    if (_isLoadingHistoryFromServer) {
      debugPrint('🎵 [HISTORY] 正在从服务端加载历史数据，跳过重复请求');
      return;
    }

    try {
      _isLoadingHistoryFromServer = true;
      debugPrint('🎵 [HISTORY] 用户已登录，重新初始化历史数据');

      // 从服务端拉取最新的历史列表
      final historyList = await UserHistoryService.getUserHistoryList();

      // 打印历史列表详细信息
      debugPrint('🎵 [HISTORY] 从服务端拉取到的历史列表数量: ${historyList.length}');

      await _updateLocalCache(historyList);

      debugPrint('🎵 [HISTORY] 登录后重新初始化完成，缓存了 ${_historyCache.length} 条历史记录');
    } catch (e) {
      debugPrint('🎵 [HISTORY] 登录后重新初始化失败: $e');
      // 初始化失败，清空缓存
      _historyCache = [];
      _historyNotifier.value = [];
    } finally {
      _isLoadingHistoryFromServer = false;
    }
  }

  /// 登出后清空缓存并停止追踪
  void _clearCacheAfterLogout() {
    debugPrint('🎵 [HISTORY] 用户已登出，清空历史缓存');

    // 清空内存缓存
    _historyCache.clear();
    _historyNotifier.value = [];
    
    // 清空本地存储
    _clearLocalStorage();
    
    // 推送空历史记录事件
    _historyStreamController.add([]);
  }

  /// 获取音频播放历史（优先从缓存，缓存为空时从服务端拉取）
  Future<List<AudioItem>> getAudioHistory({bool forceRefresh = false}) async {
    try {
      // 如果强制刷新或缓存为空，从服务端拉取
      if (forceRefresh || _historyCache.isEmpty) {
        // 防止重复请求
        if (_isLoadingHistoryFromServer) {
          debugPrint('🎵 [HISTORY] 正在从服务端加载历史数据，等待完成...');
          // 等待当前请求完成，然后返回缓存数据
          while (_isLoadingHistoryFromServer) {
            await Future.delayed(const Duration(milliseconds: 100));
          }
          return _historyCache;
        }

        try {
          _isLoadingHistoryFromServer = true;
          debugPrint('🎵 [HISTORY] 从服务端拉取历史数据');
          final historyList = await UserHistoryService.getUserHistoryList();
          await _updateLocalCache(historyList);
          return _historyCache;
        } finally {
          _isLoadingHistoryFromServer = false;
        }
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
      'isListening': _audioStateSubscription != null,
      'currentPlayingAudio': _currentPlayingAudio?.toMap(),
      'isCurrentlyPlaying': _isCurrentlyPlaying,
      'lastRecordedPosition': _lastRecordedPosition.inMilliseconds,
      'lastProgressRecordTime': _lastProgressRecordTime?.toIso8601String(),
      'recordingMethod': 'audioManager_stream_based',
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

  /// 更新本地内存缓存和本地存储
  Future<void> _updateLocalCache(List<AudioItem> newHistory) async {
    _historyCache = List.from(newHistory);
    
    // 保存到本地存储
    await _saveHistoryToStorage(_historyCache);
    
    // 通知状态变更
    _historyNotifier.value = List.from(_historyCache);
    
    // 推送历史记录变更事件
    _historyStreamController.add(List.from(_historyCache));
    
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

  /// 保存历史记录到本地存储
  Future<void> _saveHistoryToStorage(List<AudioItem> history) async {
    try {
      final historyJson = json.encode(history.map((item) => item.toMap()).toList());
      await _prefs?.setString(_historyCacheKey, historyJson);
      debugPrint('🎵 [HISTORY] 历史记录已保存到本地存储，共${history.length}条');
    } catch (e) {
      debugPrint('🎵 [HISTORY] 保存历史记录到本地存储失败: $e');
    }
  }

  /// 从本地存储加载历史记录
  Future<void> _loadCachedHistory() async {
    try {
      final historyJson = _prefs?.getString(_historyCacheKey);
      if (historyJson != null && historyJson.isNotEmpty) {
        final List<dynamic> historyData = json.decode(historyJson);
        final List<AudioItem> cachedHistory = historyData
            .map((item) => AudioItem.fromMap(item as Map<String, dynamic>))
            .toList();
        
        _historyCache = cachedHistory;
        _historyNotifier.value = List.from(_historyCache);
        
        debugPrint('🎵 [HISTORY] 从本地存储加载历史记录，共${_historyCache.length}条');
      }
    } catch (e) {
      debugPrint('🎵 [HISTORY] 从本地存储加载历史记录失败: $e');
      _historyCache = [];
      _historyNotifier.value = [];
    }
  }

  /// 清空本地存储
  Future<void> _clearLocalStorage() async {
    try {
      await _prefs?.remove(_historyCacheKey);
      debugPrint('🎵 [HISTORY] 本地存储已清空');
    } catch (e) {
      debugPrint('🎵 [HISTORY] 清空本地存储失败: $e');
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
    
    // 关闭历史记录事件流
    await _historyStreamController.close();
    
    _isInitialized = false;

    // 清空播放状态
    _currentPlayingAudio = null;
    _isCurrentlyPlaying = false;

    debugPrint('🎵 [HISTORY] 音频历史管理器资源已清理');
  }
}
