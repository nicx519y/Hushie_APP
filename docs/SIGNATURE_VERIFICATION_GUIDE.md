# 动态签名与服务端校验指南

本文档介绍客户端请求签名的生成原理、相关请求头语义，以及服务端的标准校验流程与参考实现。适用于 Hushie App 的所有后端接口安全校验。

## 目标与收益
- 防重放：时间戳 + 随机数（nonce）限制请求有效期与唯一性。
- 防篡改：任何关键数据被修改都会导致 HMAC 校验失败。
- 来源识别：通过应用签名哈希白名单识别合法构建（Debug/Release 等）。

## 相关请求头
- `X-Dynamic-Signature`：动态签名（HMAC-SHA256 结果经 Base64）。
- `X-App-Signature-Hash`：应用签名证书的 SHA-256 哈希。
- `X-Timestamp`：毫秒时间戳（客户端生成）。
- `X-Nonce`：16 位字母数字随机串（客户端生成）。
- `X-App-Integrity`：应用完整性信息（可选，JSON，用于风控参考）。
- 备用签名：`X-Signature`（HMAC-SHA256 十六进制），`X-Signature-Type=fallback`（标记使用备用方案）。

> 说明：代码中统一使用大写 Header 名；若网关层大小写归一，请按不区分大小写处理。

## 客户端生成原理

### 动态签名（X-Dynamic-Signature）
- 原文构造：`<signatureHash>|<timestamp>|<nonce>|<secretKey>`
  - `signatureHash`：应用签名证书 SHA-256 哈希（Android 通过原生获取）。
  - `timestamp`：当前毫秒时间戳。
  - `nonce`：16 位随机串，防重放。
  - `secretKey`：客户端与服务端约定的密钥（服务器持有同一密钥）。
- 算法：`HMAC-SHA256(rawData, secretKey)`，再 `Base64` 编码作为 `X-Dynamic-Signature`。
- 伴随头：必须携带 `X-App-Signature-Hash`, `X-Timestamp`, `X-Nonce`；若有完整性信息则加 `X-App-Integrity`。
- 缓存与并发：客户端对动态签名做 5 分钟缓存，并在并发场景下串行生成以避免重复计算与竞态。
- 实现位置：
  - Dart：`lib/services/http_client_service.dart`（构建头、缓存并发控制）。
  - Dart：`lib/services/app_signature_service.dart`（通过 MethodChannel 调用原生）。
  - Android 原生：`android/app/src/main/kotlin/.../SignatureVerificationService.kt`（生成动态签名与获取证书哈希）。

### 备用签名（X-Signature）
在动态签名不可用时（如原生通道异常），客户端回退到“请求级签名”。

- 原文组成（按行拼接）：
  1. HTTP 方法（大写）
  2. 请求路径 `path`（不含域名；是否包含 query 取决于双方约定，建议统一）
  3. 时间戳（毫秒）
  4. 随机数（nonce）
  5. 请求体哈希（无请求体则空串），算法：`SHA-256(JSON或原始字符串)`
  6. 关键头（按字母序）：`X-Device-ID`, `X-App-ID`, `X-API-Version`，格式：`HeaderName:HeaderValue`
- 签名算法：`HMAC-SHA256(signature_string, app_secret)`，结果以十六进制字符串作为 `X-Signature`。
- 标记：`X-Signature-Type=fallback` 用于服务端识别该路径使用备用签名。
- 实现位置：`lib/services/http_client_service.dart` 的 `_generateSignature(...)`。

## 服务端校验流程

### 1. 提取并校验基础字段
- 校验存在性：`X-App-Signature-Hash`, `X-Timestamp`, `X-Nonce`，以及 `X-Dynamic-Signature` 或 `X-Signature` 至少一种。
- 校验时间窗：`X-Timestamp` 与当前时间（毫秒）差值不超过窗口（建议 300 秒）。允许少量时钟偏差。
- 校验随机数：`X-Nonce` 需未使用（建议 Redis 记录，TTL 与时间窗一致）。

### 2. 校验来源（白名单）
- `X-App-Signature-Hash` 必须在白名单中（区分 Android Debug/Release 与 iOS 构建）。
  - 示例：`3E5479F66B...FAA`（Android Debug）、`YOUR_RELEASE_SIGNATURE_HASH`（生产）。

### 3. 计算并比较签名
- 动态签名：
  - 重构原文：`signatureHash|timestamp|nonce|secretKey`
  - 使用服务器持有的 `secretKey` 做 `HMAC-SHA256`，对比 `X-Dynamic-Signature`（Base64）。
  - 使用恒时比较（`hmac.compare_digest`）避免时序攻击。
- 备用签名：
  - 按客户端规则重建 `signature_string`（确保方法、路径、时间戳、nonce、请求体哈希、关键头完全一致）。
  - 使用 `app_secret` 做 `HMAC-SHA256` 十六进制输出，对比 `X-Signature`。
  - 注意 JSON 序列化一致性与编码（建议签名基于“原始请求体字节”的哈希）。

### 4. 完整性与风控（可选）
- 若存在 `X-App-Integrity`，可解析：`signature_valid`, `trusted_source`, `debug_build` 等字段，作为风控维度，不直接参与签名计算，但可用于拒绝非可信来源请求。

## 参考实现（Python 伪代码）

### 动态签名验证
```python
def verify_dynamic_signature(headers, secret_key, time_window=300):
    # 1. 读取头部
    dyn_sig = headers.get('X-Dynamic-Signature')
    sig_hash = headers.get('X-App-Signature-Hash')
    ts_str = headers.get('X-Timestamp')
    nonce = headers.get('X-Nonce')

    # 2. 基本校验
    if not all([dyn_sig, sig_hash, ts_str, nonce]):
        return False, 'missing_headers'

    # 3. 时间窗与重放
    ts = int(ts_str)
    now_ms = int(time.time() * 1000)
    if abs(now_ms - ts) / 1000 > time_window:
        return False, 'expired'
    if nonce_used(nonce):
        return False, 'replay_detected'

    # 4. 来源白名单
    if sig_hash not in VALID_SIGNATURE_HASHES:
        return False, 'unknown_signature_hash'

    # 5. 重算签名并比较
    raw = f"{sig_hash}|{ts}|{nonce}|{secret_key}"
    expected = hmac.new(secret_key.encode(), raw.encode(), hashlib.sha256).digest()
    expected_b64 = base64.b64encode(expected).decode()
    if not hmac.compare_digest(dyn_sig, expected_b64):
        return False, 'signature_mismatch'

    mark_nonce_used(nonce)
    return True, 'ok'
```

### 备用签名验证
```python
def verify_fallback_signature(headers, body_bytes, method, path, app_secret, time_window=300):
    # 1. 读取头部
    sig_hex = headers.get('X-Signature')
    ts_str = headers.get('X-Timestamp')
    nonce = headers.get('X-Nonce')
    device_id = headers.get('X-Device-ID', '')
    app_id = headers.get('X-App-ID', '')
    api_version = headers.get('X-API-Version', '')

    # 2. 基本校验
    if not all([sig_hex, ts_str, nonce]):
        return False, 'missing_headers'

    # 3. 时间窗与重放
    ts = int(ts_str)
    now_ms = int(time.time() * 1000)
    if abs(now_ms - ts) / 1000 > time_window:
        return False, 'expired'
    if nonce_used(nonce):
        return False, 'replay_detected'

    # 4. 构造签名字符串
    body_hash = hashlib.sha256(body_bytes or b'').hexdigest()
    parts = [
        method.upper(),
        path,
        ts_str,
        nonce,
        body_hash,
        f'X-Device-ID:{device_id}',
        f'X-App-ID:{app_id}',
        f'X-API-Version:{api_version}',
    ]
    signature_string = '\n'.join(parts)

    # 5. 重算并比较
    expected_hex = hmac.new(app_secret.encode(), signature_string.encode(), hashlib.sha256).hexdigest()
    if not hmac.compare_digest(sig_hex, expected_hex):
        return False, 'signature_mismatch'

    mark_nonce_used(nonce)
    return True, 'ok'
```

## 注意事项与最佳实践
- 路径一致性：客户端与服务端对 `path` 的定义需一致（是否包含查询参数）。
- 请求体哈希：建议基于“原始字节”计算哈希，避免 JSON 序列化差异带来的不一致。
- Header 规范：关键头名与大小写需统一；若网关改写头名，请先做映射归一。
- 时间戳单位：毫秒；允许少量偏差（NTP/手机时间误差）。
- nonce 存储：使用带 TTL 的缓存系统（如 Redis），TTL 建议与时间窗一致。
- 密钥管理：`secretKey/app_secret` 不应硬编码在服务器配置文件中，应使用安全管理（KMS/环境变量）。
- 比较方式：使用恒时比较（如 `hmac.compare_digest`）避免时序攻击。

## 代码索引
- 动态签名生成与缓存：`lib/services/http_client_service.dart`（构建请求头、缓存与并发保护）。
- 原生签名生成与证书哈希：`android/app/src/main/kotlin/.../SignatureVerificationService.kt`。
- 应用签名服务与完整性信息：`lib/services/app_signature_service.dart`。
- 备用签名算法：`lib/services/http_client_service.dart::_generateSignature(...)`。

## 示例请求头（动态签名）
```
X-Dynamic-Signature: QWxhZGRpbjpPcGVuU2VzYW1l...
X-App-Signature-Hash: 3E5479F66BC583B7AFBE5EB36527E381E50863B5545EC331E219A5B3AC578FAA
X-Timestamp: 1703123456789
X-Nonce: Ab3X9kP2mN8QwErT
X-App-Integrity: {"signature_valid":true,"trusted_source":true,"debug_build":false}
```

## 示例请求头（备用签名）
```
X-Signature: a1b2c3d4e5f6...
X-Signature-Type: fallback
X-Timestamp: 1703123456789
X-Nonce: Ab3X9kP2mN8QwErT
X-Device-ID: device_123abc456def
X-App-ID: hushie_app_v1
X-API-Version: v1
```