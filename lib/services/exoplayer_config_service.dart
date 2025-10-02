import 'package:flutter/services.dart';
import 'dart:io';

/// ExoPlayer 缓冲配置服务
/// 仅在 Android 平台生效，通过原生方法通道配置 ExoPlayer 缓冲参数
class ExoPlayerConfigService {
  static const MethodChannel _channel = MethodChannel('com.stdash.hushie_app/exoplayer_config');
  
  /// 配置 ExoPlayer 缓冲参数
  /// 
  /// [minBufferMs] 最小缓冲时间（毫秒），默认 20000ms (20秒)
  /// [maxBufferMs] 最大缓冲时间（毫秒），默认 60000ms (60秒)
  /// 
  /// 返回配置结果消息
  static Future<String?> configureBuffer({
    int minBufferMs = 20000,
    int maxBufferMs = 60000,
  }) async {
    // 仅在 Android 平台执行
    if (!Platform.isAndroid) {
      return 'ExoPlayer configuration is only available on Android platform';
    }
    
    try {
      final String? result = await _channel.invokeMethod('configureExoPlayerBuffer', {
        'minBufferMs': minBufferMs,
        'maxBufferMs': maxBufferMs,
      });
      
      return result;
    } on PlatformException catch (e) {
      return 'Failed to configure ExoPlayer buffer: ${e.message}';
    }
  }
  
  /// 使用推荐的缓冲配置
  /// 
  /// 针对音频流媒体优化的缓冲参数：
  /// - 最小缓冲：5秒（快速开始播放）
  /// - 最大缓冲：60秒（平衡性能和内存使用）
  static Future<String?> configureOptimalBuffer() async {
    return await configureBuffer(
      minBufferMs: 2000, // 2秒最小缓冲
      maxBufferMs: 600000, // 600秒最大缓冲
    );
  }
  
  /// 配置大缓冲（适用于网络不稳定环境）
  /// 
  /// 针对网络不稳定环境的缓冲参数：
  /// - 最小缓冲：10秒
  /// - 最大缓冲：300秒（5分钟）
  static Future<String?> configureLargeBuffer() async {
    return await configureBuffer(
      minBufferMs: 6000, // 6秒最小缓冲
      maxBufferMs: 600000, // 600秒最大缓冲（10分钟）
    );
  }
  
  /// 配置低延迟缓冲（适用于实时音频）
  /// 
  /// 针对低延迟需求的缓冲参数：
  /// - 最小缓冲：1秒
  /// - 最大缓冲：600秒
  static Future<String?> configureLowLatencyBuffer() async {
    return await configureBuffer(
      minBufferMs: 1000,  // 1秒最小缓冲
      maxBufferMs: 600000, // 600秒最大缓冲（10分钟）
    );
  }
  
  /// 配置高质量缓冲（适用于高品质音频）
  /// 
  /// 针对高品质音频的缓冲参数：
  /// - 最小缓冲：30秒
  /// - 最大缓冲：120秒
  static Future<String?> configureHighQualityBuffer() async {
    return await configureBuffer(
      minBufferMs: 30000,  // 30秒最小缓冲
      maxBufferMs: 120000, // 120秒最大缓冲
    );
  }
  
  /// 自定义缓冲配置（按用户需求设置）
  /// 
  /// 允许用户自定义缓冲参数：
  /// [minBufferMs] 最小缓冲时间（毫秒），建议范围：2000-30000
  /// [maxBufferMs] 最大缓冲时间（毫秒），建议范围：15000-300000
  /// 
  /// 示例用法：
  /// ```dart
  /// // 设置60秒最大缓冲（如用户文档要求）
  /// await ExoPlayerConfigService.configureCustomBuffer(
  ///   minBufferMs: 5000,  // 5秒
  ///   maxBufferMs: 60000, // 60秒
  /// );
  /// ```
  static Future<String?> configureCustomBuffer({
    required int minBufferMs,
    required int maxBufferMs,
  }) async {
    // 参数验证
    if (minBufferMs < 1000) {
      throw ArgumentError('最小缓冲时间不能少于1秒（1000ms）');
    }
    if (maxBufferMs < minBufferMs) {
      throw ArgumentError('最大缓冲时间不能小于最小缓冲时间');
    }
    if (maxBufferMs > 600000) { // 10分钟
      throw ArgumentError('最大缓冲时间不建议超过10分钟（600000ms）');
    }
    
    return await configureBuffer(
      minBufferMs: minBufferMs,
      maxBufferMs: maxBufferMs,
    );
  }
}