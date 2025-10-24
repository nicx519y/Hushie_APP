import 'dart:math' as math;
import 'package:flutter/material.dart';

/// 宽图展示组件
/// - 传入一个图片资源（任意 ImageProvider）
/// - 组件会根据容器高度等比例缩放图片（显示高度=容器高度，宽度按比例）
/// - 当图片显示宽度大于容器宽度时，图片会缓慢横向往往滑动，边缘重合时反向
class WideImageShowcase extends StatefulWidget {
  const WideImageShowcase({
    super.key,
    required this.image,
    this.scrollSpeed = 20.0, // 每秒移动像素，越大越快
    this.backgroundColor,
    this.placeholder,
  });

  /// 图片资源（支持 AssetImage、NetworkImage、FileImage 等）
  final ImageProvider image;

  /// 横向滑动速度（像素/秒）
  final double scrollSpeed;

  /// 背景色（未加载或裁剪区域）
  final Color? backgroundColor;

  /// 加载中的占位组件
  final Widget? placeholder;

  @override
  State<WideImageShowcase> createState() => _WideImageShowcaseState();
}

class _WideImageShowcaseState extends State<WideImageShowcase>
    with SingleTickerProviderStateMixin {
  ImageStream? _imageStream;
  ImageInfo? _imageInfo;
  ImageStreamListener? _imageStreamListener;

  late AnimationController _controller;
  Animation<double>? _offsetAnimation;

  double _lastOverflow = 0;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 1),
    );
    // 注意：不要在 initState 使用 createLocalImageConfiguration(context)
    // 因为它依赖于 MediaQuery，会在此处抛出异常。改为在 didChangeDependencies 解析图片。
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _resolveImage();
  }

  @override
  void didUpdateWidget(covariant WideImageShowcase oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.image != widget.image) {
      _resolveImage();
    }
    if (oldWidget.scrollSpeed != widget.scrollSpeed && _lastOverflow > 0) {
      _setupAnimation(_lastOverflow);
    }
  }

  void _resolveImage() {
    final stream = widget.image.resolve(createLocalImageConfiguration(context));
    if (_imageStream != null && _imageStreamListener != null) {
      _imageStream!.removeListener(_imageStreamListener!);
    }
    _imageStream = stream;
    _imageStreamListener = ImageStreamListener(_onImageLoaded);
    _imageStream!.addListener(_imageStreamListener!);
  }

  void _onImageLoaded(ImageInfo imageInfo, bool synchronousCall) {
    setState(() {
      _imageInfo = imageInfo;
    });
  }

  void _setupAnimation(double overflow) {
    _lastOverflow = overflow;

    if (overflow <= 0) {
      _offsetAnimation = null;
      _controller.stop();
      return;
    }

    // 根据溢出距离设置时长：时长 = 距离 / 速度
    final seconds = (overflow / widget.scrollSpeed).clamp(1.0, 60.0);
    _controller.duration = Duration(milliseconds: (seconds * 1000).round());
    _offsetAnimation = Tween<double>(begin: 0.0, end: -overflow).animate(
      CurvedAnimation(parent: _controller, curve: Curves.linear),
    );

    // 开始往返滑动
    _controller.repeat(reverse: true);
  }

  @override
  void dispose() {
    if (_imageStream != null && _imageStreamListener != null) {
      _imageStream!.removeListener(_imageStreamListener!);
    }
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final containerWidth = constraints.maxWidth.isFinite
            ? constraints.maxWidth
            : MediaQuery.of(context).size.width;
        final containerHeight = constraints.maxHeight.isFinite
            ? constraints.maxHeight
            : MediaQuery.of(context).size.height;

        // 需要明确的高度约束，若没有高度则不显示
        if (containerHeight <= 0) {
          return const SizedBox.shrink();
        }

        final imageInfo = _imageInfo;
        if (imageInfo == null) {
          return ClipRect(
            child: Container(
              color: widget.backgroundColor,
              height: containerHeight,
              width: containerWidth,
              child: Center(
                child:
                    widget.placeholder ?? const CircularProgressIndicator(),
              ),
            ),
          );
        }

        final imgW = imageInfo.image.width.toDouble();
        final imgH = imageInfo.image.height.toDouble();
        final aspect = imgW / imgH;
        final displayedWidth = containerHeight * aspect;
        final overflow = math.max(displayedWidth - containerWidth, 0.0);

        // 更新动画（若溢出变化）
        if (_offsetAnimation == null || (overflow - _lastOverflow).abs() > 0.5) {
          _setupAnimation(overflow);
        }

        return SizedBox(
          height: containerHeight,
          width: containerWidth,
          child: ClipRect(
            child: Container(
              color: widget.backgroundColor,
              child: AnimatedBuilder(
                animation: _controller,
                builder: (context, child) {
                  final dx = _offsetAnimation?.value ?? 0.0;
                  return Transform.translate(
                    offset: Offset(dx, 0.0),
                    child: OverflowBox(
                      alignment: Alignment.topLeft,
                      minWidth: displayedWidth,
                      maxWidth: displayedWidth,
                      minHeight: containerHeight,
                      maxHeight: containerHeight,
                      child: SizedBox(
                        height: containerHeight,
                        width: displayedWidth,
                        child: Image(
                          image: widget.image,
                          fit: BoxFit.fitHeight, // 高度贴合容器，高度等比例缩放
                          filterQuality: FilterQuality.medium,
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
          ),
        );
      },
    );
  }
}