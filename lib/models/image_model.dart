import 'package:flutter/widgets.dart';

class ImageModel {
  final String id;
  final ImageResolutions urls; // 多分辨率URL集合

  const ImageModel({required this.id, required this.urls});

  /// 根据逻辑像素宽度获取最合适的图片尺寸信息
  ImageResolution getBestResolution(double logicalWidth) {
    // 获取设备像素密度
    final devicePixelRatio =
        WidgetsBinding.instance.platformDispatcher.views.first.devicePixelRatio;

    // 计算实际需要的物理像素宽度
    double physicalWidth = logicalWidth * devicePixelRatio;

    // 选择与物理宽度差值绝对值最小的版本
    double minDifference = double.infinity;
    ImageResolution bestResolution = urls.x1;

    // 检查x1版本
    double difference = (physicalWidth - urls.x1.width).abs();
    if (difference < minDifference) {
      minDifference = difference;
      bestResolution = urls.x1;
    }

    // 检查x2版本
    if (urls.x2 != null) {
      difference = (physicalWidth - urls.x2!.width).abs();
      if (difference < minDifference) {
        minDifference = difference;
        bestResolution = urls.x2!;
      }
    }

    // 检查x3版本
    if (urls.x3 != null) {
      difference = (physicalWidth - urls.x3!.width).abs();
      if (difference < minDifference) {
        minDifference = difference;
        bestResolution = urls.x3!;
      }
    }

    return bestResolution;
  }

  /// 转换为JSON
  Map<String, dynamic> toJson() {
    return {'id': id, 'urls': urls.toJson()};
  }

  /// 从JSON创建实例
  factory ImageModel.fromJson(Map<String, dynamic> json) {
    return ImageModel(
      id: json['id'] ?? '',
      urls: ImageResolutions.fromJson(json['urls'] ?? {}),
    );
  }

  /// 复制实例并修改指定字段
  ImageModel copyWith({String? id, ImageResolutions? urls}) {
    return ImageModel(id: id ?? this.id, urls: urls ?? this.urls);
  }
}

/// 多分辨率URL集合
class ImageResolutions {
  final ImageResolution x1; // 1x分辨率 (必须)
  final ImageResolution? x2; // 2x分辨率 (可选)
  final ImageResolution? x3; // 3x分辨率 (可选)

  const ImageResolutions({required this.x1, this.x2, this.x3});

  /// 转换为JSON
  Map<String, dynamic> toJson() {
    return {'x1': x1.toJson(), 'x2': x2?.toJson(), 'x3': x3?.toJson()};
  }

  /// 从JSON创建实例
  factory ImageResolutions.fromJson(Map<String, dynamic> json) {
    return ImageResolutions(
      x1: ImageResolution.fromJson(json['x1'] ?? {}),
      x2: json['x2'] != null ? ImageResolution.fromJson(json['x2']) : null,
      x3: json['x3'] != null ? ImageResolution.fromJson(json['x3']) : null,
    );
  }

  /// 复制实例并修改指定字段
  ImageResolutions copyWith({
    ImageResolution? x1,
    ImageResolution? x2,
    ImageResolution? x3,
  }) {
    return ImageResolutions(
      x1: x1 ?? this.x1,
      x2: x2 ?? this.x2,
      x3: x3 ?? this.x3,
    );
  }
}

/// 单个分辨率的图片信息
class ImageResolution {
  final String url; // 图片URL
  final int width; // 图片宽度
  final int height; // 图片高度

  const ImageResolution({
    required this.url,
    required this.width,
    required this.height,
  });

  /// 转换为JSON
  Map<String, dynamic> toJson() {
    return {'url': url, 'width': width, 'height': height};
  }

  /// 从JSON创建实例
  factory ImageResolution.fromJson(Map<String, dynamic> json) {
    return ImageResolution(
      url: json['url'] ?? '',
      width: json['width'] ?? 0,
      height: json['height'] ?? 0,
    );
  }

  /// 复制实例并修改指定字段
  ImageResolution copyWith({String? url, int? width, int? height}) {
    return ImageResolution(
      url: url ?? this.url,
      width: width ?? this.width,
      height: height ?? this.height,
    );
  }
}
