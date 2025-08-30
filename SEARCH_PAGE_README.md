# 搜索页面使用说明

## 功能特性

### 1. 搜索框组件复用
- 复用了 `SearchBox` 组件，保持界面一致性
- 支持自定义提示文本
- 支持搜索变化和提交回调

### 2. 搜索结果列表复用
- 复用了 `audioList` 组件显示搜索结果
- 保持与主页相同的视频卡片样式
- 支持播放次数、点赞数、作者信息显示

### 3. 搜索历史本地存储
- 使用 `SharedPreferences` 存储搜索历史
- 自动去重，最新搜索排在前面
- 限制历史记录数量为20条
- 支持清除所有搜索历史

## 文件结构

```
lib/
├── pages/
│   ├── search_page.dart          # 搜索页面主组件
│   └── search_demo_page.dart     # 搜索页面演示
├── components/
│   ├── search_box.dart           # 搜索框组件
│   └── audio_list.dart           # 视频列表组件
└── models/
    └── audio_item.dart           # 视频数据模型
```

## 使用方法

### 1. 基本使用

```dart
import 'package:flutter/material.dart';
import 'pages/search_page.dart';

// 在需要的地方导航到搜索页面
Navigator.push(
  context,
  MaterialPageRoute(
    builder: (context) => const SearchPage(),
  ),
);
```

### 2. 演示页面

运行 `SearchDemoPage` 来查看搜索页面的完整功能：

```dart
import 'pages/search_demo_page.dart';

// 在 main.dart 中临时替换主页
home: const SearchDemoPage(),
```

## 功能说明

### 搜索历史
- 每次搜索提交后自动保存到本地存储
- 历史记录以标签形式显示
- 点击历史标签可快速搜索
- 支持一键清除所有历史

### 搜索结果
- 显示搜索状态（搜索中、无结果、有结果）
- 使用模拟数据展示搜索结果
- 结果列表支持滚动浏览
- 保持与主页相同的视频卡片样式

### 界面状态
- **初始状态**：显示搜索历史或空状态提示
- **搜索中**：显示加载动画和"搜索中..."文字
- **无结果**：显示"没有找到相关结果"提示
- **有结果**：显示搜索结果列表

## 依赖项

确保在 `pubspec.yaml` 中添加了以下依赖：

```yaml
dependencies:
  shared_preferences: ^2.2.2
```

## 扩展建议

1. **API 集成**：将模拟搜索替换为真实的 API 调用
2. **搜索建议**：在 `onSearchChanged` 中实现实时搜索建议
3. **搜索过滤**：添加按类型、时间等条件过滤搜索结果
4. **语音搜索**：集成语音识别功能
5. **搜索分析**：记录搜索行为数据用于分析

## 注意事项

- 搜索历史存储在设备本地，不同设备间不会同步
- 模拟搜索结果仅用于演示，实际使用时需要替换为真实 API
- 搜索框组件支持自定义样式，可根据需要调整 