import 'package:audio_service/audio_service.dart';
import 'package:hushie_app/config/api_config.dart';
import 'package:just_audio/just_audio.dart';
import 'package:rxdart/rxdart.dart';
import '../models/audio_item.dart';
import 'package:flutter/foundation.dart';
import 'exoplayer_config_service.dart';
import 'network_healthy_manager.dart';
import 'performance_service.dart';
import 'package:firebase_performance/firebase_performance.dart';
import 'api/tracking_service.dart';
import 'dart:async';
import 'package:flutter/services.dart' show rootBundle; // 读取预埋资产文件
import 'subscribe_privilege_manager.dart';
import 'analytics_service.dart';

// 事件：超出预览边界或无权限播放
class PreviewBoundaryEvent {
  final String? audioId;
  final Duration position;
  final Duration previewEnd;
  final String reason; // e.g., 'no_permission' / 'preview_exceeded'

  const PreviewBoundaryEvent({
    required this.audioId,
    required this.position,
    required this.previewEnd,
    this.reason = 'no_permission',
  });
}

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

  // 全局事件流：预览边界/权限限制触发
  static final StreamController<PreviewBoundaryEvent> _previewBoundaryController =
      StreamController<PreviewBoundaryEvent>.broadcast();
  static Stream<PreviewBoundaryEvent> get previewBoundaryEvents =>
      _previewBoundaryController.stream;

  // 配置：是否使用预埋音频（assets/audios/）
  static bool get _useEmbeddedAudios => ApiConfig.useEmbeddedData;
  static const String _embeddedAudiosDir = 'assets/audios';

  // 统一的音频状态流
  final BehaviorSubject<AudioPlayerState> _audioStateSubject =
      BehaviorSubject<AudioPlayerState>.seeded(AudioPlayerState());

  // 公开的统一状态流
  Stream<AudioPlayerState> get audioStateStream => _audioStateSubject.stream;

  // Analytics: 加载到可播放耗时统计
  int? _loadStartMs;
  String? _loadAudioId;
  int? _lastLoadInitialPositionMs;
  bool _loadReported = false;
  Trace? _loadTrace;

  // Analytics: 用户真实播放（仅在每次打开App的会话中上报一次）
  bool _realPlayReported = false;
  Duration? _playStartPosition;
  String? _playStartAudioId;

  // 会员权限状态
  bool _hasPremium = false;
  StreamSubscription<PrivilegeChangeEvent>? _privilegeSubscription;

  // 串行化与并发保护
  Future<void> _opSerial = Future.value();
  Future<T> _enqueueOp<T>(Future<T> Function() op) {
    final completer = Completer<T>();
    _opSerial = _opSerial.then((_) async {
      try {
        final result = await op();
        completer.complete(result);
      } catch (e, st) {
        completer.completeError(e, st);
      }
    });
    return completer.future;
  }

  Future<void>? _currentLoadTask;
  String? _loadingAudioId;

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
    // 初始化音量为最大
    _audioPlayer.setVolume(1.0);
    // 配置 Android ExoPlayer 缓冲参数
    _configureExoPlayerBuffer();

    // 根据网络健康状态驱动缓冲策略选择
    _setupDynamicBufferStrategy();

    // 监听播放状态变化
    _audioPlayer.playingStream.listen((playing) {
      _updateAudioState(isPlaying: playing);
      _broadcastState();

      // 当开始播放时，记录当前的起始进度（用于计算真实播放阈值）
      if (playing) {
        try {
          _playStartPosition = _audioPlayer.position;
          _playStartAudioId = currentAudio?.id;
        } catch (_) {
          // 忽略异常，保持默认值
        }
      }
    });

    // 监听播放位置变化 - 添加防抖动以减少更新频率
    _audioPlayer.positionStream.listen((position) {
      
      if(currentAudio != null) {
        // 使用局部变量以通过 Dart 的空安全检查
        final audio = currentAudio!;
        
        // 检查权限并暂停播放（基于当前最新进度）
        if(!_checkAudioPermission(audio) && isPlaying) {
          if(!_checkAudioPreviewPermission(audio, atPosition: position)) {
            pause();
            // seek((_audioPlayer.duration ?? Duration.zero) * ApiConfig.previewAudioRatio);
            debugPrint('🚫 [AUDIO] 无播放权限：需会员或免费音频。');

            // 派发预览边界事件
            try {
              final total = _audioPlayer.duration ?? Duration.zero;
              final previewEnd = Duration(
                milliseconds: (total.inMilliseconds * ApiConfig.previewAudioRatio).toInt(),
              );
              _previewBoundaryController.add(
                PreviewBoundaryEvent(
                  audioId: audio.id,
                  position: position,
                  previewEnd: previewEnd,
                  reason: 'preview_exceeded',
                ),
              );
            } catch (_) {}
            return;
          }
        }

        _updateAudioState(position: position);
        _broadcastState(); // 调用，减少广播频率

        // 真实播放事件：当前进度 - 开始播放的进度 >= 2s，且每次打开App只上报一次
        try {
          if (!_realPlayReported && isPlaying && _playStartPosition != null) {
            final startMs = _playStartPosition!.inMilliseconds;
            final nowMs = position.inMilliseconds;
            final deltaMs = nowMs - startMs;
            if (deltaMs >= 2000) {
              AnalyticsService().logCustomEvent(
                eventName: 'audio_real_play',
                parameters: {
                  'audio_id': audio.id,
                  'audio_title': audio.title,
                  'start_position_ms': startMs,
                  'position_ms': nowMs,
                  'delta_ms': deltaMs,
                  'timestamp': DateTime.now().millisecondsSinceEpoch,
                  'source': 'audio_service',
                },
              );
              _realPlayReported = true;
              debugPrint('📊 [ANALYTICS] audio_real_play 上报 (audio_id=${audio.id}, delta=${deltaMs}ms)');
            }
          }
        } catch (e) {
          debugPrint('📊 [ANALYTICS] audio_real_play 上报失败: $e');
        }
      }

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

    // 监听会员权限状态变化
    try {
      // 初始化当前权限状态
      final cachedPrivilege = SubscribePrivilegeManager.instance.getCachedPrivilege();
      _hasPremium = cachedPrivilege?.isValidPremium ?? false;

      _privilegeSubscription = SubscribePrivilegeManager.instance.privilegeChanges.listen(
        (event) async {
          _hasPremium = event.privilege?.isValidPremium ?? false;
        },
        onError: (error) {
          debugPrint('🏆 [AUDIO] 权限事件流错误: $error');
        },
      );
    } catch (e) {
      debugPrint('🏆 [AUDIO] 初始化权限监听失败: $e');
    }
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
    // 并发保护：相同音频的重复加载直接复用；不同音频等待当前加载完成
    if (_currentLoadTask != null) {
      if (_loadingAudioId == audio.id) {
        debugPrint('并发加载相同音频，复用当前加载任务: ${audio.title}');
        await _currentLoadTask;
        return;
      } else {
        debugPrint('已有加载任务进行中，等待其完成后再加载新音频');
        await _currentLoadTask;
      }
    }

    _loadingAudioId = audio.id;
    _currentLoadTask = _enqueueOp<void>(() async {
      try {
        // 先完全停止并重置播放器状态
        if (currentAudio != audio) {
          updatePreloadAudio(audio);
        }

        await _stopAndReset();
        _updateAudioState(currentAudio: audio);

        // 验证音频URL
        final audioUrl = audio.audioUrl;

        if (audioUrl == null || audioUrl.isEmpty) {
          throw Exception('音频URL为空');
        }

        debugPrint(
          'loadAudio url: $audioUrl${initialPosition != null ? '，初始位置: ${initialPosition.inSeconds}秒' : ''}',
        );

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

        // 选择音频来源：预埋资产优先（同名文件），否则使用网络URL
        final audioSource = await _resolveAudioSource(audioUrl);
        // 记录加载开始时间（用于统计从加载到可播放的耗时）
        _loadStartMs = DateTime.now().millisecondsSinceEpoch;
        _loadAudioId = audio.id;
        _lastLoadInitialPositionMs = initialPosition?.inMilliseconds;
        _loadReported = false;
        // 启动性能 Trace 记录从加载到 ready 的耗时
        _loadTrace = await PerformanceService().startTrace(
          'audio_load_to_ready',
        );
        _loadTrace?.putAttribute('audio_id', audio.id);
        _loadTrace?.putAttribute('audio_title', audio.title);
        if (_lastLoadInitialPositionMs != null) {
          _loadTrace?.putAttribute(
            'initial_position_ms',
            '${_lastLoadInitialPositionMs!}',
          );
        }
        if (initialPosition != null) {
          await _setAudioSourceWithRetry(
            audioSource,
            initialPosition: initialPosition,
          );
          debugPrint('音频加载完成，初始位置: ${initialPosition.inSeconds}秒');
        } else {
          await _setAudioSourceWithRetry(audioSource);
          debugPrint('音频加载完成');
        }
      } catch (e) {
        debugPrint('装载音频时出错: $e');
        // 附加网络与设备信息，便于诊断连接中止问题
        try {
          final netInfo = await NetworkHealthyManager.instance
              .getDetailedNetworkInfo();
          debugPrint('📶 [AUDIO][ERROR] 网络详情: ${netInfo.toString()}');
        } catch (logErr) {
          debugPrint('记录网络/设备详情失败: $logErr');
        }
        rethrow; // 重新抛出异常，让调用者处理
      } finally {
        _loadingAudioId = null;
        _currentLoadTask = null;
      }
    });

    await _currentLoadTask;
  }

  // 解析并选择音频源：若启用预埋音频，则尝试匹配 assets/audios/ 同名文件
  Future<AudioSource> _resolveAudioSource(String audioUrl) async {
    if (_useEmbeddedAudios) {
      final filename = _extractFilename(audioUrl);
      if (filename != null && filename.isNotEmpty) {
        final assetPath = '$_embeddedAudiosDir/$filename';
        final exists = await _assetExists(assetPath);
        if (exists) {
          debugPrint('使用预埋音频: $assetPath');
          return AudioSource.asset(assetPath);
        } else {
          debugPrint('未找到预埋音频，使用网络URL: $audioUrl');
        }
      } else {
        debugPrint('无法解析文件名，使用网络URL: $audioUrl');
      }
    }
    // 默认使用网络URL
    return AudioSource.uri(Uri.parse(audioUrl));
  }

  // 从URL中提取文件名（最后一个path segment）
  String? _extractFilename(String url) {
    try {
      final uri = Uri.parse(url);
      if (uri.pathSegments.isNotEmpty) {
        return uri.pathSegments.last;
      }
      // 兜底：简单字符串分割
      final parts = url.split('/');
      return parts.isNotEmpty ? parts.last : null;
    } catch (_) {
      final parts = url.split('/');
      return parts.isNotEmpty ? parts.last : null;
    }
  }

  // 判断资产是否存在
  Future<bool> _assetExists(String assetPath) async {
    try {
      await rootBundle.load(assetPath);
      return true;
    } catch (_) {
      return false;
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
      
      if(!_checkAudioPermission(audio) && !_checkAudioPreviewPermission(audio, atPosition: initialPosition)){
        debugPrint('🚫 [AUDIO] 无播放权限：需会员或免费音频。audio_id=${audio.id}');

        // 派发预览边界事件
        try {
          final total = _audioPlayer.duration ?? (audio.duration ?? Duration.zero);
          final previewEnd = Duration(
            milliseconds: (total.inMilliseconds * ApiConfig.previewAudioRatio).toInt(),
          );
          _previewBoundaryController.add(
            PreviewBoundaryEvent(
              audioId: audio.id,
              position: initialPosition ?? Duration.zero,
              previewEnd: previewEnd,
              reason: 'no_permission',
            ),
          );
        } catch (_) {}
        return;
      }
      await _audioPlayer.play();
      debugPrint(
        '音频播放开始成功${initialPosition != null ? '，从${initialPosition.inSeconds}秒开始' : ''}',
      );
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
      PerformanceService().stopTrace(_loadTrace);
      // 通过 TrackingService 发送打点（记录加载到可播放的耗时）
      try {
        TrackingService.track(
          actionType: 'audio_load_to_ready',
          audioId: audio.id,
          extraData: {
            'elapsed_ms': elapsedMs,
            if (_lastLoadInitialPositionMs != null)
              'initial_position_ms': _lastLoadInitialPositionMs,
            'audio_title': audio.title,
          },
        );
        debugPrint('📊 [TRACKING] audio_load_to_ready sent (elapsed=${elapsedMs}ms)');
      } catch (e) {
        debugPrint('📊 [TRACKING] 发送 audio_load_to_ready 失败: $e');
      }
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
    try {
      // 若存在当前音频，仍需权限检查
      final audio = currentAudio;
      if (audio != null) {
        if (!_checkAudioPermission(audio) && !_checkAudioPreviewPermission(audio, atPosition: _audioPlayer.position)) {
          debugPrint('🚫 [AUDIO] 无播放权限：需会员或免费音频。');

          // 派发预览边界事件
          try {
            final total = _audioPlayer.duration ?? (audio.duration ?? Duration.zero);
            final previewEnd = Duration(
              milliseconds: (total.inMilliseconds * ApiConfig.previewAudioRatio).toInt(),
            );
            _previewBoundaryController.add(
              PreviewBoundaryEvent(
                audioId: audio.id,
                position: _audioPlayer.position,
                previewEnd: previewEnd,
                reason: 'no_permission',
              ),
            );
          } catch (_) {}
          return;
        }
      }
      await _audioPlayer.play();
    } catch (e) {
      debugPrint('播放时出错: $e');
    }
  }

  @override
  Future<void> pause() async {
    try {
      await _audioPlayer.pause();
    } catch (e) {
      debugPrint('暂停播放时出错: $e');
    }
  }

  @override
  Future<void> stop() async {
    await _enqueueOp<void>(() async {
      try {
        await _audioPlayer.stop();
      } catch (e) {
        debugPrint('停止播放时出错: $e');
      } finally {
        _updateAudioState(currentAudio: null);
        mediaItem.add(null);
      }
    });
  }

  // 跳转到指定位置
  @override
  Future<void> seek(Duration position) async {

    late Duration pos = position;
    // final Duration duration = _audioPlayer.duration ?? Duration.zero;

    // if(!_checkAudioPermission(currentAudio!) && !_checkAudioPreviewPermission(currentAudio!, atPosition: pos)){
    //   if(pos.inMilliseconds > ApiConfig.previewAudioRatio * duration.inMilliseconds){
    //     pos = Duration(milliseconds: (ApiConfig.previewAudioRatio * duration.inMilliseconds).toInt());
    //   }
    // }

    try {
      await _audioPlayer.seek(pos);
    } catch (e) {
      debugPrint('跳转播放位置时出错: $e');
    }
  }

  // 设置播放速度
  @override
  Future<void> setSpeed(double speed) async {
    try {
      await _audioPlayer.setSpeed(speed);
      _updateAudioState(speed: speed);
    } catch (e) {
      debugPrint('设置播放速度时出错: $e');
    }
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

  // -------- 加载重试增强逻辑（统一策略） --------

  bool _isTransientAbort(Object e) {
    final msg = e.toString().toLowerCase();
    return msg.contains('connection aborted') ||
        msg.contains('aborted') ||
        msg.contains('network') ||
        msg.contains('timeout');
  }

  Future<void> _setAudioSourceWithRetry(
    AudioSource source, {
    Duration? initialPosition,
  }) async {
    // 统一的重试策略，缓解偶发的连接中止
    final attempts = 4;
    final delays = [
      const Duration(milliseconds: 500),
      const Duration(seconds: 1),
      const Duration(seconds: 2),
      const Duration(seconds: 4),
    ];

    for (int i = 0; i < attempts; i++) {
      try {
        if (initialPosition != null) {
          await _audioPlayer.setAudioSource(
            source,
            initialPosition: initialPosition,
          );
        } else {
          await _audioPlayer.setAudioSource(source);
        }
        return; // 成功
      } catch (e) {
        final isLast = i == attempts - 1;
        final attemptNo = i + 1;
        debugPrint(
          '🎧 [AUDIO] setAudioSource 失败(第$attemptNo/${attempts}次): $e',
        );

        // 捕获详细网络状态，帮助定位设备特有问题
        try {
          final netInfo = await NetworkHealthyManager.instance
              .getDetailedNetworkInfo();
          debugPrint('📶 [AUDIO] 当前网络详情: ${netInfo.toString()}');
        } catch (_) {}

        if (!_isTransientAbort(e) || isLast) {
          rethrow; // 非瞬时错误或已达最大重试次数，抛出
        }

        // 退避等待后重试
        final delay = delays[i];
        await Future.delayed(delay);
      }
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
    _networkStatusSubscription = NetworkHealthyManager
        .instance
        .networkStatusStream
        .listen((status) {
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

  bool _checkAudioPermission(AudioItem? audio) {
    if(audio == null) return false;
    return (audio.isFree || _hasPremium);  
  }

  bool _checkAudioPreviewPermission(AudioItem? audio, {Duration? atPosition}) {
    if(audio == null) return false;
    final position = atPosition ?? _audioPlayer.position;
    final duration = _audioPlayer.duration;
    if (duration != null) {
      final previewEndMs = (duration.inMilliseconds * ApiConfig.previewAudioRatio).floor();
      return position.inMilliseconds <= previewEndMs;
    }
    return false;
  }
}

// 播放权限检查：会员或免费音频

