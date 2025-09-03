import 'dart:io';
import 'package:device_info_plus/device_info_plus.dart';
import 'secure_storage_service.dart';

/// 设备信息服务
class DeviceInfoService {
  static final DeviceInfoPlugin _deviceInfoPlugin = DeviceInfoPlugin();

  // 缓存设备ID，避免重复获取
  static String? _cachedDeviceId;
  static bool _isInitializing = false;

  /// 获取设备ID（带缓存和安全存储）
  static Future<String> getDeviceId() async {
    // 如果已有缓存，直接返回
    if (_cachedDeviceId != null) {
      return _cachedDeviceId!;
    }

    // 防止重复初始化
    if (_isInitializing) {
      // 等待初始化完成
      while (_isInitializing) {
        await Future.delayed(const Duration(milliseconds: 100));
        if (_cachedDeviceId != null) {
          return _cachedDeviceId!;
        }
      }
    }

    _isInitializing = true;

    try {
      // 首先尝试从安全存储获取
      String? deviceId = await SecureStorageService.getDeviceId();

      if (deviceId != null &&
          deviceId.isNotEmpty &&
          deviceId != 'unknown_device') {
        _cachedDeviceId = deviceId;
        print('从安全存储获取设备ID: $deviceId');
        return deviceId;
      }

      // 如果安全存储中没有，则从设备获取
      if (Platform.isAndroid) {
        final androidInfo = await _deviceInfoPlugin.androidInfo;
        deviceId = androidInfo.id;
      } else if (Platform.isIOS) {
        final iosInfo = await _deviceInfoPlugin.iosInfo;
        deviceId = iosInfo.identifierForVendor ?? 'unknown_ios_device';
      } else if (Platform.isWindows) {
        final windowsInfo = await _deviceInfoPlugin.windowsInfo;
        deviceId = windowsInfo.deviceId;
      } else if (Platform.isMacOS) {
        final macOsInfo = await _deviceInfoPlugin.macOsInfo;
        deviceId = macOsInfo.systemGUID ?? 'unknown_macos_device';
      } else if (Platform.isLinux) {
        final linuxInfo = await _deviceInfoPlugin.linuxInfo;
        deviceId = linuxInfo.machineId ?? 'unknown_linux_device';
      } else {
        deviceId = 'unknown_device';
      }

      // 将获取到的设备ID保存到安全存储
      if (deviceId.isNotEmpty && deviceId != 'unknown_device') {
        await SecureStorageService.saveDeviceId(deviceId);
        print('设备ID已保存到安全存储: $deviceId');
      }

      // 缓存设备ID
      _cachedDeviceId = deviceId;
      print('设备ID获取成功: $deviceId');
      return deviceId;
    } catch (e) {
      print('获取设备ID失败: $e');
      // 设置默认值，避免重复失败
      _cachedDeviceId = 'unknown_device';
      return _cachedDeviceId!;
    } finally {
      _isInitializing = false;
    }
  }

  /// 清除缓存（用于测试或重置）
  static void clearCache() {
    _cachedDeviceId = null;
    _isInitializing = false;
  }

  /// 从安全存储获取设备ID（不触发设备信息获取）
  static Future<String?> getDeviceIdFromSecureStorage() async {
    try {
      return await SecureStorageService.getDeviceId();
    } catch (e) {
      print('从安全存储获取设备ID失败: $e');
      return null;
    }
  }

  /// 强制刷新设备ID（重新获取并保存）
  static Future<String> refreshDeviceId() async {
    // 清除缓存
    clearCache();

    // 清除安全存储中的设备ID
    await SecureStorageService.deleteDeviceId();

    // 重新获取
    return await getDeviceId();
  }

  /// 获取设备信息（带缓存）
  static Future<Map<String, String>> getDeviceInfo() async {
    try {
      final Map<String, String> deviceInfo = {};

      // 先获取设备ID（使用缓存）
      final deviceId = await getDeviceId();
      deviceInfo['device_id'] = deviceId;

      if (Platform.isAndroid) {
        final androidInfo = await _deviceInfoPlugin.androidInfo;
        deviceInfo['platform'] = 'Android';
        deviceInfo['version'] = androidInfo.version.release;
        deviceInfo['brand'] = androidInfo.brand;
        deviceInfo['model'] = androidInfo.model;
      } else if (Platform.isIOS) {
        final iosInfo = await _deviceInfoPlugin.iosInfo;
        deviceInfo['platform'] = 'iOS';
        deviceInfo['version'] = iosInfo.systemVersion;
        deviceInfo['brand'] = 'Apple';
        deviceInfo['model'] = iosInfo.model;
      } else if (Platform.isWindows) {
        final windowsInfo = await _deviceInfoPlugin.windowsInfo;
        deviceInfo['platform'] = 'Windows';
        deviceInfo['version'] = windowsInfo.buildNumber.toString();
        deviceInfo['brand'] = 'Microsoft';
        deviceInfo['model'] = 'PC';
      } else if (Platform.isMacOS) {
        final macOsInfo = await _deviceInfoPlugin.macOsInfo;
        deviceInfo['platform'] = 'macOS';
        deviceInfo['version'] = macOsInfo.osRelease;
        deviceInfo['brand'] = 'Apple';
        deviceInfo['model'] = macOsInfo.model;
      } else if (Platform.isLinux) {
        final linuxInfo = await _deviceInfoPlugin.linuxInfo;
        deviceInfo['platform'] = 'Linux';
        deviceInfo['version'] = linuxInfo.version ?? 'Unknown';
        deviceInfo['brand'] = 'Linux';
        deviceInfo['model'] = 'PC';
      }

      return deviceInfo;
    } catch (e) {
      print('获取设备信息失败: $e');
      return {
        'platform': 'Unknown',
        'version': 'Unknown',
        'brand': 'Unknown',
        'model': 'Unknown',
        'device_id': 'unknown_device',
      };
    }
  }
}
