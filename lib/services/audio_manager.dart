import 'dart:async';
import 'package:rxdart/rxdart.dart';
import 'package:audio_service/audio_service.dart';
import '../models/audio_item.dart';
import 'audio_service.dart';
import 'audio_playlist.dart';
import 'audio_history_manager.dart';
import 'api/audio_list_service.dart';

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
  final BehaviorSubject<Duration> _durationSubject =
      BehaviorSubject<Duration>.seeded(Duration.zero);
  final BehaviorSubject<double> _speedSubject = BehaviorSubject<double>.seeded(
    1.0,
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
      print('AudioService初始化失败: $e');
      _audioService = null;
    }
  }

  // 设置流监听
  void _setupStreamListeners() {
    if (_audioService == null) return;

    // 监听播放状态
    _audioService!.isPlayingStream.listen((isPlaying) {
      _isPlayingSubject.add(isPlaying);

      if (isPlaying) {
        print('播放状态: 开始播放');
        final currentAudio = _currentAudioSubject.value;
        if (currentAudio != null) {
          print('记录播放开始: ${currentAudio.title}');
          AudioHistoryManager.instance.recordPlayStart(currentAudio);
        }
      } else {
        print('播放状态: 停止播放');
        final currentAudio = _currentAudioSubject.value;
        if (currentAudio != null) {
          print('记录播放结束: ${currentAudio.title}');
          AudioHistoryManager.instance.recordPlayStop(
            currentAudio.id,
            _positionSubject.value,
            _durationSubject.value,
          );
        }
      }
    });

    // 监听当前音频
    _audioService!.currentAudioStream.listen((audio) {
      _currentAudioSubject.add(audio);

      // 管理播放列表
      if (audio != null) {
        final isInPlaylist =
            AudioPlaylist.instance.getAudioItemById(audio.id) != null;

        if (!isInPlaylist) {
          AudioPlaylist.instance.addAudio(audio);
        }

        print('音频改变，管理播放列表: ${audio.title}');
        _managePlaylist(audio.id);
      }
    });

    // 监听播放位置
    _audioService!.positionStream.listen((position) {
      _positionSubject.add(position);

      // 检查是否播放完成，如果完成则自动播放下一首
      _checkPlaybackCompletion(position);
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

  /// 检查播放是否完成并自动播放下一首
  void _checkPlaybackCompletion(Duration position) {
    final currentAudio = _currentAudioSubject.value;
    final totalDuration = _durationSubject.value;
    final isPlaying = _isPlayingSubject.value;

    if (currentAudio != null &&
        totalDuration.inMilliseconds > 0 &&
        position.inMilliseconds >=
            totalDuration.inMilliseconds * 0.98 && // 98%算作播放完成
        !isPlaying) {
      // 确保当前不在播放状态

      _playNextAudio(currentAudio.id);
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
          print('自动播放下一首: ${nextAudio.title}');
          await playAudio(nextAudioItem);
        }
      } else {
        print('没有找到下一首音频');
      }
    } catch (e) {
      print('自动播放下一首失败: $e');
    }
  }

  // 兼容性方法：保持原有的init接口，但改为延迟初始化
  Future<void> init() async {
    // 先初始化音频历史管理器（确保数据库可用）
    await AudioHistoryManager.instance.initialize();
    // 初始化AudioPlaylist
    await AudioPlaylist.instance.initialize();
    print('AudioManager: AudioPlaylist 初始化完成');

    // 从播放历史列表中获取最后一条播放记录
    final lastHistory = await AudioHistoryManager.instance.getRecentHistory(
      limit: 1,
    );
    if (lastHistory.isNotEmpty) {
      print('AudioManager: 最后一条播放记录: ${lastHistory.first.title}');
      AudioPlaylist.instance.addAudio(lastHistory.first);
    } else {
      print('AudioManager: 没有播放历史记录');
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
          await _ensureInitialized();
          await _audioService!.loadAudio(audioItem);
        }
      }
    } catch (e) {
      print('播放最后音频失败: $e');
    }
  }

  // 获取音频服务实例
  AudioPlayerService? get audioService {
    return _audioService;
  }

  // 播放音频
  Future<void> playAudio(AudioItem audio) async {
    try {
      await _ensureInitialized();
      if (_audioService != null) {
        await _audioService!.playAudio(audio);
      } else {
        print('音频服务未初始化，无法播放音频');
        throw Exception('音频服务未初始化');
      }
    } catch (e) {
      print('播放音频失败: $e');
      rethrow;
    }
  }

  Future<void> play() async {
    await _ensureInitialized();
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

      print("管理播放列表：当前ID: $currentAudioId");
      print("管理播放列表：是否最后一条：${playlist.isLastAudio(currentAudioId)}");
      print("管理播放列表：下一首ID: ${playlist.getNextAudio(currentAudioId)?.id}");

      // 3. 检查是否是最后一条，如果是则补充播放列表
      if (playlist.isLastAudio(currentAudioId)) {
        print('_managePlaylist: isLastAudio: true');
        await _supplementPlaylist();
      }
    } catch (e) {
      print('管理播放列表失败: $e');
    }
  }

  /// 补充播放列表
  Future<void> _supplementPlaylist() async {
    try {
      final playlist = AudioPlaylist.instance;
      final currentAudio = playlist.getCurrentAudio();

      if (currentAudio == null) {
        print('补充播放列表: 当前没有可用的音频，无法补充播放列表');
        print('播放列表状态: ${playlist.getPlaylistStats()}');
        return;
      }

      print('补充播放列表: 当前ID: $currentAudio.id');

      // 从API获取更多音频数据
      final response = await AudioListService.getAudioList(
        tag: null,
        cid: currentAudio.id,
      );

      if (response.errNo == 0 &&
          response.data != null &&
          response.data!.items.isNotEmpty) {
        // 添加新音频到播放列表
        playlist.addAudioList(response.data!.items);
        print('成功补充播放列表: ${response.data!.items.length} 首音频');
      } else {
        print('补充播放列表失败: 没有更多数据 (errNo: ${response.errNo})');
      }
    } catch (e) {
      print('补充播放列表失败: $e');
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
      await _audioService!.pause();
    }
  }

  // 停止
  Future<void> stop() async {
    await _ensureInitialized();
    if (_audioService != null) {
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
  Stream<AudioItem?> get currentAudioStream {
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

  AudioItem? get currentAudio {
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
    // 在销毁前记录最后的播放停止
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
  }
}
