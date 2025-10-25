import 'dart:async';
import 'dart:convert';
import 'package:hushie_app/services/auth_manager.dart';
import 'package:rxdart/rxdart.dart';
import 'package:audio_service/audio_service.dart';
import 'package:just_audio/just_audio.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:shared_preferences/shared_preferences.dart';
import '../models/audio_item.dart';
import '../models/audio_duration_info.dart';
import 'audio_service.dart';
import 'audio_playlist.dart';
import 'audio_history_manager.dart';
import 'api/audio_list_service.dart';

import 'package:flutter/foundation.dart';
import 'audio_likes_manager.dart';
import '../config/api_config.dart';
import 'home_page_list_service.dart';
import 'subscribe_privilege_manager.dart';

// 权限违规事件类
// 移除违规事件类定义与相关流
// class PermissionViolationEvent {
//   final AudioItem audio;
//   final String reason;
//   final DateTime timestamp;
// 
//   PermissionViolationEvent({
//     required this.audio,
//     required this.reason,
//     DateTime? timestamp,
//   }) : timestamp = timestamp ?? DateTime.now();
// }

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

  // 权限违规事件流
  // final BehaviorSubject<PermissionViolationEvent?> _permissionViolationSubject =
  //     BehaviorSubject<PermissionViolationEvent?>.seeded(null);

  // 缓存本地状态，用于比对变化
  String? _lastAudioId;
  bool _lastIsPlaying = false;
  Duration _lastPosition = Duration.zero;

  // 播放列表管理状态标志位
  bool _isManagingPlaylist = false;
  String? _lastManagedAudioId;

  // 认证状态监听
  StreamSubscription<AuthStatusChangeEvent>? _authStatusSubscription;

  // 权限状态
  bool _hasPremium = false;
  StreamSubscription<PrivilegeChangeEvent>? _premiumStatusSubscription;

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
        config: const AudioServiceConfig( // 音频服务配置
          // Android 通知渠道 ID，用于系统识别和管理通知
          androidNotificationChannelId: 'com.hushie.audio',
          // Android 通知渠道名称，用户在系统设置中看到的名称
          androidNotificationChannelName: 'Hushie.AI',
          // 设置为 true 时，音频播放时通知会持续显示（前台服务）
          androidNotificationOngoing: true,
          // 暂停时是否停止前台服务，true 表示暂停时停止前台服务
          androidStopForegroundOnPause: true,
          // 通知栏显示的图标资源路径
          androidNotificationIcon: 'drawable/ic_notification_stat',
          // 是否预加载音频封面图片，提升用户体验
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


    // 监听认证状态变化事件
    _setupAuthStatusListener();

    // 初始化权限服务并监听权限状态
    await SubscribePrivilegeManager.instance.initialize();
    _setupPrivilegeStatusListener();
    // 初始化 _hasPremium 初始值
    final cachedPrivilege = SubscribePrivilegeManager.instance.getCachedPrivilege();
    _hasPremium = cachedPrivilege?.hasPremium ?? false;

    // 使用统一的初始化方法，避免重复初始化
    await _ensureInitialized();
    debugPrint('AudioManager: AudioService 初始化完成');

    // 开启播放历史记录监听（通过AudioManager的状态流）
    try {
      final signedIn = await AuthManager.instance.isSignedIn();
      if (signedIn) {
        await signedInit();
      } else {
        await signedOutInit();
      }
    } catch (e) {
      debugPrint('AudioManager: 初始化播放流程异常，尝试未登录恢复: $e');
      try {
        await signedOutInit();
      } catch (err) {
        debugPrint('AudioManager: 未登录恢复也失败: $err');
      }
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

      // 权限检查 - 当播放状态变化为播放时进行检查
      // if (playingStateChanged && isPlaying && audio != null) {
      //   if (!_checkAudioPermission(audio)) {
      //     final reason = _hasPremium 
      //         ? 'Unknown permission error' 
      //         : 'This audio requires premium membership, playback has been paused';
      //     _handlePermissionViolation(audio, reason);
      //   }
      // }

      // 检查播放是否完成并自动播放下一首
      if(positionChanged && audioState.playerState.playing && position >= audioState.duration * 0.995 && _hasPremium) {
        _checkPlaybackCompletion();
      }
      // debugPrint('[checkWillOutPreview] 播放列表管理完成');
      
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

      // 将统一音频状态回调到历史管理器，避免其内部订阅导致的循环依赖
      try {
        AudioHistoryManager.instance.handleAudioState(audioState);
      } catch (e) {
        debugPrint('AudioHistoryManager 处理音频状态失败: $e');
      }
    });
  }



  /// 检查播放是否完成并自动播放下一首
  void _checkPlaybackCompletion() {
    final currentAudio = this.currentAudio;
    if (currentAudio != null) {
      playNextAudio(currentAudio.id);
    }
  }

  /// 播放下一首音频
  Future<void> playNextAudio(String currentAudioId) async {
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

    // Fallback: 当当前播放状态缓存为空或解析失败时，使用默认音频列表的第一条
    if (!ApiConfig.useEmbeddedData) {
      debugPrint('[AudioManager]: 预埋数据开关关闭，跳过默认音频回退');
      return;
    }
    try {
      final jsonStr = await rootBundle.loadString('assets/configs/default_audio_list.json');
      final List<dynamic> data = json.decode(jsonStr) as List<dynamic>;
      if (data.isNotEmpty) {
        final first = data.first;
        if (first is Map) {
          final audioItem = AudioItem.fromMap(Map<String, dynamic>.from(first as Map));
          debugPrint('[AudioManager]: 使用默认音频作为当前播放状态: ${audioItem.title}');

          // 持久化为 current_play_state_cache，方便下次直接恢复
          try {
            final playState = {
              'audioItem': audioItem.toMap(),
              'position': 0,
              'isPlaying': false,
              'timestamp': DateTime.now().toIso8601String(),
            };
            final prefs = await SharedPreferences.getInstance();
            await prefs.setString('current_play_state_cache', json.encode(playState));
          } catch (e) {
            debugPrint('[AudioManager]: 写入默认当前播放状态缓存失败: $e');
          }

          await playAudio(audioItem, autoPlay: false, initialPosition: Duration.zero);
          return;
        }
      } else {
        debugPrint('[AudioManager]: 默认音频列表为空，无法恢复');
      }
    } catch (e) {
      debugPrint('[AudioManager]: 读取默认音频列表失败: $e');
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
      try {
        await playAudio(lastHistory.first, autoPlay: false);
      } catch (e) {
        debugPrint('AudioManager: 从历史播放恢复失败: $e');
      }
    } else {
      debugPrint('AudioManager: 没有播放历史记录');
      await _supplementPlaylist();
      final playlist = AudioPlaylist.instance;
      if(playlist.playlistSize > 0) {
        final firstAudio = playlist.getFirstAudio();
        if(firstAudio != null) {
          try {
            await playAudio(firstAudio, autoPlay: false);
          } catch (e) {
            debugPrint('AudioManager: 从播放列表恢复失败: $e');
          }
        }
      }
    }
  }

  Future<void> signedOutInit() async {
    AudioHistoryManager.instance.startListening(needRecord: true);
    
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
          try {
            await playAudio(firstAudio, autoPlay: false);
          } catch (e) {
            debugPrint('AudioManager: 未登录初始化播放失败: $e');
          }
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
      if (!isPlaying && auto == true && _checkAudioPermission(audio)) {
        // 再次检查权限，防止权限状态在播放过程中发生变化
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
    
    try {
      // await _ensureInitialized();
      debugPrint('[playAudio]: _audioService != null : ${_audioService != null}; auto : $auto');

      if (_audioService != null) {
        if (auto == true && _checkAudioPermission(audio)) {
          await _audioService!.playAudio(
            audio,
            initialPosition: position,
          );
        } else {
          await _audioService!.loadAudio(
            audio,
            initialPosition: position,
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

      // 从首页for you获取列表第一个音频作为补充
      try {
        final listService = HomePageListService();
        await listService.initialize();
        List<AudioItem> items = listService.getTabData('for_you');
        if (items.isEmpty) {
          try {
            await listService.preloadTabData('for_you');

            if (items.isNotEmpty) {
              playlist.addAudio(items.first);
              debugPrint('成功补充播放列表(for_you): 写入首音频');
              return;
            }

          } catch (_) {}
          items = listService.getTabData('for_you');
        }
        
      } catch (e) {
        debugPrint('从首页for_you获取数据失败，回退到API: $e');
      }
      


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
      final seekPosition = position;
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


  /// 设置权限状态监听器
  void _setupPrivilegeStatusListener() {
    _premiumStatusSubscription = SubscribePrivilegeManager.instance.privilegeChanges.listen(
      (event) {
        final newHasPremium = event.hasPremium;
        if (_hasPremium != newHasPremium) {
          _hasPremium = newHasPremium;
          debugPrint('AudioManager: 权限状态更新 - hasPremium=$_hasPremium');
        }
      },
      onError: (error) {
        debugPrint('AudioManager: 权限状态监听异常: $error');
      },
    );
    debugPrint('AudioManager: 权限状态监听器已设置');
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
      // 登录时暂停播放
      pause();
      debugPrint('AudioManager: 已登录，开始监听播放历史');
    } else {
      // 登出时停止监听播放历史
      signedOutInit();
      // 暂停播放
      pause();
      debugPrint('AudioManager: 已登出，停止监听播放历史');
    }
  }

  /// 检查音频播放权限
  bool _checkAudioPermission(AudioItem audio) {
    // 如果用户有会员权限，可以播放所有音频
    if (_hasPremium) {
      return true;
    }
    
    // 如果用户没有会员权限，只能播放免费音频
    return audio.isFree;
  }


  /// 获取权限违规事件流
  // 已移除：权限违规事件流
  // Stream<PermissionViolationEvent?> get permissionViolationStream {
  //   return _permissionViolationSubject.stream;
  // }


  // 清理资源
  Future<void> dispose() async {
    // 在销毁前记录最后的播放停止
    if (_audioService != null) {
      await _audioService!.dispose();
    }


    // 清理认证状态监听
    await _authStatusSubscription?.cancel();
    _authStatusSubscription = null;

    // 清理权限状态监听
    await _premiumStatusSubscription?.cancel();
    _premiumStatusSubscription = null;

    // 关闭所有BehaviorSubject
    await _playerStateSubject.close();

    AudioHistoryManager.instance.stopListening();

    _audioService = null;
  }
}
