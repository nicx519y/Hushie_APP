# 音频缓冲配置说明

## just_audio_media_kit 配置

### 当前配置
- **缓冲大小**: 128MB（从默认的32MB增加到128MB）
- **配置位置**: `lib/main.dart`

### 配置代码
```dart
// 初始化 just_audio_media_kit 并配置缓冲大小
JustAudioMediaKit.ensureInitialized();
// 设置缓冲大小为 128MB（默认32MB）
JustAudioMediaKit.bufferSize = 128 * 1024 * 1024;
```

### 可调整的缓冲大小选项

根据不同需求，可以调整缓冲大小：

```dart
// 64MB - 适合一般使用
JustAudioMediaKit.bufferSize = 64 * 1024 * 1024;

// 128MB - 当前配置，适合高质量音频
JustAudioMediaKit.bufferSize = 128 * 1024 * 1024;

// 256MB - 适合长时间音频或网络较差的环境
JustAudioMediaKit.bufferSize = 256 * 1024 * 1024;

// 512MB - 适合极高质量音频或需要大量预缓冲的场景
JustAudioMediaKit.bufferSize = 512 * 1024 * 1024;
```

### 注意事项

1. **内存使用**: 更大的缓冲区会占用更多内存，需要平衡性能和内存使用
2. **设备限制**: 低端设备可能无法支持过大的缓冲区
3. **网络环境**: 网络较差时，更大的缓冲区可以减少卡顿
4. **音频质量**: 高质量音频文件需要更大的缓冲区

### 监控缓冲状态

可以通过以下代码监控音频缓冲状态：

```dart
// 在 AudioService 中添加缓冲监控
_audioPlayer.bufferedPositionStream.listen((buffered) {
  final total = _audioPlayer.duration ?? Duration.zero;
  if (total > Duration.zero) {
    final bufferedPercent = (buffered.inMilliseconds / total.inMilliseconds * 100).round();
    print('音频已缓冲: ${buffered.inSeconds}秒 (${bufferedPercent}%)');
  }
});
```

### 性能优化建议

1. **预加载策略**: 对即将播放的音频提前调用 `setUrl()` 进行预加载
2. **多播放器实例**: 使用多个 AudioPlayer 实例预加载下一首音频
3. **网络优化**: 确保音频服务器支持 HTTP Range 请求
4. **本地缓存**: 考虑将频繁播放的音频缓存到本地

### 故障排除

如果遇到问题：

1. **内存不足**: 减小缓冲区大小
2. **加载缓慢**: 检查网络连接和服务器响应速度
3. **播放卡顿**: 增加缓冲区大小或优化网络
4. **应用崩溃**: 检查设备内存限制，适当减小缓冲区

### 平台支持

just_audio_media_kit 主要支持：
- Windows
- Linux
- macOS（可选）
- Android（可选，但推荐使用原生 just_audio）
- iOS（可选，但推荐使用原生 just_audio）

对于 Android 和 iOS，原生的 just_audio 通常性能更好，除非需要特定的媒体格式支持。