import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/audio_item.dart';
import '../services/api/user_history_service.dart';
import '../services/api/user_privilege_service.dart';
import '../models/user_privilege_model.dart';
import 'auth_manager.dart';
import 'api/tracking_service.dart';

// 移除对 AudioManager 的依赖，避免循环依赖
import 'audio_service.dart'; // 需要AudioPlayerState类型定义

/// 音频播放历史管理器
/// 整合本地内存缓存和服务端数据同步，提供统一的历史管理接口
class AudioHistoryManager {
  static final AudioHistoryManager _instance = AudioHistoryManager._internal();
  static AudioHistoryManager get instance => _instance;

  List<AudioItem> _historyCache = []; // 本地内存缓存
  bool _isInitialized = false;
  StreamSubscription<AuthStatusChangeEvent>? _authSubscription;
  StreamSubscription<UserPrivilege?>? _privilegeSubscription;
  SharedPreferences? _prefs; // 本地存储实例

  // ValueNotifier 用于状态变更通知
  final ValueNotifier<List<AudioItem>> _historyNotifier =
      ValueNotifier<List<AudioItem>>([]);

  // 历史记录事件流控制器
  final StreamController<List<AudioItem>> _historyStreamController =
      StreamController<List<AudioItem>>.broadcast();

  // 记录控制标志：是否需要上报历史（由 AudioManager 驱动）
  bool _needRecord = false;

  // 播放记录相关状态
  AudioItem? _currentPlayingAudio;
  bool _isCurrentlyPlaying = false;
  Duration _lastRecordedPosition = Duration.zero;
  DateTime? _lastProgressRecordTime;
  bool _isRecordingProgress = false; // 防止并发记录进度
  DateTime? _lastStateSaveTime; // 上次保存本地状态的时间
  
  // 本地状态缓存，用于差异对比
  AudioPlayerState? _lastAudioState;
  
  // 防止重复请求历史数据的状态标识
  bool _isLoadingHistoryFromServer = false;

  static const int progressUpdateIntervalS = 30; // 30秒更新一次
  static const int stateSaveIntervalS = 10; // 本地状态保存间隔（10秒）
  static const String _historyCacheKey = 'audio_history_cache'; // 本地存储键名
  static const String _currentPlayStateCacheKey = 'current_play_state_cache'; // 当前播放状态缓存键名

  AudioHistoryManager._internal();

  /// 获取历史缓存状态通知器
  ValueNotifier<List<AudioItem>> get historyNotifier => _historyNotifier;

  /// 获取历史记录事件流
  Stream<List<AudioItem>> get historyStream => _historyStreamController.stream;

  /// 透传：预览边界/权限限制事件流
  Stream<PreviewBoundaryEvent> get previewBoundaryEvents =>
      AudioPlayerService.previewBoundaryEvents;

  /// 初始化历史管理器 - 从服务端拉取历史列表并缓存到本地内存
  Future<void> initialize() async {
    if (_isInitialized) return;

    try {
      debugPrint('🎵 [HISTORY] 开始初始化音频历史管理器');

      // 订阅认证状态变化事件
      _subscribeToAuthChanges();
      // 订阅权限变更事件（影响历史数据可见性）
      _subscribeToPrivilegeChanges();

      // 先从本地存储加载缓存（无论是否登录都加载）
      await _loadCachedHistory();

      // 检查用户登录状态
      if (!await AuthManager.instance.isSignedIn()) {
        _clearCacheAfterLogout();
      } else {
        // 刷新服务端数据
        await _reinitializeAfterLogin();
        debugPrint('🎵 [HISTORY] 初始化完成，缓存了 ${_historyCache.length} 条历史记录');
      }
      _isInitialized = true;
    } catch (e) {
      debugPrint('🎵 [HISTORY] 初始化失败: $e');
      _historyCache = [];
      _historyNotifier.value = [];
      _isInitialized = true; // 即使失败也标记为已初始化
    }
  }

  /// 启用历史记录更新（由 AudioManager 驱动回调）
  void startListening({bool needRecord = false}) {
    _needRecord = needRecord;
    debugPrint('🎵 [HISTORY] 启用历史记录更新（由AudioManager驱动），needRecord: $needRecord');
  }

  void stopListening() {
    _needRecord = false;
    _lastAudioState = null; // 清空状态缓存
    debugPrint('🎵 [HISTORY] 停用历史记录更新（由AudioManager驱动）');
  }

  /// 由 AudioManager 在其状态流回调中调用，传入统一的音频状态
  void handleAudioState(AudioPlayerState audioState) {
    // 如果是第一次接收状态或状态发生变化，才进行处理
    if (_lastAudioState == null || _hasStateChanged(_lastAudioState!, audioState)) {
      // 检查当前音频是否变化
      if (_lastAudioState?.currentAudio?.id != audioState.currentAudio?.id) {
        _onCurrentAudioChanged(audioState.currentAudio, needRecord: _needRecord);
      }

      // 检查播放状态是否变化
      if (_lastAudioState?.isPlaying != audioState.isPlaying) {
        _onPlayingStateChanged(audioState.isPlaying, needRecord: _needRecord);
      }

      // 检查播放位置是否变化（避免频繁的位置更新）
      if (_lastAudioState?.position != audioState.position) {
        _onPositionChanged(audioState.position, needRecord: _needRecord);
      }

      // 更新本地状态缓存
      _lastAudioState = audioState;
    }
  }

  // 移除内部订阅逻辑，依赖 AudioManager 回调驱动
  
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
  void _onCurrentAudioChanged(AudioItem? audio, {bool needRecord = false}) {
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
    if (audio != null) {
      if (needRecord) {
        _recordPlayStart(isFirst: true);
      }
      // 无论登录状态如何，都保存当前播放状态到本地缓存
      _saveCurrentPlayState();
    }
  }

  /// 播放状态变化回调
  void _onPlayingStateChanged(bool isPlaying, {bool needRecord = false}) {
    debugPrint('🎵 [HISTORY] 播放状态变化: $isPlaying');

    final wasPlaying = _isCurrentlyPlaying;
    _isCurrentlyPlaying = isPlaying;

    if (_currentPlayingAudio != null) {
      if (isPlaying && !wasPlaying) {
        // 开始播放（从暂停恢复或首次播放）
        if(needRecord) {
          _recordPlayStart();
        }
        // 无论登录状态如何，都保存当前播放状态到本地缓存
        _saveCurrentPlayState();
      } else if (!isPlaying && wasPlaying) {
        // 停止播放
        if (needRecord) {
          _recordPlayStop();
        }
        // 无论登录状态如何，都保存当前播放状态到本地缓存
        _saveCurrentPlayState();
      }
    }
  }

  /// 播放位置变化回调
  void _onPositionChanged(Duration position, {bool needRecord = false}) {
    _lastRecordedPosition = position;

    // 检查是否需要记录进度（基于时间间隔）
    if (_currentPlayingAudio != null && _isCurrentlyPlaying) {
      if (needRecord) {
        _checkAndRecordProgress();
      }
      // 检查是否需要保存本地状态（基于时间间隔）
      _checkAndSaveCurrentPlayState();
    }
  }

  /// 通用的播放进度记录辅助函数
  Future<void> _recordPlayProgressHelper({
    required String logMessage,
    required String errorMessage,
    bool isFirst = false,
    Duration? customProgress,
    Function()? onSuccess,
    Function()? onError,
  }) async {
    if (_currentPlayingAudio == null) return;

    try {
      debugPrint(logMessage);

      // 使用自定义进度或默认的当前位置
      final progressToSubmit = customProgress ?? _lastRecordedPosition;

      // 记录播放进度事件 tracking
      TrackingService.track(actionType: 'audio_play', audioId: _currentPlayingAudio!.id, extraData : {
        'audio_id': _currentPlayingAudio!.id,
        'play_progress_ms': progressToSubmit.inMilliseconds,
        'is_first': isFirst,
      });

      final bool isLogin = await AuthManager.instance.isSignedIn();

      if(isLogin) {
        final updatedHistory = await UserHistoryService.submitPlayProgress(
          audioId: _currentPlayingAudio!.id,
          isFirst: isFirst,
          playDuration: Duration.zero,
          playProgress: progressToSubmit,
        );

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

  /// 检查并保存当前播放状态到本地存储（基于时间间隔）
  void _checkAndSaveCurrentPlayState() {
    final now = DateTime.now();

    // 如果是第一次保存或者距离上次保存超过间隔时间，则保存
    if (_lastStateSaveTime == null || 
        now.difference(_lastStateSaveTime!).inSeconds >= stateSaveIntervalS) {
      _saveCurrentPlayState();
      _lastStateSaveTime = now;
    }
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
    
    // 注意：这里不再调用 _saveCurrentPlayState()，因为在调用此方法的地方已经调用了
    // 避免重复调用
  }

  /// 记录播放停止
  Future<void> _recordPlayStop() async {
    // 检查当前进度是否大于等于总体进度的98%
    Duration progressToSubmit = _lastRecordedPosition;
    
    if (_currentPlayingAudio?.duration != null) {
      final totalDuration = _currentPlayingAudio!.duration!;
      final currentProgress = _lastRecordedPosition;
      
      // 如果当前进度大于等于总时长的99.5%，则将进度重置为0
      if (totalDuration.inMilliseconds > 0 && 
          currentProgress.inMilliseconds >= (totalDuration.inMilliseconds * 0.995)) {
        progressToSubmit = Duration.zero;
        debugPrint('🎵 [HISTORY] 播放进度已达99.5%，重置进度为0: ${_formatDuration(currentProgress)} / ${_formatDuration(totalDuration)}');
      }
    }
    
    await _recordPlayProgressHelper(
      logMessage: '🎵 [HISTORY] 记录播放停止: ${_currentPlayingAudio?.title}  id: ${_currentPlayingAudio?.id}',
      errorMessage: '🎵 [HISTORY] 记录播放停止失败',
      customProgress: progressToSubmit,
      onSuccess: () {
        // 停止播放时清除进度记录时间
        _lastProgressRecordTime = null;
      },
    );
    
    // 注意：这里不再调用 _saveCurrentPlayState()，因为在调用此方法的地方已经调用了
    // 避免重复调用
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

  /// 订阅权限变更事件
  void _subscribeToPrivilegeChanges() {
    _privilegeSubscription?.cancel();
    _privilegeSubscription = UserPrivilegeService.instance.privilegeChanges.listen(
      (privilege) async {
        debugPrint('🎵 [HISTORY] 收到权限变更事件，重新请求历史数据');
        // 仅在登录状态下刷新服务端历史数据
        if (await AuthManager.instance.isSignedIn()) {
          await _reinitializeAfterLogin();
        }
      },
      onError: (error) {
        debugPrint('🎵 [HISTORY] 权限变更事件流错误: $error');
      },
    );
    debugPrint('🎵 [HISTORY] 已订阅权限变更事件');
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
    
    // 注意：不再清空当前播放状态缓存，让它在非登录状态下也能保持
    // _clearCurrentPlayState();
    
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
          _isLoadingHistoryFromServer = false;
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
      'isListening': _needRecord,
      'currentPlayingAudio': _currentPlayingAudio?.toMap(),
      'isCurrentlyPlaying': _isCurrentlyPlaying,
      'lastRecordedPosition': _lastRecordedPosition.inMilliseconds,
      'lastProgressRecordTime': _lastProgressRecordTime?.toIso8601String(),
      'recordingMethod': 'audioManager_callback_based',
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
      _prefs ??= await SharedPreferences.getInstance();
      await _prefs?.setString(_historyCacheKey, historyJson);
      debugPrint('🎵 [HISTORY] 历史记录已保存到本地存储，共${history.length}条');
    } catch (e) {
      debugPrint('🎵 [HISTORY] 保存历史记录到本地存储失败: $e');
    }
  }

  /// 从本地存储加载历史记录
  Future<void> _loadCachedHistory() async {
    try {

      _prefs ??= await SharedPreferences.getInstance();

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

      _prefs ??= await SharedPreferences.getInstance();

      await _prefs?.remove(_historyCacheKey);
      debugPrint('🎵 [HISTORY] 本地存储已清空');
    } catch (e) {
      debugPrint('🎵 [HISTORY] 清空本地存储失败: $e');
    }
  }

  /// 保存当前播放状态到本地存储
  Future<void> _saveCurrentPlayState() async {

    debugPrint('🎵 [HISTORY] 开始保存当前播放状态 到本地存储');

    if (_currentPlayingAudio == null) {
      // 如果没有当前播放音频，清空缓存
      await _clearCurrentPlayState();
      return;
    }

    try {
      final playState = {
        'audioItem': _currentPlayingAudio!.toMap(),
        'position': _lastRecordedPosition.inMilliseconds,
        'isPlaying': _isCurrentlyPlaying,
        'timestamp': DateTime.now().toIso8601String(),
      };
      
      final playStateJson = json.encode(playState);

      _prefs ??= await SharedPreferences.getInstance();
      await _prefs?.setString(_currentPlayStateCacheKey, playStateJson);

      debugPrint('🎵 [HISTORY] 当前播放状态已保存到本地存储: ${_currentPlayingAudio!.title} -> ${_formatDuration(_lastRecordedPosition)}');
    } catch (e) {
      debugPrint('🎵 [HISTORY] 保存当前播放状态到本地存储失败: $e');
    }
  }

  /// 从本地存储加载当前播放状态
  Future<Map<String, dynamic>?> _loadCurrentPlayState() async {
    try {
      _prefs ??= await SharedPreferences.getInstance();
      final playStateJson = _prefs?.getString(_currentPlayStateCacheKey);
      if (playStateJson != null && playStateJson.isNotEmpty) {
        final Map<String, dynamic> playState = json.decode(playStateJson);
        debugPrint('🎵 [HISTORY] 从本地存储加载当前播放状态: ${playState['audioItem']?['title']}');
        return playState;
      } else {
        debugPrint('🎵 [HISTORY] 本地存储当前播放状态为空');
      }
    } catch (e) {
      debugPrint('🎵 [HISTORY] 从本地存储加载当前播放状态失败: $e');
    }
    return null;
  }

  /// 清空当前播放状态缓存
  Future<void> _clearCurrentPlayState() async {
    try {
      _prefs ??= await SharedPreferences.getInstance();
      await _prefs?.remove(_currentPlayStateCacheKey);
      debugPrint('🎵 [HISTORY] 当前播放状态缓存已清空');
    } catch (e) {
      debugPrint('🎵 [HISTORY] 清空当前播放状态缓存失败: $e');
    }
  }

  /// 格式化时长为字符串
  String _formatDuration(Duration duration) {
    final minutes = duration.inMinutes;
    final seconds = duration.inSeconds.remainder(60);
    return '${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
  }

  /// 获取当前播放状态缓存（供外部调用）
  Future<Map<String, dynamic>?> getCurrentPlayStateCache() async {
    return await _loadCurrentPlayState();
  }

  /// 清理资源
  Future<void> dispose() async {
    // 停止历史记录更新
    _needRecord = false;
    _lastAudioState = null;

    // 取消认证状态订阅
    _authSubscription?.cancel();
    _authSubscription = null;
    // 取消权限变更订阅
    _privilegeSubscription?.cancel();
    _privilegeSubscription = null;

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
