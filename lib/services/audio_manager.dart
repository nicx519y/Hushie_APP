import 'package:audio_service/audio_service.dart';
import 'package:rxdart/rxdart.dart';
import 'audio_service.dart';
import '../models/audio_model.dart';
import 'audio_data_pool.dart';
import 'audio_history_manager.dart';

class AudioManager {
  static AudioManager? _instance;
  static AudioManager get instance => _instance ??= AudioManager._internal();

  AudioPlayerService? _audioService;
  bool _isInitialized = false;
  bool _isInitializing = false;

  // 使用BehaviorSubject来管理状态流
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

  AudioManager._internal();

  // 初始化音频服务（延迟初始化）
  Future<void> _ensureInitialized() async {
    if (_isInitialized || _isInitializing) return;

    _isInitializing = true;
    try {
      _audioService = await AudioService.init(
        builder: () => AudioPlayerService(),
        config: const AudioServiceConfig(
          androidNotificationChannelId: 'com.hushie.audio',
          androidNotificationChannelName: 'Hushie Audio',
          androidNotificationOngoing: true,
          androidStopForegroundOnPause: true,
        ),
      );

      // 初始化成功后，设置流监听
      _setupStreamListeners();
      _isInitialized = true;
    } catch (e) {
      print('AudioService初始化失败: $e');
      _audioService = null;
      _isInitialized = false;
    } finally {
      _isInitializing = false;
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
    });

    // 监听播放位置
    _audioService!.positionStream.listen((position) {
      _positionSubject.add(position);
    });

    // 监听播放时长
    _audioService!.durationStream.listen((duration) {
      _durationSubject.add(duration);
    });

    // 监听播放速度
    _audioService!.speedStream.listen((speed) {
      _speedSubject.add(speed);
    });
  }

  // 兼容性方法：保持原有的init接口，但改为延迟初始化
  Future<void> init() async {
    // 不在这里强制初始化，而是标记为可以初始化
    // 实际初始化将在第一次使用时进行
    return;
  }

  // 获取音频服务实例
  AudioPlayerService? get audioService {
    return _audioService;
  }

  // 播放音频
  Future<void> playAudio(AudioModel audio) async {
    await _ensureInitialized();
    if (_audioService != null) {
      // 记录播放开始
      await AudioHistoryManager.instance.recordPlayStart(audio);
      await _audioService!.playAudio(audio);
    } else {
      print('音频服务未初始化，无法播放音频');
    }
  }

  // 通过 ID 播放音频（从数据池获取）
  Future<bool> playAudioById(String audioId) async {
    try {
      // 从数据池获取音频模型
      final audioModel = AudioDataPool.instance.getAudioModelById(audioId);

      if (audioModel == null) {
        print('音频数据池中未找到 ID: $audioId 的音频');
        return false;
      }

      // 播放音频
      await playAudio(audioModel);
      print('开始播放音频: ${audioModel.title} (ID: $audioId)');
      return true;
    } catch (e) {
      print('通过 ID 播放音频失败: $e');
      return false;
    }
  }

  // 播放/暂停
  Future<void> togglePlayPause() async {
    await _ensureInitialized();
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
    await _ensureInitialized();
    if (_audioService != null) {
      // 暂停时记录播放停止（包含当前进度和停止追踪）
      final currentAudio = _currentAudioSubject.value;
      if (currentAudio != null) {
        final currentPosition = _positionSubject.value;
        final totalDuration = _durationSubject.value;
        await AudioHistoryManager.instance.recordPlayStop(
          currentAudio.id,
          currentPosition,
          totalDuration,
        );
      }

      await _audioService!.pause();
    }
  }

  // 停止
  Future<void> stop() async {
    await _ensureInitialized();
    if (_audioService != null) {
      // 记录播放停止（包含完成状态判断和停止进度追踪）
      final currentAudio = _currentAudioSubject.value;
      if (currentAudio != null) {
        final currentPosition = _positionSubject.value;
        final totalDuration = _durationSubject.value;
        await AudioHistoryManager.instance.recordPlayStop(
          currentAudio.id,
          currentPosition,
          totalDuration,
        );
      }

      await _audioService!.stop();
    }
  }

  // 跳转
  Future<void> seek(Duration position) async {
    await _ensureInitialized();
    if (_audioService != null) {
      await _audioService!.seek(position);
    }
  }

  // 设置播放速度
  Future<void> setSpeed(double speed) async {
    await _ensureInitialized();
    if (_audioService != null) {
      await _audioService!.setSpeed(speed);
    }
  }

  // 快进30秒
  Future<void> fastForward() async {
    await _ensureInitialized();
    if (_audioService != null) {
      await _audioService!.fastForward();
    }
  }

  // 快退30秒
  Future<void> rewind() async {
    await _ensureInitialized();
    if (_audioService != null) {
      await _audioService!.rewind();
    }
  }

  // 获取播放状态流 - 修复版本
  Stream<bool> get isPlayingStream {
    return _isPlayingSubject.stream;
  }

  // 获取当前音频流 - 修复版本
  Stream<AudioModel?> get currentAudioStream {
    return _currentAudioSubject.stream;
  }

  // 获取播放位置流 - 修复版本
  Stream<Duration> get positionStream {
    return _positionSubject.stream;
  }

  // 获取总时长流 - 修复版本
  Stream<Duration> get durationStream {
    return _durationSubject.stream;
  }

  // 获取播放速度流 - 修复版本
  Stream<double> get speedStream {
    return _speedSubject.stream;
  }

  // 获取当前状态
  bool get isPlaying {
    return _isPlayingSubject.value;
  }

  AudioModel? get currentAudio {
    return _currentAudioSubject.value;
  }

  Duration get position {
    return _positionSubject.value;
  }

  Duration get duration {
    return _durationSubject.value;
  }

  double get speed {
    return _speedSubject.value;
  }

  // 清理资源
  Future<void> dispose() async {
    if (_audioService != null) {
      await _audioService!.dispose();
    }

    // 关闭所有BehaviorSubject
    await _isPlayingSubject.close();
    await _currentAudioSubject.close();
    await _positionSubject.close();
    await _durationSubject.close();
    await _speedSubject.close();

    _audioService = null;
    _isInitialized = false;
    _isInitializing = false;
    _instance = null;
  }
}
