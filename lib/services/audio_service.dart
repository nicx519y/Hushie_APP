import 'package:audio_service/audio_service.dart';
import 'package:just_audio/just_audio.dart';
import 'package:rxdart/rxdart.dart';
import '../models/audio_item.dart';

class AudioPlayerService extends BaseAudioHandler {
  final AudioPlayer _audioPlayer = AudioPlayer();

  // 播放状态流
  final BehaviorSubject<bool> _isPlayingSubject = BehaviorSubject<bool>.seeded(
    false,
  );
  final BehaviorSubject<AudioItem?> _currentAudioSubject =
      BehaviorSubject<AudioItem?>.seeded(null);
  final BehaviorSubject<Duration> _positionSubject =
      BehaviorSubject<Duration>.seeded(Duration.zero);
  final BehaviorSubject<Duration> _durationSubject =
      BehaviorSubject<Duration>.seeded(Duration.zero);
  final BehaviorSubject<double> _speedSubject = BehaviorSubject<double>.seeded(
    1.0,
  );
  final BehaviorSubject<PlayerState> _playerStateSubject = BehaviorSubject<PlayerState>.seeded(
    PlayerState(false, ProcessingState.idle)
  );
  final BehaviorSubject<Duration> _bufferedPositionSubject = BehaviorSubject<Duration>.seeded(
    Duration.zero,
  );

  // 公开的流
  Stream<bool> get isPlayingStream => _isPlayingSubject.stream;
  Stream<AudioItem?> get currentAudioStream => _currentAudioSubject.stream;
  Stream<Duration> get positionStream => _positionSubject.stream;
  Stream<Duration> get durationStream => _durationSubject.stream;
  Stream<double> get speedStream => _speedSubject.stream;
  Stream<PlayerState> get playerStateStream => _playerStateSubject.stream;
  Stream<Duration> get bufferedPositionStream => _bufferedPositionSubject.stream;

  // 当前状态的getter
  bool get isPlaying => _isPlayingSubject.value;
  AudioItem? get currentAudio => _currentAudioSubject.value;
  Duration get position => _positionSubject.value;
  Duration get duration => _durationSubject.value;
  double get speed => _speedSubject.value;
  PlayerState get playerState => _playerStateSubject.value;
  Duration get bufferedPosition => _bufferedPositionSubject.value;

  AudioPlayerService() {
    _init();
  }

  void _init() {
    // 监听播放状态变化
    _audioPlayer.playingStream.listen((playing) {
      _isPlayingSubject.add(playing);
      _broadcastState();
    });

    // 监听播放位置变化
    _audioPlayer.positionStream.listen((position) {
      _positionSubject.add(position);
      _broadcastState();
    });

    // 监听播放时长变化
    _audioPlayer.durationStream.listen((duration) {
      if (duration != null) {
        _durationSubject.add(duration);
      }
    });

    // 监听播放速度变化
    _audioPlayer.speedStream.listen((speed) {
      _speedSubject.add(speed);
    });

    // 监听播放完成
    _audioPlayer.playerStateStream.listen((state) {
      _playerStateSubject.add(state);
    });

    // 监听缓冲位置变化
    _audioPlayer.bufferedPositionStream.listen((bufferedPosition) {
      _bufferedPositionSubject.add(bufferedPosition);
    });
  }

  Future<void> loadAudio(AudioItem audio) async {
    try {
      // 先完全停止并重置播放器状态

      await _stopAndReset();
      _currentAudioSubject.add(audio);

      // 验证音频URL
      final audioUrl = audio.audioUrl;

      if (audioUrl == null || audioUrl.isEmpty) {
        throw Exception('音频URL为空');
      }

      print('loadAudio url: $audioUrl');

      // 安全地获取封面URL
      String? coverUrlString;
      try {
        final bestResolution = audio.cover.getBestResolution(80);
        coverUrlString = bestResolution.url;
        print('loadAudio cover url: $coverUrlString');
      } catch (e) {
        print('获取封面URL失败: $e，使用默认封面');
        coverUrlString = null;
      }

      // 设置MediaItem用于通知栏显示
      final mediaItemData = MediaItem(
        id: audio.id,
        album: "Hushie",
        title: audio.title,
        artist: audio.author,
        duration: audio.durationMs != null
            ? Duration(milliseconds: audio.durationMs!)
            : Duration.zero,
        artUri: coverUrlString != null ? Uri.parse(coverUrlString) : null,
        extras: audio.toMap(),
      );

      mediaItem.add(mediaItemData);

      // 加载音频文件
      await _audioPlayer.setUrl(audioUrl);
    } catch (e) {
      print('装载音频时出错: $e');
      rethrow; // 重新抛出异常，让调用者处理
    }
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

  // 加载并播放音频
  Future<void> playAudio(AudioItem audio) async {
    try {
      // 只有当音频ID不同时才重新加载，避免不必要的buffering
      final currentAudio = _currentAudioSubject.value;
      if (currentAudio == null || currentAudio.id != audio.id) {
        print('加载新音频: ${audio.title} (ID: ${audio.id})');
        await loadAudio(audio);
      } else {
        print('相同音频，跳过重新加载: ${audio.title} (ID: ${audio.id})');
      }
      
      await _audioPlayer.play();
      print('音频播放开始成功');
    } catch (e) {
      print('播放音频时出错: $e');
      await stop();
    }
  }

  /// 清理和验证URL
  String? _cleanAndValidateUrl(String url) {
    if (url.isEmpty) return null;

    // 移除首尾空白字符
    String cleaned = url.trim();

    // 检查是否包含无效字符
    if (cleaned.contains(' ')) {
      // 如果包含空格，尝试编码
      cleaned = cleaned.replaceAll(' ', '%20');
    }

    // 检查是否以有效的协议开头
    if (cleaned.startsWith('http://') ||
        cleaned.startsWith('https://') ||
        cleaned.startsWith('file://') ||
        cleaned.startsWith('content://')) {
      return cleaned;
    }

    // 如果没有协议，检查是否是有效的域名或路径
    if (cleaned.contains('.') || cleaned.startsWith('/')) {
      return cleaned;
    }

    // 如果都不符合，返回null表示无效
    return null;
  }

  // 私有方法：停止并重置播放器
  Future<void> _stopAndReset() async {
    try {
      if (_audioPlayer.playing) {
        await _audioPlayer.stop();
      }
      // 添加小延迟确保资源完全释放
      await Future.delayed(const Duration(milliseconds: 100));
    } catch (e) {
      print('停止播放器时出错: $e');
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
      print('停止播放时出错: $e');
    } finally {
      _currentAudioSubject.add(null);
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
    _speedSubject.add(speed);
  }

  // 广播播放状态
  void _broadcastState() {
    final playing = _audioPlayer.playing;
    final processingState = _getProcessingState();

    playbackState.add(
      PlaybackState(
        controls: [
          MediaControl.rewind,
          if (playing) MediaControl.pause else MediaControl.play,
          MediaControl.fastForward,
          MediaControl.stop,
        ],
        systemActions: {
          MediaAction.seek,
          MediaAction.seekForward,
          MediaAction.seekBackward,
        },
        androidCompactActionIndices: const [0, 1, 3],
        processingState: processingState,
        playing: playing,
        updatePosition: _audioPlayer.position,
        bufferedPosition: _audioPlayer.bufferedPosition,
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

  // 清理资源
  Future<void> dispose() async {
    await _audioPlayer.dispose();
    await _isPlayingSubject.close();
    await _currentAudioSubject.close();
    await _positionSubject.close();
    await _durationSubject.close();
    await _speedSubject.close();
    await _playerStateSubject.close();
    await _bufferedPositionSubject.close();
  }
}
