import 'package:audio_service/audio_service.dart';
import 'package:just_audio/just_audio.dart';
import 'package:rxdart/rxdart.dart';
import '../models/audio_model.dart';

class AudioPlayerService extends BaseAudioHandler {
  final AudioPlayer _audioPlayer = AudioPlayer();

  // 播放状态流
  final BehaviorSubject<bool> _isPlayingSubject = BehaviorSubject<bool>.seeded(
    false,
  );
  final BehaviorSubject<AudioModel?> _currentAudioSubject =
      BehaviorSubject<AudioModel?>.seeded(null);
  final BehaviorSubject<Duration> _positionSubject =
      BehaviorSubject<Duration>.seeded(Duration.zero);
  final BehaviorSubject<Duration> _durationSubject =
      BehaviorSubject<Duration>.seeded(Duration.zero);
  final BehaviorSubject<double> _speedSubject = BehaviorSubject<double>.seeded(
    1.0,
  );

  // 公开的流
  Stream<bool> get isPlayingStream => _isPlayingSubject.stream;
  Stream<AudioModel?> get currentAudioStream => _currentAudioSubject.stream;
  Stream<Duration> get positionStream => _positionSubject.stream;
  Stream<Duration> get durationStream => _durationSubject.stream;
  Stream<double> get speedStream => _speedSubject.stream;

  // 当前状态的getter
  bool get isPlaying => _isPlayingSubject.value;
  AudioModel? get currentAudio => _currentAudioSubject.value;
  Duration get position => _positionSubject.value;
  Duration get duration => _durationSubject.value;
  double get speed => _speedSubject.value;

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
      if (state.processingState == ProcessingState.completed) {
        _onPlaybackCompleted();
      }
    });
  }

  // 加载并播放音频
  Future<void> playAudio(AudioModel audio) async {
    try {
      print('开始播放音频: ${audio.title} (ID: ${audio.id})');

      // 先完全停止并重置播放器状态
      await _stopAndReset();

      _currentAudioSubject.add(audio);

      // 设置MediaItem用于通知栏显示
      mediaItem.add(
        MediaItem(
          id: audio.id,
          album: "Hushie",
          title: audio.title,
          artist: audio.artist,
          duration: audio.duration,
          artUri: Uri.parse(audio.coverUrl.getBestResolution(80).url),
          extras: audio.toJson(),
        ),
      );

      print('正在加载音频文件: ${audio.audioUrl}');
      // 加载音频文件
      await _audioPlayer.setUrl(audio.audioUrl);

      print('开始播放音频');
      // 开始播放
      await _audioPlayer.play();
      print('音频播放开始成功');
    } catch (e) {
      print('播放音频时出错: $e');
      await stop();
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

  // 播放完成回调
  void _onPlaybackCompleted() {
    // 可以在这里实现自动播放下一首的逻辑
    stop();
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
  }
}
