# Android 启动页面配置说明

## 概述
本项目已配置自定义Android启动页面，使用logo.png图标和主题色背景。

## 配置文件

### 1. 启动页面背景配置
- **文件位置**: `android/app/src/main/res/drawable/launch_background.xml`
- **功能**: 定义启动页面的背景和图标布局

### 2. Android 5.0+ 启动页面配置
- **文件位置**: `android/app/src/main/res/drawable-v21/launch_background.xml`
- **功能**: 为Android 5.0及以上版本提供启动页面配置

### 3. 启动页面样式
- **文件位置**: `android/app/src/main/res/values/styles.xml`
- **功能**: 定义LaunchTheme样式，应用启动页面背景

### 4. 夜间模式启动页面样式
- **文件位置**: `android/app/src/main/res/values-night/styles.xml`
- **功能**: 为夜间模式提供启动页面样式

## 启动页面特性

### 背景颜色
- 使用主题色 `#F359AA`（粉色）
- 支持日间和夜间模式

### Logo图标
- 使用 `@drawable/logo` 资源
- 居中显示
- 图标文件：`android/app/src/main/res/drawable/logo.png`

## 如何修改

### 更换背景颜色
修改 `launch_background.xml` 中的颜色值：
```xml
<solid android:color="#你的颜色代码" />
```

### 更换Logo图标
1. 将新的图标文件复制到 `android/app/src/main/res/drawable/` 目录
2. 修改 `launch_background.xml` 中的图标引用：
```xml
android:src="@drawable/你的图标名称"
```

### 调整Logo位置
修改 `android:gravity` 属性：
- `center`: 居中
- `center_horizontal|top`: 水平居中，顶部对齐
- `center_horizontal|bottom`: 水平居中，底部对齐

## 注意事项

1. **图标格式**: Android启动页面只支持位图格式（PNG、JPG等），不支持SVG
2. **分辨率**: 建议使用高分辨率图标以确保在不同设备上的显示效果
3. **文件大小**: 启动页面图标不宜过大，以免影响启动速度
4. **缓存**: 修改启动页面后，可能需要清理应用缓存或重新安装才能看到效果

## 测试

启动页面会在以下情况显示：
1. 应用冷启动时
2. 从后台恢复时（如果系统回收了应用进程）

要测试启动页面效果，可以：
1. 完全关闭应用
2. 重新启动应用
3. 观察启动过程中的页面显示 