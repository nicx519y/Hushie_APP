# Google Sign-In 配置指南

本文档说明如何在 Hushie.AI 应用中配置 Google 登录功能。

## 1. 依赖配置

### 1.1 添加依赖

已在 `pubspec.yaml` 中添加了以下依赖：
- `google_sign_in: ^6.2.1` - Google 登录插件
- `device_info_plus: ^10.1.0` - 设备信息插件

### 1.2 安装依赖

```bash
flutter pub get
```

## 2. 认证流程

### 2.1 完整流程

1. **Google 登录**: 用户通过 Google 账号登录，获取 ID Token
2. **获取设备信息**: 获取当前设备的唯一标识符
3. **请求 Access Token**: 将 Google ID Token 和设备 ID 发送到服务器
4. **获取 Access Token**: 服务器验证后返回访问令牌

### 2.2 API 端点

- **Google 登录**: `/auth/google` (POST)
- **获取 Access Token**: `/auth/google/token` (POST)
- **登出**: `/auth/google/logout` (POST)
- **删除账户**: `/auth/google/delete` (POST)

## 3. Android 配置

### 3.1 创建 Google Cloud Project

1. 访问 [Google Cloud Console](https://console.cloud.google.com/)
2. 创建新项目或选择现有项目
3. 启用 Google Sign-In API

### 3.2 配置 OAuth 2.0

1. 在 Google Cloud Console 中，转到 "APIs & Services" > "Credentials"
2. 点击 "Create Credentials" > "OAuth 2.0 Client IDs"
3. 选择 "Android" 应用类型
4. 填写应用信息：
   - Package name: `com.example.hushie_app`
   - SHA-1 certificate fingerprint: 获取方法见下方

### 3.3 获取 SHA-1 指纹

#### Debug 版本：
```bash
cd android
./gradlew signingReport
```

#### Release 版本：
```bash
keytool -list -v -keystore <your-keystore-path> -alias <your-key-alias>
```

### 3.4 下载配置文件

1. 下载 `google-services.json` 文件
2. 将文件放置在 `android/app/` 目录下
3. 确保文件已添加到版本控制（不要忽略）

### 3.5 更新 build.gradle

已在 `android/app/build.gradle.kts` 中添加了 Google Services 插件。

## 4. iOS 配置

### 4.1 配置 OAuth 2.0

1. 在 Google Cloud Console 中，创建 iOS 类型的 OAuth 2.0 客户端 ID
2. Bundle ID: `com.example.hushieApp`

### 4.2 下载配置文件

1. 下载 `GoogleService-Info.plist` 文件
2. 将文件添加到 iOS 项目中
3. 确保文件已添加到版本控制

### 4.3 更新 Info.plist

在 `ios/Runner/Info.plist` 中添加：

```xml
<key>CFBundleURLTypes</key>
<array>
    <dict>
        <key>CFBundleURLName</key>
        <string>REVERSED_CLIENT_ID</string>
        <key>CFBundleURLSchemes</key>
        <array>
            <string>REVERSED_CLIENT_ID_FROM_GOOGLESERVICE_INFO_PLIST</string>
        </array>
    </dict>
</array>
```

## 5. 使用方法

### 5.1 使用 AuthService（推荐）

`AuthService` 提供了完整的账户管理功能，推荐使用：

```dart
import 'package:hushie_app/services/auth_service.dart';

// 1. 完整的Google登录流程（自动保存到本地）
final result = await AuthService.googleSignIn();
if (result.success) {
  print('登录成功: ${result.userInfo?.displayName}');
  // 认证信息已自动保存到本地安全存储
}

// 2. 检查登录状态
final isLoggedIn = await AuthService.isLoggedIn();

// 3. 获取本地存储的access token
final accessToken = await AuthService.getAccessToken();

// 4. 获取用户信息
final userInfo = await AuthService.getUserInfo();

// 5. 登出
await AuthService.logout();

// 6. 删除账户
final deleteResult = await AuthService.deleteAccount();
```

### 5.2 基本登录流程

```dart
import 'package:hushie_app/services/api_service.dart';

// 1. Google 登录
final response = await ApiService.googleSignIn();
if (response.errNo == 0) {
  final userInfo = response.data!;
  print('登录成功: ${userInfo.displayName}');
  
  // 2. 获取 access token（自动包含设备ID）
  final tokenResponse = await ApiService.getGoogleAccessToken(
    googleToken: userInfo.idToken,
  );
  
  if (tokenResponse.errNo == 0) {
    final tokenInfo = tokenResponse.data!;
    print('获取到 access token: ${tokenInfo.accessToken}');
    print('设备ID已自动包含在请求中');
    // 保存 token 用于后续 API 调用
  }
}
```

### 5.3 检查登录状态

```dart
// 检查是否已登录
final isSignedIn = await ApiService.isGoogleSignedIn();

// 获取当前用户
final currentUser = await ApiService.getCurrentGoogleUser();
```

### 5.4 登出

```dart
// 登出
await ApiService.googleSignOut();
```

### 5.5 获取设备信息

```dart
import 'package:hushie_app/services/device_info_service.dart';

// 获取设备ID
final deviceId = await DeviceInfoService.getDeviceId();

// 获取完整设备信息
final deviceInfo = await DeviceInfoService.getDeviceInfo();
print('平台: ${deviceInfo['platform']}');
print('版本: ${deviceInfo['version']}');
print('设备ID: ${deviceInfo['device_id']}');
```

## 6. 服务器端要求

### 6.1 请求格式

服务器需要处理以下格式的请求：

#### 获取 Access Token
```json
POST /auth/google/token
{
  "google_token": "google_id_token_here",
  "device_id": "device_unique_identifier",
  "grant_type": "google_token"
}
```

#### 登出
```json
POST /auth/google/logout
{
  "action": "logout",
  "timestamp": 1234567890
}
```

#### 删除账户
```json
POST /auth/google/delete
{
  "action": "delete_account",
  "timestamp": 1234567890,
  "confirmation": true
}
```

### 6.2 响应格式

服务器应返回以下格式的响应：

#### 获取 Access Token
```json
{
  "errNo": 0,
  "data": {
    "access_token": "access_token_here",
    "refresh_token": "refresh_token_here",
    "expires_in": 3600,
    "token_type": "Bearer"
  }
}
```

#### 登出和删除账户
```json
{
  "errNo": 0,
  "data": null
}
```

## 7. 使用方式

### 7.1 基本使用

```dart
import 'package:your_app/services/auth_service.dart';

// 1. Google登录
final loginResult = await AuthService.googleLogin();
if (loginResult.success) {
  print('登录成功: ${loginResult.userInfo?.displayName}');
} else {
  print('登录失败: ${loginResult.message}');
}

// 2. 检查登录状态
final isLoggedIn = await AuthService.isLoggedIn();

// 3. 获取用户信息
final userInfo = await AuthService.getUserInfo();

// 4. 获取Access Token
final accessToken = await AuthService.getAccessToken();

// 5. 登出
final logoutResult = await AuthService.googleLogout();

// 6. 删除账户
final deleteResult = await AuthService.googleAccountDelete();
```

### 7.2 接口说明

#### `AuthService.googleLogin()`
- **功能**: 完整的Google登录流程
- **包含**: Google账户登录 → 服务器获取accessToken → 存储到本地安全存储
- **返回**: `AuthResult` 包含用户信息和token信息

#### `AuthService.googleLogout()`
- **功能**: 完整的Google登出流程
- **包含**: 请求服务器logout接口 → Google账户登出 → 清除本地安全存储
- **返回**: `AuthResult` 表示登出结果

#### `AuthService.googleAccountDelete()`
- **功能**: 完整的Google账户删除流程
- **包含**: Google账户登出 → 请求服务器删除账户接口 → 清除本地安全存储
- **返回**: `AuthResult` 表示删除结果

### 7.3 HTTP客户端服务

项目提供了统一的HTTP客户端服务 `HttpClientService`，自动处理公共请求头：

```dart
import 'package:your_app/services/http_client_service.dart';

// 基本HTTP方法
final response = await HttpClientService.get(uri);
final response = await HttpClientService.post(uri, body: data);
final response = await HttpClientService.put(uri, body: data);
final response = await HttpClientService.delete(uri);
final response = await HttpClientService.patch(uri, body: data);

// JSON便捷方法
final response = await HttpClientService.postJson(uri, body: jsonData);
final response = await HttpClientService.putJson(uri, body: jsonData);
final response = await HttpClientService.patchJson(uri, body: jsonData);
```

#### 自动添加的请求头

- **X-Device-ID**: 设备唯一标识（自动获取）
- **Authorization**: Bearer token（如果用户已登录，自动添加）
- **Content-Type**: application/json
- **Accept**: application/json
- **User-Agent**: Hushie.AI/1.0.0

#### 自定义请求头

```dart
final response = await HttpClientService.get(
  uri,
  headers: {
    'X-Custom-Header': 'custom_value',
    'X-API-Version': 'v1',
  },
);
// 自定义请求头会与自动添加的请求头合并
```

## 8. 错误处理

### 8.1 错误码说明

- `0`: 成功
- `-1`: 一般错误
- `-2`: 用户取消登录
- `500`: 服务器错误

### 8.2 常见问题

1. **SHA-1 指纹不匹配**
   - 确保使用正确的 keystore 文件
   - 检查 debug 和 release 版本的指纹

2. **OAuth 客户端 ID 不匹配**
   - 确保 Android 和 iOS 的客户端 ID 配置正确
   - 检查包名和 Bundle ID

3. **设备ID获取失败**
   - 确保已添加 `device_info_plus` 依赖
   - 检查平台权限设置

4. **网络错误**
   - 检查网络连接
   - 确保 Google 服务可访问

5. **安全存储失败**
   - 检查平台权限设置
   - 确保设备支持安全存储
   - 验证生物识别设置（如果启用）

## 9. 测试

### 9.1 Mock 模式

开发阶段可以使用 Mock 数据进行测试：

```dart
// 设置 Mock 模式
ApiService.setApiMode(ApiMode.mock);
```

### 9.2 真实测试

1. 在真实设备上测试
2. 确保 Google Play Services 已安装（Android）
3. 确保设备已登录 Google 账号
4. 验证设备ID是否正确获取

## 10. 安全注意事项

1. **不要硬编码 OAuth 客户端 ID**
2. **保护 google-services.json 和 GoogleService-Info.plist 文件**
3. **在生产环境中使用适当的签名配置**
4. **定期更新依赖版本**
5. **设备ID用于安全验证，不要泄露给用户**

## 11. 相关链接

- [Google Sign-In Flutter 插件](https://pub.dev/packages/google_sign_in)
- [Device Info Plus 插件](https://pub.dev/packages/device_info_plus)
- [Google Cloud Console](https://console.cloud.google.com/)
- [Google Sign-In 文档](https://developers.google.com/identity/sign-in/android)
- [Flutter 平台集成](https://flutter.dev/docs/development/platform-integration) 