import 'dart:io';
import 'dart:math';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:crypto/crypto.dart';

/// 应用动态签名验证服务
/// 实现基于HMAC-SHA256的动态签名生成和验证
class AppSignatureService {
  static const MethodChannel _channel = MethodChannel('app_signature_verification');
  
  // 与服务器约定的密钥（实际项目中应该从安全存储获取）
  static const String _secretKey = 'your_secret_key_here';
  
  // 缓存签名哈希，避免重复获取
  static String? _cachedSignatureHash;
  static DateTime? _lastCacheTime;
  static const Duration _cacheValidDuration = Duration(minutes: 10);
  
  /// 获取应用签名哈希
  /// @return 签名哈希值，如果获取失败返回null
  Future<String?> getSignatureHash() async {
    try {
      // 检查缓存是否有效
      if (_cachedSignatureHash != null && 
          _lastCacheTime != null && 
          DateTime.now().difference(_lastCacheTime!).compareTo(_cacheValidDuration) < 0) {
        debugPrint('🔐 [SIGNATURE] 使用缓存的签名哈希');
        return _cachedSignatureHash;
      }
      
      final String result = await _channel.invokeMethod('getSignatureHash');
      _cachedSignatureHash = result;
      _lastCacheTime = DateTime.now();
      debugPrint('🔐 [SIGNATURE] 获取Android签名哈希: $result');
      return result;
    } catch (e) {
      debugPrint('🔐 [SIGNATURE] 获取签名哈希失败: $e');
      return null;
    }
  }
  
  /// 生成动态签名参数
  /// @return 包含签名、时间戳、随机数的Map，如果生成失败返回null
  Future<Map<String, String>?> generateDynamicSignature() async {
    try {
      // 1. 生成时间戳（毫秒）
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      
      // 2. 生成随机数
      final nonce = _generateNonce();
      
      // 3. 生成动态签名
      final dynamic signatureResult = await _channel.invokeMethod('generateDynamicSignature', {
        'timestamp': timestamp,
        'nonce': nonce,
        'secretKey': _secretKey,
      });
      
      if (signatureResult == null) {
        debugPrint('🔐 [SIGNATURE] 动态签名生成失败');
        return null;
      }
      
      final Map<String, dynamic> resultMap = Map<String, dynamic>.from(signatureResult as Map);
      final result = {
        'signature': resultMap['signature']?.toString() ?? '',
        'timestamp': resultMap['timestamp']?.toString() ?? timestamp.toString(),
        'nonce': resultMap['nonce']?.toString() ?? nonce,
      };
      
      debugPrint('🔐 [SIGNATURE] 动态签名生成成功: ${result['signature']?.substring(0, 10)}...');
      return result;
    } catch (e) {
      debugPrint('🔐 [SIGNATURE] 生成动态签名失败: $e');
      return null;
    }
  }
  
  /// 生成随机数
  /// @return 16位随机字符串
  String _generateNonce() {
    const chars = 'abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789';
    final random = Random.secure();
    return List.generate(16, (index) => chars[random.nextInt(chars.length)]).join();
  }
  

  
  /// 验证应用签名（兼容旧接口）
  /// @return 始终返回true，实际验证由服务器完成
  Future<bool> verifySignature() async {
    final signatureHash = await getSignatureHash();
    return signatureHash != null;
  }
  
  /// 获取签名信息（兼容旧接口）
  /// @return 签名信息字符串
  Future<String> getSignatureInfo() async {
    try {
      final hash = await getSignatureHash();
      if (hash != null) {
        return 'SHA256:$hash';
      } else {
        return 'SIGNATURE_UNAVAILABLE';
      }
    } catch (e) {
      debugPrint('🔐 [SIGNATURE] 获取签名信息失败: $e');
      return 'SIGNATURE_ERROR';
    }
  }
  
  /// 清除缓存
  static void clearCache() {
    _cachedSignatureHash = null;
    _lastCacheTime = null;
    debugPrint('🔐 [SIGNATURE] 签名缓存已清除');
  }
  
  /// 验证应用签名（静态方法，兼容旧代码）
  static Future<bool> verifyAppSignature() async {
    final service = AppSignatureService();
    return await service.verifySignature();
  }
  
  /// 获取应用完整性信息（兼容旧接口）
  Future<Map<String, dynamic>> getIntegrityInfo() async {
    try {
      final Map<dynamic, dynamic> result = await _channel.invokeMethod('getIntegrityInfo');
      return Map<String, dynamic>.from(result);
    } catch (e) {
      debugPrint('🔐 [SIGNATURE] 获取完整性信息失败: $e');
      return {
        'isSignatureValid': false,
        'installerPackageName': null,
        'isFromTrustedSource': false,
        'isDebugBuild': kDebugMode,
        'isIntegrityValid': false,
      };
    }
  }
}

/// 应用完整性信息模型
class AppIntegrityInfo {
  final bool isSignatureValid;
  final String? installerPackageName;
  final bool isFromTrustedSource;
  final bool isDebugBuild;
  final bool isIntegrityValid;
  
  const AppIntegrityInfo({
    required this.isSignatureValid,
    this.installerPackageName,
    required this.isFromTrustedSource,
    required this.isDebugBuild,
    required this.isIntegrityValid,
  });
  
  factory AppIntegrityInfo.fromMap(Map<String, dynamic> map) {
    return AppIntegrityInfo(
      isSignatureValid: map['isSignatureValid'] ?? false,
      installerPackageName: map['installerPackageName'],
      isFromTrustedSource: map['isFromTrustedSource'] ?? false,
      isDebugBuild: map['isDebugBuild'] ?? false,
      isIntegrityValid: map['isIntegrityValid'] ?? false,
    );
  }
  
  Map<String, dynamic> toMap() {
    return {
      'isSignatureValid': isSignatureValid,
      'installerPackageName': installerPackageName,
      'isFromTrustedSource': isFromTrustedSource,
      'isDebugBuild': isDebugBuild,
      'isIntegrityValid': isIntegrityValid,
    };
  }
  
  @override
  String toString() {
    return 'AppIntegrityInfo(isSignatureValid: $isSignatureValid, '
           'installerPackageName: $installerPackageName, '
           'isFromTrustedSource: $isFromTrustedSource, '
           'isDebugBuild: $isDebugBuild, '
           'isIntegrityValid: $isIntegrityValid)';
  }
}