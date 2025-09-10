import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:hushie_app/models/image_model.dart';

/// 带备用图片的图片组件
/// 支持网络图片和本地资源，当图片加载失败时自动显示备用图片
class FallbackImage extends StatelessWidget {
  /// 音频对象
  final ImageModel? imageResource;
  final String? fallbackImage;
  final BoxFit? fit;
  
  /// 图片宽度
  final double width;
  
  /// 图片高度
  final double height;
  
  /// 圆角半径
  final double borderRadius;

  const FallbackImage({
    super.key,
    this.imageResource,
    this.fallbackImage,
    this.fit = BoxFit.cover,
    this.width = 70,
    this.height = 78,
    this.borderRadius = 0,
  });

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(borderRadius),
      child: SizedBox(
        width: width,
        height: height,
        child: Builder(
          builder: (context) {
            String? imageUrl;
            try {
              imageUrl = imageResource?.getBestResolution(width).url;
            } catch (e) {
              debugPrint('获取封面图片失败: $e');
              imageUrl = null;
            }
            return CachedNetworkImage(
              imageUrl: imageUrl ?? '',
              fit: fit,
              errorWidget: (context, url, error) => fallbackImage == null 
              ? Container(
                color: Colors.grey[200],
              ) 
              : Image.asset(fallbackImage!, fit: fit),
            );
          },
        ),
      ),
    );
  }
}
