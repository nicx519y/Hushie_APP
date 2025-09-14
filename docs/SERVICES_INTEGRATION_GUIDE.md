# 服务集成指南

## 概述

本项目实现了基于事件驱动的认证状态管理机制，当用户登录状态发生变化时，相关的数据管理器会自动响应并更新缓存。

## 核心服务

### 1. AuthService - 认证服务
- 管理用户登录状态和Token生命周期
- 提供认证状态变化事件流
- 支持登录、登出、删除账户等操作

### 2. UserLikesManager - 用户喜欢音频管理器
- 管理用户喜欢的音频列表
- 提供本地缓存和服务端同步
- 自动响应登录状态变化

### 3. AudioHistoryManager - 音频播放历史管理器
- 管理用户播放历史记录
- 提供播放进度追踪和定时上报
- 自动响应登录状态变化

## 消息机制

### 认证状态枚举
```dart
enum AuthStatus {
  unknown,        // 未知状态（初始化中）
  authenticated,  // 已认证
  unauthenticated // 未认证
}
```

### 认证状态变化事件
```dart
class AuthStatusChangeEvent {
  final AuthStatus status;
  final GoogleAuthResponse? user;
  final DateTime timestamp;
}
```

## 使用示例

### 应用启动时初始化
```dart
void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // 1. 初始化API配置
  ApiConfig.initialize(debugMode: true);
  
  // 2. 初始化认证状态
  await AuthService.initializeAuthStatus();
  
  // 3. 初始化数据管理器（它们会自动订阅认证状态变化）
  await UserLikesManager.instance.initialize();
  await AudioHistoryManager.instance.initialize();
  
  runApp(MyApp());
}
```

### 登录流程
```dart
// 用户点击登录按钮
final result = await AuthService.signInWithGoogle();
if (result.errNo == 0) {
  // 登录成功，UserLikesManager和AudioHistoryManager会自动收到通知
  // 并重新初始化它们的缓存数据
  debugPrint('登录成功');
} else {
  debugPrint('登录失败');
}
```

### 登出流程
```dart
// 用户点击登出按钮
await AuthService.signOut();
// UserLikesManager和AudioHistoryManager会自动收到通知
// 并清空它们的缓存数据，AudioHistoryManager还会停止进度追踪
```

### 使用喜欢功能
```dart
// 检查音频是否被喜欢
bool isLiked = UserLikesManager.instance.isAudioLiked(audioId);

// 切换喜欢状态
bool success = await UserLikesManager.instance.toggleLike(audioId);

// 获取喜欢列表
List<AudioItem> likedAudios = await UserLikesManager.instance.getLikedAudios();
```

### 使用播放历史功能
```dart
// 记录播放开始（会启动定时进度追踪）
await AudioHistoryManager.instance.recordPlayStart(audioItem, progressMs);

// 更新播放位置（供AudioManager调用）
AudioHistoryManager.instance.updateCurrentPosition(Duration(seconds: 30));

// 记录播放停止（会停止定时追踪并提交最终进度）
await AudioHistoryManager.instance.recordPlayStop(audioId, progressMs, durationMs);

// 获取播放历史
List<AudioItem> history = await AudioHistoryManager.instance.getAudioHistory();
```

## 自动化特性

### 登录状态变化时的自动响应

1. **用户登录时**：
   - `UserLikesManager` 自动从服务端拉取喜欢列表并更新缓存
   - `AudioHistoryManager` 自动从服务端拉取播放历史并更新缓存

2. **用户登出时**：
   - `UserLikesManager` 自动清空喜欢列表缓存
   - `AudioHistoryManager` 自动清空历史缓存并停止进度追踪

### 缓存策略

- **优先使用缓存**：所有数据获取操作优先从本地缓存返回
- **智能刷新**：支持强制刷新以获取最新数据
- **降级处理**：网络请求失败时返回缓存数据

### 错误处理

- **网络异常**：自动降级到缓存数据
- **登录状态异常**：自动清理相关缓存
- **初始化失败**：标记为已初始化以避免重复尝试

## 注意事项

1. **初始化顺序**：必须先初始化 `AuthService.initializeAuthStatus()`，再初始化其他管理器
2. **资源清理**：应用退出时调用各服务的 `dispose()` 方法清理资源
3. **线程安全**：所有管理器都使用单例模式，但不是线程安全的，请在主线程使用
4. **网络依赖**：所有数据同步都依赖网络连接，离线时只能使用缓存数据 