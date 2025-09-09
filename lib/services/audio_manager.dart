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

class AudioManager {
  static final AudioManager _instance = AudioManager._internal();
  static AudioManager get instance => _instance;

  AudioPlayerService? _audioService;
  final BehaviorSubject<bool> _isPlayingSubject = BehaviorSubject<bool>.seeded(
    false,
  );
  final BehaviorSubject<AudioItem?> _currentAudioSubject =
      BehaviorSubject<AudioItem?>.seeded(null);
  final BehaviorSubject<Duration> _positionSubject =
      BehaviorSubject<Duration>.seeded(Duration.zero);
  final BehaviorSubject<AudioDurationInfo> _durationSubject =
      BehaviorSubject<AudioDurationInfo>.seeded(
        const AudioDurationInfo(totalDuration: Duration.zero)
      );
  final BehaviorSubject<double> _speedSubject = BehaviorSubject<double>.seeded(
    1.0,
  );
  final BehaviorSubject<PlayerState> _playerStateSubject = BehaviorSubject<PlayerState>.seeded(
    PlayerState(false, ProcessingState.idle),
  );
  final BehaviorSubject<bool> _canPlayAllDurationSubject = BehaviorSubject<bool>.seeded(
    false,
  );
  final BehaviorSubject<bool> _canAutoPlayNextSubject = BehaviorSubject<bool>.seeded(
    false,
  );
  final BehaviorSubject<Duration> _bufferedPositionSubject = BehaviorSubject<Duration>.seeded(
    Duration.zero,
  );

  AudioManager._internal();

  // 初始化音频服务（延迟初始化）
  Future<void> _ensureInitialized() async {
    if (_audioService != null) return;

    try {
      _audioService = await AudioService.init(
        builder: () => AudioPlayerService(),
        config: const AudioServiceConfig(
          androidNotificationChannelId: 'com.hushie.audio',
          androidNotificationChannelName: 'Hushie Audio',
          androidNotificationOngoing: true,
          androidStopForegroundOnPause: true,
          androidNotificationIcon: 'mipmap/logo',
        ),
      );

      // 初始化成功后，设置流监听
      _setupStreamListeners();
    } catch (e) {
      debugPrint('AudioService初始化失败: $e');
      _audioService = null;
    }
  }

  // 设置流监听
  void _setupStreamListeners() {
    if (_audioService == null) return;

    // 监听播放状态
    _audioService!.isPlayingStream.listen((isPlaying) {
      _isPlayingSubject.add(isPlaying);
    });

    // 监听当前音频
    _audioService!.currentAudioStream.listen((audio) {
      _currentAudioSubject.add(audio);

      // 更新时长信息
      final currentDurationInfo = _durationSubject.value;
      final newDurationInfo = AudioDurationInfo.withValidation(
        totalDuration: currentDurationInfo.totalDuration,
        previewStart: audio?.previewStart,
        previewDuration: audio?.previewDuration,
      );
      _durationSubject.add(newDurationInfo);

      // 管理播放列表
      if (audio != null) {
        final isInPlaylist =
            AudioPlaylist.instance.getAudioItemById(audio.id) != null;

        if (!isInPlaylist) {
          AudioPlaylist.instance.addAudio(audio);
        }

        _managePlaylist(audio.id);
        
        // 检查是否需要从预览开始位置播放
        final canPlayAllDuration = _canPlayAllDurationSubject.value;
        if (!canPlayAllDuration 
          && audio.previewStart != null 
          && audio.previewStart! > Duration.zero 
          && audio.previewDuration != null 
          && audio.previewDuration! > Duration.zero) {
          debugPrint('音频改变，需要从预览开始位置播放');
          // 等待音频加载完成后再seek到预览开始位置
          _waitForAudioLoadedAndSeek(audio.previewStart!);
        }
      }
    });

    // 监听播放位置
    _audioService!.positionStream.listen((position) {
      _positionSubject.add(position);
    });

    // 监听播放时长
    _audioService!.durationStream.listen((duration) {
      final currentAudio = _currentAudioSubject.value;
      final newDurationInfo = AudioDurationInfo.withValidation(
        totalDuration: duration,
        previewStart: currentAudio?.previewStart,
        previewDuration: currentAudio?.previewDuration,
      );
      _durationSubject.add(newDurationInfo);
    });

    // 监听播放速度
    _audioService!.speedStream.listen((speed) {
      _speedSubject.add(speed);
    });

    // 监听播放位置，检查预览区间限制
    _positionSubject.stream.listen((position) {
      _checkPreviewDurationLimit(position);
    });

    // 监听播放器状态变化
    _audioService!.playerStateStream.listen((playerState) {
      _playerStateSubject.add(playerState);
      _checkPlaybackCompletion(playerState);
    });

    // 监听缓冲位置
    _audioService!.bufferedPositionStream.listen((bufferedPosition) {
      _bufferedPositionSubject.add(bufferedPosition);
    });

  }

  Duration _transformPosition(Duration position) {
    // 如果不能播放全部时长，直接返回原位置
    if (!_canPlayAllDurationSubject.value) {
      return position;
    }
    
    final currentAudio = _currentAudioSubject.value;
    if (currentAudio == null) {
      return position;
    }
    
    final previewStart = currentAudio.previewStart;
    final previewDuration = currentAudio.previewDuration;
    
    // 检查预览参数是否有效
    if (previewStart == null || previewStart < Duration.zero ||
        previewDuration == null || previewDuration <= Duration.zero) {
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
    final currentAudio = _currentAudioSubject.value;
    if(playerState.processingState == ProcessingState.completed && currentAudio != null) {
      if(canAutoPlayNext) {
        _playNextAudio(currentAudio.id);
      } else {
        pause();
      }
    }
  }

  /// 检查预览时长限制
  void _checkPreviewDurationLimit(Duration position) {
    final currentAudio = _currentAudioSubject.value;
    final canPlayAllDuration = _canPlayAllDurationSubject.value;
    final isPlaying = _isPlayingSubject.value;

    if (!canPlayAllDuration && currentAudio != null && isPlaying) {
      final previewStart = currentAudio.previewStart ?? Duration.zero;
      final previewDuration = currentAudio.previewDuration ?? Duration.zero;
      
      // 当previewStart > 0 && previewDuration > 0时，检查是否超出预览区间
      if (previewStart > Duration.zero && previewDuration > Duration.zero) {
        final previewEnd = previewStart + previewDuration;
        
        // 如果播放位置超过预览区间末尾，则停止播放
        if (position >= previewEnd) {
          pause();
          debugPrint('预览时长限制：播放到预览区间末尾，停止播放');
        }
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
    // 先初始化音频历史管理器（确保数据库可用）
    await AudioHistoryManager.instance.initialize();
    debugPrint('AudioManager: AudioHistoryManager 初始化完成');

    // 初始化AudioPlaylist
    await AudioPlaylist.instance.initialize();
    debugPrint('AudioManager: AudioPlaylist 初始化完成');

    await _ensureInitialized();
    debugPrint('AudioManager: AudioService 初始化完成');

    // 设置音频服务，开启播放历史记录
    AudioHistoryManager.instance.setAudioService(_audioService!);

    // 从播放历史列表中获取最后一条播放记录
    final lastHistory = await AudioHistoryManager.instance.getAudioHistory();
    if (lastHistory.isNotEmpty) {
      debugPrint('AudioManager: 最后一条播放记录: ${lastHistory.first.title}');
      AudioPlaylist.instance.addAudio(lastHistory.first);
    } else {
      debugPrint('AudioManager: 没有播放历史记录');
    }

    // 播放最后的音频并暂停
    await _loadLastAudio();

    // 不在这里强制初始化AudioService，而是标记为可以初始化
    // 实际初始化将在第一次使用时进行
    return;
  }

  /// 播放最后的音频并暂停
  Future<void> _loadLastAudio() async {
    try {
      final lastAudio = AudioPlaylist.instance.getLastLoadedAudio();
      if (lastAudio != null) {
        final audioItem = AudioPlaylist.instance.getAudioItemById(lastAudio.id);
        if (audioItem != null) {
          // await _ensureInitialized();
          await _audioService!.loadAudio(audioItem);
        }
      }
    } catch (e) {
      debugPrint('播放最后音频失败: $e');
    }
  }

  // 获取音频服务实例
  AudioPlayerService? get audioService {
    return _audioService;
  }

  // 播放音频
  Future<void> playAudio(AudioItem audio) async {
    // 1. 如果 audio 和当前在播放的 audio id 相同，则直接 return
    final currentAudio = _currentAudioSubject.value;

    if (currentAudio != null && currentAudio.id == audio.id) {
      debugPrint('相同音频正在播放，跳过: ${audio.title} (ID: ${audio.id})');
      return;
    }

    // 2. 从历史列表获取新音频的播放进度，作为起始播放进度
    final position = AudioHistoryManager.instance.getPlaybackPosition(audio.id);
    
    // 3. 通过 _transformPosition 过滤 initialPosition 得到正确的 initialPosition
    final transformedPosition = _transformPosition(position);

    try {
      // await _ensureInitialized();
      if (_audioService != null) {
        await _audioService!.playAudio(audio, initialPosition: transformedPosition);
        

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
      debugPrint('AudioManager: seek到位置 $seekPosition (原始位置: $position)');
      
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

  // 获取播放状态流 - 修复版本
  Stream<bool> get isPlayingStream {
    return _isPlayingSubject.stream;
  }

  // 获取当前音频流 - 修复版本
  Stream<AudioItem?> get currentAudioStream {
    return _currentAudioSubject.stream;
  }

  // 获取播放位置流 - 修复版本
  Stream<Duration> get positionStream {
    return _positionSubject.stream;
  }

  // 获取总时长流 - 修复版本
  Stream<AudioDurationInfo> get durationStream {
    return _durationSubject.stream;
  }

  // 获取播放速度流 - 修复版本
  Stream<double> get speedStream {
    return _speedSubject.stream;
  }

  // 获取播放器状态流
  Stream<PlayerState> get playerStateStream {
    return _playerStateSubject.stream;
  }

  // 获取缓冲位置流
  Stream<Duration> get bufferedPositionStream {
    return _bufferedPositionSubject.stream;
  }

  // 获取当前状态
  bool get isPlaying {
    return _isPlayingSubject.value;
  }

  AudioItem? get currentAudio {
    return _currentAudioSubject.value;
  }

  Duration get position {
    return _positionSubject.value;
  }

  AudioDurationInfo get durationInfo {
    return _durationSubject.value;
  }

  Duration get duration {
    return _durationSubject.value.totalDuration;
  }

  double get speed {
    return _speedSubject.value;
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
    return _bufferedPositionSubject.value;
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

  /// 等待音频加载完成后进行seek操作
  void _waitForAudioLoadedAndSeek(Duration seekPosition) {
    // 监听播放器状态，等待音频加载完成
    StreamSubscription? subscription;
    subscription = _playerStateSubject.stream.listen((playerState) {
      // 当音频加载完成且不是loading状态时，进行seek操作
      if (playerState.processingState == ProcessingState.ready ||
          playerState.processingState == ProcessingState.buffering) {
        subscription?.cancel();
        
        // 延迟一小段时间确保音频完全准备好
        Timer(const Duration(milliseconds: 100), () async {
          try {
            await _audioService?.seek(seekPosition);
            debugPrint('音频加载完成后seek到预览开始位置: $seekPosition');
          } catch (e) {
            debugPrint('延迟seek操作失败: $e');
          }
        });
      }
    });
    
  }

  // 清理资源
  Future<void> dispose() async {
    // 在销毁前记录最后的播放停止
    if (_audioService != null) {
      await _audioService!.dispose();
    }

    // 关闭所有BehaviorSubject
    await _isPlayingSubject.close();
    await _currentAudioSubject.close();
    await _positionSubject.close();
    await _durationSubject.close();
    await _speedSubject.close();
    await _playerStateSubject.close();
    await _canPlayAllDurationSubject.close();
    await _canAutoPlayNextSubject.close();
    await _bufferedPositionSubject.close();

    _audioService = null;
  }
}
