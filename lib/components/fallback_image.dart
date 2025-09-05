import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';

/// 带备用图片的图片组件
/// 支持网络图片和本地资源，当图片加载失败时自动显示备用图片
class FallbackImage extends StatelessWidget {
  /// 图片URL或路径
  final String? imageUrl;
  
  /// 备用图片路径（默认为 assets/images/backup.png）
  final String fallbackImage;
  
  /// 图片适配方式
  final BoxFit fit;
  
  /// 图片宽度
  final double? width;
  
  /// 图片高度
  final double? height;
  
  /// 圆角半径
  final double borderRadius;
  
  /// 占位符颜色
  final Color? placeholderColor;
  
  /// 淡入动画持续时间
  final Duration fadeInDuration;
  
  /// 是否显示加载指示器
  final bool showLoadingIndicator;
  
  /// 加载指示器大小
  final double loadingIndicatorSize;

  const FallbackImage({
    super.key,
    this.imageUrl,
    this.fallbackImage = 'assets/images/backup.png',
    this.fit = BoxFit.cover,
    this.width,
    this.height,
    this.borderRadius = 0,
    this.placeholderColor,
    this.fadeInDuration = const Duration(milliseconds: 300),
    this.showLoadingIndicator = true,
    this.loadingIndicatorSize = 20,
  });

  @override
  Widget build(BuildContext context) {
    Widget imageWidget = _buildImageWidget();
    
    // 如果有圆角，添加圆角裁剪
    if (borderRadius > 0) {
      imageWidget = ClipRRect(
        borderRadius: BorderRadius.circular(borderRadius),
        child: imageWidget,
      );
    }
    
    // 如果有指定尺寸，包装在Container中
    if (width != null || height != null) {
      imageWidget = SizedBox(
        width: width,
        height: height,
        child: imageWidget,
      );
    }
    
    return imageWidget;
  }

  Widget _buildImageWidget() {
    // 如果URL为空或空字符串，直接使用备用图片
    if (imageUrl == null || imageUrl!.isEmpty) {
      return _buildFallbackImage();
    }

    // 如果是网络图片，使用CachedNetworkImage处理错误
    if (imageUrl!.startsWith('http')) {
      return CachedNetworkImage(
        imageUrl: imageUrl!,
        fit: fit,
        fadeInDuration: fadeInDuration,
        placeholder: (context, url) => _buildPlaceholder(),
        errorWidget: (context, url, error) {
          print('🖼️ 网络图片加载失败: ，使用备用图片');
          return _buildFallbackImage();
        },
      );
    }

    // 如果是本地资源，使用Image.asset处理错误
    return Image.asset(
      imageUrl!,
      fit: fit,
      errorBuilder: (context, error, stackTrace) {
        print('🖼️ 本地图片加载失败: ，使用备用图片');
        return _buildFallbackImage();
      },
    );
  }

  /// 构建备用图片
  Widget _buildFallbackImage() {
    return Image.asset(
      fallbackImage,
      fit: fit,
      errorBuilder: (context, error, stackTrace) {
        print('🖼️ 备用图片也加载失败: ');
        return _buildErrorWidget();
      },
    );
  }

  /// 构建占位符
  Widget _buildPlaceholder() {
    return Container(
      color: placeholderColor ?? Colors.grey[300],
      child: showLoadingIndicator
          ? Center(
              child: SizedBox(
                width: loadingIndicatorSize,
                height: loadingIndicatorSize,
                child: const CircularProgressIndicator(strokeWidth: 2),
              ),
            )
          : null,
    );
  }

  /// 构建错误组件
  Widget _buildErrorWidget() {
    return Container(
      color: placeholderColor ?? Colors.grey[300],
      child: const Center(
        child: Icon(
          Icons.error_outline,
          color: Colors.grey,
          size: 24,
        ),
      ),
    );
  }
}
