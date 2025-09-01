import 'dart:io';
import 'package:device_info_plus/device_info_plus.dart';

/// 设备信息服务
class DeviceInfoService {
  static final DeviceInfoPlugin _deviceInfoPlugin = DeviceInfoPlugin();

  /// 获取设备ID
  static Future<String> getDeviceId() async {
    try {
      if (Platform.isAndroid) {
        final androidInfo = await _deviceInfoPlugin.androidInfo;
        return androidInfo.id;
      } else if (Platform.isIOS) {
        final iosInfo = await _deviceInfoPlugin.iosInfo;
        return iosInfo.identifierForVendor ?? 'unknown_ios_device';
      } else if (Platform.isWindows) {
        final windowsInfo = await _deviceInfoPlugin.windowsInfo;
        return windowsInfo.deviceId;
      } else if (Platform.isMacOS) {
        final macOsInfo = await _deviceInfoPlugin.macOsInfo;
        return macOsInfo.systemGUID ?? 'unknown_macos_device';
      } else if (Platform.isLinux) {
        final linuxInfo = await _deviceInfoPlugin.linuxInfo;
        return linuxInfo.machineId ?? 'unknown_linux_device';
      } else {
        return 'unknown_device';
      }
    } catch (e) {
      print('获取设备ID失败: $e');
      return 'unknown_device';
    }
  }

  /// 获取设备信息
  static Future<Map<String, String>> getDeviceInfo() async {
    try {
      final Map<String, String> deviceInfo = {};

      if (Platform.isAndroid) {
        final androidInfo = await _deviceInfoPlugin.androidInfo;
        deviceInfo['platform'] = 'Android';
        deviceInfo['version'] = androidInfo.version.release;
        deviceInfo['brand'] = androidInfo.brand;
        deviceInfo['model'] = androidInfo.model;
        deviceInfo['device_id'] = androidInfo.id;
      } else if (Platform.isIOS) {
        final iosInfo = await _deviceInfoPlugin.iosInfo;
        deviceInfo['platform'] = 'iOS';
        deviceInfo['version'] = iosInfo.systemVersion;
        deviceInfo['brand'] = 'Apple';
        deviceInfo['model'] = iosInfo.model;
        deviceInfo['device_id'] = iosInfo.identifierForVendor ?? 'unknown';
      } else if (Platform.isWindows) {
        final windowsInfo = await _deviceInfoPlugin.windowsInfo;
        deviceInfo['platform'] = 'Windows';
        deviceInfo['version'] = windowsInfo.buildNumber.toString();
        deviceInfo['brand'] = 'Microsoft';
        deviceInfo['model'] = 'PC';
        deviceInfo['device_id'] = windowsInfo.deviceId;
      } else if (Platform.isMacOS) {
        final macOsInfo = await _deviceInfoPlugin.macOsInfo;
        deviceInfo['platform'] = 'macOS';
        deviceInfo['version'] = macOsInfo.osRelease;
        deviceInfo['brand'] = 'Apple';
        deviceInfo['model'] = macOsInfo.model;
        deviceInfo['device_id'] = macOsInfo.systemGUID ?? 'unknown';
      } else if (Platform.isLinux) {
        final linuxInfo = await _deviceInfoPlugin.linuxInfo;
        deviceInfo['platform'] = 'Linux';
        deviceInfo['version'] = linuxInfo.version ?? 'Unknown';
        deviceInfo['brand'] = 'Linux';
        deviceInfo['model'] = 'PC';
        deviceInfo['device_id'] = linuxInfo.machineId ?? 'unknown';
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
