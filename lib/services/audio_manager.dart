import 'dart:async';
import 'package:rxdart/rxdart.dart';
import 'package:audio_service/audio_service.dart';
import 'package:just_audio/just_audio.dart';
import '../models/audio_item.dart';
import '../models/audio_duration_info.dart';
import 'audio_service.dart';
import 'audio_playlist.dart';
import 'audio_history_manager.dart';
import 'api/audio_list_service.dart';
import 'package:flutter/foundation.dart';

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
  final BehaviorSubject<bool> _canPlayAllDurationSubject =
      BehaviorSubject<bool>.seeded(false);
  final BehaviorSubject<bool> _canAutoPlayNextSubject =
      BehaviorSubject<bool>.seeded(false);

  // 预览区间即将超出事件流
  static final StreamController<PreviewOutEvent> _previewOutController =
      StreamController<PreviewOutEvent>.broadcast();

  /// 预览区间即将超出事件流（供外部订阅）
  static Stream<PreviewOutEvent> get previewOutEvents =>
      _previewOutController.stream;

  AudioManager._internal();

  // 初始化音频服务（延迟初始化）
  Future<void> _ensureInitialized() async {
    // 如果已经初始化完成，直接返回
    if (_isInitialized && _audioService != null) {
      debugPrint('AudioService already initialized');
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
          androidNotificationChannelId: 'com.hushie.ai',
          androidNotificationChannelName: 'Hushie.AI',
          androidNotificationOngoing: true,
          androidStopForegroundOnPause: true,
          androidNotificationIcon: 'drawable/ic_notification',
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

  // 设置流监听
  void _setupStreamListeners() {
    if (_audioService == null) {
      debugPrint('Cannot setup stream listeners: _audioService is null');
      return;
    }

    debugPrint('Setting up AudioManager stream listeners...');
    // 监听统一的音频状态流
    _audioService!.audioStateStream.listen((audioState) {
      debugPrint('AudioManager received audioState: isPlaying=${audioState.isPlaying}');
      
      // 管理播放列表
      final audio = audioState.currentAudio;
      if (audio != null) {
        final isInPlaylist =
            AudioPlaylist.instance.getAudioItemById(audio.id) != null;

        if (!isInPlaylist) {
          AudioPlaylist.instance.addAudio(audio);
        }

        _managePlaylist(
          audio.id,
        ); // 管理播放列表，将当前音频添加到播放列表，如果当前音频是播放列表最后一条，则继续补充下面的播放列表
      }
      
      // 检查预览区间
      final position = audioState.position;
      if (_checkWillOutPreview(position)) {
        // 发送预览区间即将超出事件
        pause();
        _previewOutController.add(PreviewOutEvent(position: position));
      }
      
      // 更新播放器状态
      _playerStateSubject.add(audioState.playerState);
      _checkPlaybackCompletion(audioState.playerState);
    });
  }

  // 检查是否超出预览区间
  bool _checkWillOutPreview(Duration position) {
    if (currentAudio == null ||
        !isPlaying ||
        _canPlayAllDurationSubject.value) {
      return false;
    }

    final previewStart = currentAudio!.previewStart ?? Duration.zero;
    final previewDuration = currentAudio!.previewDuration ?? Duration.zero;
    final hasPreview =
        previewStart >= Duration.zero && previewDuration > Duration.zero;

    if (hasPreview && position >= previewStart + previewDuration) {
      debugPrint('[playAudio] position: $position previewStart: $previewStart previewDuration: $previewDuration');
      return true;
    }
    return false;
  }

  Duration _transformPosition(Duration position, {AudioItem? audio}) {
    // 如果能播放全部时长，直接返回原位置
    if (_canPlayAllDurationSubject.value) {
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
  void _checkPlaybackCompletion(PlayerState playerState) {
    final canAutoPlayNext = _canAutoPlayNextSubject.value;
    final currentAudio = this.currentAudio;
    if (playerState.processingState == ProcessingState.completed &&
        currentAudio != null) {
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

  // 兼容性方法：保持原有的init接口，但改为延迟初始化
  Future<void> init() async {
    debugPrint('AudioManager.init() called');
    
    // 先初始化音频历史管理器（确保数据库可用）
    await AudioHistoryManager.instance.initialize();
    debugPrint('AudioManager: AudioHistoryManager 初始化完成');

    // 初始化AudioPlaylist
    await AudioPlaylist.instance.initialize();
    debugPrint('AudioManager: AudioPlaylist 初始化完成');

    // 使用统一的初始化方法，避免重复初始化
    await _ensureInitialized();
    debugPrint('AudioManager: AudioService 初始化完成');

    // 开启播放历史记录监听（通过AudioManager的状态流）
    AudioHistoryManager.instance.startListening();

    // 从播放历史列表中获取最后一条播放记录
    final lastHistory = await AudioHistoryManager.instance.getAudioHistory();
    if (lastHistory.isNotEmpty) {
      debugPrint('AudioManager: 最后一条播放记录: ${lastHistory.first.title}');
      playAudio(lastHistory.first, autoPlay: false);
    } else {
      debugPrint('AudioManager: 没有播放历史记录');
    }

    // 不在这里强制初始化AudioService，而是标记为可以初始化
    // 实际初始化将在第一次使用时进行
    return;
  }

  // 获取音频服务实例
  AudioPlayerService? get audioService {
    return _audioService;
  }

  // 播放音频
  Future<void> playAudio(AudioItem audio, {bool? autoPlay = true}) async {
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

    // 2. 从历史列表获取新音频的播放进度，作为起始播放进度
    final position = AudioHistoryManager.instance.getPlaybackPosition(audio.id);
    // 3. 通过 _transformPosition 过滤 initialPosition 得到正确的 initialPosition
    final transformedPosition = _transformPosition(position, audio: audio );

    debugPrint('[playAudio]: 音频预览: 开始 ${audio.previewStart}, 长度 ${audio.previewDuration}');
    debugPrint('[playAudio]: 从历史记录获取的播放位置: $position');
    debugPrint('[playAudio]: 转换后的播放位置: $transformedPosition');

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

  /// 管理播放列表（清理和补充）
  Future<void> _managePlaylist(String currentAudioId) async {
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
    return _audioService?.currentState.duration ?? Duration.zero;
  }

  double get speed {
    return _audioService?.currentState.speed ?? 1.0;
  }

  PlayerState get playerState {
    return _playerStateSubject.value;
  }

  bool get canPlayAllDuration {
    return _canPlayAllDurationSubject.value;
  }

  bool get canAutoPlayNext {
    return _canAutoPlayNextSubject.value;
  }

  Duration get bufferedPosition {
    return _audioService?.currentState.bufferedPosition ?? Duration.zero;
  }

  // 获取状态流
  Stream<bool> get canPlayAllDurationStream {
    return _canPlayAllDurationSubject.stream;
  }

  Stream<bool> get canAutoPlayNextStream {
    return _canAutoPlayNextSubject.stream;
  }

  // 设置状态
  void setCanPlayAllDuration(bool canPlay) {
    _canPlayAllDurationSubject.add(canPlay);
    debugPrint('设置canPlayAllDuration: $canPlay');
  }

  void setCanAutoPlayNext(bool canAutoPlay) {
    _canAutoPlayNextSubject.add(canAutoPlay);
    debugPrint('设置canAutoPlayNext: $canAutoPlay');
  }

  // 清理资源
  Future<void> dispose() async {
    // 在销毁前记录最后的播放停止
    if (_audioService != null) {
      await _audioService!.dispose();
    }

    // 关闭所有BehaviorSubject
    await _playerStateSubject.close();
    await _canPlayAllDurationSubject.close();
    await _canAutoPlayNextSubject.close();

    // 关闭StreamController
    await _previewOutController.close();

    _audioService = null;
  }
}
