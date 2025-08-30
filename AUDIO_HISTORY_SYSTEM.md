# 音频播放历史系统

## 概述

音频播放历史系统是一个完整的本地存储解决方案，用于记录用户的音频播放行为，包括播放进度、播放时间等信息。系统采用三层架构：数据库存储层、历史管理层和数据池缓存层。

## 核心特性

### 🎯 **智能存储管理**
- **存储上限**: 默认 50 条记录，可配置
- **先进先出**: 超过上限时自动删除最旧记录
- **去重处理**: 重复播放同一音频时更新现有记录

### 📊 **完整进度追踪**
- **播放开始**: 自动记录，进度设为 0
- **播放停止**: 记录当前进度
- **播放完成**: 进度自动重置为 0
- **定期更新**: 每 30 秒（可配置）自动保存进度

### 🔄 **数据池集成**
- **启动加载**: 应用启动时将历史数据加载到数据池
- **实时同步**: 新播放的音频自动同步到数据池
- **统一管理**: 历史数据和 API 数据统一管理

## 系统架构

```
┌─────────────────┐    ┌──────────────────┐    ┌─────────────────┐
│   AudioManager  │───▶│ AudioHistoryMgr  │───▶│ AudioDataPool   │
│   (播放控制)     │    │   (历史管理)      │    │   (内存缓存)     │
└─────────────────┘    └──────────────────┘    └─────────────────┘
         │                       │                       │
         ▼                       ▼                       ▼
┌─────────────────┐    ┌──────────────────┐    ┌─────────────────┐
│  AudioService   │    │ AudioHistoryDB   │    │   AudioItem     │
│   (音频服务)     │    │  (SQLite 存储)    │    │   (数据模型)     │
└─────────────────┘    └──────────────────┘    └─────────────────┘
```

## 数据模型

### AudioHistory 模型

```dart
class AudioHistory {
  final String id;              // 音频 ID
  final String title;           // 标题
  final String artist;          // 艺术家
  final String description;     // 描述
  final String audioUrl;        // 音频 URL
  final String coverUrl;        // 封面 URL
  final Duration duration;      // 总时长
  final int likesCount;         // 点赞数
  
  // 历史记录特有字段
  final Duration playbackPosition; // 播放进度
  final DateTime lastPlayedAt;     // 最后播放时间
  final DateTime createdAt;        // 首次播放时间
}
```

### 数据库表结构

```sql
CREATE TABLE audio_history (
  id TEXT PRIMARY KEY,
  title TEXT NOT NULL,
  artist TEXT NOT NULL,
  description TEXT,
  audio_url TEXT NOT NULL,
  cover_url TEXT,
  duration_ms INTEGER NOT NULL,
  likes_count INTEGER DEFAULT 0,
  playback_position_ms INTEGER DEFAULT 0,
  last_played_at INTEGER NOT NULL,
  created_at INTEGER NOT NULL
);

CREATE INDEX idx_last_played_at ON audio_history (last_played_at DESC);
```

## 使用方式

### 1. 系统初始化

在 `main.dart` 中已自动初始化：

```dart
void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // 初始化音频历史管理器（会自动加载历史数据到数据池）
  await AudioHistoryManager.instance.initialize();
  
  // 初始化音频服务
  await AudioManager.instance.init();
  
  runApp(const MyApp());
}
```

### 2. 配置选项

```dart
// 设置最大历史记录数量
AudioHistoryDatabase.setMaxHistoryCount(100);

// 设置进度更新间隔（秒）
AudioHistoryDatabase.setProgressUpdateInterval(15);

// 或使用便捷方法
AudioHistoryManager.instance.configureSettings(
  maxHistoryCount: 100,
  progressUpdateInterval: 15,
);
```

### 3. 获取播放历史

```dart
// 获取最近播放的 10 条记录
final recentHistory = await AudioHistoryManager.instance.getRecentHistory(limit: 10);

// 获取所有播放历史
final allHistory = await AudioHistoryManager.instance.getAllHistory();

// 搜索播放历史
final searchResults = await AudioHistoryManager.instance.searchHistory('音乐名称');

// 获取指定音频的播放历史
final audioHistory = await AudioHistoryManager.instance.getAudioHistory('audio_id');
```

### 4. 播放历史管理

```dart
// 删除指定音频的历史记录
await AudioHistoryManager.instance.deleteHistory('audio_id');

// 清空所有播放历史
await AudioHistoryManager.instance.clearAllHistory();

// 获取历史统计信息
final stats = await AudioHistoryManager.instance.getHistoryStats();
print('总记录数: ${stats['total_count']}');
print('今日播放: ${stats['today_count']}');
```

## 自动化功能

### 1. 播放生命周期管理

系统会自动处理音频播放的完整生命周期：

```dart
// 开始播放时 - 自动执行
AudioManager.instance.playAudioById('audio_id');
// ↓ 自动触发
// - 记录播放开始（进度设为 0）
// - 添加到历史数据库
// - 同步到数据池

// 播放过程中 - 自动执行
// - 每 30 秒自动更新播放进度
// - 实时监听播放位置变化

// 停止播放时 - 自动执行
AudioManager.instance.stop();
// ↓ 自动触发
// - 记录最终播放进度
// - 如果播放完成（95%+），进度重置为 0
```

### 2. 存储限制管理

```dart
// 当历史记录达到上限时，系统会自动：
// 1. 删除最旧的记录（先进先出）
// 2. 为新记录腾出空间
// 3. 打印删除日志
```

### 3. 重复播放处理

```dart
// 当重复播放同一音频时：
// 1. 检查历史记录中是否已存在该音频
// 2. 如果存在，删除旧记录
// 3. 创建新记录并插入
// 4. 确保每个音频只有一条最新记录
```

## 高级功能

### 1. 播放进度计算

```dart
final history = await AudioHistoryManager.instance.getAudioHistory('audio_id');
if (history != null) {
  // 播放进度百分比
  final progress = history.progressPercentage; // 0.0 - 1.0
  
  // 格式化显示
  final formattedProgress = history.formattedProgress; // "2:30 / 4:15"
  
  // 是否播放完成
  final isCompleted = history.isCompleted; // true/false
}
```

### 2. 历史统计分析

```dart
final stats = await AudioHistoryManager.instance.getHistoryStats();

print('=== 播放历史统计 ===');
print('总记录数: ${stats['total_count']}');
print('今日播放: ${stats['today_count']}');
print('最近播放: ${stats['last_played_at']}');
print('存储使用率: ${(stats['usage_percentage'] * 100).toStringAsFixed(1)}%');
```

### 3. 数据同步

```dart
// 手动同步历史数据到数据池
await AudioHistoryManager.instance.syncHistoryToDataPool();

// 调试信息
await AudioHistoryManager.instance.printDebugInfo();
```

## 最佳实践

### 1. 性能优化

```dart
// ✅ 推荐：使用批量操作
final historyList = await AudioHistoryManager.instance.getAllHistory();

// ❌ 避免：频繁的单条查询
for (final id in audioIds) {
  final history = await AudioHistoryManager.instance.getAudioHistory(id);
}
```

### 2. 错误处理

```dart
try {
  final history = await AudioHistoryManager.instance.getAudioHistory(audioId);
  if (history != null) {
    // 处理历史数据
  } else {
    // 音频未播放过
  }
} catch (e) {
  print('获取播放历史失败: $e');
  // 降级处理
}
```

### 3. 资源管理

```dart
// 应用退出时清理资源
@override
void dispose() {
  AudioHistoryManager.instance.dispose();
  super.dispose();
}
```

## 配置参数

| 参数名 | 默认值 | 说明 |
|--------|--------|------|
| `maxHistoryCount` | 50 | 最大存储历史记录数量 |
| `progressUpdateInterval` | 30 | 进度更新间隔（秒） |
| `completionThreshold` | 0.95 | 播放完成阈值（95%） |

## 调试工具

### 1. 打印详细信息

```dart
// 打印历史管理器调试信息
await AudioHistoryManager.instance.printDebugInfo();

// 打印数据库调试信息
await AudioHistoryDatabase.instance.printDebugInfo();
```

### 2. 统计信息查看

```dart
final stats = await AudioHistoryManager.instance.getHistoryStats();
print('历史统计: $stats');

final dbSize = await AudioHistoryDatabase.instance.getDatabaseSize();
print('数据库大小: ${dbSize}KB');
```

## 注意事项

### 1. 数据持久化
- 历史数据存储在本地 SQLite 数据库中
- 应用卸载后数据会丢失
- 建议在云端备份重要播放历史

### 2. 性能考虑
- 进度更新采用间隔机制，避免频繁写入
- 使用索引优化查询性能
- 自动清理过期数据，控制数据库大小

### 3. 隐私保护
- 所有数据仅存储在本地
- 不会自动上传到服务器
- 用户可随时清空播放历史

## 扩展功能

未来可以考虑的功能扩展：

1. **云端同步**: 将播放历史同步到云端
2. **播放统计**: 生成详细的播放统计报告
3. **推荐算法**: 基于播放历史推荐音频
4. **播放习惯分析**: 分析用户播放偏好
5. **历史导出**: 支持导出播放历史数据

## 总结

音频播放历史系统提供了完整的播放记录功能：

- ✅ **自动化管理**: 无需手动干预，自动记录播放历史
- ✅ **智能存储**: 先进先出策略，防止数据过多
- ✅ **进度追踪**: 精确记录播放进度，支持断点续播
- ✅ **数据池集成**: 与内存缓存无缝集成
- ✅ **性能优化**: 高效的数据库操作和索引优化
- ✅ **调试友好**: 丰富的调试工具和统计信息

这套系统为音频应用提供了强大的播放历史管理能力！ 