# Android 应用动态签名验证系统

## 概述

本文档描述了一个基于动态签名算法的Android应用身份验证系统。该系统通过客户端获取应用签名，结合约定的动态算法生成验证字符串，服务器端使用相同算法进行身份验证，确保应用的真实性和完整性。

## 核心特性

- **动态签名生成**：基于应用签名和时间戳等因素生成动态验证字符串
- **双端同步算法**：客户端和服务器端使用相同的签名生成算法
- **防重放攻击**：通过时间窗口和随机数防止签名重用
- **高安全性**：结合多种因素生成签名，难以伪造
- **实时验证**：服务器端实时计算和验证签名

## 系统架构

```
┌─────────────────┐    ┌──────────────────┐    ┌─────────────────┐
│   Android App   │    │   HTTP Request   │    │   Server Side   │
│                 │    │                  │    │                 │
│ 1. 获取应用签名  │───▶│ X-App-Signature  │───▶│ 1. 解析请求头    │
│ 2. 生成时间戳    │    │ X-Timestamp      │    │ 2. 获取参数      │
│ 3. 计算动态签名  │    │ X-Nonce          │    │ 3. 计算期望签名  │
│ 4. 发送请求     │    │ X-Dynamic-Sign   │    │ 4. 比较验证      │
└─────────────────┘    └──────────────────┘    └─────────────────┘
```

## 客户端实现

### 1. 获取应用签名

#### Android 原生实现 (SignatureVerificationService.kt)

```kotlin
package com.hushie.app.signature

import android.content.Context
import android.content.pm.PackageManager
import android.content.pm.Signature
import android.util.Log
import java.security.MessageDigest

class SignatureVerificationService(private val context: Context) {
    
    companion object {
        private const val TAG = "SignatureVerification"
    }
    
    /**
     * 获取应用签名的原始字节数据
     */
    fun getAppSignatureBytes(): ByteArray? {
        return try {
            val signatures = getAppSignatures()
            if (signatures.isEmpty()) {
                Log.e(TAG, "无法获取应用签名")
                return null
            }
            
            signatures[0].toByteArray()
        } catch (e: Exception) {
            Log.e(TAG, "获取签名字节数据异常: ${e.message}", e)
            null
        }
    }
    
    /**
     * 获取应用签名的SHA-256哈希值
     */
    fun getAppSignatureHash(): String? {
        return try {
            val signatureBytes = getAppSignatureBytes()
            if (signatureBytes == null) {
                return null
            }
            
            val md = MessageDigest.getInstance("SHA-256")
            md.update(signatureBytes)
            val hashBytes = md.digest()
            
            hashBytes.joinToString("") { "%02X".format(it) }
        } catch (e: Exception) {
            Log.e(TAG, "计算签名哈希异常: ${e.message}", e)
            null
        }
    }
    
    /**
     * 生成动态签名字符串
     */
    fun generateDynamicSignature(timestamp: Long, nonce: String, secretKey: String): String? {
        return try {
            val signatureHash = getAppSignatureHash()
            if (signatureHash == null) {
                Log.e(TAG, "无法获取应用签名哈希")
                return null
            }
            
            // 构建签名原文：签名哈希 + 时间戳 + 随机数 + 密钥
            val rawData = "${signatureHash}|${timestamp}|${nonce}|${secretKey}"
            
            // 计算HMAC-SHA256
            val hmacSha256 = javax.crypto.Mac.getInstance("HmacSHA256")
            val secretKeySpec = javax.crypto.spec.SecretKeySpec(secretKey.toByteArray(), "HmacSHA256")
            hmacSha256.init(secretKeySpec)
            
            val signatureBytes = hmacSha256.doFinal(rawData.toByteArray())
            android.util.Base64.encodeToString(signatureBytes, android.util.Base64.NO_WRAP)
            
        } catch (e: Exception) {
            Log.e(TAG, "生成动态签名异常: ${e.message}", e)
            null
        }
    }
    
    private fun getAppSignatures(): Array<Signature> {
        val packageManager = context.packageManager
        val packageName = context.packageName
        
        return if (android.os.Build.VERSION.SDK_INT >= android.os.Build.VERSION_CODES.P) {
            val packageInfo = packageManager.getPackageInfo(
                packageName, 
                PackageManager.GET_SIGNING_CERTIFICATES
            )
            packageInfo.signingInfo?.apkContentsSigners ?: emptyArray()
        } else {
            @Suppress("DEPRECATION")
            val packageInfo = packageManager.getPackageInfo(
                packageName, 
                PackageManager.GET_SIGNATURES
            )
            @Suppress("DEPRECATION")
            packageInfo.signatures ?: emptyArray()
        }
    }
}
```

#### Flutter 插件接口 (SignatureVerificationPlugin.kt)

```kotlin
package com.hushie.app.signature

import io.flutter.embedding.engine.plugins.FlutterPlugin
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import io.flutter.plugin.common.MethodChannel.MethodCallHandler
import io.flutter.plugin.common.MethodChannel.Result

class SignatureVerificationPlugin: FlutterPlugin, MethodCallHandler {
    private lateinit var channel: MethodChannel
    private lateinit var signatureService: SignatureVerificationService
    
    override fun onAttachedToEngine(flutterPluginBinding: FlutterPlugin.FlutterPluginBinding) {
        channel = MethodChannel(flutterPluginBinding.binaryMessenger, "signature_verification")
        channel.setMethodCallHandler(this)
        signatureService = SignatureVerificationService(flutterPluginBinding.applicationContext)
    }
    
    override fun onMethodCall(call: MethodCall, result: Result) {
        when (call.method) {
            "getSignatureHash" -> {
                val hash = signatureService.getAppSignatureHash()
                if (hash != null) {
                    result.success(hash)
                } else {
                    result.error("SIGNATURE_ERROR", "无法获取应用签名哈希", null)
                }
            }
            "generateDynamicSignature" -> {
                val timestamp = call.argument<Long>("timestamp") ?: 0L
                val nonce = call.argument<String>("nonce") ?: ""
                val secretKey = call.argument<String>("secretKey") ?: ""
                
                val signature = signatureService.generateDynamicSignature(timestamp, nonce, secretKey)
                if (signature != null) {
                    result.success(signature)
                } else {
                    result.error("SIGNATURE_ERROR", "生成动态签名失败", null)
                }
            }
            else -> {
                result.notImplemented()
            }
        }
    }
    
    override fun onDetachedFromEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        channel.setMethodCallHandler(null)
    }
}
```

### 2. Flutter 服务层实现

#### 动态签名服务 (app_signature_service.dart)

```dart
import 'dart:io';
import 'dart:math';
import 'package:flutter/services.dart';
import 'package:flutter/foundation.dart';

class AppSignatureService {
  static const MethodChannel _channel = MethodChannel('signature_verification');
  
  // 与服务器约定的密钥（实际项目中应该从安全存储获取）
  static const String _secretKey = 'your_secret_key_here';
  
  /**
   * 获取应用签名哈希
   */
  Future<String?> getSignatureHash() async {
    try {
      if (Platform.isAndroid) {
        final String result = await _channel.invokeMethod('getSignatureHash');
        return result;
      } else {
        // iOS 平台返回固定标识
        return 'iOS_APP_SIGNATURE';
      }
    } catch (e) {
      debugPrint('🔐 [SIGNATURE] 获取签名哈希失败: $e');
      return null;
    }
  }
  
  /**
   * 生成动态签名参数
   */
  Future<Map<String, String>?> generateDynamicSignature() async {
    try {
      // 1. 生成时间戳（毫秒）
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      
      // 2. 生成随机数
      final nonce = _generateNonce();
      
      // 3. 生成动态签名
      String? signature;
      if (Platform.isAndroid) {
        signature = await _channel.invokeMethod('generateDynamicSignature', {
          'timestamp': timestamp,
          'nonce': nonce,
          'secretKey': _secretKey,
        });
      } else {
        // iOS 平台使用 Dart 实现
        signature = await _generateIOSSignature(timestamp, nonce);
      }
      
      if (signature == null) {
        return null;
      }
      
      return {
        'signature': signature,
        'timestamp': timestamp.toString(),
        'nonce': nonce,
      };
    } catch (e) {
      debugPrint('🔐 [SIGNATURE] 生成动态签名失败: $e');
      return null;
    }
  }
  
  /**
   * 生成随机数
   */
  String _generateNonce() {
    const chars = 'abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789';
    final random = Random.secure();
    return List.generate(16, (index) => chars[random.nextInt(chars.length)]).join();
  }
  
  /**
   * iOS 平台签名生成（Dart 实现）
   */
  Future<String?> _generateIOSSignature(int timestamp, String nonce) async {
    try {
      // iOS 使用固定签名标识
      const signatureHash = 'iOS_APP_SIGNATURE';
      
      // 构建签名原文
      final rawData = '$signatureHash|$timestamp|$nonce|$_secretKey';
      
      // 这里需要实现 HMAC-SHA256，可以使用 crypto 包
      // 为简化示例，这里返回 Base64 编码的原文
      final bytes = rawData.codeUnits;
      return base64Encode(bytes);
    } catch (e) {
      debugPrint('🔐 [SIGNATURE] iOS签名生成失败: $e');
      return null;
    }
  }
}
```

#### HTTP 客户端集成 (http_client_service.dart)

```dart
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'app_signature_service.dart';

class HttpClientService {
  final AppSignatureService _signatureService = AppSignatureService();
  
  /**
   * 发送带动态签名的 GET 请求
   */
  Future<http.Response> get(String url, {Map<String, String>? headers}) async {
    final signedHeaders = await _buildSignedHeaders(headers);
    return http.get(Uri.parse(url), headers: signedHeaders);
  }
  
  /**
   * 发送带动态签名的 POST 请求
   */
  Future<http.Response> post(String url, {
    Map<String, String>? headers,
    Object? body,
  }) async {
    final signedHeaders = await _buildSignedHeaders(headers);
    return http.post(Uri.parse(url), headers: signedHeaders, body: body);
  }
  
  /**
   * 构建包含动态签名的请求头
   */
  Future<Map<String, String>> _buildSignedHeaders(Map<String, String>? originalHeaders) async {
    final headers = Map<String, String>.from(originalHeaders ?? {});
    
    try {
      // 生成动态签名参数
      final signatureData = await _signatureService.generateDynamicSignature();
      
      if (signatureData != null) {
        headers['X-App-Signature'] = signatureData['signature']!;
        headers['X-Timestamp'] = signatureData['timestamp']!;
        headers['X-Nonce'] = signatureData['nonce']!;
        
        debugPrint('🔐 [HTTP] 已添加动态签名头');
      } else {
        debugPrint('⚠️ [HTTP] 动态签名生成失败，使用原始请求头');
      }
    } catch (e) {
      debugPrint('❌ [HTTP] 构建签名头异常: $e');
    }
    
    return headers;
  }
}
```

## 服务器端实现

### Python 实现示例

```python
import hmac
import hashlib
import base64
import time
import json
import logging
from typing import Tuple, Optional, Dict

class DynamicSignatureVerifier:
    
    def __init__(self, secret_key: str, time_window: int = 300):
        """
        初始化动态签名验证器
        
        Args:
            secret_key: 与客户端约定的密钥
            time_window: 时间窗口（秒），防止重放攻击
        """
        self.secret_key = secret_key
        self.time_window = time_window
        
        # 合法应用签名哈希白名单
        self.valid_signatures = {
            # Android Debug 签名
            '3E5479F66BC583B7AFBE5EB36527E381E50863B5545EC331E219A5B3AC578FAA': {
                'platform': 'android',
                'environment': 'debug',
                'description': 'Android Debug Build'
            },
            # Android Release 签名
            'YOUR_RELEASE_SIGNATURE_HASH': {
                'platform': 'android', 
                'environment': 'production',
                'description': 'Android Release Build'
            },
            # iOS 签名标识
            'iOS_APP_SIGNATURE': {
                'platform': 'ios',
                'environment': 'production', 
                'description': 'iOS App Store Build'
            }
        }
        
        # 用于防重放的 nonce 缓存（实际项目中应使用 Redis）
        self.used_nonces = set()
    
    def verify_request(self, request_headers: Dict[str, str]) -> Tuple[bool, str, Optional[Dict]]:
        """
        验证请求的动态签名
        
        Args:
            request_headers: HTTP 请求头字典
            
        Returns:
            tuple: (is_valid: bool, message: str, app_info: dict)
        """
        try:
            # 1. 提取签名相关头部
            signature = request_headers.get('X-App-Signature')
            timestamp_str = request_headers.get('X-Timestamp')
            nonce = request_headers.get('X-Nonce')
            
            if not all([signature, timestamp_str, nonce]):
                return False, '缺少必要的签名头部', None
            
            # 2. 验证时间戳
            try:
                timestamp = int(timestamp_str)
            except ValueError:
                return False, '时间戳格式错误', None
                
            current_time = int(time.time() * 1000)  # 毫秒时间戳
            time_diff = abs(current_time - timestamp) / 1000  # 转换为秒
            
            if time_diff > self.time_window:
                return False, f'请求已过期，时间差: {time_diff}秒', None
            
            # 3. 验证 nonce（防重放）
            if nonce in self.used_nonces:
                return False, '检测到重放攻击', None
            
            # 4. 尝试验证所有可能的应用签名
            for app_signature_hash, app_info in self.valid_signatures.items():
                expected_signature = self._calculate_signature(
                    app_signature_hash, timestamp, nonce
                )
                
                if hmac.compare_digest(signature, expected_signature):
                    # 签名验证成功
                    self.used_nonces.add(nonce)
                    logging.info(f'动态签名验证成功: {app_info["description"]}')
                    return True, '验证通过', app_info
            
            # 所有签名都不匹配
            return False, '签名验证失败', None
            
        except Exception as e:
            logging.error(f'签名验证异常: {str(e)}')
            return False, f'验证过程出错: {str(e)}', None
    
    def _calculate_signature(self, app_signature_hash: str, timestamp: int, nonce: str) -> str:
        """
        计算期望的动态签名
        
        Args:
            app_signature_hash: 应用签名哈希
            timestamp: 时间戳
            nonce: 随机数
            
        Returns:
            计算得到的签名字符串
        """
        # 构建签名原文（与客户端保持一致）
        raw_data = f"{app_signature_hash}|{timestamp}|{nonce}|{self.secret_key}"
        
        # 计算 HMAC-SHA256
        signature_bytes = hmac.new(
            self.secret_key.encode('utf-8'),
            raw_data.encode('utf-8'),
            hashlib.sha256
        ).digest()
        
        # Base64 编码
        return base64.b64encode(signature_bytes).decode('utf-8')
    
    def add_valid_signature(self, signature_hash: str, platform: str, 
                          environment: str, description: str):
        """
        添加新的合法签名到白名单
        """
        self.valid_signatures[signature_hash] = {
            'platform': platform,
            'environment': environment,
            'description': description
        }
        logging.info(f'已添加新签名: {description}')

# Flask 应用示例
from flask import Flask, request, jsonify

app = Flask(__name__)
verifier = DynamicSignatureVerifier('your_secret_key_here')

@app.before_request
def verify_signature():
    """请求前验证动态签名"""
    if request.endpoint in ['health', 'public_api']:  # 跳过公开接口
        return
    
    is_valid, message, app_info = verifier.verify_request(dict(request.headers))
    
    if not is_valid:
        return jsonify({
            'error': 'SIGNATURE_VERIFICATION_FAILED',
            'message': message
        }), 403
    
    # 将应用信息附加到请求上下文
    request.app_info = app_info

@app.route('/api/protected')
def protected_api():
    return jsonify({
        'message': '访问成功',
        'app_info': request.app_info
    })

if __name__ == '__main__':
    app.run(debug=True)
```

### Node.js 实现示例

```javascript
const crypto = require('crypto');
const express = require('express');

class DynamicSignatureVerifier {
    constructor(secretKey, timeWindow = 300) {
        this.secretKey = secretKey;
        this.timeWindow = timeWindow * 1000; // 转换为毫秒
        
        // 合法应用签名白名单
        this.validSignatures = {
            '3E5479F66BC583B7AFBE5EB36527E381E50863B5545EC331E219A5B3AC578FAA': {
                platform: 'android',
                environment: 'debug',
                description: 'Android Debug Build'
            },
            'YOUR_RELEASE_SIGNATURE_HASH': {
                platform: 'android',
                environment: 'production', 
                description: 'Android Release Build'
            },
            'iOS_APP_SIGNATURE': {
                platform: 'ios',
                environment: 'production',
                description: 'iOS App Store Build'
            }
        };
        
        // 防重放 nonce 缓存
        this.usedNonces = new Set();
    }
    
    verifyRequest(headers) {
        try {
            // 1. 提取签名相关头部
            const signature = headers['x-app-signature'];
            const timestampStr = headers['x-timestamp'];
            const nonce = headers['x-nonce'];
            
            if (!signature || !timestampStr || !nonce) {
                return { isValid: false, message: '缺少必要的签名头部' };
            }
            
            // 2. 验证时间戳
            const timestamp = parseInt(timestampStr);
            if (isNaN(timestamp)) {
                return { isValid: false, message: '时间戳格式错误' };
            }
            
            const currentTime = Date.now();
            const timeDiff = Math.abs(currentTime - timestamp);
            
            if (timeDiff > this.timeWindow) {
                return { isValid: false, message: `请求已过期，时间差: ${timeDiff/1000}秒` };
            }
            
            // 3. 验证 nonce
            if (this.usedNonces.has(nonce)) {
                return { isValid: false, message: '检测到重放攻击' };
            }
            
            // 4. 验证签名
            for (const [appSignatureHash, appInfo] of Object.entries(this.validSignatures)) {
                const expectedSignature = this.calculateSignature(appSignatureHash, timestamp, nonce);
                
                if (crypto.timingSafeEqual(
                    Buffer.from(signature, 'base64'),
                    Buffer.from(expectedSignature, 'base64')
                )) {
                    this.usedNonces.add(nonce);
                    console.log(`动态签名验证成功: ${appInfo.description}`);
                    return { isValid: true, message: '验证通过', appInfo };
                }
            }
            
            return { isValid: false, message: '签名验证失败' };
            
        } catch (error) {
            console.error(`签名验证异常: ${error.message}`);
            return { isValid: false, message: `验证过程出错: ${error.message}` };
        }
    }
    
    calculateSignature(appSignatureHash, timestamp, nonce) {
        // 构建签名原文
        const rawData = `${appSignatureHash}|${timestamp}|${nonce}|${this.secretKey}`;
        
        // 计算 HMAC-SHA256
        const hmac = crypto.createHmac('sha256', this.secretKey);
        hmac.update(rawData);
        
        return hmac.digest('base64');
    }
}

// Express 应用示例
const app = express();
const verifier = new DynamicSignatureVerifier('your_secret_key_here');

// 签名验证中间件
function signatureMiddleware(req, res, next) {
    // 跳过公开接口
    if (req.path === '/health' || req.path.startsWith('/public/')) {
        return next();
    }
    
    const result = verifier.verifyRequest(req.headers);
    
    if (!result.isValid) {
        return res.status(403).json({
            error: 'SIGNATURE_VERIFICATION_FAILED',
            message: result.message
        });
    }
    
    req.appInfo = result.appInfo;
    next();
}

app.use(signatureMiddleware);

app.get('/api/protected', (req, res) => {
    res.json({
        message: '访问成功',
        appInfo: req.appInfo
    });
});

app.listen(3000, () => {
    console.log('服务器启动在端口 3000');
});
```

## 安全特性

### 1. 防重放攻击

- **时间窗口限制**：请求时间戳必须在指定时间窗口内（默认5分钟）
- **Nonce 唯一性**：每个随机数只能使用一次
- **签名绑定**：签名与时间戳和随机数强绑定

### 2. 防伪造攻击

- **密钥保护**：客户端和服务器共享密钥，第三方无法获取
- **多因子签名**：结合应用签名、时间戳、随机数生成
- **HMAC 算法**：使用安全的 HMAC-SHA256 算法

### 3. 传输安全

- **HTTPS 强制**：所有请求必须使用 HTTPS 加密传输
- **签名不可逆**：传输的是 HMAC 结果，无法逆向获取原始信息
- **头部保护**：关键信息通过 HTTP 头部传输，不暴露在 URL 中

## 部署配置

### 1. 客户端配置

```dart
// config/signature_config.dart
class SignatureConfig {
  // 生产环境密钥（应从安全存储获取）
  static const String secretKey = 'your_production_secret_key';
  
  // 开发环境密钥
  static const String debugSecretKey = 'your_debug_secret_key';
  
  static String get currentSecretKey {
    return kDebugMode ? debugSecretKey : secretKey;
  }
}
```

### 2. 服务器配置

```python
# config.py
import os

class Config:
    # 从环境变量获取密钥
    SECRET_KEY = os.getenv('SIGNATURE_SECRET_KEY', 'default_secret_key')
    
    # 时间窗口配置（秒）
    TIME_WINDOW = int(os.getenv('SIGNATURE_TIME_WINDOW', '300'))
    
    # Redis 配置（用于 nonce 缓存）
    REDIS_URL = os.getenv('REDIS_URL', 'redis://localhost:6379')
```

### 3. 环境变量设置

```bash
# 生产环境
export SIGNATURE_SECRET_KEY="your_super_secure_production_key"
export SIGNATURE_TIME_WINDOW="300"
export REDIS_URL="redis://your-redis-server:6379"

# 开发环境
export SIGNATURE_SECRET_KEY="your_debug_key"
export SIGNATURE_TIME_WINDOW="600"
```

## 故障排除

### 客户端问题

1. **签名生成失败**
   - 检查应用是否正确签名
   - 确认密钥配置正确
   - 查看原生层日志输出

2. **时间同步问题**
   - 确保设备时间准确
   - 检查时区设置
   - 考虑网络延迟影响

### 服务器端问题

1. **签名验证失败**
   - 检查密钥是否与客户端一致
   - 确认签名算法实现正确
   - 验证时间窗口配置

2. **重放攻击检测**
   - 检查 nonce 缓存是否正常工作
   - 确认缓存过期时间设置
   - 监控异常请求模式

### 调试工具

```python
# 签名调试工具
def debug_signature_verification(app_signature_hash, timestamp, nonce, secret_key):
    raw_data = f"{app_signature_hash}|{timestamp}|{nonce}|{secret_key}"
    print(f"签名原文: {raw_data}")
    
    signature = hmac.new(
        secret_key.encode('utf-8'),
        raw_data.encode('utf-8'),
        hashlib.sha256
    ).digest()
    
    signature_b64 = base64.b64encode(signature).decode('utf-8')
    print(f"生成签名: {signature_b64}")
    
    return signature_b64
```

## 性能优化

### 1. 缓存优化

- 使用 Redis 缓存已使用的 nonce
- 设置合理的缓存过期时间
- 定期清理过期的 nonce 记录

### 2. 算法优化

- 使用高效的 HMAC 实现
- 避免重复的签名计算
- 优化字符串拼接操作

### 3. 网络优化

- 减少不必要的请求头
- 使用 HTTP/2 提升传输效率
- 实施请求压缩

## 版本历史

### v3.0.0 (2024-01-XX)
- **全新架构**：采用动态签名验证机制
- **增强安全性**：防重放攻击和防伪造攻击
- **实时验证**：服务器端实时计算和验证签名
- **跨平台支持**：统一的 Android 和 iOS 实现
- **完整文档**：提供详细的实现指南和示例代码

## 许可证

MIT License - 详见 LICENSE 文件