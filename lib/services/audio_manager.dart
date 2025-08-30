import 'package:audio_service/audio_service.dart';
import 'audio_service.dart';
import '../models/audio_model.dart';

class AudioManager {
  static AudioManager? _instance;
  static AudioManager get instance => _instance ??= AudioManager._internal();

  AudioPlayerService? _audioService;
  bool _isInitialized = false;

  AudioManager._internal();

  // 初始化音频服务
  Future<void> init() async {
    if (!_isInitialized) {
      _audioService = await AudioService.init(
        builder: () => AudioPlayerService(),
        config: const AudioServiceConfig(
          androidNotificationChannelId: 'com.hushie.audio',
          androidNotificationChannelName: 'Hushie Audio',
          androidNotificationOngoing: true,
          androidStopForegroundOnPause: true,
        ),
      );
      _isInitialized = true;
    }
  }

  // 获取音频服务实例
  AudioPlayerService get audioService {
    if (!_isInitialized || _audioService == null) {
      throw Exception('AudioManager not initialized. Call init() first.');
    }
    return _audioService!;
  }

  // 播放音频
  Future<void> playAudio(AudioModel audio) async {
    await init();
    await audioService.playAudio(audio);
  }

  // 播放/暂停
  Future<void> togglePlayPause() async {
    await init();
    if (audioService.isPlaying) {
      await audioService.pause();
    } else {
      await audioService.play();
    }
  }

  // 暂停
  Future<void> pause() async {
    await init();
    await audioService.pause();
  }

  // 停止
  Future<void> stop() async {
    await init();
    await audioService.stop();
  }

  // 跳转
  Future<void> seek(Duration position) async {
    await init();
    await audioService.seek(position);
  }

  // 设置播放速度
  Future<void> setSpeed(double speed) async {
    await init();
    await audioService.setSpeed(speed);
  }

  // 快进30秒
  Future<void> fastForward() async {
    await init();
    await audioService.fastForward();
  }

  // 快退30秒
  Future<void> rewind() async {
    await init();
    await audioService.rewind();
  }

  // 获取播放状态流
  Stream<bool> get isPlayingStream async* {
    await init();
    yield* audioService.isPlayingStream;
  }

  // 获取当前音频流
  Stream<AudioModel?> get currentAudioStream async* {
    await init();
    yield* audioService.currentAudioStream;
  }

  // 获取播放位置流
  Stream<Duration> get positionStream async* {
    await init();
    yield* audioService.positionStream;
  }

  // 获取总时长流
  Stream<Duration> get durationStream async* {
    await init();
    yield* audioService.durationStream;
  }

  // 获取播放速度流
  Stream<double> get speedStream async* {
    await init();
    yield* audioService.speedStream;
  }

  // 获取当前状态
  bool get isPlaying {
    if (!_isInitialized || _audioService == null) return false;
    return audioService.isPlaying;
  }

  AudioModel? get currentAudio {
    if (!_isInitialized || _audioService == null) return null;
    return audioService.currentAudio;
  }

  Duration get position {
    if (!_isInitialized || _audioService == null) return Duration.zero;
    return audioService.position;
  }

  Duration get duration {
    if (!_isInitialized || _audioService == null) return Duration.zero;
    return audioService.duration;
  }

  double get speed {
    if (!_isInitialized || _audioService == null) return 1.0;
    return audioService.speed;
  }

  // 清理资源
  Future<void> dispose() async {
    if (_audioService != null) {
      await _audioService!.dispose();
    }
    _audioService = null;
    _isInitialized = false;
    _instance = null;
  }
}
