# 安全存储使用说明

## 概述

本项目使用 `flutter_secure_storage` 来安全存储敏感信息，如访问令牌、刷新令牌、用户信息等。这比使用 `SharedPreferences` 更安全，因为数据会被加密存储。

## 安全特性

### 1. **Android 平台**
- 使用 `EncryptedSharedPreferences` 进行数据加密
- 数据存储在应用的私有目录中
- 支持生物识别加密（如果设备支持）

### 2. **iOS 平台**
- 使用 `Keychain` 进行数据存储
- 数据在首次解锁设备后可用
- 不同步到 iCloud，保持数据本地化

### 3. **Web 平台**
- 使用加密的数据库存储
- 支持自定义数据库名称和公钥

## 使用方法

### 1. **安装依赖**

在 `pubspec.yaml` 中添加：
```yaml
dependencies:
  flutter_secure_storage: ^9.0.0
```

### 2. **基本操作**

```dart
import 'package:your_app/services/secure_storage_service.dart';

// 存储访问令牌
await SecureStorageService.saveAccessToken('your_access_token');

// 获取访问令牌
final token = await SecureStorageService.getAccessToken();

// 删除访问令牌
await SecureStorageService.deleteAccessToken();

// 清除所有认证数据
await SecureStorageService.clearAllAuthData();
```

### 3. **存储的数据类型**

| 数据类型 | 键名 | 说明 |
|---------|------|------|
| 访问令牌 | `access_token` | 用于API认证的访问令牌 |
| 刷新令牌 | `refresh_token` | 用于刷新访问令牌的刷新令牌 |
| 令牌过期时间 | `token_expires_at` | 访问令牌的过期时间戳 |
| 用户信息 | `user_info` | 用户的详细信息（JSON格式） |
| 设备ID | `device_id` | 设备的唯一标识符 |

## 迁移指南

### 从 SharedPreferences 迁移

如果你之前使用 `SharedPreferences` 存储敏感信息，可以按以下步骤迁移：

```dart
// 1. 从 SharedPreferences 读取数据
final prefs = await SharedPreferences.getInstance();
final oldToken = prefs.getString('old_access_token');

// 2. 保存到安全存储
if (oldToken != null) {
  await SecureStorageService.saveAccessToken(oldToken);
  
  // 3. 删除旧数据
  await prefs.remove('old_access_token');
}
```

### 批量迁移

```dart
Future<void> migrateToSecureStorage() async {
  final prefs = await SharedPreferences.getInstance();
  
  // 迁移访问令牌
  final accessToken = prefs.getString('access_token');
  if (accessToken != null) {
    await SecureStorageService.saveAccessToken(accessToken);
    await prefs.remove('access_token');
  }
  
  // 迁移刷新令牌
  final refreshToken = prefs.getString('refresh_token');
  if (refreshToken != null) {
    await SecureStorageService.saveRefreshToken(refreshToken);
    await prefs.remove('refresh_token');
  }
  
  // 迁移用户信息
  final userInfo = prefs.getString('user_info');
  if (userInfo != null) {
    await SecureStorageService.saveUserInfo(userInfo);
    await prefs.remove('user_info');
  }
  
  print('数据迁移完成');
}
```

## 最佳实践

### 1. **错误处理**
```dart
try {
  final token = await SecureStorageService.getAccessToken();
  if (token != null) {
    // 使用令牌
  } else {
    // 处理令牌不存在的情况
  }
} catch (e) {
  print('获取令牌失败: $e');
  // 处理错误
}
```

### 2. **数据验证**
```dart
Future<bool> isTokenValid() async {
  try {
    final token = await SecureStorageService.getAccessToken();
    final expiresAt = await SecureStorageService.getTokenExpiresAt();
    
    if (token == null || expiresAt == null) {
      return false;
    }
    
    final now = DateTime.now().millisecondsSinceEpoch;
    return now < expiresAt;
  } catch (e) {
    return false;
  }
}
```

### 3. **定期清理**
```dart
Future<void> cleanupExpiredTokens() async {
  try {
    final expiresAt = await SecureStorageService.getTokenExpiresAt();
    if (expiresAt != null) {
      final now = DateTime.now().millisecondsSinceEpoch;
      if (now >= expiresAt) {
        await SecureStorageService.clearAllAuthData();
        print('已清理过期的令牌');
      }
    }
  } catch (e) {
    print('清理过期令牌失败: $e');
  }
}
```

## 安全注意事项

### 1. **不要存储敏感信息**
- ✅ 存储：访问令牌、刷新令牌、用户ID
- ❌ 不要存储：密码、信用卡信息、社会安全号码

### 2. **定期轮换令牌**
```dart
// 在令牌即将过期时自动刷新
if (token.isExpiringSoon) {
  await refreshToken();
}
```

### 3. **登出时清理数据**
```dart
Future<void> signOut() async {
  // 调用服务器登出
  await apiService.logout();
  
  // 清理本地存储
  await SecureStorageService.clearAllAuthData();
}
```

## 故障排除

### 1. **数据丢失**
- 检查设备是否支持加密存储
- 确认应用权限设置
- 验证存储键名是否正确

### 2. **性能问题**
- 避免频繁的读写操作
- 使用缓存减少存储访问
- 批量操作时使用 `Future.wait`

### 3. **平台兼容性**
- Android: 确保设备支持加密存储
- iOS: 检查 Keychain 访问权限
- Web: 验证浏览器兼容性

## 总结

使用 `flutter_secure_storage` 可以显著提高应用的安全性，特别是对于存储敏感认证信息。通过遵循最佳实践和正确处理错误，可以确保用户数据的安全性和应用的稳定性。

记住：安全存储不是万能的，它只是保护本地数据的一种方式。对于高度敏感的信息，仍然需要额外的安全措施，如服务器端验证、加密传输等。 