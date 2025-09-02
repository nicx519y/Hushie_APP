import 'package:flutter/widgets.dart';

class ImageModel {
  final String id;
  final ImageResolutions urls; // 多分辨率URL集合

  const ImageModel({required this.id, required this.urls});

  /// 根据逻辑像素宽度获取最合适的图片尺寸信息
  ImageResolution getBestResolution(double logicalWidth) {
    // 安全检查
    if (urls.x1.url.isEmpty) {
      throw Exception('ImageModel: x1 分辨率的 URL 为空');
    }

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
    // 检查 urls 字段是否存在且有效
    final urlsData = json['urls'];
    ImageResolutions urls;

    if (urlsData != null &&
        urlsData is Map<String, dynamic> &&
        urlsData.isNotEmpty) {
      urls = ImageResolutions.fromJson(urlsData);
    } else {
      // 如果 urls 数据无效，创建一个默认的 ImageResolutions
      urls = ImageResolutions(
        x1: ImageResolution(
          url: 'assets/images/logo.png', // 使用现有的 logo 图片作为默认封面
          width: 400,
          height: 600,
        ),
      );
    }

    return ImageModel(id: json['id'] ?? '', urls: urls);
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
    // 检查 x1 字段是否存在且有效
    final x1Data = json['x1'];
    ImageResolution x1;

    if (x1Data != null && x1Data is Map<String, dynamic> && x1Data.isNotEmpty) {
      x1 = ImageResolution.fromJson(x1Data);
    } else {
      // 如果 x1 数据无效，创建一个默认的 ImageResolution
      x1 = ImageResolution(
        url: 'assets/images/logo.png',
        width: 400,
        height: 600,
      );
    }

    return ImageResolutions(
      x1: x1,
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
    final url = json['url'] ?? '';

    // 验证 URL 格式
    if (url.isNotEmpty) {
      try {
        // 尝试解析 URL，如果失败则抛出异常
        Uri.parse(url);
      } catch (e) {
        print('警告: 无效的图片URL格式: $url');
        // 不抛出异常，而是使用空字符串，让调用者处理
      }
    }

    return ImageResolution(
      url: url.isNotEmpty ? url : 'assets/images/logo.png',
      width: json['width'] ?? 400,
      height: json['height'] ?? 600,
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
