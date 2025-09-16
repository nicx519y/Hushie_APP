import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../services/audio_service.dart';

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
  
  // 预览区域在渲染窗口中的开始位置（计算得出）
  late final Duration _renderPreviewStart;
  
  // 预览区域在渲染窗口中的结束位置（计算得出）
  late final Duration _renderPreviewEnd;
  
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
    debugPrint('  真实时长: \${_realDuration.inMilliseconds}ms');
    debugPrint('  预览开始: \${_previewStart.inMilliseconds}ms');
    debugPrint('  预览时长: \${_previewDuration.inMilliseconds}ms');
    debugPrint('  预览模式: \$_isPreviewMode');
    
    if (_isPreviewMode) {
      // 计算渲染窗口参数
      _calculateRenderWindow();
      debugPrint('  渲染开始: \${_renderStart.inMilliseconds}ms');
      debugPrint('  渲染时长: \${_renderDuration.inMilliseconds}ms');
      debugPrint('  预览在渲染中开始: \${_renderPreviewStart.inMilliseconds}ms');
      debugPrint('  预览在渲染中结束: \${_renderPreviewEnd.inMilliseconds}ms');
    } else {
      // 非预览模式，渲染窗口等于真实窗口
      _renderStart = Duration.zero;
      _renderDuration = _realDuration;
      _renderPreviewStart = Duration.zero;
      _renderPreviewEnd = _realDuration;
      debugPrint('  普通模式 - 渲染时长: \${_renderDuration.inMilliseconds}ms');
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
    
    // 计算预览区域在渲染窗口中的相对位置
    _renderPreviewStart = _previewStart - _renderStart;
    _renderPreviewEnd = _renderPreviewStart + _previewDuration;
    
    // 确保预览区域在渲染窗口范围内
    _renderPreviewStart = Duration(microseconds: _renderPreviewStart.inMicroseconds.clamp(0, _renderDuration.inMicroseconds));
    _renderPreviewEnd = Duration(microseconds: _renderPreviewEnd.inMicroseconds.clamp(0, _renderDuration.inMicroseconds));
    
    debugPrint('[positionProxy] previewStart: \$_previewStart previewDuration: \$_previewDuration');
    debugPrint('[positionProxy] totalDuration \$_realDuration');
    debugPrint('[positionProxy] renderStart: \$_renderStart renderDuration: \$_renderDuration');
    debugPrint('[positionProxy] renderPreviewStart: \$_renderPreviewStart renderPreviewEnd: \$_renderPreviewEnd');
  }

  /// 是否为预览模式
  bool get isPreviewMode => _isPreviewMode;
  Duration get renderDuration => _renderDuration;
  Duration get renderStart => _renderStart;
  Duration get renderPreviewStart => _renderPreviewStart;
  Duration get renderPreviewEnd => _renderPreviewEnd;

  /// 将真实位置转换为渲染位置
  /// [realPosition] 真实的播放位置
  /// 返回用于UI显示的位置值（相对于渲染窗口的位置）
  Duration realPositionToRenderPosition(Duration realPosition) {
    if (!_isPreviewMode) {
      // 非预览模式，直接返回真实位置
      // debugPrint('非预览模式，直接返回真实位置: \${realPosition.inMilliseconds}ms');
      return realPosition;
    }

    // 预览模式下的转换逻辑
    if (realPosition < _renderStart) {
      // 还未到渲染窗口开始时间
      // debugPrint('预览模式 - 还未到渲染窗口开始时间: \${Duration.zero.inMilliseconds}ms');
      return Duration.zero;
    }
    
    if (realPosition >= _renderStart + _renderDuration) {
      // 超过渲染窗口结束时间
      // debugPrint('预览模式 - 超过渲染窗口结束时间: \${_renderDuration.inMilliseconds}ms');
      return _renderDuration;
    }
    
    // 在渲染窗口范围内，返回相对于渲染窗口开始的位置
    // debugPrint('预览模式 - 在渲染窗口范围内: \${(realPosition - _renderStart).inMilliseconds}ms');
    return realPosition - _renderStart;
  }

  /// 将渲染位置转换为真实位置
  /// [renderPosition] UI显示的位置（相对于渲染窗口）
  /// 返回真实的播放位置
  Duration renderPositionToRealPosition(Duration renderPosition) {
    if (!_isPreviewMode) {
      // 非预览模式，直接返回渲染位置
      // debugPrint('非预览模式，直接返回渲染位置: \${renderPosition.inMilliseconds}ms');
      return renderPosition;
    }

    // 预览模式下的转换逻辑
    // 将渲染位置映射到渲染窗口范围内的真实位置
    Duration clampedPosition = Duration(microseconds: renderPosition.inMicroseconds.clamp(0, _renderDuration.inMicroseconds));
    // debugPrint('预览模式 - 渲染位置转换为真实位置: \${(_renderStart + clampedPosition).inMilliseconds}ms');
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
  
  /// 创建流监听器代理服务
  static DurationProxyService createStreamListener() {
    return DurationProxyService(
      duration: Duration.zero,
      isPreviewMode: false,
    );
  }
}

/// AudioPlayerState 代理扩展
/// 
/// 为 Stream\<AudioPlayerState\> 添加代理功能的扩展方法
extension AudioStateProxyExtension on Stream<AudioPlayerState> {
  /// 添加代理功能，支持链式调用
  /// 
  /// 使用方式：
  /// ```dart
  /// _audioManager.audioStateStream
  ///   .proxy(durationProxyService)
  ///   .listen((proxiedState) {
  ///     // proxiedState.duration 已经过滤处理
  ///   });
  /// ```
  AudioStateProxyStream proxy(DurationProxyService durationProxy) {
    return AudioStateProxyStream(this, durationProxy);
  }
}

/// AudioPlayerState 代理流
/// 
/// 提供对 AudioPlayerState 的代理功能，主要处理 duration 字段的过滤
class AudioStateProxyStream {
  final Stream<AudioPlayerState> _sourceStream;
  final DurationProxyService _durationProxy;
  
  AudioStateProxyStream(this._sourceStream, this._durationProxy);
  
  /// 监听代理后的音频状态流
  /// 
  /// 返回的 AudioPlayerState 中的 duration 字段已经过滤处理
  StreamSubscription<AudioPlayerState> listen(
    void Function(AudioPlayerState) onData, {
    Function? onError,
    void Function()? onDone,
    bool? cancelOnError,
  }) {
    return _sourceStream
        .map((audioState) => _proxyAudioState(audioState))
        .listen(
          onData,
          onError: onError,
          onDone: onDone,
          cancelOnError: cancelOnError,
        );
  }
  
  /// 代理 AudioPlayerState，处理 duration 字段和渲染预览区域
  AudioPlayerState _proxyAudioState(AudioPlayerState originalState) {
    // 获取过滤后的 duration
    Duration proxiedDuration = originalState.duration;
    Duration renderPreviewStart = Duration.zero;
    Duration renderPreviewEnd = Duration.zero;
    
    // 如果有当前音频且代理服务已初始化
    if (originalState.currentAudio != null) {
      final audio = originalState.currentAudio!;
      
      // 检查是否有预览配置
      if (audio.previewDuration != null && audio.previewDuration! > Duration.zero) {
        // 预览模式：使用与renderValueToRealPosition相同的计算逻辑
        final realDuration = originalState.duration;
        final previewStart = audio.previewStart ?? Duration.zero;
        final previewDuration = audio.previewDuration!;
        
        // 修复后的计算逻辑：优先保证预览区域在渲染窗口内
        // 1. 计算理想的渲染窗口时长（预览时长的3倍）
        int targetMicroseconds = (previewDuration.inMicroseconds * 3).round();
        Duration idealRenderDuration = Duration(microseconds: targetMicroseconds);
        
        // 2. 计算预览区域的结束位置
        Duration previewEnd = previewStart + previewDuration;
        
        Duration renderStart;
        Duration renderDuration;
        
        // 3. 优先保证预览区域完全在渲染窗口内，并尽量居中
        if (idealRenderDuration >= previewDuration) {
          // 渲染窗口足够大，可以包含预览区域
          
          // 计算预览区域的中心点
          Duration previewCenter = previewStart + Duration(
            microseconds: (previewDuration.inMicroseconds / 2).round()
          );
          
          // 尝试让预览区域在渲染窗口中居中
          Duration idealRenderStart = previewCenter - Duration(
            microseconds: (idealRenderDuration.inMicroseconds / 2).round()
          );
          
          // 调整边界：确保渲染窗口不超出音频范围
          if (idealRenderStart < Duration.zero) {
            idealRenderStart = Duration.zero;
          }
          
          Duration idealRenderEnd = idealRenderStart + idealRenderDuration;
          if (idealRenderEnd > realDuration) {
            idealRenderStart = realDuration - idealRenderDuration;
            if (idealRenderStart < Duration.zero) {
              idealRenderStart = Duration.zero;
              idealRenderDuration = realDuration;
            }
          }
          
          // 验证预览区域是否完全在调整后的渲染窗口内
          Duration finalRenderEnd = idealRenderStart + idealRenderDuration;
          if (previewStart >= idealRenderStart && previewEnd <= finalRenderEnd) {
            renderStart = idealRenderStart;
            renderDuration = idealRenderDuration;
          } else {
            // 如果居中方案不可行，回退到以预览开始位置为准
            renderStart = previewStart;
            renderDuration = Duration(
              microseconds: (realDuration.inMicroseconds - renderStart.inMicroseconds)
                .clamp(
                  math.min(previewDuration.inMicroseconds, idealRenderDuration.inMicroseconds),
                  math.max(previewDuration.inMicroseconds, idealRenderDuration.inMicroseconds)
                )
            );
          }
        } else {
          // 渲染窗口比预览区域还小，直接使用预览区域
          renderStart = previewStart;
          renderDuration = previewDuration;
          
          // 确保不超出音频边界
          if (renderStart + renderDuration > realDuration) {
            if (renderDuration <= realDuration) {
              renderStart = realDuration - renderDuration;
            } else {
              renderStart = Duration.zero;
              renderDuration = realDuration;
            }
          }
        }
        
        // 4. 最终边界检查
        renderStart = Duration(
          microseconds: renderStart.inMicroseconds.clamp(0, realDuration.inMicroseconds)
        );
        renderDuration = Duration(
          microseconds: renderDuration.inMicroseconds
            .clamp(0, realDuration.inMicroseconds - renderStart.inMicroseconds)
        );
        
        // 5. 计算预览区域在渲染窗口中的相对位置
        renderPreviewStart = previewStart - renderStart;
        renderPreviewEnd = renderPreviewStart + previewDuration;
        
        // 6. 确保预览区域在渲染窗口范围内
        renderPreviewStart = Duration(microseconds: renderPreviewStart.inMicroseconds.clamp(0, renderDuration.inMicroseconds));
        renderPreviewEnd = Duration(microseconds: renderPreviewEnd.inMicroseconds.clamp(0, renderDuration.inMicroseconds));
        
        // 使用渲染窗口的时长作为代理后的duration
        proxiedDuration = renderDuration;
      } else {
        // 非预览模式，预览区域覆盖整个渲染窗口
        renderPreviewStart = Duration.zero;
        renderPreviewEnd = proxiedDuration;
      }
    }
    
    // 转换真实位置为渲染位置
    Duration proxiedPosition = originalState.position;
    Duration proxiedBufferedPosition = originalState.bufferedPosition;
    if (originalState.currentAudio != null) {
      final audio = originalState.currentAudio!;
      // 检查是否为预览模式（有预览配置）
      if (audio.previewDuration != null && audio.previewDuration! > Duration.zero) {
        // 预览模式下需要转换位置
        final realDuration = originalState.duration;
        final previewStart = audio.previewStart ?? Duration.zero;
        final previewDuration = audio.previewDuration!;
        
        // 使用与上面相同的渲染窗口计算逻辑
        int targetMicroseconds = (previewDuration.inMicroseconds * 3).round();
        Duration idealRenderDuration = Duration(microseconds: targetMicroseconds);
        Duration previewEnd = previewStart + previewDuration;
        
        Duration renderStart;
        Duration renderDuration;
        
        if (idealRenderDuration >= previewDuration) {
          Duration previewCenter = previewStart + Duration(
            microseconds: (previewDuration.inMicroseconds / 2).round()
          );
          Duration idealRenderStart = previewCenter - Duration(
            microseconds: (idealRenderDuration.inMicroseconds / 2).round()
          );
          
          if (idealRenderStart < Duration.zero) {
            idealRenderStart = Duration.zero;
          }
          
          Duration idealRenderEnd = idealRenderStart + idealRenderDuration;
          if (idealRenderEnd > realDuration) {
            idealRenderStart = realDuration - idealRenderDuration;
            if (idealRenderStart < Duration.zero) {
              idealRenderStart = Duration.zero;
              idealRenderDuration = realDuration;
            }
          }
          
          Duration finalRenderEnd = idealRenderStart + idealRenderDuration;
          if (previewStart >= idealRenderStart && previewEnd <= finalRenderEnd) {
            renderStart = idealRenderStart;
            renderDuration = idealRenderDuration;
          } else {
            renderStart = previewStart;
            renderDuration = Duration(
              microseconds: (realDuration.inMicroseconds - renderStart.inMicroseconds)
                .clamp(
                  math.min(previewDuration.inMicroseconds, idealRenderDuration.inMicroseconds),
                  math.max(previewDuration.inMicroseconds, idealRenderDuration.inMicroseconds)
                )
            );
          }
        } else {
          renderStart = previewStart;
          renderDuration = previewDuration;
          
          if (renderStart + renderDuration > realDuration) {
            if (renderDuration <= realDuration) {
              renderStart = realDuration - renderDuration;
            } else {
              renderStart = Duration.zero;
              renderDuration = realDuration;
            }
          }
        }
        
        renderStart = Duration(
          microseconds: renderStart.inMicroseconds.clamp(0, realDuration.inMicroseconds)
        );
        renderDuration = Duration(
          microseconds: renderDuration.inMicroseconds
            .clamp(0, realDuration.inMicroseconds - renderStart.inMicroseconds)
        );
        
        // 将真实位置转换为渲染位置
        Duration realPosition = originalState.position;
        if (realPosition < renderStart) {
          proxiedPosition = Duration.zero;
        } else if (realPosition >= renderStart + renderDuration) {
          proxiedPosition = renderDuration;
        } else {
          proxiedPosition = realPosition - renderStart;
        }
        
        // 将真实缓冲位置转换为渲染缓冲位置（使用相同的转换逻辑）
        Duration realBufferedPosition = originalState.bufferedPosition;
        if (realBufferedPosition < renderStart) {
          proxiedBufferedPosition = Duration.zero;
        } else if (realBufferedPosition >= renderStart + renderDuration) {
          proxiedBufferedPosition = renderDuration;
        } else {
          proxiedBufferedPosition = realBufferedPosition - renderStart;
        }
      }
    }
    
    // 返回代理后的状态
    return originalState.copyWith(
      duration: proxiedDuration,
      position: proxiedPosition,
      bufferedPosition: proxiedBufferedPosition,
      renderPreviewStart: renderPreviewStart,
      renderPreviewEnd: renderPreviewEnd,
    );
  }
  
  /// 将渲染值转换为真实值（用于拖拽时的位置转换）
  /// [renderValue] 渲染值（0.0-1.0）
  /// [currentAudioState] 当前音频状态
  /// [realDuration] 真实的音频总时长
  /// 返回真实的播放位置
  Duration renderValueToRealPosition(double renderValue, AudioPlayerState currentAudioState, Duration realDuration) {
    if (currentAudioState.currentAudio == null) {
      return Duration.zero;
    }
    
    final audio = currentAudioState.currentAudio!;
    
    // 检查是否有预览配置
    if (audio.previewDuration != null && audio.previewDuration! > Duration.zero) {
      // 预览模式：需要转换渲染值到真实位置
      final previewStart = audio.previewStart ?? Duration.zero;
      final previewDuration = audio.previewDuration!;
      
      // 修复后的计算逻辑：优先保证预览区域在渲染窗口内
      // 1. 计算理想的渲染窗口时长（预览时长的3倍）
      int targetMicroseconds = (previewDuration.inMicroseconds * 3).round();
      Duration idealRenderDuration = Duration(microseconds: targetMicroseconds);
      
      // 2. 计算预览区域的结束位置
      Duration previewEnd = previewStart + previewDuration;
      
      Duration renderStart;
      Duration renderDuration;
      
      // 3. 优先保证预览区域完全在渲染窗口内，并尽量居中
       if (idealRenderDuration >= previewDuration) {
         // 渲染窗口足够大，可以包含预览区域
         
         // 计算预览区域的中心点
         Duration previewCenter = previewStart + Duration(
           microseconds: (previewDuration.inMicroseconds / 2).round()
         );
         
         // 尝试让预览区域在渲染窗口中居中
         Duration idealRenderStart = previewCenter - Duration(
           microseconds: (idealRenderDuration.inMicroseconds / 2).round()
         );
         
         // 调整边界：确保渲染窗口不超出音频范围
         if (idealRenderStart < Duration.zero) {
           idealRenderStart = Duration.zero;
         }
         
         Duration idealRenderEnd = idealRenderStart + idealRenderDuration;
         if (idealRenderEnd > realDuration) {
           idealRenderStart = realDuration - idealRenderDuration;
           if (idealRenderStart < Duration.zero) {
             idealRenderStart = Duration.zero;
             idealRenderDuration = realDuration;
           }
         }
         
         // 验证预览区域是否完全在调整后的渲染窗口内
         Duration finalRenderEnd = idealRenderStart + idealRenderDuration;
         if (previewStart >= idealRenderStart && previewEnd <= finalRenderEnd) {
           renderStart = idealRenderStart;
           renderDuration = idealRenderDuration;
         } else {
           // 如果居中方案不可行，回退到以预览开始位置为准
           renderStart = previewStart;
           renderDuration = Duration(
             microseconds: (realDuration.inMicroseconds - renderStart.inMicroseconds)
               .clamp(
                 math.min(previewDuration.inMicroseconds, idealRenderDuration.inMicroseconds),
                 math.max(previewDuration.inMicroseconds, idealRenderDuration.inMicroseconds)
               )
           );
         }
       } else {
         // 渲染窗口比预览区域还小，直接使用预览区域
         renderStart = previewStart;
         renderDuration = previewDuration;
         
         // 确保不超出音频边界
         if (renderStart + renderDuration > realDuration) {
           if (renderDuration <= realDuration) {
             renderStart = realDuration - renderDuration;
           } else {
             renderStart = Duration.zero;
             renderDuration = realDuration;
           }
         }
       }
      
      // 4. 最终边界检查
      renderStart = Duration(
        microseconds: renderStart.inMicroseconds.clamp(0, realDuration.inMicroseconds)
      );
      renderDuration = Duration(
        microseconds: renderDuration.inMicroseconds
          .clamp(0, realDuration.inMicroseconds - renderStart.inMicroseconds)
      );
      
      // 4. 将渲染值转换为渲染窗口内的位置
      Duration renderPosition = Duration(
        microseconds: (renderValue * renderDuration.inMicroseconds).round()
      );
      
      // 5. 确保渲染位置在渲染窗口范围内
      Duration clampedRenderPosition = Duration(
        microseconds: renderPosition.inMicroseconds.clamp(0, renderDuration.inMicroseconds)
      );
      
      // 6. 转换为真实位置
      return renderStart + clampedRenderPosition;
    } else {
       // 非预览模式，直接使用渲染值计算真实位置
       return Duration(
         microseconds: (renderValue * realDuration.inMicroseconds).round()
       );
     }
  }
  
  /// 转换为 Stream<AudioPlayerState>
  Stream<AudioPlayerState> asStream() {
    return _sourceStream.map((audioState) => _proxyAudioState(audioState));
  }
  
  /// 支持其他 Stream 操作
  AudioStateProxyStream where(bool Function(AudioPlayerState) test) {
    return AudioStateProxyStream(
      _sourceStream.where(test),
      _durationProxy,
    );
  }
  
  AudioStateProxyStream skip(int count) {
    return AudioStateProxyStream(
      _sourceStream.skip(count),
      _durationProxy,
    );
  }
  
  AudioStateProxyStream take(int count) {
    return AudioStateProxyStream(
      _sourceStream.take(count),
      _durationProxy,
    );
  }
  
  AudioStateProxyStream distinct([bool Function(AudioPlayerState, AudioPlayerState)? equals]) {
    return AudioStateProxyStream(
      _sourceStream.distinct(equals),
      _durationProxy,
    );
  }
}

/// 简化的代理工厂类
/// 
/// 提供便捷的方法来创建和使用音频状态代理
class AudioStateProxy {
  /// 创建一个简单的 duration 过滤代理
  /// 
  /// 使用方式：
  /// ```dart
  /// final proxy = AudioStateProxy.createDurationFilter();
  /// _audioManager.audioStateStream
  ///   .proxy(proxy)
  ///   .listen((state) {
  ///     // state.duration 已过滤
  ///   });
  /// ```
  static DurationProxyService createDurationFilter() {
    return DurationProxyService.createStreamListener();
  }
  
  /// 为指定的音频状态流添加代理功能
  /// 
  /// 使用方式：
  /// ```dart
  /// AudioStateProxy.proxyStream(
  ///   _audioManager.audioStateStream,
  ///   onData: (proxiedState) {
  ///     // 处理代理后的状态
  ///   },
  /// );
  /// ```
  static StreamSubscription<AudioPlayerState> proxyStream(
    Stream<AudioPlayerState> stream, {
    required void Function(AudioPlayerState) onData,
    Function? onError,
    void Function()? onDone,
    bool? cancelOnError,
  }) {
    final proxy = createDurationFilter();
    return stream
        .proxy(proxy)
        .listen(
          onData,
          onError: onError,
          onDone: onDone,
          cancelOnError: cancelOnError,
        );
  }
}