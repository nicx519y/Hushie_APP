import 'package:audio_service/audio_service.dart';
import 'package:just_audio/just_audio.dart';
import 'package:rxdart/rxdart.dart';
import '../models/audio_item.dart';
import 'package:flutter/foundation.dart';
import 'exoplayer_config_service.dart';
import 'network_healthy_manager.dart';
import 'analytics_service.dart';
import 'performance_service.dart';
import 'package:firebase_performance/firebase_performance.dart';
import 'dart:async';

// 音频状态数据类
class AudioPlayerState {
  final AudioItem? currentAudio;
  final Duration position;
  final Duration bufferedPosition;
  final Duration duration;
  final bool isPlaying;
  final double speed;
  final PlayerState playerState;
  final Duration renderPreviewStart;
  final Duration renderPreviewEnd;
  final AudioItem? preloadAudio;

  AudioPlayerState({
    this.currentAudio,
    this.position = Duration.zero,
    this.bufferedPosition = Duration.zero,
    this.duration = Duration.zero,
    this.isPlaying = false,
    this.speed = 1.0,
    PlayerState? playerState,
    this.renderPreviewStart = Duration.zero,
    this.renderPreviewEnd = Duration.zero,
    this.preloadAudio,
  }) : playerState = playerState ?? PlayerState(false, ProcessingState.idle);

  AudioPlayerState copyWith({
    AudioItem? currentAudio,
    Duration? position,
    Duration? bufferedPosition,
    Duration? duration,
    bool? isPlaying,
    double? speed,
    PlayerState? playerState,
    Duration? renderPreviewStart,
    Duration? renderPreviewEnd,
    AudioItem? preloadAudio,
  }) {
    return AudioPlayerState(
      currentAudio: currentAudio ?? this.currentAudio,
      position: position ?? this.position,
      bufferedPosition: bufferedPosition ?? this.bufferedPosition,
      duration: duration ?? this.duration,
      isPlaying: isPlaying ?? this.isPlaying,
      speed: speed ?? this.speed,
      playerState: playerState ?? this.playerState,
      renderPreviewStart: renderPreviewStart ?? this.renderPreviewStart,
      renderPreviewEnd: renderPreviewEnd ?? this.renderPreviewEnd,
      preloadAudio: preloadAudio ?? this.preloadAudio,
    );
  }
}

class AudioPlayerService extends BaseAudioHandler {
  final AudioPlayer _audioPlayer = AudioPlayer();

  // 统一的音频状态流
  final BehaviorSubject<AudioPlayerState> _audioStateSubject = BehaviorSubject<AudioPlayerState>.seeded(
    AudioPlayerState(),
  );

  // 公开的统一状态流
  Stream<AudioPlayerState> get audioStateStream => _audioStateSubject.stream;

  // Analytics: 加载到可播放耗时统计
  int? _loadStartMs;
  String? _loadAudioId;
  int? _lastLoadInitialPositionMs;
  bool _loadReported = false;
  Trace? _loadTrace;


  // 当前状态的getter
  AudioPlayerState get currentState => _audioStateSubject.value;
  bool get isPlaying => _audioStateSubject.value.isPlaying;
  AudioItem? get currentAudio => _audioStateSubject.value.currentAudio;
  Duration get position => _audioStateSubject.value.position;
  Duration get duration => _audioStateSubject.value.duration;
  double get speed => _audioStateSubject.value.speed;
  PlayerState get playerState => _audioStateSubject.value.playerState;
  Duration get bufferedPosition => _audioStateSubject.value.bufferedPosition;


  AudioPlayerService() {
    debugPrint('AudioPlayerService constructor called');
    _init();
    // 确保初始状态被发送
    debugPrint('Initial audioState: ${_audioStateSubject.value}');
  }

  void _init() {
    // 配置 Android ExoPlayer 缓冲参数
    _configureExoPlayerBuffer();

    // 根据网络健康状态驱动缓冲策略选择
    _setupDynamicBufferStrategy();
    
    // 监听播放状态变化
    _audioPlayer.playingStream.listen((playing) {
      _updateAudioState(isPlaying: playing);
      _broadcastState();
    });

    // 监听播放位置变化 - 添加防抖动以减少更新频率
    _audioPlayer.positionStream.listen((position) {
      _updateAudioState(position: position);
      _broadcastState(); // 调用，减少广播频率
      // 位置更新不需要频繁广播状态，其他状态变化时会自动广播
    });

    // 监听播放时长变化
    _audioPlayer.durationStream.listen((duration) {
      if (duration != null) {
        _updateAudioState(duration: duration);
      }
    });

    // 监听播放速度变化
    _audioPlayer.speedStream.listen((speed) {
      _updateAudioState(speed: speed);
    });

    // 监听播放完成
    _audioPlayer.playerStateStream.listen((state) {
      _updateAudioState(playerState: state);
      if (state.processingState == ProcessingState.ready) {
        _stopLoadTraceIfNeeded();
      }
    });

    // 监听缓冲位置变化
    _audioPlayer.bufferedPositionStream.listen((bufferedPosition) {
      _updateAudioState(bufferedPosition: bufferedPosition);
    });
  }

  // 统一的状态更新方法
  void _updateAudioState({
    AudioItem? currentAudio,
    Duration? position,
    Duration? bufferedPosition,
    Duration? duration,
    bool? isPlaying,
    double? speed,
    PlayerState? playerState,
    Duration? renderPreviewStart,
    Duration? renderPreviewEnd,
    AudioItem? preloadAudio,
  }) {
    final newState = _audioStateSubject.value.copyWith(
      currentAudio: currentAudio,
      position: position,
      bufferedPosition: bufferedPosition,
      duration: duration,
      isPlaying: isPlaying,
      speed: speed,
      playerState: playerState,
      renderPreviewStart: renderPreviewStart,
      renderPreviewEnd: renderPreviewEnd,
      preloadAudio: preloadAudio,
    );
    _audioStateSubject.add(newState);
  }

  // 公共方法：更新预加载音频状态
  void updatePreloadAudio(AudioItem? preloadAudio) {
    _updateAudioState(preloadAudio: preloadAudio);
  }

  Future<void> loadAudio(AudioItem audio, {Duration? initialPosition}) async {
    try {
      // 先完全停止并重置播放器状态
      if(currentAudio != audio) {
        updatePreloadAudio(audio);
      }

      await _stopAndReset();
      _updateAudioState(currentAudio: audio);

      // 验证音频URL
      final audioUrl = audio.audioUrl;

      if (audioUrl == null || audioUrl.isEmpty) {
        throw Exception('音频URL为空');
      }

      debugPrint('loadAudio url: $audioUrl${initialPosition != null ? '，初始位置: ${initialPosition.inSeconds}秒' : ''}');

      // 安全地获取封面URL
      String? coverUrlString;
      try {
        final bestResolution = audio.cover.getBestResolution(160);
        final url = bestResolution.url;
        
        // 验证URL有效性，避免设置无效的artUri
        if (url.isNotEmpty && 
            url.startsWith('http') && 
            !url.contains('/default.jpg') && 
            !url.contains('placeholder')) {
          coverUrlString = url;
          debugPrint('loadAudio cover url: $coverUrlString');
        } else {
          debugPrint('loadAudio 封面URL无效或为默认图片: $url，跳过artUri设置');
          coverUrlString = null;
        }
      } catch (e) {
        debugPrint('获取封面URL失败: $e，使用默认封面');
        coverUrlString = null;
      }

      // 设置MediaItem用于通知栏显示
      final mediaItemData = MediaItem(
        id: audio.id,
        album: "Hushie",
        title: audio.title,
        artist: audio.author,
        duration: audio.duration ?? Duration.zero,
        artUri: coverUrlString != null ? Uri.parse(coverUrlString) : null,
        extras: audio.toMap(),
      );

      mediaItem.add(mediaItemData);

      // 加载音频文件，使用 setAudioSource 的 initialPosition 参数
      final audioSource = AudioSource.uri(Uri.parse(audioUrl));
      // 记录加载开始时间（用于统计从加载到可播放的耗时）
      _loadStartMs = DateTime.now().millisecondsSinceEpoch;
      _loadAudioId = audio.id;
      _lastLoadInitialPositionMs = initialPosition?.inMilliseconds;
      _loadReported = false;
      // 启动性能 Trace 记录从加载到 ready 的耗时
      _loadTrace = await PerformanceService().startTrace('audio_load_to_ready');
      _loadTrace?.putAttribute('audio_id', audio.id);
      _loadTrace?.putAttribute('audio_title', audio.title);
      if (_lastLoadInitialPositionMs != null) {
        _loadTrace?.putAttribute('initial_position_ms', '${_lastLoadInitialPositionMs!}');
      }
      if (initialPosition != null) {
        await _audioPlayer.setAudioSource(audioSource, initialPosition: initialPosition);
        debugPrint('音频加载完成，初始位置: ${initialPosition.inSeconds}秒');
      } else {
        await _audioPlayer.setAudioSource(audioSource);
        debugPrint('音频加载完成');
      }
    } catch (e) {
      debugPrint('装载音频时出错: $e');
      rethrow; // 重新抛出异常，让调用者处理
    }
  }

  // 加载并播放音频
  Future<void> playAudio(AudioItem audio, {Duration? initialPosition}) async {
    try {
      // 检查是否需要加载新音频或重新设置初始位置
      final currentAudio = this.currentAudio;
      if (currentAudio == null || currentAudio.id != audio.id) {
        debugPrint('加载新音频: ${audio.title} (ID: ${audio.id})');
        await loadAudio(audio, initialPosition: initialPosition);
      } else if (initialPosition != null) {
        // 如果是同一个音频但指定了新的初始位置，重新加载
        debugPrint('相同音频但需要设置初始位置，重新加载: ${audio.title}');
        await loadAudio(audio, initialPosition: initialPosition);
      } else {
        debugPrint('相同音频，跳过重新加载: ${audio.title} (ID: ${audio.id})');
      }
      
      await _audioPlayer.play();
      debugPrint('音频播放开始成功${initialPosition != null ? '，从${initialPosition.inSeconds}秒开始' : ''}');
    } catch (e) {
      debugPrint('播放音频时出错: $e');
      await stop();
    }
  }

  // 停止 Trace 并记录从开始加载到可播放的耗时
  void _stopLoadTraceIfNeeded() async {
    try {
      final audio = currentAudio;
      if (audio == null) return;
      if (_loadReported) return;
      if (_loadAudioId != audio.id) return;
      if (_loadStartMs == null) return;
      final nowMs = DateTime.now().millisecondsSinceEpoch;
      final elapsedMs = nowMs - _loadStartMs!;
      _loadTrace?.setMetric('elapsed_ms', elapsedMs);
      await PerformanceService().stopTrace(_loadTrace);
      _loadTrace = null;
      _loadReported = true;
      debugPrint('⚡ [PERF] 音频加载到可播放耗时: ${elapsedMs}ms (${audio.title})');
    } catch (e) {
      debugPrint('⚡ [PERF] 记录音频加载耗时失败: $e');
    }
  }

  // 私有方法：停止并重置播放器
  Future<void> _stopAndReset() async {
    try {
      if (_audioPlayer.playing) {
        await _audioPlayer.stop();
      }
      // 添加小延迟确保资源完全释放
      await Future.delayed(const Duration(milliseconds: 100));
      
      // 使用统一的状态更新方法重置所有状态
      _updateAudioState(
        currentAudio: null,
        position: Duration.zero,
        duration: null,
        isPlaying: false,
        speed: 1.0,
        bufferedPosition: Duration.zero,
      );
    } catch (e) {
      debugPrint('停止播放器时出错: $e');
    }
  }

  // 播放/暂停切换
  @override
  Future<void> play() async {
    await _audioPlayer.play();
  }

  @override
  Future<void> pause() async {
    await _audioPlayer.pause();
  }

  @override
  Future<void> stop() async {
    try {
      await _audioPlayer.stop();
    } catch (e) {
      debugPrint('停止播放时出错: $e');
    } finally {
      _updateAudioState(currentAudio: null);
      mediaItem.add(null);
    }
  }

  // 跳转到指定位置
  @override
  Future<void> seek(Duration position) async {
    await _audioPlayer.seek(position);
  }

  // 设置播放速度
  @override
  Future<void> setSpeed(double speed) async {
    await _audioPlayer.setSpeed(speed);
    _updateAudioState(speed: speed);
  }

  // 广播播放状态
  void _broadcastState() {
    final playing = _audioPlayer.playing;
    final processingState = _getProcessingState();

    playbackState.add(
      PlaybackState(
        // 通知栏显示的控制按钮列表
        controls: [
          // 根据播放状态动态显示播放或暂停按钮
          if (playing) MediaControl.pause else MediaControl.play,
          // MediaControl.stop, // 停止按钮（已注释）
        ],
        // 支持的系统操作集合
        systemActions: {
          // 允许用户拖拽进度条来跳转播放位置
          MediaAction.seek,
        },
        // Android 紧凑通知栏模式下显示的按钮索引（第0和第1个按钮）
        androidCompactActionIndices: const [0],
        // 当前音频处理状态（空闲、加载中、缓冲中、就绪、完成）
        processingState: processingState,
        // 当前是否正在播放
        playing: playing,
        // 当前播放位置，用于通知栏进度条显示
        updatePosition: _audioPlayer.position,
        // 当前缓冲位置，用于显示缓冲进度
        bufferedPosition: _audioPlayer.bufferedPosition,
        // 当前播放速度（1.0为正常速度）
        speed: _audioPlayer.speed,
      ),
    );
  }

  AudioProcessingState _getProcessingState() {
    switch (_audioPlayer.processingState) {
      case ProcessingState.idle:
        return AudioProcessingState.idle;
      case ProcessingState.loading:
        return AudioProcessingState.loading;
      case ProcessingState.buffering:
        return AudioProcessingState.buffering;
      case ProcessingState.ready:
        return AudioProcessingState.ready;
      case ProcessingState.completed:
        return AudioProcessingState.completed;
    }
  }

  // 快进
  @override
  Future<void> fastForward() async {
    final position = _audioPlayer.position;
    final duration = _audioPlayer.duration;
    if (duration != null) {
      final newPosition = position + const Duration(seconds: 30);
      await seek(newPosition > duration ? duration : newPosition);
    }
  }

  // 快退
  @override
  Future<void> rewind() async {
    final position = _audioPlayer.position;
    final newPosition = position - const Duration(seconds: 30);
    await seek(newPosition < Duration.zero ? Duration.zero : newPosition);
  }

  @override
  Future<void> onTaskRemoved() async {
    // 当任务被移除时的处理
    await stop();
  }

  // 配置 ExoPlayer 缓冲参数（仅 Android 平台）
  Future<void> _configureExoPlayerBuffer() async {
    try {
      final result = await ExoPlayerConfigService.configureOptimalBuffer();
      if (kDebugMode) {
        debugPrint('ExoPlayer buffer configuration result: $result');
      }
    } catch (e) {
      if (kDebugMode) {
        debugPrint('Failed to configure ExoPlayer buffer: $e');
      }
    }
  }

  // 动态缓冲策略：根据网络健康状态选择缓冲配置
  StreamSubscription<NetworkHealthStatus>? _networkStatusSubscription;
  NetworkHealthStatus _lastAppliedNetworkStatus = NetworkHealthStatus.unknown;

  void _setupDynamicBufferStrategy() {
    // 懒初始化网络健康管理器，避免在应用入口增加启动耗时
    // 若已初始化则内部会直接返回（在管理器中实现幂等保护）
    NetworkHealthyManager.instance.initialize();

    // 主动检查一次网络状态并应用策略
    NetworkHealthyManager.instance.checkNetworkHealth().then((status) {
      _applyBufferStrategyForStatus(status);
    });

    // 订阅网络状态变化，适时调整缓冲策略
    _networkStatusSubscription = NetworkHealthyManager.instance.networkStatusStream.listen((status) {
      _applyBufferStrategyForStatus(status);
    });
  }

  Future<void> _applyBufferStrategyForStatus(NetworkHealthStatus status) async {
    // 避免重复应用同一状态导致的过度配置
    if (_lastAppliedNetworkStatus == status) {
      return;
    }

    _lastAppliedNetworkStatus = status;

    try {
      switch (status) {
        case NetworkHealthStatus.healthy:
          if (kDebugMode) {
            debugPrint('📶 [AUDIO] 网络健康，应用推荐缓冲（1s/600s）');
          }
          await ExoPlayerConfigService.configureLowLatencyBuffer();
          break;
        case NetworkHealthStatus.serverUnhealthy:
          if (kDebugMode) {
            debugPrint('📶 [AUDIO] 服务器不健康，应用大缓冲（6s/600s）');
          }
          await ExoPlayerConfigService.configureLargeBuffer();
          break;
        case NetworkHealthStatus.noConnection:
          if (kDebugMode) {
            debugPrint('📶 [AUDIO] 无网络连接，保持当前配置，不做调整');
          }
          // 无网络时不调整缓冲，避免误操作
          break;
        case NetworkHealthStatus.error:
        case NetworkHealthStatus.unknown:
          if (kDebugMode) {
            debugPrint('📶 [AUDIO] 网络状态未知/错误，应用推荐缓冲作为回退');
          }
          await ExoPlayerConfigService.configureOptimalBuffer();
          break;
      }
    } catch (e) {
      if (kDebugMode) {
        debugPrint('📶 [AUDIO] 应用缓冲策略失败: $e');
      }
    }
  }

  // 清理资源
  Future<void> dispose() async {
    await _audioPlayer.dispose();
    await _audioStateSubject.close();
    await _networkStatusSubscription?.cancel();
  }
}
