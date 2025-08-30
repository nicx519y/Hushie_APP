# Hushie 音频播放服务

这是一个功能完整的 Flutter 音频播放服务，支持后台播放、通知栏控制等高级功能。

## 功能特性

### ✨ 核心功能
- 🎵 **音频播放** - 支持网络音频文件播放
- ⏯️ **播放控制** - 播放、暂停、停止、快进、快退
- 🔄 **播放速度** - 支持 0.5x 到 2.0x 播放速度调节
- 📱 **后台播放** - 支持应用在后台时继续播放音频
- 🔔 **通知栏控制** - 在通知栏显示播放信息和控制按钮
- 📊 **播放进度** - 实时显示播放进度和总时长
- 🎨 **美观界面** - 提供沉浸式的音频播放界面

### 🏗️ 架构设计
- **AudioModel** - 音频数据模型
- **AudioPlayerService** - 核心音频播放服务，继承自 BaseAudioHandler
- **AudioManager** - 单例管理器，统一管理音频播放功能
- **AudioPlayerPage** - 全屏音频播放界面
- **AudioExamplePage** - 示例页面，展示如何使用音频服务

## 依赖包

```yaml
dependencies:
  # 音频播放
  just_audio: ^0.9.36
  
  # 后台音频服务
  audio_service: ^0.18.12
  
  # 响应式编程
  rxdart: ^0.27.7
```

## 权限配置

### Android (android/app/src/main/AndroidManifest.xml)

```xml
<!-- 音频播放权限 -->
<uses-permission android:name="android.permission.INTERNET" />
<uses-permission android:name="android.permission.WAKE_LOCK" />
<uses-permission android:name="android.permission.FOREGROUND_SERVICE" />
<uses-permission android:name="android.permission.FOREGROUND_SERVICE_MEDIA_PLAYBACK" />

<!-- 音频服务 -->
<service android:name="com.ryanheise.audioservice.AudioService"
    android:foregroundServiceType="mediaPlayback"
    android:exported="true">
    <intent-filter>
        <action android:name="android.media.browse.MediaBrowserService" />
    </intent-filter>
</service>

<!-- 媒体按钮接收器 -->
<receiver android:name="com.ryanheise.audioservice.MediaButtonReceiver"
    android:exported="true">
    <intent-filter>
        <action android:name="android.intent.action.MEDIA_BUTTON" />
    </intent-filter>
</receiver>
```

## 快速开始

### 1. 初始化音频服务

在 `main.dart` 中初始化音频服务：

```dart
void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // 初始化音频服务
  await AudioManager.instance.init();
  
  runApp(const MyApp());
}
```

### 2. 创建音频模型

```dart
final audio = AudioModel(
  id: '1',
  title: '音乐标题',
  artist: '艺术家',
  description: '音乐描述',
  audioUrl: 'https://example.com/audio.mp3',
  coverUrl: 'https://example.com/cover.jpg',
  duration: const Duration(minutes: 3, seconds: 45),
  likesCount: 1250,
);
```

### 3. 播放音频

```dart
// 获取音频管理器实例
final audioManager = AudioManager.instance;

// 播放音频
await audioManager.playAudio(audio);

// 播放/暂停切换
await audioManager.togglePlayPause();

// 停止播放
await audioManager.stop();

// 快进30秒
await audioManager.fastForward();

// 快退30秒
await audioManager.rewind();

// 设置播放速度
await audioManager.setSpeed(1.5);

// 跳转到指定位置
await audioManager.seek(Duration(seconds: 60));
```

### 4. 监听播放状态

```dart
class MyAudioWidget extends StatefulWidget {
  @override
  _MyAudioWidgetState createState() => _MyAudioWidgetState();
}

class _MyAudioWidgetState extends State<MyAudioWidget> {
  late AudioManager _audioManager;

  @override
  void initState() {
    super.initState();
    _audioManager = AudioManager.instance;
    _listenToAudioState();
  }

  void _listenToAudioState() {
    // 监听播放状态
    _audioManager.isPlayingStream.listen((isPlaying) {
      setState(() {
        // 更新UI
      });
    });

    // 监听播放位置
    _audioManager.positionStream.listen((position) {
      setState(() {
        // 更新进度条
      });
    });

    // 监听当前音频
    _audioManager.currentAudioStream.listen((audio) {
      setState(() {
        // 更新当前播放信息
      });
    });
  }
}
```

## 使用示例

### 简单播放

```dart
final audioManager = AudioManager.instance;

// 创建音频对象
final audio = AudioModel(
  id: 'unique_id',
  title: '夜曲',
  artist: '周杰伦',
  audioUrl: 'https://example.com/yequ.mp3',
  coverUrl: 'https://example.com/cover.jpg',
  duration: Duration(minutes: 4, seconds: 32),
  // ... 其他属性
);

// 播放音频
await audioManager.playAudio(audio);
```

### 全屏播放界面

```dart
Navigator.push(
  context,
  MaterialPageRoute(
    builder: (context) => AudioPlayerPage(audio: audio),
  ),
);
```

## API 参考

### AudioManager

| 方法 | 说明 |
|------|------|
| `playAudio(AudioModel audio)` | 播放指定音频 |
| `togglePlayPause()` | 播放/暂停切换 |
| `pause()` | 暂停播放 |
| `stop()` | 停止播放 |
| `seek(Duration position)` | 跳转到指定位置 |
| `setSpeed(double speed)` | 设置播放速度 |
| `fastForward()` | 快进30秒 |
| `rewind()` | 快退30秒 |

### 状态流

| 流 | 类型 | 说明 |
|----|------|------|
| `isPlayingStream` | `Stream<bool>` | 播放状态流 |
| `currentAudioStream` | `Stream<AudioModel?>` | 当前音频流 |
| `positionStream` | `Stream<Duration>` | 播放位置流 |
| `durationStream` | `Stream<Duration>` | 总时长流 |
| `speedStream` | `Stream<double>` | 播放速度流 |

## 注意事项

1. **网络权限** - 确保已添加网络访问权限
2. **音频格式** - 支持常见的音频格式（MP3、AAC、WAV等）
3. **后台播放** - 需要正确配置前台服务权限
4. **资源管理** - 应用退出时记得调用 `dispose()` 清理资源
5. **错误处理** - 建议添加适当的错误处理机制

## 故障排除

### 无法播放音频
- 检查音频URL是否有效
- 确认网络权限配置
- 查看音频格式是否支持

### 后台播放不工作
- 检查前台服务权限配置
- 确认AudioService配置正确
- 查看系统电池优化设置

### 通知栏不显示
- 检查通知权限
- 确认MediaItem配置正确
- 查看AudioService运行状态

## 示例项目

项目中包含了完整的示例代码：
- `lib/pages/audio_player_page.dart` - 集成了音频播放的播放页面

运行项目后，可以在"Audio"标签页查看完整的功能演示。 