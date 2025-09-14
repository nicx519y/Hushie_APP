# 音频预览事件机制使用指南

## 概述

音频管理器现在使用基于Stream的事件机制来处理预览区间即将超出的情况，替代了之前的回调函数列表实现。这种方式更符合Flutter的最佳实践，提供了更好的类型安全和错误处理。

## 事件定义

### PreviewOutEvent

```dart
class PreviewOutEvent {
  final Duration position;    // 当前播放位置
  final DateTime timestamp;   // 事件发生时间
}
```

## 使用方法

### 1. 监听预览事件

```dart
import 'dart:async';
import '../services/audio_manager.dart';

class MyWidget extends StatefulWidget {
  @override
  State<MyWidget> createState() => _MyWidgetState();
}

class _MyWidgetState extends State<MyWidget> {
  StreamSubscription<PreviewOutEvent>? _previewSubscription;

  @override
  void initState() {
    super.initState();
    _setupPreviewListener();
  }

  void _setupPreviewListener() {
    _previewSubscription = AudioManager.previewOutEvents.listen(
      (PreviewOutEvent event) {
        // 处理预览区间即将超出事件
        print('预览时间到，位置: ${event.position}');
        _handlePreviewTimeout(event);
      },
      onError: (error) {
        print('预览事件监听错误: $error');
      },
    );
  }

  void _handlePreviewTimeout(PreviewOutEvent event) {
    // 自定义处理逻辑
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('预览时间已到，播放已暂停')),
    );
  }

  @override
  void dispose() {
    _previewSubscription?.cancel();
    super.dispose();
  }
}
```

### 2. 多个监听器

```dart
// 可以有多个组件同时监听同一个事件流
class ComponentA extends StatefulWidget {
  // 监听预览事件，显示UI提示
}

class ComponentB extends StatefulWidget {
  // 监听预览事件，记录分析数据
}

class ComponentC extends StatefulWidget {
  // 监听预览事件，执行其他业务逻辑
}
```

### 3. 条件监听

```dart
void _setupConditionalListener() {
  _previewSubscription = AudioManager.previewOutEvents
      .where((event) => event.position.inSeconds > 30) // 只处理超过30秒的事件
      .listen((event) {
        _handleLongPreview(event);
      });
}
```

### 4. 事件转换

```dart
void _setupTransformedListener() {
  _previewSubscription = AudioManager.previewOutEvents
      .map((event) => {
        'position_seconds': event.position.inSeconds,
        'timestamp': event.timestamp.toIso8601String(),
      })
      .listen((data) {
        _sendAnalytics(data);
      });
}
```

## 与旧版本的对比

### 旧版本（回调函数）

```dart
// 旧版本 - 不推荐
void setupOldCallback() {
  AudioManager.instance.addPreviewOutCallback(() {
    print('预览超时');
  });
}

// 需要手动管理回调函数的添加和删除
// 没有类型安全
// 错误处理困难
// 不支持事件过滤和转换
```

### 新版本（Stream事件）

```dart
// 新版本 - 推荐
void setupNewListener() {
  final subscription = AudioManager.previewOutEvents.listen(
    (PreviewOutEvent event) {
      print('预览超时: ${event.position}');
    },
  );
}

// 自动管理订阅生命周期
// 完整的类型安全
// 内置错误处理
// 支持丰富的Stream操作符
```

## 最佳实践

### 1. 及时取消订阅

```dart
@override
void dispose() {
  _previewSubscription?.cancel(); // 防止内存泄漏
  super.dispose();
}
```

### 2. 错误处理

```dart
_previewSubscription = AudioManager.previewOutEvents.listen(
  (event) => _handleEvent(event),
  onError: (error) => _handleError(error),
  onDone: () => _handleDone(),
);
```

### 3. 避免在监听器中执行耗时操作

```dart
void _handlePreviewOut(PreviewOutEvent event) {
  // ✅ 好的做法
  _showQuickNotification();
  
  // ❌ 避免耗时操作
  // await _uploadLargeFile();
  
  // ✅ 如果需要耗时操作，使用异步处理
  _performAsyncOperation(event);
}

void _performAsyncOperation(PreviewOutEvent event) async {
  // 在单独的方法中处理耗时操作
}
```

### 4. 使用StreamBuilder在UI中响应事件

```dart
Widget build(BuildContext context) {
  return StreamBuilder<PreviewOutEvent>(
    stream: AudioManager.previewOutEvents,
    builder: (context, snapshot) {
      if (snapshot.hasData) {
        final event = snapshot.data!;
        return Text('最后预览超时: ${event.position}');
      }
      return Text('等待预览事件...');
    },
  );
}
```

## 注意事项

1. **内存管理**: 确保在组件销毁时取消订阅，避免内存泄漏
2. **错误处理**: 为监听器添加错误处理，避免未捕获的异常
3. **性能考虑**: 避免在事件处理器中执行耗时操作
4. **生命周期**: 在适当的生命周期方法中设置和取消监听

## 示例代码

完整的使用示例请参考: `lib/examples/audio_preview_event_example.dart`