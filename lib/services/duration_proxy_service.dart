import 'package:flutter/material.dart';
/// 音频时长代理服务
/// 负责将真实的音频时长和位置转换为经过展现策略过滤的渲染值
/// 
/// 窗口概念说明：
/// - 真实窗口：完整的音频时长范围 [0, realDuration]
/// - 预览窗口：从previewStart开始，长度为previewDuration的窗口
/// - 渲染窗口：用于UI显示的窗口，长度为预览窗口的3倍，尽量与预览窗口开始位置重合
class DurationProxyService {
  // 真实的音频总时长
  final Duration _realDuration;
  
  // 预览窗口开始时间
  final Duration _previewStart;
  
  // 预览窗口时长
  final Duration _previewDuration;
  
  // 渲染窗口开始时间（计算得出）
  late final Duration _renderStart;
  
  // 渲染窗口时长（计算得出）
  late final Duration _renderDuration;
  
  // 是否启用预览模式
  final bool _isPreviewMode;

  DurationProxyService({
    required Duration duration,
    Duration previewStart = Duration.zero,
    Duration previewDuration = Duration.zero,
    bool isPreviewMode = false,
  }) : _realDuration = duration,
       _previewStart = previewStart,
       _previewDuration = previewDuration,
       _isPreviewMode = isPreviewMode && previewDuration > Duration.zero {
    
    // 打印创建模型时的数据
    debugPrint('DurationProxyService 创建:');
    debugPrint('  真实时长: ${_realDuration.inMilliseconds}ms');
    debugPrint('  预览开始: ${_previewStart.inMilliseconds}ms');
    debugPrint('  预览时长: ${_previewDuration.inMilliseconds}ms');
    debugPrint('  预览模式: $_isPreviewMode');
    
    if (_isPreviewMode) {
      // 计算渲染窗口参数
      _calculateRenderWindow();
      debugPrint('  渲染开始: ${_renderStart.inMilliseconds}ms');
      debugPrint('  渲染时长: ${_renderDuration.inMilliseconds}ms');
    } else {
      // 非预览模式，渲染窗口等于真实窗口
      _renderStart = Duration.zero;
      _renderDuration = _realDuration;
      debugPrint('  普通模式 - 渲染时长: ${_renderDuration.inMilliseconds}ms');
    }
    debugPrint('---');
  }
  
  /// 计算渲染窗口的开始位置和时长
  void _calculateRenderWindow() {
    // 渲染窗口长度为预览窗口的3倍，但不能超过真实时长
    int targetMicroseconds = (_previewDuration.inMicroseconds * 3).round();
    Duration targetRenderDuration = Duration(
      microseconds: targetMicroseconds > _realDuration.inMicroseconds 
        ? _realDuration.inMicroseconds 
        : targetMicroseconds
    );
    
    // 计算渲染窗口开始位置，尽量与预览窗口重合，但确保不超出边界
    Duration targetRenderStart = Duration(
      microseconds: (_previewStart.inMicroseconds)
        .clamp(0, (_realDuration.inMicroseconds - targetRenderDuration.inMicroseconds).clamp(0, _realDuration.inMicroseconds))
    );
    
    // 最终确保渲染窗口时长不超出剩余空间
    targetRenderDuration = Duration(
      microseconds: (targetRenderDuration.inMicroseconds)
        .clamp(0, _realDuration.inMicroseconds - targetRenderStart.inMicroseconds)
    );
    
    _renderStart = targetRenderStart;
    _renderDuration = targetRenderDuration;
  }

  /// 是否为预览模式
  bool get isPreviewMode => _isPreviewMode;
  Duration get renderDuration => _renderDuration;
  Duration get renderStart => _renderStart;

  /// 将真实位置转换为渲染位置
  /// [realPosition] 真实的播放位置
  /// 返回用于UI显示的位置值（相对于渲染窗口的位置）
  Duration realPositionToRenderPosition(Duration realPosition) {
    if (!_isPreviewMode) {
      // 非预览模式，直接返回真实位置
      // debugPrint('非预览模式，直接返回真实位置: ${realPosition.inMilliseconds}ms');
      return realPosition;
    }

    // 预览模式下的转换逻辑
    if (realPosition < _renderStart) {
      // 还未到渲染窗口开始时间
      // debugPrint('预览模式 - 还未到渲染窗口开始时间: ${Duration.zero.inMilliseconds}ms');
      return Duration.zero;
    }
    
    if (realPosition >= _renderStart + _renderDuration) {
      // 超过渲染窗口结束时间
      // debugPrint('预览模式 - 超过渲染窗口结束时间: ${_renderDuration.inMilliseconds}ms');
      return _renderDuration;
    }
    
    // 在渲染窗口范围内，返回相对于渲染窗口开始的位置
    // debugPrint('预览模式 - 在渲染窗口范围内: ${(realPosition - _renderStart).inMilliseconds}ms');
    return realPosition - _renderStart;
  }

  /// 将渲染位置转换为真实位置
  /// [renderPosition] UI显示的位置（相对于渲染窗口）
  /// 返回真实的播放位置
  Duration renderPositionToRealPosition(Duration renderPosition) {
    if (!_isPreviewMode) {
      // 非预览模式，直接返回渲染位置
      // debugPrint('非预览模式，直接返回渲染位置: ${renderPosition.inMilliseconds}ms');
      return renderPosition;
    }

    // 预览模式下的转换逻辑
    // 将渲染位置映射到渲染窗口范围内的真实位置
    Duration clampedPosition = Duration(microseconds: renderPosition.inMicroseconds.clamp(0, _renderDuration.inMicroseconds));
    // debugPrint('预览模式 - 渲染位置转换为真实位置: ${(_renderStart + clampedPosition).inMilliseconds}ms');
    return _renderStart + clampedPosition;
  }

  /// 创建预览模式的代理服务
  static DurationProxyService createPreview({
    required Duration duration,
    required Duration previewStart,
    required Duration previewDuration,
  }) {
    return DurationProxyService(
      duration: duration,
      previewStart: previewStart,
      previewDuration: previewDuration,
      isPreviewMode: true,
    );
  }

  /// 创建普通模式的代理服务
  static DurationProxyService createNormal(Duration duration) {
    return DurationProxyService(
      duration: duration,
      isPreviewMode: false,
    );
  }
}