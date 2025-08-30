# 动态 Tabs 接口说明

## 概述

本项目实现了动态 tabs 管理系统，支持从服务器动态获取首页的 tab 配置，并实现本地缓存和离线支持。

## 功能特性

- ✅ **动态 Tabs**: 支持从服务器动态获取 tab 配置
- ✅ **固定 Tab**: "For You" tab 始终固定为第一个
- ✅ **本地缓存**: 支持本地存储和缓存过期管理
- ✅ **离线支持**: 网络失败时使用缓存数据
- ✅ **实时刷新**: 支持手动刷新 tabs 配置
- ✅ **Mock 支持**: 开发时支持 Mock 数据模式

## 架构设计

### 1. 数据模型

```dart
class TabItem {
  final String id;           // 唯一标识
  final String title;        // 显示标题
  final String? icon;        // 图标（可选）
  final String? tag;         // API 请求标签
  final bool isDefault;      // 是否为默认 tab
  final int order;           // 排序
  final bool isEnabled;      // 是否启用
}
```

### 2. 核心服务

#### TabManager
- 管理 tabs 的获取、缓存和本地存储
- 实现缓存过期策略（默认24小时）
- 提供离线兜底方案

#### ApiService
- 支持 Mock 和真实接口两种模式
- 统一的错误处理和响应格式

### 3. 缓存策略

```
1. 优先使用本地缓存（未过期）
2. 缓存过期时从服务器获取
3. 服务器失败时使用过期缓存
4. 所有方法失败时使用默认 tabs
```

## API 接口

### 获取首页 Tabs

**接口地址**: `GET /home/tabs`

**响应格式**:
```json
{
  "success": true,
  "message": "获取 tabs 成功",
  "data": [
    {
      "id": "mf",
      "title": "M/F",
      "tag": "M/F",
      "order": 1,
      "is_enabled": true
    },
    {
      "id": "fm",
      "title": "F/M", 
      "tag": "F/M",
      "order": 2,
      "is_enabled": true
    }
  ]
}
```

### Mock 数据

Mock 模式下返回预定义的 tabs：
- M/F (tag: "M/F")
- F/M (tag: "F/M") 
- ASMR (tag: "ASMR")
- NSFW (tag: "NSFW")

## 使用方法

### 1. 基本使用

```dart
// 获取所有 tabs
final tabs = await TabManager.instance.getAllTabs();

// 强制刷新 tabs
final refreshedTabs = await TabManager.instance.refreshTabs();
```

### 2. 在 HomePage 中使用

```dart
class HomePage extends StatefulWidget {
  @override
  void initState() {
    super.initState();
    _initializeTabs(); // 异步初始化 tabs
  }

  Future<void> _initializeTabs() async {
    final tabs = await TabManager.instance.getAllTabs();
    setState(() {
      _tabItems = tabs;
    });
    // 初始化 TabController 等
  }
}
```

### 3. 手动刷新

```dart
// 刷新按钮
TextButton(
  onPressed: _refreshTabs,
  child: Text('刷新 Tabs'),
),

Future<void> _refreshTabs() async {
  final tabs = await TabManager.instance.refreshTabs();
  // 更新 UI 和 TabController
}
```

## 配置说明

### 1. 缓存配置

```dart
class TabManager {
  // 缓存过期时间（24小时）
  static const Duration _cacheExpiry = Duration(hours: 24);
  
  // 本地存储的 key
  static const String _storageKey = 'home_tabs';
  static const String _lastUpdateKey = 'home_tabs_last_update';
}
```

### 2. 默认 Tabs

```dart
// 默认的 "For You" tab
static const TabItem _defaultForYouTab = TabItem(
  id: 'for_you',
  title: 'For You',
  tag: null,
  isDefault: true,
  order: 0,
  isEnabled: true,
);
```

## 开发调试

### 1. 查看缓存状态

```dart
// 在控制台查看缓存信息
print('使用缓存的 tabs: ${cachedTabs.length} 个');
print('已保存 ${tabs.length} 个 tabs 到本地存储');
```

### 2. 清除缓存

```dart
// 清除本地缓存
await TabManager.instance.clearCache();
```

### 3. 切换 API 模式

```dart
// 切换到 Mock 模式
ApiService.setApiMode(ApiMode.mock);

// 切换到真实接口模式  
ApiService.setApiMode(ApiMode.real);
```

## 错误处理

### 1. 网络错误

- 自动使用缓存数据
- 显示用户友好的错误提示
- 提供重试机制

### 2. 数据错误

- 使用默认 tabs 作为兜底
- 记录错误日志
- 不影响应用正常运行

### 3. 缓存错误

- 重新从服务器获取
- 使用默认配置
- 清理损坏的缓存数据

## 性能优化

### 1. 延迟加载

- Tabs 在 initState 中异步加载
- 不阻塞 UI 渲染
- 支持加载状态指示

### 2. 智能缓存

- 避免重复网络请求
- 合理的过期策略
- 内存和磁盘双重缓存

### 3. 错误恢复

- 多层级的错误处理
- 优雅的降级策略
- 用户体验优先

## 扩展功能

### 1. 自定义 Tab 样式

```dart
// 支持图标、颜色等自定义属性
Tab(
  child: Row(
    children: [
      Icon(tab.icon),
      Text(tab.title),
    ],
  ),
)
```

### 2. 动态权限控制

```dart
// 根据用户权限显示/隐藏 tabs
if (tab.isEnabled && userHasPermission(tab.id)) {
  // 显示 tab
}
```

### 3. A/B 测试支持

```dart
// 支持不同用户看到不同的 tab 配置
final tabs = await TabManager.instance.getAllTabs(
  userId: currentUser.id,
  experimentId: currentExperiment.id,
);
```

## 注意事项

1. **TabController 管理**: 动态 tabs 需要正确管理 TabController 的生命周期
2. **状态同步**: 确保 tabs 变化时相关状态数据同步更新
3. **错误边界**: 提供完善的错误处理和用户反馈
4. **性能考虑**: 避免频繁的 tabs 刷新和重建

## 更新日志

- **v1.0.0**: 初始版本，支持基础的动态 tabs 功能
- 支持本地缓存和离线使用
- 完整的错误处理和降级策略
- Mock 数据模式支持 