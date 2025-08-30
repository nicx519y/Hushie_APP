# API 接口使用说明

## 概述

本项目实现了一个完整的音频数据接口系统，支持 Mock 本地数据和真实 API 接口的无缝切换，方便开发和调试。

## 功能特性

- ✅ **双模式支持**: Mock 数据模式和真实 API 模式
- ✅ **完整的数据模型**: 支持音频信息、分页、响应格式等
- ✅ **搜索和过滤**: 支持关键词搜索和标签过滤
- ✅ **分页加载**: 支持分页获取数据
- ✅ **错误处理**: 完善的错误处理和用户反馈
- ✅ **热切换**: 开发时可实时切换 Mock/真实接口

## 文件结构

```
lib/
├── models/
│   ├── audio_item.dart          # 音频数据模型
│   └── api_response.dart        # API 响应模型
├── services/
│   └── api_service.dart         # API 服务类
├── data/
│   └── mock_data.dart           # Mock 数据
├── config/
│   └── api_config.dart          # API 配置
└── pages/
    └── home_page.dart           # 更新后的首页（使用新接口）
```

## 核心组件

### 1. ApiService 类

主要的 API 服务类，负责处理所有 API 调用：

```dart
// 获取首页音频列表
final response = await ApiService.getHomeAudioList(
  page: 1,
  pageSize: 10,
  searchQuery: '搜索关键词',
);

// 获取热门音频
final popularResponse = await ApiService.getPopularAudio(limit: 5);

// 根据 ID 获取音频详情
final detailResponse = await ApiService.getAudioById('123');
```

### 2. AudioItem 模型

完整的音频数据模型：

```dart
class AudioItem {
  final String id;
  final String cover;        // 封面图片
  final String title;        // 标题
  final String desc;         // 描述
  final String author;       // 作者
  final String avatar;       // 作者头像
  final int playTimes;       // 播放次数
  final int likesCount;      // 点赞数
  final String? audioUrl;    // 音频 URL
  final String? duration;    // 时长
  final DateTime? createdAt; // 创建时间
  final List<String>? tags;  // 标签
}
```

### 3. API 响应格式

标准化的 API 响应格式：

```dart
class ApiResponse<T> {
  final bool success;
  final String message;
  final T? data;
  final int? code;
}

class PaginatedResponse<T> {
  final List<T> items;
  final int currentPage;
  final int totalPages;
  final int totalItems;
  final bool hasNextPage;
}
```

## 使用方式

### 1. 基础配置

在 `main.dart` 中已自动初始化：

```dart
void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // 初始化 API 配置
  ApiConfig.initialize(debugMode: true);
  
  // ... 其他初始化代码
}
```

### 2. 切换 API 模式

#### 方法一：代码切换

```dart
// 切换到 Mock 模式
ApiService.setApiMode(ApiMode.mock);

// 切换到真实接口模式
ApiService.setApiMode(ApiMode.real);
```

#### 方法二：界面切换

首页已内置模式切换按钮，点击即可切换并自动重新加载数据。

### 3. 获取数据示例

```dart
// 获取首页列表
Future<void> loadHomeData() async {
  final response = await ApiService.getHomeAudioList(
    page: 1,
    pageSize: 10,
    searchQuery: searchText.isNotEmpty ? searchText : null,
  );
  
  if (response.success && response.data != null) {
    final paginatedData = response.data!;
    setState(() {
      audioItems = paginatedData.items;
      hasMoreData = paginatedData.hasNextPage;
    });
  } else {
    // 处理错误
    showError(response.message);
  }
}
```

## Mock 数据特性

### 1. 内置测试数据

提供 8 个不同类型的音频数据，包含：
- 不同的音乐风格（流行、电子、爵士、摇滚等）
- 完整的元数据（标题、作者、描述、播放次数等）
- 高质量的示例图片
- 真实的音频 URL

### 2. 模拟网络行为

- **延迟模拟**: 200-1000ms 随机延迟
- **错误模拟**: 5% 概率返回错误，测试错误处理
- **搜索功能**: 支持标题、作者、描述搜索
- **标签过滤**: 支持按标签筛选
- **分页处理**: 完整的分页逻辑

### 3. 数据操作

```dart
// 获取所有数据
final allItems = MockData.getAllAudioItems();

// 分页获取
final pageItems = MockData.getAudioItems(
  page: 2, 
  pageSize: 5,
  searchQuery: '关键词',
  tags: ['pop', 'trending'],
);

// 获取热门数据
final popular = MockData.getPopularAudioItems(limit: 5);

// 获取最新数据
final latest = MockData.getLatestAudioItems(limit: 5);
```

## 真实 API 接口规范

### 1. 基础 URL

```
https://your-api-domain.com/api/v1
```

### 2. 接口列表

| 接口 | 方法 | 端点 | 说明 |
|------|------|------|------|
| 获取音频列表 | GET | `/audio/list` | 支持分页、搜索、标签过滤 |
| 获取音频详情 | GET | `/audio/{id}` | 根据 ID 获取详情 |
| 获取热门音频 | GET | `/audio/popular` | 获取热门音频列表 |
| 获取标签列表 | GET | `/tags` | 获取所有可用标签 |

### 3. 请求参数

#### 获取音频列表 (GET /audio/list)

| 参数 | 类型 | 必填 | 说明 |
|------|------|------|------|
| page | int | 否 | 页码，默认 1 |
| page_size | int | 否 | 每页大小，默认 10 |
| search | string | 否 | 搜索关键词 |
| tags | string | 否 | 标签列表，逗号分隔 |

#### 获取热门音频 (GET /audio/popular)

| 参数 | 类型 | 必填 | 说明 |
|------|------|------|------|
| limit | int | 否 | 返回数量限制，默认 5 |

### 4. 响应格式

#### 成功响应

```json
{
  "success": true,
  "message": "获取数据成功",
  "data": {
    "items": [
      {
        "id": "1",
        "cover": "https://example.com/cover.jpg",
        "title": "音频标题",
        "desc": "音频描述",
        "author": "作者名称",
        "avatar": "https://example.com/avatar.jpg",
        "play_times": 1234,
        "likes_count": 567,
        "audio_url": "https://example.com/audio.mp3",
        "duration": "3:24",
        "created_at": "2024-01-15T10:30:00Z",
        "tags": ["pop", "trending"]
      }
    ],
    "current_page": 1,
    "total_pages": 10,
    "total_items": 100,
    "page_size": 10,
    "has_next_page": true,
    "has_previous_page": false
  }
}
```

#### 错误响应

```json
{
  "success": false,
  "message": "错误信息",
  "code": 400
}
```

## 配置说明

### 1. ApiConfig 配置

```dart
class ApiConfig {
  static const String baseUrl = 'https://your-api-domain.com/api/v1';
  static const Duration defaultTimeout = Duration(seconds: 10);
  static const int defaultPageSize = 10;
  static const bool enableMockMode = true;
}
```

### 2. 环境配置

可以通过环境变量或配置文件来控制：

```dart
// 根据构建环境自动切换
const isDebugMode = kDebugMode;
final apiMode = isDebugMode ? ApiMode.mock : ApiMode.real;
ApiService.setApiMode(apiMode);
```

## 开发建议

### 1. 开发流程

1. **开发阶段**: 使用 Mock 模式进行界面开发和逻辑测试
2. **联调阶段**: 切换到真实接口模式进行接口联调
3. **测试阶段**: 两种模式混合使用，确保兼容性
4. **发布阶段**: 确保使用真实接口模式

### 2. 错误处理

```dart
final response = await ApiService.getHomeAudioList();

if (response.success && response.data != null) {
  // 处理成功数据
  handleSuccess(response.data!);
} else {
  // 处理错误
  showErrorMessage(response.message);
  
  // 根据错误码做特殊处理
  switch (response.code) {
    case 404:
      // 数据不存在
      break;
    case 500:
      // 服务器错误
      break;
    default:
      // 其他错误
  }
}
```

### 3. 性能优化

- 使用分页加载避免一次性加载大量数据
- 实现数据缓存减少重复请求
- 合理设置请求超时时间
- 在 Mock 模式下模拟真实的网络延迟

## 常见问题

### Q: 如何添加新的接口？

A: 在 `ApiService` 类中添加新方法，同时在 `MockData` 中添加对应的模拟数据。

### Q: 如何修改 Mock 数据？

A: 直接编辑 `lib/data/mock_data.dart` 文件中的 `_audioItems` 数组。

### Q: 如何配置真实接口地址？

A: 修改 `lib/config/api_config.dart` 中的 `baseUrl` 常量。

### Q: 如何在生产环境禁用 Mock 模式？

A: 设置 `ApiConfig.enableMockMode = false` 或在初始化时强制使用真实接口模式。

## 更新日志

- **v1.0.0**: 初始版本，支持基础的音频数据获取和 Mock 功能
- 支持搜索、分页、标签过滤
- 完整的错误处理和用户反馈
- 开发模式下的接口切换功能 