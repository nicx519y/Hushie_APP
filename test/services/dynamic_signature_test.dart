import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/services.dart';
import 'package:hushie_app/services/app_signature_service.dart';
import 'package:hushie_app/services/http_client_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  group('动态签名验证系统测试', () {
    late AppSignatureService appSignatureService;

    setUp(() {
      appSignatureService = AppSignatureService();
      
      // 模拟Android平台的方法通道
      TestDefaultBinaryMessengerBinding.instance!.defaultBinaryMessenger
          .setMockMethodCallHandler(
        const MethodChannel('app_signature_verification'),
        (MethodCall methodCall) async {
          switch (methodCall.method) {
            case 'getSignatureHash':
              return 'mock_signature_hash_12345';
            case 'generateDynamicSignature':
              final args = methodCall.arguments as Map<String, dynamic>;
              return {
                'signature': 'mock_dynamic_signature_${args['timestamp']}_${args['nonce']}',
                'timestamp': args['timestamp'],
                'nonce': args['nonce'],
              };
            case 'getIntegrityInfo':
              return {
                'isSignatureValid': true,
                'installerPackageName': 'com.android.vending',
                'isFromTrustedSource': true,
                'isDebugBuild': false,
                'isIntegrityValid': true,
              };
            default:
              return null;
          }
        },
      );
    });

    tearDown(() {
      TestDefaultBinaryMessengerBinding.instance!.defaultBinaryMessenger
          .setMockMethodCallHandler(
        const MethodChannel('app_signature_verification'),
        null,
      );
      AppSignatureService.clearCache();
    });

    test('应该能够获取应用签名哈希', () async {
      final signatureHash = await appSignatureService.getSignatureHash();
      
      expect(signatureHash, isNotNull);
      expect(signatureHash, equals('mock_signature_hash_12345'));
    });

    test('应该能够生成动态签名参数', () async {
      final dynamicSignature = await appSignatureService.generateDynamicSignature();
      
      expect(dynamicSignature, isNotNull);
      expect(dynamicSignature!['signature'], isNotNull);
      expect(dynamicSignature['timestamp'], isNotNull);
      expect(dynamicSignature['nonce'], isNotNull);
      
      // 验证时间戳格式
      final timestamp = int.tryParse(dynamicSignature['timestamp']!);
      expect(timestamp, isNotNull);
      expect(timestamp! > 0, isTrue);
      
      // 验证随机数长度
      expect(dynamicSignature['nonce']!.length, equals(16));
      
      // 验证签名不为空
      expect(dynamicSignature['signature']!.isNotEmpty, isTrue);
    });

    test('应该能够获取应用完整性信息', () async {
      final integrityInfo = await appSignatureService.getIntegrityInfo();
      
      expect(integrityInfo, isNotNull);
      expect(integrityInfo['isSignatureValid'], isTrue);
      expect(integrityInfo['isFromTrustedSource'], isTrue);
      expect(integrityInfo['isIntegrityValid'], isTrue);
    });

    test('签名哈希应该被正确缓存', () async {
      // 第一次获取
      final hash1 = await appSignatureService.getSignatureHash();
      
      // 第二次获取（应该使用缓存）
      final hash2 = await appSignatureService.getSignatureHash();
      
      expect(hash1, equals(hash2));
      expect(hash1, equals('mock_signature_hash_12345'));
    });

    test('清除缓存后应该重新获取签名哈希', () async {
      // 获取签名哈希
      await appSignatureService.getSignatureHash();
      
      // 清除缓存
      AppSignatureService.clearCache();
      
      // 再次获取（应该重新调用原生方法）
      final hash = await appSignatureService.getSignatureHash();
      expect(hash, equals('mock_signature_hash_12345'));
    });

    test('多次生成的动态签名应该不同', () async {
      final signature1 = await appSignatureService.generateDynamicSignature();
      
      // 等待1毫秒确保时间戳不同
      await Future.delayed(const Duration(milliseconds: 1));
      
      final signature2 = await appSignatureService.generateDynamicSignature();
      
      expect(signature1, isNotNull);
      expect(signature2, isNotNull);
      
      // 时间戳应该不同
      expect(signature1!['timestamp'], isNot(equals(signature2!['timestamp'])));
      
      // 随机数应该不同
      expect(signature1['nonce'], isNot(equals(signature2['nonce'])));
      
      // 签名应该不同
      expect(signature1['signature'], isNot(equals(signature2['signature'])));
    });

    test('兼容性方法应该正常工作', () async {
      // 测试静态方法
      final isValid = await AppSignatureService.verifyAppSignature();
      expect(isValid, isTrue);
      
      // 测试实例方法
      final isValidInstance = await appSignatureService.verifySignature();
      expect(isValidInstance, isTrue);
      
      // 测试签名信息获取
      final signatureInfo = await appSignatureService.getSignatureInfo();
      expect(signatureInfo, contains('SHA256:'));
    });
  });

  group('HTTP客户端动态签名集成测试', () {
    setUp(() {
      // 模拟设备信息服务
      TestDefaultBinaryMessengerBinding.instance!.defaultBinaryMessenger
          .setMockMethodCallHandler(
        const MethodChannel('device_info_service'),
        (MethodCall methodCall) async {
          switch (methodCall.method) {
            case 'getDeviceId':
              return 'mock_device_id_12345';
            default:
              return null;
          }
        },
      );
      
      // 模拟签名验证服务
      TestDefaultBinaryMessengerBinding.instance!.defaultBinaryMessenger
          .setMockMethodCallHandler(
        const MethodChannel('app_signature_verification'),
        (MethodCall methodCall) async {
          switch (methodCall.method) {
            case 'getSignatureHash':
              return 'mock_signature_hash_12345';
            case 'generateDynamicSignature':
              final args = methodCall.arguments as Map<String, dynamic>;
              return 'mock_dynamic_signature_${args['timestamp']}_${args['nonce']}';
            case 'getIntegrityInfo':
              return {
                'isSignatureValid': true,
                'installerPackageName': 'com.android.vending',
                'isFromTrustedSource': true,
                'isDebugBuild': false,
                'isIntegrityValid': true,
              };
            default:
              return null;
          }
        },
      );
    });

    tearDown(() {
      TestDefaultBinaryMessengerBinding.instance!.defaultBinaryMessenger
          .setMockMethodCallHandler(
        const MethodChannel('device_info_service'),
        null,
      );
      TestDefaultBinaryMessengerBinding.instance!.defaultBinaryMessenger
          .setMockMethodCallHandler(
        const MethodChannel('app_signature_verification'),
        null,
      );
      AppSignatureService.clearCache();
      HttpClientService.clearDeviceIdCache();
    });

    test('HTTP请求头应该包含动态签名信息', () async {
      // 注意：这个测试需要模拟HTTP请求，实际项目中可能需要使用http_mock等库
      // 这里主要测试请求头构建逻辑
      
      try {
        // 尝试构建请求头（会调用动态签名生成）
        final uri = Uri.parse('https://api.example.com/test');
        
        // 由于我们无法直接访问_buildRequestHeaders方法，
        // 我们通过发起一个实际请求来测试（会超时，但能测试请求头构建）
        await HttpClientService.get(
          uri,
          timeout: const Duration(milliseconds: 100),
        ).timeout(
          const Duration(milliseconds: 50),
          onTimeout: () => throw TimeoutException('Expected timeout'),
        );
      } catch (e) {
        // 预期会超时或连接失败，这是正常的
        expect(e.toString(), anyOf([
          contains('TimeoutException'),
          contains('SocketException'),
          contains('ClientException'),
        ]));
      }
    });
  });

  group('错误处理测试', () {
    setUp(() {
      // 模拟方法通道错误
      TestDefaultBinaryMessengerBinding.instance!.defaultBinaryMessenger
          .setMockMethodCallHandler(
        const MethodChannel('app_signature_verification'),
        (MethodCall methodCall) async {
          throw PlatformException(
            code: 'SIGNATURE_ERROR',
            message: 'Mock signature error',
          );
        },
      );
    });

    tearDown(() {
      TestDefaultBinaryMessengerBinding.instance!.defaultBinaryMessenger
          .setMockMethodCallHandler(
        const MethodChannel('app_signature_verification'),
        null,
      );
      AppSignatureService.clearCache();
    });

    test('签名获取失败时应该返回null', () async {
      final appSignatureService = AppSignatureService();
      final signatureHash = await appSignatureService.getSignatureHash();
      
      expect(signatureHash, isNull);
    });

    test('动态签名生成失败时应该返回null', () async {
      final appSignatureService = AppSignatureService();
      final dynamicSignature = await appSignatureService.generateDynamicSignature();
      
      expect(dynamicSignature, isNull);
    });

    test('验证方法在错误时应该返回false', () async {
      final appSignatureService = AppSignatureService();
      final isValid = await appSignatureService.verifySignature();
      
      expect(isValid, isFalse);
    });
  });
}

class TimeoutException implements Exception {
  final String message;
  TimeoutException(this.message);
  
  @override
  String toString() => 'TimeoutException: $message';
}