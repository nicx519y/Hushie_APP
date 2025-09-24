import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter/foundation.dart';

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
  static const String _appVersionKey = 'app_version';

  /// 存储访问令牌
  static Future<bool> saveAccessToken(String token) async {
    try {
      await _storage.write(key: _accessTokenKey, value: token);
      return true;
    } catch (e) {
      debugPrint('保存访问令牌失败: $e');
      return false;
    }
  }

  /// 获取访问令牌
  static Future<String?> getAccessToken() async {
    try {
      return await _storage.read(key: _accessTokenKey);
    } catch (e) {
      debugPrint('获取访问令牌失败: $e');
      return null;
    }
  }

  /// 存储刷新令牌
  static Future<bool> saveRefreshToken(String token) async {
    try {
      await _storage.write(key: _refreshTokenKey, value: token);
      return true;
    } catch (e) {
      debugPrint('保存刷新令牌失败: $e');
      return false;
    }
  }

  /// 获取刷新令牌
  static Future<String?> getRefreshToken() async {
    try {
      return await _storage.read(key: _refreshTokenKey);
    } catch (e) {
      debugPrint('获取刷新令牌失败: $e');
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
      debugPrint('保存令牌过期时间失败: $e');
      return false;
    }
  }

  /// 获取令牌过期时间
  static Future<int?> getTokenExpiresAt() async {
    try {
      final value = await _storage.read(key: _tokenExpiresAtKey);
      return value != null ? int.tryParse(value) : null;
    } catch (e) {
      debugPrint('获取令牌过期时间失败: $e');
      return null;
    }
  }

  /// 存储用户信息
  static Future<bool> saveUserInfo(String userInfo) async {
    try {
      await _storage.write(key: _userInfoKey, value: userInfo);
      return true;
    } catch (e) {
      debugPrint('保存用户信息失败: $e');
      return false;
    }
  }

  /// 获取用户信息
  static Future<String?> getUserInfo() async {
    try {
      return await _storage.read(key: _userInfoKey);
    } catch (e) {
      debugPrint('获取用户信息失败: $e');
      return null;
    }
  }

  /// 存储设备ID
  static Future<bool> saveDeviceId(String deviceId) async {
    try {
      await _storage.write(key: _deviceIdKey, value: deviceId);
      return true;
    } catch (e) {
      debugPrint('保存设备ID失败: $e');
      return false;
    }
  }

  /// 获取设备ID
  static Future<String?> getDeviceId() async {
    try {
      return await _storage.read(key: _deviceIdKey);
    } catch (e) {
      debugPrint('获取设备ID失败: $e');
      return null;
    }
  }

  /// 删除访问令牌
  static Future<bool> deleteAccessToken() async {
    try {
      await _storage.delete(key: _accessTokenKey);
      return true;
    } catch (e) {
      debugPrint('删除访问令牌失败: $e');
      return false;
    }
  }

  /// 删除刷新令牌
  static Future<bool> deleteRefreshToken() async {
    try {
      await _storage.delete(key: _refreshTokenKey);
      return true;
    } catch (e) {
      debugPrint('删除刷新令牌失败: $e');
      return false;
    }
  }

  /// 删除令牌过期时间
  static Future<bool> deleteTokenExpiresAt() async {
    try {
      await _storage.delete(key: _tokenExpiresAtKey);
      return true;
    } catch (e) {
      debugPrint('删除令牌过期时间失败: $e');
      return false;
    }
  }

  /// 删除用户信息
  static Future<bool> deleteUserInfo() async {
    try {
      await _storage.delete(key: _userInfoKey);
      return true;
    } catch (e) {
      debugPrint('删除用户信息失败: $e');
      return false;
    }
  }

  /// 删除设备ID
  static Future<bool> deleteDeviceId() async {
    try {
      await _storage.delete(key: _deviceIdKey);
      return true;
    } catch (e) {
      debugPrint('删除设备ID失败: $e');
      return false;
    }
  }

  /// 清除所有数据
  static Future<bool> clearAll() async {
    try {
      await _storage.deleteAll();
      return true;
    } catch (e) {
      debugPrint('清除所有数据失败: $e');
      return false;
    }
  }

  /// 检查是否包含特定键
  static Future<bool> containsKey(String key) async {
    try {
      return await _storage.containsKey(key: key);
    } catch (e) {
      debugPrint('检查键存在失败: $e');
      return false;
    }
  }

  /// 获取所有键
  static Future<List<String>> getAllKeys() async {
    try {
      return await _storage.readAll().then((map) => map.keys.toList());
    } catch (e) {
      debugPrint('获取所有键失败: $e');
      return [];
    }
  }

  /// 批量读取认证相关数据
  /// 返回包含accessToken、refreshToken、expiresAt的Map
  static Future<Map<String, String?>> getAllAuthData() async {
    try {
      final allData = await _storage.readAll();
      return {
        'accessToken': allData[_accessTokenKey],
        'refreshToken': allData[_refreshTokenKey],
        'expiresAt': allData[_tokenExpiresAtKey],
        'userInfo': allData[_userInfoKey],
      };
    } catch (e) {
      debugPrint('批量获取认证数据失败: $e');
      return {
        'accessToken': null,
        'refreshToken': null,
        'expiresAt': null,
        'userInfo': null,
      };
    }
  }

  /// 通用方法：存储字符串
  static Future<bool> setString(String key, String value) async {
    try {
      await _storage.write(key: key, value: value);
      return true;
    } catch (e) {
      debugPrint('存储字符串失败 key=$key: $e');
      return false;
    }
  }

  /// 通用方法：获取字符串
  static Future<String?> getString(String key) async {
    try {
      return await _storage.read(key: key);
    } catch (e) {
      debugPrint('获取字符串失败 key=$key: $e');
      return null;
    }
  }

  /// 通用方法：删除指定键
  static Future<bool> deleteKey(String key) async {
    try {
      await _storage.delete(key: key);
      return true;
    } catch (e) {
      debugPrint('删除键失败 key=$key: $e');
      return false;
    }
  }

  /// 存储应用版本号
  static Future<bool> saveAppVersion(String version) async {
    try {
      await _storage.write(key: _appVersionKey, value: version);
      return true;
    } catch (e) {
      debugPrint('保存应用版本号失败: $e');
      return false;
    }
  }

  /// 获取应用版本号
  static Future<String?> getAppVersion() async {
    try {
      return await _storage.read(key: _appVersionKey);
    } catch (e) {
      debugPrint('获取应用版本号失败: $e');
      return null;
    }
  }

  /// 删除应用版本号
  static Future<bool> deleteAppVersion() async {
    try {
      await _storage.delete(key: _appVersionKey);
      return true;
    } catch (e) {
      debugPrint('删除应用版本号失败: $e');
      return false;
    }
  }
}
