import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// 安全存储服务
/// 用于存储敏感信息，如访问令牌、刷新令牌等
/// 使用设备加密存储，比SharedPreferences更安全
class SecureStorageService {
  static const FlutterSecureStorage _storage = FlutterSecureStorage(
    // 配置选项
    aOptions: AndroidOptions(
      encryptedSharedPreferences: true, // 使用加密的SharedPreferences
    ),
    iOptions: IOSOptions(
      accessibility: KeychainAccessibility.first_unlock, // 首次解锁后可用
      synchronizable: false, // 不同步到iCloud
    ),
    webOptions: WebOptions(
      dbName: 'hushie_secure_storage', // Web端数据库名称
      publicKey: 'hushie_public_key', // Web端公钥
    ),
  );

  // 存储键名常量
  static const String _accessTokenKey = 'access_token';
  static const String _refreshTokenKey = 'refresh_token';
  static const String _tokenExpiresAtKey = 'token_expires_at';
  static const String _userInfoKey = 'user_info';
  static const String _deviceIdKey = 'device_id';

  /// 存储访问令牌
  static Future<bool> saveAccessToken(String token) async {
    try {
      await _storage.write(key: _accessTokenKey, value: token);
      return true;
    } catch (e) {
      print('保存访问令牌失败: $e');
      return false;
    }
  }

  /// 获取访问令牌
  static Future<String?> getAccessToken() async {
    try {
      return await _storage.read(key: _accessTokenKey);
    } catch (e) {
      print('获取访问令牌失败: $e');
      return null;
    }
  }

  /// 存储刷新令牌
  static Future<bool> saveRefreshToken(String token) async {
    try {
      await _storage.write(key: _refreshTokenKey, value: token);
      return true;
    } catch (e) {
      print('保存刷新令牌失败: $e');
      return false;
    }
  }

  /// 获取刷新令牌
  static Future<String?> getRefreshToken() async {
    try {
      return await _storage.read(key: _refreshTokenKey);
    } catch (e) {
      print('获取刷新令牌失败: $e');
      return null;
    }
  }

  /// 存储令牌过期时间
  static Future<bool> saveTokenExpiresAt(int timestamp) async {
    try {
      await _storage.write(
        key: _tokenExpiresAtKey,
        value: timestamp.toString(),
      );
      return true;
    } catch (e) {
      print('保存令牌过期时间失败: $e');
      return false;
    }
  }

  /// 获取令牌过期时间
  static Future<int?> getTokenExpiresAt() async {
    try {
      final value = await _storage.read(key: _tokenExpiresAtKey);
      return value != null ? int.tryParse(value) : null;
    } catch (e) {
      print('获取令牌过期时间失败: $e');
      return null;
    }
  }

  /// 存储用户信息
  static Future<bool> saveUserInfo(String userInfo) async {
    try {
      await _storage.write(key: _userInfoKey, value: userInfo);
      return true;
    } catch (e) {
      print('保存用户信息失败: $e');
      return false;
    }
  }

  /// 获取用户信息
  static Future<String?> getUserInfo() async {
    try {
      return await _storage.read(key: _userInfoKey);
    } catch (e) {
      print('获取用户信息失败: $e');
      return null;
    }
  }

  /// 存储设备ID
  static Future<bool> saveDeviceId(String deviceId) async {
    try {
      await _storage.write(key: _deviceIdKey, value: deviceId);
      return true;
    } catch (e) {
      print('保存设备ID失败: $e');
      return false;
    }
  }

  /// 获取设备ID
  static Future<String?> getDeviceId() async {
    try {
      return await _storage.read(key: _deviceIdKey);
    } catch (e) {
      print('获取设备ID失败: $e');
      return null;
    }
  }

  /// 删除访问令牌
  static Future<bool> deleteAccessToken() async {
    try {
      await _storage.delete(key: _accessTokenKey);
      return true;
    } catch (e) {
      print('删除访问令牌失败: $e');
      return false;
    }
  }

  /// 删除刷新令牌
  static Future<bool> deleteRefreshToken() async {
    try {
      await _storage.delete(key: _refreshTokenKey);
      return true;
    } catch (e) {
      print('删除刷新令牌失败: $e');
      return false;
    }
  }

  /// 删除令牌过期时间
  static Future<bool> deleteTokenExpiresAt() async {
    try {
      await _storage.delete(key: _tokenExpiresAtKey);
      return true;
    } catch (e) {
      print('删除令牌过期时间失败: $e');
      return false;
    }
  }

  /// 删除用户信息
  static Future<bool> deleteUserInfo() async {
    try {
      await _storage.delete(key: _userInfoKey);
      return true;
    } catch (e) {
      print('删除用户信息失败: $e');
      return false;
    }
  }

  /// 删除设备ID
  static Future<bool> deleteDeviceId() async {
    try {
      await _storage.delete(key: _deviceIdKey);
      return true;
    } catch (e) {
      print('删除设备ID失败: $e');
      return false;
    }
  }

  /// 清除所有认证相关数据
  static Future<bool> clearAllAuthData() async {
    try {
      await Future.wait([
        deleteAccessToken(),
        deleteRefreshToken(),
        deleteTokenExpiresAt(),
        deleteUserInfo(),
      ]);
      return true;
    } catch (e) {
      print('清除认证数据失败: $e');
      return false;
    }
  }

  /// 清除所有数据
  static Future<bool> clearAll() async {
    try {
      await _storage.deleteAll();
      return true;
    } catch (e) {
      print('清除所有数据失败: $e');
      return false;
    }
  }

  /// 检查是否包含特定键
  static Future<bool> containsKey(String key) async {
    try {
      return await _storage.containsKey(key: key);
    } catch (e) {
      print('检查键存在失败: $e');
      return false;
    }
  }

  /// 获取所有键
  static Future<List<String>> getAllKeys() async {
    try {
      return await _storage.readAll().then((map) => map.keys.toList());
    } catch (e) {
      print('获取所有键失败: $e');
      return [];
    }
  }
}
