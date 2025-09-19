# Google Pay 集成指南

本指南介绍如何在 Hushie Audio 应用中使用 Google Pay 支付功能。

## 📋 已完成的集成步骤

### 1. 依赖配置
- ✅ 已添加 `pay: ^3.2.1` 包到 `pubspec.yaml`
- ✅ 已配置 Android `build.gradle.kts` 文件
- ✅ 已添加 Google Play Services Wallet 依赖
- ✅ 已设置最小 SDK 版本为 19

### 2. 配置文件
- ✅ 已创建 `assets/configs/google_pay_config.json` 配置文件
- ✅ 已将配置文件添加到 `pubspec.yaml` 的 assets 列表

### 3. 服务类
- ✅ 已创建 `GooglePayService` 服务类
- ✅ 已实现支付按钮组件
- ✅ 已实现支付结果处理

### 4. 演示页面
- ✅ 已创建 `GooglePayDemoPage` 演示页面
- ✅ 已实现完整的支付流程演示

## 🚀 如何使用

### 基本用法

```dart
import 'package:hushie_app/services/google_pay_service.dart';
import 'package:pay/pay.dart';

// 检查用户是否可以使用 Google Pay
bool canPay = await GooglePayService.canUserPay();

// 创建 Google Pay 按钮
Widget payButton = GooglePayService.buildGooglePayButton(
  onPaymentResult: (result) {
    // 处理支付结果
    print('支付结果: $result');
  },
  paymentItems: GooglePayService.createPaymentItems(
    amount: '9.99',
    currency: 'USD',
    label: '音频订阅',
  ),
);
```

### 在页面中使用

```dart
import 'package:flutter/material.dart';
import 'package:hushie_app/pages/google_pay_demo_page.dart';

// 导航到 Google Pay 演示页面
Navigator.push(
  context,
  MaterialPageRoute(
    builder: (context) => const GooglePayDemoPage(),
  ),
);
```

## ⚙️ 配置说明

### 测试环境配置
当前配置使用测试环境 (`"environment": "TEST"`)，支持以下测试卡:
- Visa: `4111111111111111`
- Mastercard: `5555555555554444`
- American Express: `378282246310005`

### 生产环境配置
要切换到生产环境，需要:

1. **获取 Google Pay 商户 ID**
   - 访问 [Google Pay Business Console](https://pay.google.com/business/console)
   - 创建商户账户并获取 Merchant ID

2. **配置支付网关**
   - 选择支付处理商 (如 Stripe, Square, Braintree 等)
   - 获取网关商户 ID

3. **更新配置文件**
   ```json
   {
     "provider": "google_pay",
     "data": {
       "environment": "PRODUCTION",
       "merchantInfo": {
         "merchantId": "你的商户ID",
         "merchantName": "Hushie Audio"
       },
       "allowedPaymentMethods": [{
         "tokenizationSpecification": {
           "type": "PAYMENT_GATEWAY",
           "parameters": {
             "gateway": "stripe",
             "gatewayMerchantId": "你的网关商户ID"
           }
         }
       }]
     }
   }
   ```

## 🔧 支持的支付网关

Google Pay 支持多种支付处理商:
- **Stripe** - 推荐用于全球支付
- **Square** - 适合北美市场
- **Braintree** - PayPal 旗下服务
- **Adyen** - 企业级解决方案
- **Worldpay** - 传统支付处理商

## 📱 平台支持

- ✅ **Android**: 完全支持 Google Pay
- ❌ **iOS**: 需要使用 Apple Pay (已包含在 pay 包中)
- ❌ **Web**: 需要额外配置 Google Pay Web API

## 🛠️ 故障排除

### 常见问题

1. **Google Pay 按钮不显示**
   - 确保设备已安装 Google Pay 应用
   - 检查设备是否支持 NFC
   - 确认 Google Pay 中已添加支付方式

2. **支付失败**
   - 检查网络连接
   - 确认配置文件格式正确
   - 验证商户 ID 和网关配置

3. **构建错误**
   - 确保 Android minSdkVersion >= 19
   - 检查 Google Play Services 依赖版本
   - 运行 `flutter clean` 后重新构建

### 调试技巧

```dart
// 启用调试日志
import 'package:flutter/foundation.dart';

if (kDebugMode) {
  print('Google Pay 调试信息: $paymentResult');
}
```

## 📚 相关资源

- [Google Pay API 文档](https://developers.google.com/pay/api)
- [Flutter Pay 包文档](https://pub.dev/packages/pay)
- [Google Pay 集成要求](https://developers.google.com/pay/api/android/guides/setup)
- [Google Pay Business Console](https://pay.google.com/business/console)

## 🔒 安全注意事项

1. **永远不要在客户端存储敏感信息**
   - 支付令牌应立即发送到后端处理
   - 不要记录完整的支付数据

2. **验证支付结果**
   - 在后端验证支付令牌的有效性
   - 实施防重放攻击机制

3. **遵循 PCI DSS 标准**
   - 使用 HTTPS 传输支付数据
   - 定期更新安全证书

---

**注意**: 当前配置仅用于测试目的。在生产环境中使用前，请确保完成所有必要的安全审查和合规检查。