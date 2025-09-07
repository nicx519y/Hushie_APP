class AudioDurationInfo {
  final Duration totalDuration;
  final Duration? previewStart;
  final Duration? previewDuration;

  const AudioDurationInfo({
    required this.totalDuration,
    this.previewStart,
    this.previewDuration,
  });

  /// 创建带边界验证的AudioDurationInfo
  factory AudioDurationInfo.withValidation({
    required Duration totalDuration,
    Duration? previewStart,
    Duration? previewDuration,
  }) {
    // 验证previewStart边界
    Duration? validatedPreviewStart;
    if (previewStart != null) {
      if (previewStart >= Duration.zero && previewStart <= totalDuration) {
        validatedPreviewStart = previewStart;
      } else {
        validatedPreviewStart = null; // 超出边界则设为null
      }
    }

    // 验证previewDuration边界
    Duration? validatedPreviewDuration;
    if (previewDuration != null && validatedPreviewStart != null) {
      final maxPreviewDuration = totalDuration - validatedPreviewStart;
      if (previewDuration >= Duration.zero && previewDuration <= maxPreviewDuration) {
        validatedPreviewDuration = previewDuration;
      } else if (previewDuration > maxPreviewDuration) {
        validatedPreviewDuration = maxPreviewDuration; // 超出最大值则限制为最大值
      } else {
        validatedPreviewDuration = null; // 小于0则设为null
      }
    } else if (previewDuration != null) {
      // 如果previewStart无效但previewDuration有效，则检查是否小于totalDuration
      if (previewDuration >= Duration.zero && previewDuration <= totalDuration) {
        validatedPreviewDuration = previewDuration;
      } else {
        validatedPreviewDuration = null;
      }
    }

    return AudioDurationInfo(
      totalDuration: totalDuration,
      previewStart: validatedPreviewStart,
      previewDuration: validatedPreviewDuration,
    );
  }

  AudioDurationInfo copyWith({
    Duration? totalDuration,
    Duration? previewStart,
    Duration? previewDuration,
  }) {
    return AudioDurationInfo(
      totalDuration: totalDuration ?? this.totalDuration,
      previewStart: previewStart ?? this.previewStart,
      previewDuration: previewDuration ?? this.previewDuration,
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is AudioDurationInfo &&
        other.totalDuration == totalDuration &&
        other.previewStart == previewStart &&
        other.previewDuration == previewDuration;
  }

  @override
  int get hashCode {
    return totalDuration.hashCode ^
        previewStart.hashCode ^
        previewDuration.hashCode;
  }

  @override
  String toString() {
    return 'AudioDurationInfo(totalDuration: $totalDuration, previewStart: $previewStart, previewDuration: $previewDuration)';
  }
}