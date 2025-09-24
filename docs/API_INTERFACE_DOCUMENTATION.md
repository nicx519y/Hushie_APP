

# Hushie.AI API 接口文档

## 概述

本文档描述了 Hushie.AI 应用中已实现的所有网络请求接口。所有接口都遵循统一的响应格式，并自动包含完整的安全验签和认证信息。

## 基础信息

- Base URL: 通过 `ApiConfig.baseUrl` 配置
- 响应格式: 统一使用 `{ errNo: 0, data: { ... } }` 格式
- 认证方式: Bearer Token (自动添加)
- 签名算法: HMAC-SHA256 (自动生成)
- 安全防护: 防重放攻击、防篡改、身份验证

### 通用响应格式

```json
{
  "errNo": 0,
  "data": {
    // 具体数据内容
  }
}
```

### 错误响应格式

```json
{
  "errNo": -1,
  "data": null
}
```

### 字段说明

- **errNo**: 错误码，0表示成功，非0表示失败
- **data**: 响应数据，失败时为null

---

## 🔐 API安全验签机制

### 签名验证流程

所有API请求都会自动进行签名验证，确保请求的安全性和完整性：

1. 收集签名参数: HTTP方法、请求路径、时间戳、随机数、请求体哈希、关键请求头
2. 构建签名字符串: 按照固定格式组合所有参数
3. 生成签名: 使用HMAC-SHA256算法和应用密钥生成签名
4. 验证签名: 服务器验证签名的有效性和时间戳

### 签名算法详解

#### 签名字符串格式

```
HTTP_METHOD
REQUEST_PATH
TIMESTAMP
NONCE
BODY_HASH(SHA256)
X-Device-ID:device_value
X-App-ID:app_value
X-API-Version:version_value
```

#### 签名生成

```
HMAC-SHA256(signature_string, app_secret)
```

### 安全特性

- ✅ 防重放攻击: 时间戳验证（5分钟有效期）+ 随机数
- ✅ 防篡改: 请求体哈希验证 + 关键请求头签名
- ✅ 身份验证: 三层身份识别（应用、设备、用户）
- ✅ 可追踪性: 请求ID支持全链路追踪


---

## 📋 标准请求头

### 自动添加的安全请求头

所有API请求都会自动添加以下请求头：

| 请求头 | 类型 | 说明 | 示例值 |
|--------|------|------|--------|
| Content-Type | 基础 | 内容类型 | `application/json` |
| Accept | 基础 | 接受类型 | `application/json` |
| App-Version | 基础 | 应用版本 | `HushieApp/1.0.0` |
| X-API-Version | 身份 | API版本标识 | `v1` |
| X-App-ID | 身份 | 应用标识 | `hushie_app_v1` |
| X-Client-Platform | 身份 | 客户端平台 | `flutter` |
| X-Device-ID | 身份 | 设备唯一标识 | `device_123abc456def` |
| X-App-Signature | 安全 | 应用签名哈希 | `SHA256:a1b2c3d4e5f6...` |
| X-App-Integrity | 安全 | 应用完整性信息 | `{"signature_valid":true,"trusted_source":true,"debug_build":false}` |
| X-Timestamp | 安全 | Unix时间戳（毫秒） | `1703123456789` |
| X-Nonce | 安全 | 16位随机字符串 | `Ab3X9kP2mN8QwErT` |
| X-Request-ID | 追踪 | 请求唯一标识 | `req_1703123456_123456` |
| X-Signature | 安全 | HMAC-SHA256签名 | `a1b2c3d4e5f6...` |
| Authorization | 认证 | Bearer Token | `Bearer eyJhbGc...` |

### 请求示例

```http
GET /audio/list?tag=rock&count=20 HTTP/1.1
Host: api.example.com
Content-Type: application/json
Accept: application/json
App-Version: HushieApp/1.0.0
X-API-Version: v1
X-App-ID: hushie_app_v1
X-Client-Platform: flutter
X-Device-ID: device_123abc456def
X-Timestamp: 1703123456789
X-Nonce: Ab3X9kP2mN8QwErT
X-Request-ID: req_1703123456_123456
X-Signature: a1b2c3d4e5f6789...
Authorization: Bearer eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9...
```


---

## 🖥️ 服务器端实现指南

### 请求头字段处理详解

以下详细说明服务器端应该如何处理和验证每个请求头字段：

#### 1. 基础请求头

| 请求头 | 服务器使用方式 | 验证逻辑 | 示例代码 |
|--------|----------------|----------|----------|
| Content-Type | 解析请求体格式 | 验证是否为 `application/json` | `if (contentType !== 'application/json') return 400` |
| Accept | 确定响应格式 | 验证客户端接受的格式 | `if (!accept.includes('application/json')) return 406` |
| App-Version | 日志记录、统计分析 | 检查是否为合法客户端 | `if (!appVersion.startsWith('HushieApp/')) log('unknown_client')` |

#### 2. 身份识别请求头

| 请求头 | 服务器使用方式 | 验证逻辑 | 安全考虑 |
|--------|----------------|----------|----------|
| X-API-Version | API版本路由 | 检查版本兼容性 | 拒绝不支持的版本 |
| X-App-ID | 应用身份验证 | 验证应用合法性 | 检查应用是否被禁用 |
| X-Client-Platform | 平台特定逻辑 | 验证平台标识 | 统计平台使用情况 |
| X-Device-ID | 设备追踪、风控 | 设备唯一性验证 | 检测异常设备行为 |

#### 3. 安全验证请求头

| 请求头 | 服务器使用方式 | 验证逻辑 | 安全级别 |
|--------|----------------|----------|----------|
| X-Timestamp | 防重放攻击 | 检查时间戳有效性 | ⭐⭐⭐⭐⭐ 关键 |
| X-Nonce | 防重放攻击 | 验证随机数唯一性 | ⭐⭐⭐⭐⭐ 关键 |
| X-Signature | 请求完整性验证 | HMAC-SHA256签名验证 | ⭐⭐⭐⭐⭐ 关键 |

#### 4. 认证和追踪请求头

| 请求头 | 服务器使用方式 | 验证逻辑 | 业务价值 |
|--------|----------------|----------|----------|
| Authorization | 用户身份验证 | JWT Token解析验证 | 用户权限控制 |
| X-Request-ID | 链路追踪 | 日志关联分析 | 问题排查、性能监控 |


---

## 🔐 服务器端签名验证实现

### 核心验证流程

```python
def validate_request_signature(request):
    """
    服务器端签名验证核心函数
    """
    # 1. 提取请求头
    headers = request.headers
    method = request.method
    path = request.path
    body = request.body
    
    # 2. 获取签名相关字段
    timestamp = headers.get('X-Timestamp')
    nonce = headers.get('X-Nonce')
    client_signature = headers.get('X-Signature')
    app_id = headers.get('X-App-ID')
    
    # 3. 基础验证
    if not all([timestamp, nonce, client_signature, app_id]):
        return False, "Missing required signature headers"
    
    # 4. 时间戳验证（防重放攻击）
    if not validate_timestamp(timestamp):
        return False, "Invalid or expired timestamp"
    
    # 5. 随机数验证（防重放攻击）
    if not validate_nonce(nonce, timestamp):
        return False, "Invalid or duplicate nonce"
    
    # 6. 生成服务器端签名
    server_signature = generate_signature(
        method, path, timestamp, nonce, body, headers
    )
    
    # 7. 签名比较
    if not secure_compare(client_signature, server_signature):
        return False, "Signature verification failed"
    
    return True, "Signature verified successfully"

def validate_timestamp(timestamp_str):
    """
    时间戳验证：检查是否在5分钟有效期内
    """
    try:
        timestamp = int(timestamp_str)
        current_time = int(time.time() * 1000)  # 毫秒
        time_diff = abs(current_time - timestamp)
        
        # 5分钟 = 300秒 = 300000毫秒
        max_drift = 300000
        
        return time_diff <= max_drift
    except (ValueError, TypeError):
        return False

def validate_nonce(nonce, timestamp):
    """
    随机数验证：检查唯一性（使用Redis缓存）
    """
    # 生成唯一键
    nonce_key = f"nonce:{nonce}:{timestamp}"
    
    # 检查是否已存在
    if redis_client.exists(nonce_key):
        return False
    
    # 存储nonce，设置10分钟过期
    redis_client.setex(nonce_key, 600, "used")
    return True

def generate_signature(method, path, timestamp, nonce, body, headers):
    """
    服务器端签名生成（与客户端算法完全一致）
    """
    signature_parts = []
    
    # HTTP方法
    signature_parts.append(method.upper())
    
    # 请求路径
    signature_parts.append(path)
    
    # 时间戳
    signature_parts.append(timestamp)
    
    # 随机数
    signature_parts.append(nonce)
    
    # 请求体哈希
    if body:
        body_hash = hashlib.sha256(body.encode()).hexdigest()
        signature_parts.append(body_hash)
    else:
        signature_parts.append('')
    
    # 关键请求头（按字母顺序）
    key_headers = ['X-Device-ID', 'X-App-ID', 'X-API-Version']
    for header_name in key_headers:
        header_value = headers.get(header_name, '')
        signature_parts.append(f"{header_name}:{header_value}")
    
    # 构建签名字符串
    signature_string = '\n'.join(signature_parts)
    
    # 生成HMAC-SHA256签名
    app_secret = get_app_secret(headers.get('X-App-ID'))
    signature = hmac.new(
        app_secret.encode(),
        signature_string.encode(),
        hashlib.sha256
    ).hexdigest()
    
    return signature

def secure_compare(a, b):
    """
    安全的字符串比较，防止时序攻击
    """
    return hmac.compare_digest(a, b)
```


---

## 🛡️ 分层安全验证策略

### 第一层：基础格式验证

```python
def validate_basic_headers(request):
    """
    基础请求头格式验证
    """
    required_headers = [
        'Content-Type',
        'X-API-Version', 
        'X-App-ID',
        'X-Device-ID',
        'X-Timestamp',
        'X-Nonce',
        'X-Signature'
    ]
    
    missing_headers = []
    for header in required_headers:
        if header not in request.headers:
            missing_headers.append(header)
    
    if missing_headers:
        return False, f"Missing headers: {missing_headers}"
    
    # 格式验证
    if not validate_header_formats(request.headers):
        return False, "Invalid header format"
    
    return True, "Basic validation passed"

def validate_header_formats(headers):
    """
    请求头格式验证
    """
    # API版本格式检查
    if not re.match(r'^v\d+$', headers.get('X-API-Version', '')):
        return False
    
    # 应用ID格式检查
    if not re.match(r'^[a-z_]+_v\d+$', headers.get('X-App-ID', '')):
        return False
    
    # 设备ID格式检查（至少16位字符）
    if len(headers.get('X-Device-ID', '')) < 16:
        return False
    
    # 时间戳格式检查（13位数字）
    if not re.match(r'^\d{13}$', headers.get('X-Timestamp', '')):
        return False
    
    # 随机数格式检查（16位字母数字）
    if not re.match(r'^[a-zA-Z0-9]{16}$', headers.get('X-Nonce', '')):
        return False
    
    return True
```

### 第二层：应用身份验证

```python
def validate_app_identity(headers):
    """
    应用身份验证
    """
    app_id = headers.get('X-App-ID')
    api_version = headers.get('X-API-Version')
    client_platform = headers.get('X-Client-Platform')
    
    # 检查应用是否注册
    app_config = get_app_config(app_id)
    if not app_config:
        return False, "Unknown application"
    
    # 检查应用状态
    if app_config.status != 'active':
        return False, "Application disabled"
    
    # 检查API版本兼容性
    if api_version not in app_config.supported_versions:
        return False, "API version not supported"
    
    # 检查平台支持
    if client_platform not in app_config.supported_platforms:
        return False, "Platform not supported"
    
    return True, "App identity verified"

def get_app_config(app_id):
    """
    获取应用配置（示例）
    """
    app_configs = {
        'hushie_app_v1': {
            'status': 'active',
            'supported_versions': ['v1'],
            'supported_platforms': ['flutter', 'ios', 'android'],
            'secret_key': 'your_app_secret_key_here',
            'rate_limit': 1000,  # 每分钟请求限制
            'features': ['audio_streaming', 'user_auth']
        }
    }
    return app_configs.get(app_id)
```

### 第三层：设备风控

```python
def validate_device_behavior(headers, user_context):
    """
    设备行为风控验证
    """
    device_id = headers.get('X-Device-ID')
    app_version = headers.get('App-Version')
    
    # 设备风险评估
    risk_score = calculate_device_risk(device_id, user_context)
    
    if risk_score > 80:  # 高风险
        return False, "Device blocked due to suspicious activity"
    elif risk_score > 60:  # 中风险
        # 要求额外验证
        return True, "Additional verification required"
    
    return True, "Device validation passed"

def calculate_device_risk(device_id, user_context):
    """
    设备风险评分计算
    """
    risk_score = 0
    
    # 检查设备请求频率
    request_count = get_device_request_count(device_id, minutes=60)
    if request_count > 1000:
        risk_score += 30
    
    # 检查地理位置异常
    if is_geo_location_anomaly(device_id, user_context.ip):
        risk_score += 25
    
    # 检查设备指纹变化
    if is_device_fingerprint_changed(device_id, user_context):
        risk_score += 20
    
    # 检查异常登录模式
    if is_abnormal_login_pattern(device_id):
        risk_score += 25
    
    return min(risk_score, 100)
```

### 第四层：用户认证

```python
def validate_user_authentication(headers):
    """
    用户身份认证验证
    """
    auth_header = headers.get('Authorization')
    
    if not auth_header:
        return False, "Missing authorization header"
    
    if not auth_header.startswith('Bearer '):
        return False, "Invalid authorization format"
    
    token = auth_header[7:]  # 移除 "Bearer " 前缀
    
    # JWT Token验证
    try:
        payload = verify_jwt_token(token)
        
        # 检查Token过期
        if payload['exp'] < time.time():
            return False, "Token expired"
        
        # 检查Token权限
        if not validate_token_permissions(payload, headers):
            return False, "Insufficient permissions"
        
        return True, payload
        
    except Exception as e:
        return False, f"Token verification failed: {str(e)}"

def verify_jwt_token(token):
    """
    JWT Token验证
    """
    try:
        # 使用应用密钥验证Token
        payload = jwt.decode(
            token,
            get_jwt_secret(),
            algorithms=['HS256']
        )
        return payload
    except jwt.ExpiredSignatureError:
        raise Exception("Token has expired")
    except jwt.InvalidTokenError:
        raise Exception("Invalid token")
```


---

## 📊 请求处理中间件示例

```python
class SecurityMiddleware:
    """
    安全验证中间件
    """
    
    def __init__(self):
        self.validation_layers = [
            self.validate_basic_headers,
            self.validate_signature,
            self.validate_app_identity,
            self.validate_device_behavior,
            self.validate_user_authentication
        ]
    
    def process_request(self, request):
        """
        请求安全验证主流程
        """
        # 记录请求开始
        request_id = request.headers.get('X-Request-ID')
        self.log_request_start(request_id, request)
        
        try:
            # 逐层安全验证
            for layer in self.validation_layers:
                success, message = layer(request)
                if not success:
                    self.log_security_violation(request_id, layer.__name__, message)
                    return self.create_error_response(403, message)
            
            # 所有验证通过
            self.log_request_success(request_id)
            return None  # 继续处理请求
            
        except Exception as e:
            self.log_security_error(request_id, str(e))
            return self.create_error_response(500, "Security validation error")
    
    def log_request_start(self, request_id, request):
        """
        记录请求开始日志
        """
        logger.info({
            'event': 'request_start',
            'request_id': request_id,
            'method': request.method,
            'path': request.path,
            'device_id': request.headers.get('X-Device-ID'),
            'app_id': request.headers.get('X-App-ID'),
            'timestamp': time.time()
        })
    
    def log_security_violation(self, request_id, layer, message):
        """
        记录安全违规日志
        """
        logger.warning({
            'event': 'security_violation',
            'request_id': request_id,
            'validation_layer': layer,
            'violation_reason': message,
            'timestamp': time.time()
        })
    
    def create_error_response(self, status_code, message):
        """
        创建错误响应
        """
        return {
            'status_code': status_code,
            'body': json.dumps({
                'errNo': status_code,
                'data': None,
                'message': message
            }),
            'headers': {
                'Content-Type': 'application/json'
            }
        }
```


---

## 🔧 配置管理

```python
class SecurityConfig:
    """
    安全配置管理
    """
    
    # 时间戳容忍度（毫秒）
    TIMESTAMP_TOLERANCE = 300000  # 5分钟
    
    # 随机数缓存时间（秒）
    NONCE_CACHE_TTL = 600  # 10分钟
    
    # 签名算法
    SIGNATURE_ALGORITHM = 'HMAC-SHA256'
    
    # 应用密钥配置
    APP_SECRETS = {
        'hushie_app_v1': 'your_app_secret_key_here'
    }
    
    # 速率限制配置
    RATE_LIMITS = {
        'default': 100,     # 每分钟100次
        'premium': 1000,    # 高级用户每分钟1000次
    }
    
    # 设备风控阈值
    DEVICE_RISK_THRESHOLDS = {
        'low': 30,
        'medium': 60,
        'high': 80
    }
    
    @staticmethod
    def get_app_secret(app_id):
        """获取应用密钥"""
        return SecurityConfig.APP_SECRETS.get(app_id)
    
    @staticmethod
    def get_rate_limit(user_tier):
        """获取速率限制"""
        return SecurityConfig.RATE_LIMITS.get(user_tier, SecurityConfig.RATE_LIMITS['default'])
```


---

## 📈 监控和告警

```python
class SecurityMonitor:
    """
    安全监控系统
    """
    
    def __init__(self):
        self.metrics = SecurityMetrics()
        self.alerter = SecurityAlerter()
    
    def track_security_event(self, event_type, details):
        """
        追踪安全事件
        """
        # 更新指标
        self.metrics.increment(f"security.{event_type}")
        
        # 检查是否需要告警
        if self.should_alert(event_type, details):
            self.alerter.send_alert(event_type, details)
    
    def should_alert(self, event_type, details):
        """
        判断是否需要发送告警
        """
        # 签名验证失败率过高
        if event_type == 'signature_failure':
            failure_rate = self.metrics.get_rate('security.signature_failure', minutes=5)
            if failure_rate > 10:  # 5分钟内超过10次失败
                return True
        
        # 同一设备短时间内多次违规
        elif event_type == 'device_violation':
            device_id = details.get('device_id')
            violation_count = self.metrics.get_device_violations(device_id, minutes=10)
            if violation_count > 5:
                return True
        
        return False
```

这个服务器端实现指南为开发者提供了完整的安全验证框架，确保API的安全性和可靠性！


---

## 1. 音频相关接口

### 1.1 获取音频列表

接口描述: 获取音频列表，支持按标签筛选和从指定ID开始获取

请求信息:
- URL: `GET /audio/list`
- 方法: GET

#### 上行参数

| 参数名 | 类型 | 必填 | 默认值 | 说明 |
|--------|------|------|--------|------|
| tag | String | 否 | - | 音频标签，用于筛选 |
| cid | String | 否 | - | 从此ID开始往下获取 |
| count | int | 否 | 10 | 返回的音频数量 |

#### 请求示例

```http
GET /audio/list?tag=rock&count=20 HTTP/1.1
Host: api.example.com
X-API-Version: v1
X-App-ID: hushie_app_v1
X-Device-ID: device_123abc456def
X-Timestamp: 1703123456789
X-Nonce: Ab3X9kP2mN8QwErT
X-Signature: a1b2c3d4e5f6789...
Authorization: Bearer eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9...
```

#### 响应格式

```json
{
  "errNo": 0,
  "data": {
    "items": [
      {
        "id": "audio_001",
        "cover": {
          "urls": {
            "x1": {
              "url": "https://example.com/cover1_400x600.jpg",
              "width": 400,
              "height": 600
            },
            "x2": {
              "url": "https://example.com/cover1_800x1200.jpg",
              "width": 800,
              "height": 1200
            },
            "x3": {
              "url": "https://example.com/cover1_1200x1800.jpg",
              "width": 1200,
              "height": 1800
            }
          }
        },
        "bg_image": {
          "urls": {
            "x1": {
              "url": "https://example.com/bg1_800x600.jpg",
              "width": 800,
              "height": 600
            },
            "x2": {
              "url": "https://example.com/bg1_1600x1200.jpg",
              "width": 1600,
              "height": 1200
            }
          }
        },
        "title": "Music in the Wires",
        "desc": "The dark pop-rock track opens extended +22",
        "author": "Buddha",
        "avatar": "https://example.com/avatar1.jpg",
        "play_times": 1300123,
        "likes_count": 22933,
        "audio_url": "https://example.com/audio1.mp3",
        "duration": "180000",
        "preview_start_ms": 30000,
        "preview_duration_ms": 15000,
        "is_liked": true,
      }
    ]
  }
}
```

---

### 1.2 搜索音频

接口描述: 根据搜索关键词搜索音频

请求信息:
- URL: `GET /audio/search`
- 方法: GET

#### 上行参数

| 参数名 | 类型 | 必填 | 默认值 | 说明 |
|--------|------|------|--------|------|
| q | String | 是 | - | 搜索关键词 |
| cid | String | 否 | - | 从此ID开始往下获取 |
| count | int | 否 | 10 | 返回的音频数量 |

#### 请求示例

```http
GET /audio/search?q=rock&count=15 HTTP/1.1
Host: api.example.com
X-API-Version: v1
X-App-ID: hushie_app_v1
X-Device-ID: device_123abc456def
X-Timestamp: 1703123456789
X-Nonce: Ab3X9kP2mN8QwErT
X-Signature: a1b2c3d4e5f6789...
Authorization: Bearer eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9...
```

#### 响应格式

```json
{
  "errNo": 0,
  "data": {
    "items": [
      {
        "id": "audio_002",
        "cover": {
          "urls": {
            "x1": {
              "url": "https://example.com/cover2_400x500.jpg",
              "width": 400,
              "height": 500
            },
            "x2": {
              "url": "https://example.com/cover2_800x1000.jpg",
              "width": 800,
              "height": 1000
            },
            "x3": {
              "url": "https://example.com/bg2_1600x1200.jpg",
              "width": 1600,
              "height": 1200
            }
          }
        },
        "bg_image": {
          "urls": {
            "x1": {
              "url": "https://example.com/bg2_800x600.jpg",
              "width": 800,
              "height": 600
            },
            "x2": {
              "url": "https://example.com/bg2_1600x1200.jpg",
              "width": 1600,
              "height": 1200
            }
          }
        },
        "title": "Rock Anthem",
        "desc": "High energy rock music",
        "author": "Rock Band",
        "avatar": "https://example.com/avatar2.jpg",
        "play_times": 850000,
        "likes_count": 15678,
        "audio_url": "https://example.com/audio2.mp3",
        "duration": "180000",
        "preview_start_ms": 30000,
        "preview_duration_ms": 15000,
        "is_liked": false,
      }
    ]
  }
}
```

---

### 1.3 获取用户喜欢的音频

接口描述: 获取当前登录用户喜欢的音频列表

请求信息:
- URL: `GET /user/likes`
- 方法: GET

#### 上行参数

| 参数名 | 类型 | 必填 | 默认值 | 说明 |
|--------|------|------|--------|------|
| cid | String | 否 | - | 从此ID开始往下获取 |
| count | int | 否 | 20 | 返回的音频数量 |

#### 请求示例

```http
GET /user/likes?count=25 HTTP/1.1
Host: api.example.com
X-API-Version: v1
X-App-ID: hushie_app_v1
X-Device-ID: device_123abc456def
X-Timestamp: 1703123456789
X-Nonce: Ab3X9kP2mN8QwErT
X-Signature: a1b2c3d4e5f6789...
Authorization: Bearer eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9...
```

#### 响应格式

```json
{
  "errNo": 0,
  "data": {
    "items": [
      {
        "id": "audio_003",
        "cover": {
          "urls": {
            "x1": {
              "url": "https://example.com/cover3_400x600.jpg",
              "width": 400,
              "height": 600
            },
            "x2": {
              "url": "https://example.com/cover3_800x1200.jpg",
              "width": 800,
              "height": 1200
            },
            "x3": {
              "url": "https://example.com/cover3_1200x1800.jpg",
              "width": 1200,
              "height": 1800
            }
          }
        },
        "bgImage": {
          "urls": {
            "x1": {
                "url": "https://example.com/cover3_400x600.jpg",
                "width": 400,
                "height": 600
              },
              "x2": {
                "url": "https://example.com/cover3_800x1200.jpg",
                "width": 800,
                "height": 1200
            }
          },
        },
        "title": "Favorite Song",
        "desc": "User's favorite audio track",
        "author": "Favorite Artist",
        "avatar": "https://example.com/avatar3.jpg",
        "play_times": 1200000,
        "likes_count": 45000,
        "audio_url": "https://example.com/audio3.mp3",
        "duration": "180000",
        "preview_start_ms": 30000,
        "preview_duration_ms": 15000,
        "is_liked": true,
      }
    ]
  }
}
```

---

### 1.4 点赞/取消点赞音频

接口描述: 对指定音频进行点赞或取消点赞操作

请求信息:
- URL: `POST /audio/like`
- 方法: POST

#### 上行参数

| 参数名 | 类型 | 必填 | 说明 |
|--------|------|------|------|
| cid | String | 是 | 音频唯一标识 |
| action | String | 是 | 操作类型: "like" 或 "unlike" |

#### 请求示例

```http
POST /audio/like HTTP/1.1
Host: api.example.com
X-API-Version: v1
X-App-ID: hushie_app_v1
X-Device-ID: device_123abc456def
X-Timestamp: 1703123456789
X-Nonce: Ab3X9kP2mN8QwErT
X-Signature: a1b2c3d4e5f6789...
Authorization: Bearer eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9...
Content-Type: application/json

{
  "cid": "audio_001",
  "action": "like"
}
```

#### 响应格式

```json
{
  "errNo": 0,
  "data": {
    "cid": "audio_001",
    "is_liked": true,
    "likes_count": 22934,
  }
}
```

#### 取消点赞示例

```http
POST /audio/like HTTP/1.1
Host: api.example.com
X-API-Version: v1
X-App-ID: hushie_app_v1
X-Device-ID: device_123abc456def
X-Timestamp: 1703123456789
X-Nonce: Ab3X9kP2mN8QwErT
X-Signature: a1b2c3d4e5f6789...
Authorization: Bearer eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9...
Content-Type: application/json

{
  "cid": "audio_001",
  "action": "unlike"
}
```

#### 取消点赞响应

```json
{
  "errNo": 0,
  "data": {
    "cid": "audio_001",
    "is_liked": false,
    "likes_count": 22933,
  }
}
```
### 1.5 获取用户播放历史

接口描述：获取用户播放历史列表

请求信息:
- URL: `GET /user/history-list`
- 方法: GET

#### 上行参数: 无

#### 请求示例

```http
GET /home/tabs HTTP/1.1
Host: api.example.com
X-API-Version: v1
X-App-ID: hushie_app_v1
X-Device-ID: device_123abc456def
X-Timestamp: 1703123456789
X-Nonce: Ab3X9kP2mN8QwErT
X-Signature: a1b2c3d4e5f6789...
Authorization: Bearer eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9...
```

#### 响应格式

```json
{
  "errNo": 0,
  "data": {
    "history": [
      {
        "id": "audio_003",
        "cover": {
          "urls": {
            "x1": {
              "url": "https://example.com/cover3_400x600.jpg",
              "width": 400,
              "height": 600
            },
            "x2": {
              "url": "https://example.com/cover3_800x1200.jpg",
              "width": 800,
              "height": 1200
            },
            "x3": {
              "url": "https://example.com/cover3_1200x1800.jpg",
              "width": 1200,
              "height": 1800
            }
          }
        },
        "bgImage": {
          "urls": {
            "x1": {
                "url": "https://example.com/cover3_400x600.jpg",
                "width": 400,
                "height": 600
              },
              "x2": {
                "url": "https://example.com/cover3_800x1200.jpg",
                "width": 800,
                "height": 1200
            }
          },
        },
        "title": "Favorite Song",
        "desc": "User's favorite audio track",
        "author": "Favorite Artist",
        "avatar": "https://example.com/avatar3.jpg",
        "play_times": 1200000,
        "likes_count": 45000,
        "audio_url": "https://example.com/audio3.mp3",
        "duration": "180000",
        "preview_start_ms": 30000,
        "preview_duration_ms": 15000,
        "is_liked": true,
        "play_progress_ms": 3924801,
        "play_duration_ms": 1204312,
        "last_play_at_s": 124123123, // Unix 时间戳 单位秒
      },
      ...
    ]
  }
}
```

---


### 1.6 提交用户播放进度

接口描述: 提交用户播放一首音频的进度

请求信息:
- URL: `POST /user/play`
- 方法: POST

#### 上行参数:
- 增加is_first参数，用于播放次数统计

```json
{
  "id": "music_123",
  "is_first": true,
  "play_duration_ms": 12314,
  "play_progress_ms": 12414,
  "cid": "music_123",
  "count": 20,
}
```

#### 请求示例

```http
GET /home/tabs HTTP/1.1
Host: api.example.com
X-API-Version: v1
X-App-ID: hushie_app_v1
X-Device-ID: device_123abc456def
X-Timestamp: 1703123456789
X-Nonce: Ab3X9kP2mN8QwErT
X-Signature: a1b2c3d4e5f6789...
Authorization: Bearer eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9...
```


#### 响应格式:

```json
{
  "errNo": 0,
  "data": {
    "history": [
      {
        "id": "audio_003",
        "cover": {
          "urls": {
            "x1": {
              "url": "https://example.com/cover3_400x600.jpg",
              "width": 400,
              "height": 600
            },
            "x2": {
              "url": "https://example.com/cover3_800x1200.jpg",
              "width": 800,
              "height": 1200
            },
            "x3": {
              "url": "https://example.com/cover3_1200x1800.jpg",
              "width": 1200,
              "height": 1800
            }
          }
        },
        "bgImage": {
          "urls": {
            "x1": {
                "url": "https://example.com/cover3_400x600.jpg",
                "width": 400,
                "height": 600
              },
              "x2": {
                "url": "https://example.com/cover3_800x1200.jpg",
                "width": 800,
                "height": 1200
            }
          },
        },
        "title": "Favorite Song",
        "desc": "User's favorite audio track",
        "author": "Favorite Artist",
        "avatar": "https://example.com/avatar3.jpg",
        "play_times": 1200000,
        "likes_count": 45000,
        "audio_url": "https://example.com/audio3.mp3",
        "duration": "180000",
        "preview_start_ms": 30000,
        "preview_duration_ms": 15000,
        "is_liked": true,
        "play_progress_ms": 3924801,
        "play_duration_ms": 1204312,
        "last_play_at_s": 124123,
      },
      ...
    ]
  }
}
```

### 1.7 获取音频详情

接口描述：获取音频详情信息

请求信息:
- URL: `GET /audios/{id}`
- 方法: GET

上行参数:
```json
{
  "id": "audio_003",
}
```



## 2. 首页相关接口

### 2.1 获取首页Tabs

接口描述: 获取首页的标签页配置

请求信息:
- URL: `GET /home/tabs`
- 方法: GET

上行参数: 无

#### 请求示例

```http
GET /home/tabs HTTP/1.1
Host: api.example.com
X-API-Version: v1
X-App-ID: hushie_app_v1
X-Device-ID: device_123abc456def
X-Timestamp: 1703123456789
X-Nonce: Ab3X9kP2mN8QwErT
X-Signature: a1b2c3d4e5f6789...
Authorization: Bearer eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9...
```

#### 响应格式

```json
{
  "errNo": 0,
  "data": {
    "tabs": [
      {
        "id": "tab_1",
        "label": "F/W",
        "items": "items": [
          {
            "id": "audio_003",
            "cover": {
              "urls": {
                "x1": {
                  "url": "https://example.com/cover3_400x600.jpg",
                  "width": 400,
                  "height": 600
                },
                "x2": {
                  "url": "https://example.com/cover3_800x1200.jpg",
                  "width": 800,
                  "height": 1200
                },
                "x3": {
                  "url": "https://example.com/cover3_1200x1800.jpg",
                  "width": 1200,
                  "height": 1800
                }
              }
            },
            "bgImage": {
              "urls": {
                "x1": {
                    "url": "https://example.com/cover3_400x600.jpg",
                    "width": 400,
                    "height": 600
                  },
                  "x2": {
                    "url": "https://example.com/cover3_800x1200.jpg",
                    "width": 800,
                    "height": 1200
                }
              },
            },
            "title": "Favorite Song",
            "desc": "User's favorite audio track",
            "author": "Favorite Artist",
            "avatar": "https://example.com/avatar3.jpg",
            "play_times": 1200000,
            "likes_count": 45000,
            "audio_url": "https://example.com/audio3.mp3",
            "duration": "180000",
            "preview_start_ms": 30000,
            "preview_duration_ms": 15000,
            "is_liked": true,
          }
        ],
        ...
      },
      {
        "id": "tab_2",
        "label": "W/F",
        "items": "items": [
          {
            "id": "audio_003",
            "cover": {
              "urls": {
                "x1": {
                  "url": "https://example.com/cover3_400x600.jpg",
                  "width": 400,
                  "height": 600
                },
                "x2": {
                  "url": "https://example.com/cover3_800x1200.jpg",
                  "width": 800,
                  "height": 1200
                },
                "x3": {
                  "url": "https://example.com/cover3_1200x1800.jpg",
                  "width": 1200,
                  "height": 1800
                }
              }
            },
            "bgImage": {
              "urls": {
                "x1": {
                    "url": "https://example.com/cover3_400x600.jpg",
                    "width": 400,
                    "height": 600
                  },
                  "x2": {
                    "url": "https://example.com/cover3_800x1200.jpg",
                    "width": 800,
                    "height": 1200
                }
              },
            },
            "title": "Favorite Song",
            "desc": "User's favorite audio track",
            "author": "Favorite Artist",
            "avatar": "https://example.com/avatar3.jpg",
            "play_times": 1200000,
            "likes_count": 45000,
            "audio_url": "https://example.com/audio3.mp3",
            "duration": "180000",
            "preview_start_ms": 30000,
            "preview_duration_ms": 15000,
            "is_liked": true,
          }
        ],
        ...
      }
    ]
  }
}
```

---

## 3. 认证相关接口

### 3.1 Google账号登录

接口描述: 使用Google账号进行登录，获取授权码或ID Token

请求信息:
- URL: `POST /auth/google/login`
- 方法: POST

#### 上行参数

| 参数名 | 类型 | 必填 | 说明 |
|--------|------|------|------|
| google_token | String | 是 | Google授权码或ID Token |
| grant_type | String | 是 | 授权类型: "google_token" 或 "authorization_code" |

#### 请求示例

```http
POST /auth/google/login HTTP/1.1
Host: api.example.com
X-API-Version: v1
X-App-ID: hushie_app_v1
X-Device-ID: device_123abc456def
X-Timestamp: 1703123456789
X-Nonce: Ab3X9kP2mN8QwErT
X-Signature: a1b2c3d4e5f6789...
Content-Type: application/json

{
  "google_token": "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9...",
  "grant_type": "google_token"
}
```

#### 响应格式

```json
{
  "errNo": 0,
  "data": {
    "access_token": "access_token_here",
    "refresh_token": "refresh_token_here",
    "expires_in": 3600,
    "token_type": "Bearer",
    "expires_at": 1703127056
  }
}
```


---

### 3.2 刷新Access Token

接口描述: 使用Refresh Token刷新访问令牌

请求信息:
- URL: `POST /auth/google/refresh`
- 方法: POST

#### 上行参数

| 参数名 | 类型 | 必填 | 说明 |
|--------|------|------|------|
| refresh_token | String | 是 | 刷新令牌 |
| grant_type | String | 是 | 固定值: "refresh_token" |

#### 请求示例

```http
POST /auth/google/refresh HTTP/1.1
Host: api.example.com
X-API-Version: v1
X-App-ID: hushie_app_v1
X-Device-ID: device_123abc456def
X-Timestamp: 1703123456789
X-Nonce: Ab3X9kP2mN8QwErT
X-Signature: a1b2c3d4e5f6789...
Content-Type: application/json

{
  "refresh_token": "refresh_token_here",
  "grant_type": "refresh_token"
}
```

#### 响应格式

```json
{
  "errNo": 0,
  "data": {
    "access_token": "new_access_token_here",
    "refresh_token": "new_refresh_token_here",
    "expires_in": 3600,
    "token_type": "Bearer",
    "expires_at": 1703127056
  }
}
```


---

### 3.3 验证Token

接口描述: 验证Access Token的有效性

请求信息:
- URL: `POST /auth/google/validate`
- 方法: POST

#### 上行参数

| 参数名 | 类型 | 必填 | 说明 |
|--------|------|------|------|
| access_token | String | 是 | 访问令牌 |

#### 请求示例

```http
POST /auth/google/validate HTTP/1.1
Host: api.example.com
X-API-Version: v1
X-App-ID: hushie_app_v1
X-Device-ID: device_123abc456def
X-Timestamp: 1703123456789
X-Nonce: Ab3X9kP2mN8QwErT
X-Signature: a1b2c3d4e5f6789...
Authorization: Bearer eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9...
Content-Type: application/json

{
  "access_token": "access_token_to_validate"
}
```

#### 响应格式

```json
{
  "errNo": 0,
  "data": {
    "is_valid": true,
    "expires_at": 1703127056,
    "user_id": "user_123",
    "email": "user@example.com",
    "scopes": ["email", "profile"]
  }
}
```


---

### 3.4 服务器登出

接口描述: 通知服务器用户登出

请求信息:
- URL: `POST /auth/google/logout`
- 方法: POST

#### 上行参数

| 参数名 | 类型 | 必填 | 说明 |
|--------|------|------|------|
| action | String | 是 | 固定值: "logout" |
| timestamp | int | 是 | 当前时间戳 |

#### 请求示例

```http
POST /auth/google/logout HTTP/1.1
Host: api.example.com
X-API-Version: v1
X-App-ID: hushie_app_v1
X-Device-ID: device_123abc456def
X-Timestamp: 1703123456789
X-Nonce: Ab3X9kP2mN8QwErT
X-Signature: a1b2c3d4e5f6789...
Authorization: Bearer eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9...
Content-Type: application/json

{
  "action": "logout",
  "timestamp": 1703123456789
}
```

#### 响应格式

```json
{
  "errNo": 0,
  "data": null
}
```


---

### 3.5 删除账户

接口描述: 删除用户账户

请求信息:
- URL: `POST /auth/google/delete`
- 方法: POST

#### 上行参数

| 参数名 | 类型 | 必填 | 说明 |
|--------|------|------|------|
| action | String | 是 | 固定值: "delete_account" |
| timestamp | int | 是 | 当前时间戳 |
| confirmation | bool | 是 | 确认删除，固定值: true |

#### 请求示例

```http
POST /auth/google/delete HTTP/1.1
Host: api.example.com
X-API-Version: v1
X-App-ID: hushie_app_v1
X-Device-ID: device_123abc456def
X-Timestamp: 1703123456789
X-Nonce: Ab3X9kP2mN8QwErT
X-Signature: a1b2c3d4e5f6789...
Authorization: Bearer eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9...
Content-Type: application/json

{
  "action": "delete_account",
  "timestamp": 1703123456789,
  "confirmation": true
}
```

#### 响应格式

```json
{
  "errNo": 0,
  "data": null
}
```


---

### 3.6 获取用户信息

接口描述: 获取当前登录用户的基本信息

请求信息:
- URL: `GET /auth/userinfo`
- 方法: GET

#### 上行参数: 无

#### 请求示例:
```
GET /auth/userinfo HTTP/1.1
Host: api.example.com
X-API-Version: v1
X-App-ID: hushie_app_v1
X-Device-ID: device_123abc456def
X-Timestamp: 1703123456789
X-Nonce: Ab3X9kP2mN8QwErT
X-Signature: a1b2c3d4e5f6789...
Authorization: Bearer eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9...
```

#### 响应格式:
```json
{
  "errNo": 0,
  "data": {
    "uid": "user_12345",
    "nickname": "SexiestGod",
    "avatar": "https://example.com/avatars/user_12345.jpg",
    "is_vip": true
  }
}
```

#### 字段说明:
| 字段名 | 类型 | 说明 |
|--------|------|------|
| uid | String | 用户唯一标识 |
| nickname | String | 用户昵称 |
| avatar | String | 用户头像URL |
| is_vip | Boolean | 是否为VIP用户 |


---

## 4. 数据模型

### 4.1 AudioItem (音频项)

```json
{
  "id": "string",                 // 音频唯一标识
  "cover": {                      // 封面图片（多分辨率）
    "urls": {                     // 多分辨率URL集合
      "x1": {                     // 1x分辨率（必须）
        "url": "string",          // 图片URL
        "width": 400,             // 图片宽度
        "height": 600             // 图片高度
      },
      "x2": {                     // 2x分辨率（可选）
        "url": "string",          // 图片URL
        "width": 800,             // 图片宽度
        "height": 1200            // 图片高度
      },
      "x3": {                     // 3x分辨率（可选）
        "url": "string",          // 图片URL
        "width": 1200,            // 图片宽度
        "height": 1800            // 图片高度
      }
    }
  },
  "bg_image": {                   // 背景图片（多分辨率，可选）
    "urls": {                     // 多分辨率URL集合
      "x1": {                     // 1x分辨率（必须）
        "url": "string",          // 图片URL
        "width": "int",             // 图片宽度
        "height": "int"             // 图片高度
      },
      "x2": {                     // 2x分辨率（可选）
        "url": "string",            // 图片URL
        "width": "int",             // 图片宽度
        "height": "int"             // 图片高度
      }
    }
  },
  "title": "string",              // 音频标题
  "desc": "string",               // 音频描述
  "author": "string",             // 作者名称
  "avatar": "string",             // 作者头像URL
  "play_times": "int",            // 播放次数
  "likes_count": "int",           // 点赞数量
  "audio_url": "string",          // 音频文件URL
  "duration": "string",           // 音频总时长
  "created_at": "string",         // 创建时间
  "tags": ["string"],             // 标签数组
  "playback_position_ms": "int",  // 上次播放进度位置(毫秒)
  "last_played_at": "int",        // 最后播放时间戳
  "preview_start_ms": "int",      // 可预览开始时间点(毫秒)
  "preview_duration_ms": "int",    // 可预览时长(毫秒)
  "is_liked": "bool"              // 是否赞过
}
```

### 4.2 ImageModel (图片模型)

```json
{
  "urls": {                       // 多分辨率URL集合
    "x1": {                       // 1x分辨率（必须）
      "url": "string",            // 图片URL
      "width": "int",             // 图片宽度
      "height": "int"             // 图片高度
    },
    "x2": {                       // 2x分辨率（可选）
      "url": "string",            // 图片URL
      "width": "int",             // 图片宽度
      "height": "int"             // 图片高度
    },
    "x3": {                       // 3x分辨率（可选）
      "url": "string",            // 图片URL
      "width": "int",             // 图片宽度
      "height": "int"             // 图片高度
    }
  }
}
```

### 4.3 AccessTokenResponse (访问令牌响应)

```json
{
  "access_token": "string",   // 访问令牌
  "refresh_token": "string",  // 刷新令牌
  "expires_in": "int",        // 过期时间（秒）
  "token_type": "string",     // 令牌类型，通常为"Bearer"
  "expires_at": "int"         // 过期时间戳
}
```

### 4.4 TokenValidationResponse (令牌验证响应)

```json
{
  "is_valid": "boolean",      // 令牌是否有效
  "expires_at": "int",        // 过期时间戳
  "user_id": "string",        // 用户ID
  "email": "string",          // 用户邮箱
  "scopes": ["string"]        // 权限范围
}
```

### 4.5 TabItem (标签项)

```json
{
  "id": "string",           // 标签唯一标识
  "label": "string"         // 标签标题
}
```

### 4.6 UserInfoModel (用户信息模型)

```json
{
  "uid": "string",          // 用户唯一标识
  "nickname": "string",     // 用户昵称
  "avatar": "string",       // 用户头像URL
  "is_vip": "boolean"       // 是否为VIP用户
}
```


## 6. 音频预览功能

### 6.1 预览字段说明

音频预览功能允许用户在不完整播放音频的情况下，体验音频的特定片段。

#### 预览字段

| 字段名 | 类型 | 单位 | 说明 | 示例值 |
|--------|------|------|------|--------|
| preview_start_ms | int | 毫秒 | 可预览开始时间点 | 30000 (30秒) |
| preview_duration_ms | int | 毫秒 | 可预览时长 | 15000 (15秒) |

#### 预览逻辑

1. 预览范围: 从 `preview_start_ms` 开始，播放 `preview_duration_ms` 时长
2. 预览示例: 如果 `preview_start_ms = 30000`, `preview_duration_ms = 15000`
- 预览将从音频的第30秒开始
- 播放15秒的音频片段
- 预览结束时间为第45秒

#### 使用场景

- **试听功能**: 用户可以在购买前试听音频片段
- **内容预览**: 快速了解音频内容和风格
- **版权保护**: 限制用户只能听到部分内容
- **用户体验**: 提供快速的内容概览


---

## 7. 错误码说明

| 错误码 | 说明 | 处理建议 |
|--------|------|----------|
| 0 | 成功 | - |
| -1 | 通用错误 | 检查请求参数和网络连接 |
| -2 | 用户取消操作 | 无需处理，用户主动取消 |
| -3 | 认证信息缺失 | 检查Google登录配置 |
| 401 | 未授权 | Token无效或过期，需要重新登录 |
| 403 | 签名验证失败 | 检查签名算法和应用密钥 |
| 429 | 请求过于频繁 | 实施请求限流和重试机制 |
| 500 | 服务器内部错误 | 稍后重试或联系技术支持 |


---

## 8. 安全配置

### 8.1 应用配置

```dart
class ApiConfig {
  static const String appId = 'hushie_app_v1';
  static const String apiVersion = 'v1';
  static const String clientPlatform = 'flutter';
  static const String signatureAlgorithm = 'HMAC-SHA256';
  static const int nonceLength = 16;
  static const int maxTimestampDrift = 300; // 5分钟
}
```

### 8.2 安全检查

- ✅ 时间戳验证: 服务器检查时间戳是否在5分钟内
- ✅ 随机数验证: 确保每个随机数在短时间内唯一
- ✅ 签名验证: 验证请求签名的完整性
- ✅ Token验证: 检查访问令牌的有效性
- ✅ 设备验证: 验证设备ID的合法性

### 8.3 自定义请求头

可以在调用时添加自定义请求头，会与自动添加的请求头合并：

```dart
final response = await HttpClientService.get(
  uri,
  headers: {
    'X-Custom-Header': 'custom_value',
    'X-Feature-Flag': 'enable_new_feature',
  },
);
```


---

## 9. 开发指南

### 9.1 使用示例

```dart
// 获取音频列表
final response = await HttpClientService.get(
  Uri.parse(ApiConfig.getFullUrl('/audio/list?tag=rock&count=20')),
);

// POST请求示例
final response = await HttpClientService.postJson(
  Uri.parse(ApiConfig.getFullUrl('/auth/google/login')),
  body: {
    'google_token': 'token_here',
    'grant_type': 'google_token',
  },
);
```

### 9.2 错误处理

```dart
try {
  final response = await HttpClientService.get(uri);
  if (response.statusCode == 200) {
    final data = json.decode(response.body);
    // 处理成功响应
  } else {
    // 处理HTTP错误
  }
} catch (e) {
  // 处理网络异常
}
```

### 9.3 签名调试

在开发环境中，可以启用签名调试信息：

```dart
ApiConfig.initialize(debugMode: true);
```

这将输出详细的签名信息，帮助调试签名相关问题。
