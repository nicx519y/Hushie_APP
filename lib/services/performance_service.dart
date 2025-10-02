import 'package:flutter/foundation.dart';
import 'package:firebase_performance/firebase_performance.dart';
import 'dart:ui' as ui;
import '../config/api_config.dart';
import 'device_info_service.dart';

/// Firebase Performance 监控服务
/// 封装初始化、Trace 与网络指标记录
class PerformanceService {
  static final PerformanceService _instance = PerformanceService._internal();
  factory PerformanceService() => _instance;
  PerformanceService._internal();

  bool _initialized = false;
  late final FirebasePerformance _perf;
  final Map<String, String> _globalAttributes = {};

  /// 初始化 Performance 采集
  Future<void> initialize() async {
    if (_initialized) return;
    try {
      _perf = FirebasePerformance.instance;
      // 在 Debug 构建中默认关闭采集，避免噪声；必要时可在本地临时开启
      await _perf.setPerformanceCollectionEnabled(!kDebugMode);
      debugPrint('⚡ [PERF] Performance 监控初始化完成');
      // 设置设备 locale 相关的全局属性
      try {
        final locale = ui.PlatformDispatcher.instance.locale;
        final country = locale.countryCode ?? '';
        final tag = locale.toLanguageTag();
        setGlobalAttribute('locale', tag);
        if (country.isNotEmpty) {
          setGlobalAttribute('country', country);
        }
      } catch (e) {
        debugPrint('⚡ [PERF] 初始化 locale/country 属性失败: $e');
      }
      // 设置设备与应用信息的全局属性
      try {
        // 确保 AppVersion 已初始化
        await ApiConfig.initialize();
        final deviceInfo = await DeviceInfoService.getDeviceInfo();
        final platform = deviceInfo['platform'] ?? 'Unknown';
        final deviceId = deviceInfo['device_id'] ?? 'unknown_device';
        final appVersion = ApiConfig.getAppVersion();
        setGlobalAttributes({
          'platform': platform,
          'device_id': deviceId,
          'app_version': appVersion,
        });
      } catch (e) {
        debugPrint('⚡ [PERF] 初始化设备/应用属性失败: $e');
      }
      _initialized = true;
    } catch (e) {
      debugPrint('❌ [PERF] 初始化失败: $e');
    }
  }

  /// 设置单个全局属性（在每个 Trace/HttpMetric 启动时自动附加）
  void setGlobalAttribute(String key, String value) {
    if (key.isEmpty) return;
    _globalAttributes[key] = value;
  }

  /// 批量设置全局属性
  void setGlobalAttributes(Map<String, String> attrs) {
    for (final entry in attrs.entries) {
      setGlobalAttribute(entry.key, entry.value);
    }
  }

  /// 删除全局属性
  void removeGlobalAttribute(String key) {
    _globalAttributes.remove(key);
  }

  void _applyGlobalAttributesToTrace(Trace trace) {
    _globalAttributes.forEach((k, v) {
      try {
        trace.putAttribute(k, v);
      } catch (_) {
        // 忽略单个属性失败
      }
    });
  }

  void _applyGlobalAttributesToHttpMetric(HttpMetric metric) {
    _globalAttributes.forEach((k, v) {
      try {
        metric.putAttribute(k, v);
      } catch (_) {
        // 忽略单个属性失败
      }
    });
  }

  /// 创建并启动一个自定义 Trace
  /// 返回 Trace 对象；使用者负责在适当时机调用 stop()
  Future<Trace?> startTrace(String name) async {
    try {
      final trace = _perf.newTrace(name);
      await trace.start();
      _applyGlobalAttributesToTrace(trace);
      return trace;
    } catch (e) {
      debugPrint('❌ [PERF] 启动 Trace 失败($name): $e');
      return null;
    }
  }

  /// 停止指定 Trace（空安全）
  Future<void> stopTrace(Trace? trace) async {
    try {
      if (trace != null) {
        await trace.stop();
      }
    } catch (e) {
      debugPrint('❌ [PERF] 停止 Trace 失败: $e');
    }
  }

  /// 对网络请求进行性能度量
  /// 需在请求前调用 startHttpMetric，并在请求完成后调用 stopHttpMetric
  Future<HttpMetric?> startHttpMetric(Uri url, HttpMethod method) async {
    try {
      final metric = _perf.newHttpMetric(url.toString(), method);
      await metric.start();
      _applyGlobalAttributesToHttpMetric(metric);
      return metric;
    } catch (e) {
      debugPrint('❌ [PERF] 启动 HttpMetric 失败(${url.toString()}): $e');
      return null;
    }
  }

  /// 结束网络度量，并可选记录额外信息（响应码、大小等）
  Future<void> stopHttpMetric(
    HttpMetric? metric, {
    int? responseCode,
    int? requestPayloadSize,
    int? responsePayloadSize,
    String? contentType,
  }) async {
    try {
      if (metric == null) return;
      if (responseCode != null) metric.httpResponseCode = responseCode;
      if (requestPayloadSize != null) metric.requestPayloadSize = requestPayloadSize;
      if (responsePayloadSize != null) metric.responsePayloadSize = responsePayloadSize;
      if (contentType != null) metric.responseContentType = contentType;
      await metric.stop();
    } catch (e) {
      debugPrint('❌ [PERF] 结束 HttpMetric 失败: $e');
    }
  }
}