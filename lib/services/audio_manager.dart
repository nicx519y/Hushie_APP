import 'dart:async';
import 'package:hushie_app/services/auth_manager.dart';
import 'package:rxdart/rxdart.dart';
import 'package:audio_service/audio_service.dart';
import 'package:just_audio/just_audio.dart';
import '../models/audio_item.dart';
import '../models/audio_duration_info.dart';
import 'audio_service.dart';
import 'audio_playlist.dart';
import 'audio_history_manager.dart';
import 'api/audio_list_service.dart';
import 'subscribe_privilege_manager.dart';
import 'package:flutter/foundation.dart';
import 'audio_likes_manager.dart';

/// 预览区间即将超出事件
class PreviewOutEvent {
  final Duration position;
  final DateTime timestamp;

  PreviewOutEvent({required this.position, DateTime? timestamp})
      : timestamp = timestamp ?? DateTime.now();

  @override
  String toString() {
    return 'PreviewOutEvent(position: $position, timestamp: $timestamp)';
  }
}

class AudioManager {
  static final AudioManager _instance = AudioManager._internal();
  static AudioManager get instance => _instance;

  AudioPlayerService? _audioService;
  bool _isInitializing = false;
  bool _isInitialized = false;
  final BehaviorSubject<PlayerState> _playerStateSubject =
      BehaviorSubject<PlayerState>.seeded(
        PlayerState(false, ProcessingState.idle),
      );

  // preloadAudio 流，用于推送预加载的音频信息
  final BehaviorSubject<AudioItem?> _preloadAudioSubject =
      BehaviorSubject<AudioItem?>.seeded(null);

  // 缓存本地状态，用于比对变化
  String? _lastAudioId;
  bool _lastIsPlaying = false;
  Duration _lastPosition = Duration.zero;
  bool _isPreviewMode = false;

  // 播放列表管理状态标志位
  bool _isManagingPlaylist = false;
  String? _lastManagedAudioId;

  // 预览区间即将超出事件流
  static final StreamController<PreviewOutEvent> _previewOutController =
      StreamController<PreviewOutEvent>.broadcast();

  // 权益状态监听
  StreamSubscription<PrivilegeChangeEvent>? _privilegeSubscription;
  
  // 认证状态监听
  StreamSubscription<AuthStatusChangeEvent>? _authStatusSubscription;

  /// 预览区间即将超出事件流（供外部订阅）
  static Stream<PreviewOutEvent> get previewOutEvents =>
      _previewOutController.stream;

  AudioManager._internal();

  // 初始化音频服务（延迟初始化）
  Future<void> _ensureInitialized() async {
    // 如果已经初始化完成，直接返回
    if (_isInitialized && _audioService != null) {
      return;
    }

    // 如果正在初始化，等待初始化完成
    if (_isInitializing) {
      debugPrint('AudioService is initializing, waiting...');
      while (_isInitializing) {
        await Future.delayed(const Duration(milliseconds: 50));
      }
      return;
    }

    _isInitializing = true;
    debugPrint('Initializing AudioService...');
    try {
      _audioService = await AudioService.init(
        builder: () => AudioPlayerService(),
        config: const AudioServiceConfig(
          androidNotificationChannelId: 'com.hushie.audio',
          androidNotificationChannelName: 'Hushie.AI',
          androidNotificationOngoing: true,
          androidStopForegroundOnPause: true,
          androidNotificationIcon: 'drawable/ic_notification_stat',
          preloadArtwork: true,
        ),
      );

      debugPrint('AudioService initialized successfully');
      // 初始化成功后，设置流监听
      _setupStreamListeners();
      _isInitialized = true;
    } catch (e) {
      debugPrint('AudioService初始化失败: $e');
      _audioService = null;
      _isInitialized = false;
    } finally {
      _isInitializing = false;
    }
  }

  Future<void> preloadLastPlayedAudio() async {
    await _ensureInitialized();
    await reloadCurrentPlayStateCache();
  }

  // 兼容性方法：保持原有的init接口，但改为延迟初始化
  Future<void> init() async {
    debugPrint('AudioManager.init() called');
    
    // 先初始化音频历史管理器（确保数据库可用）
    await AudioHistoryManager.instance.initialize();
    debugPrint('AudioManager: AudioHistoryManager 初始化完成');

    await AudioLikesManager.instance.initialize();
    debugPrint('AudioManager: AudioLikesManager 初始化完成');

    // 初始化AudioPlaylist
    await AudioPlaylist.instance.initialize();
    debugPrint('AudioManager: AudioPlaylist 初始化完成');

    // 获取当前权益状态并设置播放权限
    await _initializePrivilegeStatus();

    // 监听权益变化事件
    _setupPrivilegeListener();

    // 监听认证状态变化事件
    _setupAuthStatusListener();

    // 使用统一的初始化方法，避免重复初始化
    await _ensureInitialized();
    debugPrint('AudioManager: AudioService 初始化完成');

    // 开启播放历史记录监听（通过AudioManager的状态流）
    try {
      if(await AuthManager.instance.isSignedIn()) {
        signedInit();
      } else {
        signedOutInit();
      }
    } catch (e) {
      signedOutInit();
    }

    // 不在这里强制初始化AudioService，而是标记为可以初始化
    // 实际初始化将在第一次使用时进行
    return;
  }

  // 设置流监听
  void _setupStreamListeners() {
    if (_audioService == null) {
      debugPrint('Cannot setup stream listeners: _audioService is null');
      return;
    }

    debugPrint('Setting up AudioManager stream listeners...');
    // 监听统一的音频状态流
    _audioService!.audioStateStream.listen((audioState) async {
      // debugPrint('[checkWillOutPreview] AudioManager received audioState: isPlaying=${audioState.isPlaying}');
      
      final audio = audioState.currentAudio;
      final currentAudioId = audio?.id;
      final isPlaying = audioState.isPlaying;
      final position = audioState.position;
      
      // 检查音频是否发生变化
      bool audioChanged = _lastAudioId != currentAudioId;
      bool playingStateChanged = _lastIsPlaying != isPlaying;
      bool positionChanged = (_lastPosition - position).abs() > const Duration(milliseconds: 200);
      // bool positionChanged = _lastPosition != position;
      // debugPrint('[checkWillOutPreview] positionChanged: $positionChanged; _lastPosition: $_lastPosition; position: $position');
      // 管理播放列表 - 只在音频ID发生变化时执行
      if (audioChanged && audio != null) {
        debugPrint('Audio changed from ${_lastAudioId} to ${currentAudioId}');
        final isInPlaylist =
            AudioPlaylist.instance.getAudioItemById(audio.id) != null;

        if (!isInPlaylist) {
          AudioPlaylist.instance.addAudio(audio);
        }

        try {
          await _managePlaylist( audio.id ); // 管理播放列表，将当前音频添加到播放列表，如果当前音频是播放列表最后一条，则继续补充下面的播放列表
        } catch (e) {
          debugPrint('管理播放列表失败: $e');
        }
      }

      // 检查播放是否完成并自动播放下一首
      if(positionChanged && audioState.playerState.playing && position >= audioState.duration * 0.98) {
        _checkPlaybackCompletion();
      }
      // debugPrint('[checkWillOutPreview] 播放列表管理完成');
      
      // 检查预览区间 - 只在位置发生明显变化时检查
      if (positionChanged && _checkWillOutPreview(position)) {
        // 发送预览区间即将超出事件
        
        // 在暂停之前，跳转到预览区域中离当前位置最近的点
        final nearestPosition = _transformPosition(position);
        debugPrint('[AudioManager] 超出预览区间，从 $position 跳转到最近位置 $nearestPosition');
        await seek(nearestPosition);
        
        pause();
        _previewOutController.add(PreviewOutEvent(position: position));
      }
      
      // 更新播放器状态 - 只在状态发生变化时更新
      if (playingStateChanged || audioChanged) {
        _playerStateSubject.add(audioState.playerState);
        
      }
      
      // 监听 preloadAudio 变化并推送到流
      final preloadAudio = audioState.preloadAudio;
      if (_preloadAudioSubject.value != preloadAudio) {
        _preloadAudioSubject.add(preloadAudio);
        debugPrint('PreloadAudio 状态更新: ${preloadAudio?.title ?? 'null'}');
      }
      
      // 更新缓存的状态
      _lastAudioId = currentAudioId;
      _lastIsPlaying = isPlaying;
      if(positionChanged) {
        _lastPosition = position;
      }
    });
  }

  // 检查是否超出预览区间
  bool _checkWillOutPreview(Duration position) {
    if (currentAudio == null ||
        !isPlaying ||
        !_isPreviewMode) {
      return false;
    }

    final previewStart = currentAudio!.previewStart ?? Duration.zero;
    final previewDuration = currentAudio!.previewDuration ?? Duration.zero;
    final hasPreview =
        previewStart >= Duration.zero && previewDuration > Duration.zero;

    // debugPrint('[checkWillOutPreview] position: $position previewStart: $previewStart previewDuration: $previewDuration, hasPreview: $hasPreview');    

    if (hasPreview && (position >= previewStart + previewDuration || position < previewStart)) {
      debugPrint('[playAudio] position: $position previewStart: $previewStart previewDuration: $previewDuration');
      return true;
    }
    return false;
  }

  Duration _transformPosition(Duration position, {AudioItem? audio}) {
    // 如果能播放全部时长，直接返回原位置
    if (!_isPreviewMode) {
      return position;
    }

    late AudioItem currentAudio;

    if(audio != null) {
      currentAudio = audio;
    } else if(this.currentAudio != null) {
      currentAudio = this.currentAudio!;
    } else {
      return position;
    }

    final previewStart = currentAudio.previewStart;
    final previewDuration = currentAudio.previewDuration;

    // 检查预览参数是否有效
    if (previewStart == null ||
        previewStart < Duration.zero ||
        previewDuration == null ||
        previewDuration <= Duration.zero) {
      return position;
    }

    // 计算预览区间的结束位置
    final previewEnd = previewStart + previewDuration;

    // 如果位置在预览区间内，直接返回
    if (position >= previewStart && position <= previewEnd) {
      return position;
    }

    // 如果位置在预览区间外，返回最近的边界位置
    if (position < previewStart) {
      // 位置在预览开始之前，返回预览开始位置
      return previewStart;
    } else {
      // 位置在预览结束之后，返回预览结束位置
      return previewEnd;
    }
  }

  /// 检查播放是否完成并自动播放下一首
  void _checkPlaybackCompletion() {
    final canAutoPlayNext = !_isPreviewMode;
    final currentAudio = this.currentAudio;
    if (currentAudio != null) {
      if (canAutoPlayNext) {
        _playNextAudio(currentAudio.id);
      } else {
        pause();
      }
    }
  }

  /// 播放下一首音频
  Future<void> _playNextAudio(String currentAudioId) async {
    try {
      final playlist = AudioPlaylist.instance;

      final nextAudio = playlist.getNextAudio(currentAudioId);

      if (nextAudio != null) {
        final nextAudioItem = playlist.getAudioItemById(nextAudio.id);
        if (nextAudioItem != null) {
          debugPrint('自动播放下一首: ${nextAudio.title}');
          await playAudio(nextAudioItem);
        }
      } else {
        debugPrint('没有找到下一首音频');
      }
    } catch (e) {
      debugPrint('自动播放下一首失败: $e');
    }
  }

  

  // 重新加载当前播放状态缓存
  Future<void> reloadCurrentPlayStateCache() async {
    debugPrint('[AudioManager]: 重新加载当前播放状态缓存');
    final currentPlayStateCache = await AudioHistoryManager.instance.getCurrentPlayStateCache();
    if (currentPlayStateCache != null) {
      try {
        final audioItemMap = currentPlayStateCache['audioItem'] as Map<String, dynamic>;
        final audioItem = AudioItem.fromMap(audioItemMap);
        final position = Duration(milliseconds: currentPlayStateCache['position'] as int);
        debugPrint('[AudioManager]: 从当前播放状态缓存恢复: ${audioItem.title} 位置: $position');
        await playAudio(audioItem, autoPlay: false, initialPosition: position);
        return;
      } catch (e) {
        debugPrint('[AudioManager]: 从当前播放状态缓存恢复失败: $e');
      }
    } else {
      debugPrint('[AudioManager]: 当前播放状态缓存为空');
    }
  }

  Future<void> signedInit() async {
    AudioHistoryManager.instance.startListening(needRecord: true);
    
    // 首先尝试从当前播放状态缓存中恢复
    
    if(currentAudio != null) {
      return;
    }
    // 如果缓存恢复失败，从播放历史列表中获取最后一条播放记录
    final lastHistory = await AudioHistoryManager.instance.getAudioHistory();
    if (lastHistory.isNotEmpty) {
      debugPrint('AudioManager: 最后一条播放记录: ${lastHistory.first.title}');
      await playAudio(lastHistory.first, autoPlay: false);
    } else {
      debugPrint('AudioManager: 没有播放历史记录');
      await _supplementPlaylist();
      final playlist = AudioPlaylist.instance;
      if(playlist.playlistSize > 0) {
        final firstAudio = playlist.getFirstAudio();
        if(firstAudio != null) {
          await playAudio(firstAudio, autoPlay: false);
        }
      }
    }
  }

  Future<void> signedOutInit() async {
    AudioHistoryManager.instance.startListening(needRecord: false);
    
    if(currentAudio != null) {
      return;
    }
    
    // 如果缓存恢复失败，从播放列表获取音频
    final playlist = AudioPlaylist.instance;
    if(playlist.playlistSize <= 0) {
      await _supplementPlaylist();
      final playlist = AudioPlaylist.instance;
      if(playlist.playlistSize > 0) {
        final firstAudio = playlist.getFirstAudio();
        if(firstAudio != null) {
          await playAudio(firstAudio, autoPlay: false);
        }
      }
    }
  }

  // 获取音频服务实例
  AudioPlayerService? get audioService {
    return _audioService;
  }

  // 播放音频
  Future<void> playAudio(AudioItem audio, {bool? autoPlay = true, Duration? initialPosition} ) async {
    // 1. 如果 audio 和当前在播放的 audio id 相同，则直接 return
    final currentAudio = this.currentAudio;
    final bool auto = autoPlay ?? true;

    if (currentAudio != null && currentAudio.id == audio.id) {
      debugPrint('相同音频正在播放，跳过: ${audio.title} (ID: ${audio.id})');
      if (!isPlaying && autoPlay == true) {
        play();
      }
      return;
    }

    // 如果是不同的音频，先停止之前的播放
    if(currentAudio != null && currentAudio.id != audio.id) {
      await stop();
    }

    // 2. 从历史列表获取新音频的播放进度，作为起始播放进度

    late Duration position;

    if(initialPosition == null || initialPosition <= Duration.zero) {
      position = AudioHistoryManager.instance.getPlaybackPosition(audio.id);
    } else {
      position = initialPosition;
    }
    
    // 3. 通过 _transformPosition 过滤 initialPosition 得到正确的 initialPosition
    final transformedPosition = _transformPosition(position, audio: audio);

    try {
      // await _ensureInitialized();
      debugPrint('[playAudio]: _audioService != null : ${_audioService != null}; auto : $auto');

      if (_audioService != null) {
        if (auto == true) {
          await _audioService!.playAudio(
            audio,
            initialPosition: transformedPosition,
          );
        } else {
          await _audioService!.loadAudio(
            audio,
            initialPosition: transformedPosition,
          );
        }
      } else {
        debugPrint('音频服务未初始化，无法播放音频');
        throw Exception('音频服务未初始化');
      }
    } catch (e) {
      debugPrint('播放音频失败: $e');
      rethrow;
    }
  }

  Future<void> play() async {
    // await _ensureInitialized();
    if (_audioService != null) {
      await _audioService!.play();
    }
  }

  // 检查当前播放位置是否超出预览区间
  bool get isOutOfPreview {
    // 如果不是预览模式，返回false
    if (!_isPreviewMode) {
      return false;
    }
    
    // 如果没有当前音频，返回false
    if (currentAudio == null) {
      return false;
    }
    
    final audio = currentAudio!;
    final currentPosition = position;
    final previewStart = audio.previewStart ?? Duration.zero;
    final previewDuration = audio.previewDuration ?? Duration.zero;
    
    // 检查预览参数是否有效
    if (previewStart < Duration.zero || previewDuration <= Duration.zero) {
      return false;
    }
    
    final previewEnd = previewStart + previewDuration;
    
    // 判断当前位置是否在预览区域之外
    return currentPosition < previewStart || currentPosition >= previewEnd;
  }

  /// 管理播放列表（清理和补充）
  Future<void> _managePlaylist(String currentAudioId) async {
    // 防止频繁触发：如果正在管理播放列表或者是同一个音频ID，直接返回
    if (_isManagingPlaylist || _lastManagedAudioId == currentAudioId) {
      debugPrint('_managePlaylist: 跳过重复操作 - isManaging: $_isManagingPlaylist, lastManagedId: $_lastManagedAudioId, currentId: $currentAudioId');
      return;
    }

    _isManagingPlaylist = true;
    _lastManagedAudioId = currentAudioId;

    try {
      final playlist = AudioPlaylist.instance;

      // 1. 清理当前音频之前的数据
      playlist.clearBeforeCurrent(currentAudioId);

      // 2. 设置当前播放索引
      playlist.setCurrentIndex(currentAudioId);

      // 3. 检查是否是最后一条，如果是则补充播放列表
      if (playlist.isLastAudio(currentAudioId)) {
        debugPrint('_managePlaylist: isLastAudio: true');
        await _supplementPlaylist();
      }
    } catch (e) {
      debugPrint('管理播放列表失败: $e');
    } finally {
      _isManagingPlaylist = false;
    }
  }

  /// 补充播放列表
  Future<void> _supplementPlaylist() async {
    try {
      final playlist = AudioPlaylist.instance;
      final currentAudio = playlist.getCurrentAudio();

      // 从API获取更多音频数据
      final response = await AudioListService.getAudioList(
        tag: null,
        cid: currentAudio?.id ?? '',
      );

      if (response.isNotEmpty) {
        // 添加新音频到播放列表
        playlist.addAudioList(response);
        debugPrint('成功补充播放列表: ${response.length} 首音频');
      } else {
        debugPrint('补充播放列表失败: 没有更多数据');
      }
    } catch (e) {
      debugPrint('补充播放列表失败: $e');
    }
  }

  // 播放/暂停
  Future<void> togglePlayPause() async {
    // await _ensureInitialized();
    if (_audioService != null) {
      if (_audioService!.isPlaying) {
        await pause(); // pause() 会自动处理进度记录
      } else {
        await _audioService!.play();
      }
    }
  }

  // 暂停
  Future<void> pause() async {
    // await _ensureInitialized();
    if (_audioService != null) {
      await _audioService!.pause();
    }
  }

  // 停止
  Future<void> stop() async {
    // await _ensureInitialized();
    if (_audioService != null) {
      await _audioService!.stop();
    }
  }

  // 跳转
  Future<void> seek(Duration position) async {
    // await _ensureInitialized();
    if (_audioService != null) {
      // 使用 _transformPosition 方法处理位置转换
      final seekPosition = _transformPosition(position);
      // debugPrint('[progressBar] AudioManager: seek到位置 $seekPosition (原始位置: $position)');

      return await _audioService!.seek(seekPosition);
    }
  }

  // 设置播放速度
  Future<void> setSpeed(double speed) async {
    // await _ensureInitialized();
    if (_audioService != null) {
      await _audioService!.setSpeed(speed);
    }
  }

  // 快进30秒
  Future<void> fastForward() async {
    // await _ensureInitialized();
    if (_audioService != null) {
      await _audioService!.fastForward();
    }
  }

  // 快退30秒
  Future<void> rewind() async {
    // await _ensureInitialized();
    if (_audioService != null) {
      await _audioService!.rewind();
    }
  }

  // 获取统一的音频状态流
  Stream<AudioPlayerState> get audioStateStream {
    // 如果服务未初始化，先初始化然后返回流
    if (_audioService == null) {
      _ensureInitialized();
      // 返回一个延迟流，等待初始化完成后再订阅真实流
      return Stream.fromFuture(_ensureInitialized()).asyncExpand((_) {
        return _audioService?.audioStateStream ?? Stream.empty();
      });
    }
    return _audioService!.audioStateStream;
  }

  // 获取播放器状态流
  Stream<PlayerState> get playerStateStream {
    return _playerStateSubject.stream;
  }

  // 获取 preloadAudio 流
  Stream<AudioItem?> get preloadAudioStream {
    return _preloadAudioSubject.stream;
  }

  // 获取当前状态
  bool get isPlaying {
    return _audioService?.currentState.isPlaying ?? false;
  }

  AudioItem? get currentAudio {
    return _audioService?.currentState.currentAudio;
  }

  Duration get position {
    return _audioService?.currentState.position ?? Duration.zero;
  }

  AudioDurationInfo get durationInfo {
    final audio = currentAudio;
    final duration = _audioService?.currentState.duration ?? Duration.zero;
    return AudioDurationInfo.withValidation(
      totalDuration: duration,
      previewStart: audio?.previewStart,
      previewDuration: audio?.previewDuration,
    );
  }

  Duration get duration {
    final playerDuration = _audioService?.currentState.duration ?? Duration.zero;
    final apiDuration = currentAudio?.duration;
    
    // 数据一致性检查和日志记录
    if (playerDuration != Duration.zero && apiDuration != null) {
      final diffSeconds = (playerDuration.inSeconds - apiDuration.inSeconds).abs();
      if (diffSeconds > 5) { // 差异超过5秒认为异常
        debugPrint('[AudioManager] Duration数据不一致 - 播放器:${playerDuration.inSeconds}s, API:${apiDuration.inSeconds}s, 差异:${diffSeconds}s');
      }
    }
    
    // 优先返回播放器的真实时长
    return playerDuration;
  }

  double get speed {
    return _audioService?.currentState.speed ?? 1.0;
  }

  PlayerState get playerState {
    return _playerStateSubject.value;
  }

  Duration get bufferedPosition {
    return _audioService?.currentState.bufferedPosition ?? Duration.zero;
  }

  /// 初始化权益状态
  Future<void> _initializePrivilegeStatus() async {
    try {
      final hasPremium = await SubscribePrivilegeManager.instance.hasValidPremium();
      
      debugPrint('AudioManager: 初始化权益状态 - hasPremium: $hasPremium');
      _updatePlaybackPermissions(hasPremium);
    } catch (e) {
      debugPrint('AudioManager: 初始化权益状态失败: $e');
      // 失败时设置为无权限状态
      _updatePlaybackPermissions(false);
    }
  }

  /// 设置权益监听器
  void _setupPrivilegeListener() {
    _privilegeSubscription = SubscribePrivilegeManager.instance.privilegeChanges.listen(
      (event) {
        debugPrint('AudioManager: 收到权益变化事件 - hasPremium: ${event.hasPremium}');
        _updatePlaybackPermissions(event.hasPremium);
      },
      onError: (error) {
        debugPrint('AudioManager: 权益状态监听异常: $error');
      },
    );
    debugPrint('AudioManager: 权益状态监听器已设置');
  }

  /// 设置认证状态监听器
  void _setupAuthStatusListener() {
    _authStatusSubscription = AuthManager.instance.authStatusChanges.listen(
      (event) {
        debugPrint('AudioManager: 收到认证状态变化事件 - status: ${event.status}');
        _handleAuthStatusChange(event.status);
      },
      onError: (error) {
        debugPrint('AudioManager: 认证状态监听异常: $error');
      },
    );
    debugPrint('AudioManager: 认证状态监听器已设置');
  }

  /// 处理认证状态变化
  void _handleAuthStatusChange(AuthStatus status) {
    debugPrint('AudioManager: 处理认证状态变化 - status: $status');
    
    if (status == AuthStatus.authenticated) {
      // 登录时开始监听播放历史
      signedInit();
      debugPrint('AudioManager: 已登录，开始监听播放历史');
    } else {
      // 登出时停止监听播放历史
      signedOutInit();
      debugPrint('AudioManager: 已登出，停止监听播放历史');
    }
  }

  /// 根据权益状态更新播放权限
  void _updatePlaybackPermissions(bool hasPremium) {
    debugPrint('AudioManager: 更新播放权限 - hasPremium: $hasPremium');
    
    // 根据权益状态设置预览模式（hasPremium为true时，预览模式为false）
    _isPreviewMode = !hasPremium;
    
    debugPrint('AudioManager: 播放权限已更新 - 预览模式: ${!hasPremium}');
  }

  // 清理资源
  Future<void> dispose() async {
    // 在销毁前记录最后的播放停止
    if (_audioService != null) {
      await _audioService!.dispose();
    }

    // 清理权益状态监听
    await _privilegeSubscription?.cancel();
    _privilegeSubscription = null;

    // 清理认证状态监听
    await _authStatusSubscription?.cancel();
    _authStatusSubscription = null;

    // 关闭所有BehaviorSubject
    await _playerStateSubject.close();

    // 关闭StreamController
    await _previewOutController.close();

    AudioHistoryManager.instance.stopListening();

    _audioService = null;
  }
}
