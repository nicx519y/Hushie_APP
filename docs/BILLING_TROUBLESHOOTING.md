# Google Play Billing 故障排除指南

## 🚨 已知问题

### OnePlus 设备 + Android 11 PendingIntent 问题

**问题描述：**
在 OnePlus 设备上运行 Android 11 时，Google Play Billing Library 7.1.1 的 `ProxyBillingActivity.onCreate` 方法中出现 `NullPointerException`，错误发生在 `PendingIntent.getIntentSender()` 调用时。

**错误堆栈：**
```
java.lang.NullPointerException: Attempt to invoke virtual method 'android.content.IntentSender android.app.PendingIntent.getIntentSender()' on a null object reference
    at com.android.billingclient.api.ProxyBillingActivity.onCreate(ProxyBillingActivity.java:XX)
```

**根本原因：**
1. **PendingIntent 为空：** BillingClient 在启动购买流程时未能正确创建或传递 PendingIntent
2. **设备特定问题：** OnePlus 对 Android 系统的定制可能影响 Intent 处理机制
3. **Android 11 兼容性：** Android 11 对 PendingIntent 的可变性要求更严格

## 🛠️ 解决方案

### 1. 库版本升级
- ✅ 已升级 Google Play Billing Library 到 7.1.1
- ✅ 已升级 in_app_purchase Flutter 插件到最新版本

### 2. 错误处理增强
- ✅ 添加设备检测逻辑，识别 OnePlus 设备
- ✅ 添加 Android 版本检测，特别处理 Android 11+
- ✅ 实现设备特定的错误处理和用户提示

### 3. 购买流程改进
- ✅ 添加服务初始化状态检查
- ✅ 增强日志记录，便于问题诊断
- ✅ 添加购买流程超时机制
- ✅ 改进异常处理和资源清理

### 4. 重试机制
- ✅ 为高风险设备配置实现智能重试策略
- ✅ OnePlus + Android 11 设备：最多重试 2 次，延迟 3 秒
- ✅ 其他设备：最多重试 1 次，延迟 1 秒

## 📱 设备特定处理

### OnePlus 设备检测
```dart
// 自动检测 OnePlus 设备
final isOnePlusDevice = deviceInfo.manufacturer.toLowerCase().contains('oneplus');
```

### Android 11+ 检测
```dart
// 检测 Android 11 或更高版本
final isAndroid11Plus = deviceInfo.version.sdkInt >= 30;
```

### 高风险配置
当同时满足以下条件时，被标记为高风险配置：
- OnePlus 设备
- Android 11 或更高版本

## 🔧 用户操作建议

### 对于 OnePlus 用户
1. **重启应用**：完全关闭应用后重新打开
2. **清除 Google Play 商店缓存**：
   - 设置 → 应用管理 → Google Play 商店 → 存储 → 清除缓存
3. **更新 Google Play 商店**：确保使用最新版本
4. **重启设备**：在某些情况下可以解决系统级问题

### 对于所有用户
1. **检查网络连接**：确保网络稳定
2. **检查 Google 账户**：确保已正确登录 Google 账户
3. **检查支付方式**：确保 Google 账户绑定了有效的支付方式

## 📊 监控和日志

### 错误收集
应用会自动收集以下信息用于问题诊断：
- 设备制造商和型号
- Android 版本和 SDK 级别
- 错误发生时的详细堆栈信息
- 购买流程的各个阶段状态

### 日志标识
在日志中查找以下标识：
- `🚨 Billing 错误报告` - 设备特定错误
- `❌ 购买流程启动失败` - 购买流程问题
- `⏰ 购买流程超时` - 超时问题

## 🔄 版本历史

### v1.0.2+25
- ✅ 升级 Billing Library 到 7.1.1
- ✅ 添加 OnePlus 设备特殊处理
- ✅ 实现智能重试机制
- ✅ 增强错误处理和日志记录

## 📞 技术支持

如果问题仍然存在，请联系技术支持并提供：
1. 设备型号和 Android 版本
2. 应用版本号
3. 错误发生的具体步骤
4. 应用日志（如果可能）

---

**注意：** 此问题主要影响 OnePlus 设备上的 Android 11 用户。我们正在持续监控和改进相关处理逻辑。