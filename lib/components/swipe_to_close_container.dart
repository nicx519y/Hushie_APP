import 'package:flutter/material.dart';

/// 下滑关闭容器组件
/// 
/// 这个组件提供了下滑手势来关闭页面的功能，可以包裹任何子组件
/// 
/// 使用示例:
/// ```dart
/// SwipeToCloseContainer(
///   onClose: () => Navigator.pop(context),
///   child: YourPageContent(),
/// )
/// ```
class SwipeToCloseContainer extends StatefulWidget {
  /// 子组件
  final Widget child;
  
  /// 关闭回调函数
  final VoidCallback onClose;
  
  /// 拖拽阈值，超过此值将触发关闭 (默认: 100.0)
  final double dragThreshold;
  
  /// 是否启用拖拽指示器 (默认: true)
  final bool showDragIndicator;
  
  /// 背景颜色 (默认: Colors.transparent)
  final Color backgroundColor;
  
  /// 动画持续时间 (默认: 300ms)
  final Duration animationDuration;

  const SwipeToCloseContainer({
    Key? key,
    required this.child,
    required this.onClose,
    this.dragThreshold = 100.0,
    this.showDragIndicator = true,
    this.backgroundColor = Colors.transparent,
    this.animationDuration = const Duration(milliseconds: 300),
  }) : super(key: key);

  @override
  State<SwipeToCloseContainer> createState() => _SwipeToCloseContainerState();
}

class _SwipeToCloseContainerState extends State<SwipeToCloseContainer> {
  // 手势下滑关闭相关状态
  double _dragOffset = 0.0; // 当前拖拽偏移量
  bool _isDragging = false; // 是否正在拖拽

  /// 手势开始处理
  void _onPanStart(DragStartDetails details) {
    setState(() {
      _isDragging = true;
      _dragOffset = 0.0;
    });
  }

  /// 手势更新处理
  void _onPanUpdate(DragUpdateDetails details) {
    setState(() {
      _dragOffset += details.delta.dy;
      // 限制拖拽范围：不能向上超过原始位置(0)，向下没有限制
      _dragOffset = _dragOffset.clamp(0.0, double.infinity);
    });
  }

  /// 手势结束处理
  void _onPanEnd(DragEndDetails details) {
    setState(() {
      _isDragging = false;
    });
    
    if (_dragOffset > widget.dragThreshold) {
      // 超过阈值，关闭页面
      widget.onClose();
      // 关键：延迟重置拖拽偏移，保证下次打开从顶部开始
      Future.delayed(widget.animationDuration, () {
        if (!mounted) return;
        setState(() {
          _dragOffset = 0.0;
        });
      });
    } else {
      // 未超过阈值，平滑回弹到原位置
      _animateToPosition(0.0);
    }
  }

  /// 动画到指定位置
  void _animateToPosition(double targetOffset) {
    final startOffset = _dragOffset;
    final distance = targetOffset - startOffset;
    final startTime = DateTime.now().millisecondsSinceEpoch;
    
    void animate() {
      final currentTime = DateTime.now().millisecondsSinceEpoch;
      final elapsed = currentTime - startTime;
      final progress = (elapsed / widget.animationDuration.inMilliseconds).clamp(0.0, 1.0);
      
      // 使用三次贝塞尔曲线 (ease-out)
      final easedProgress = 1.0 - (1.0 - progress) * (1.0 - progress) * (1.0 - progress);
      
      setState(() {
        _dragOffset = startOffset + (distance * easedProgress);
      });
      
      if (progress < 1.0) {
        WidgetsBinding.instance.addPostFrameCallback((_) => animate());
      }
    }
    
    animate();
  }

  /// 构建拖拽指示器
  Widget _buildDragIndicator() {
    if (!widget.showDragIndicator || !_isDragging) {
      return const SizedBox.shrink();
    }

    final progress = (_dragOffset / widget.dragThreshold).clamp(0.0, 1.0);
    final isNearThreshold = progress >= 0.8;

    return Positioned(
      top: 50,
      left: 0,
      right: 0,
      child: Center(
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          decoration: BoxDecoration(
            color: Colors.black.withOpacity(0.7),
            borderRadius: BorderRadius.circular(20),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // 进度条
              Container(
                width: 100,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.3),
                  borderRadius: BorderRadius.circular(2),
                ),
                child: FractionallySizedBox(
                  alignment: Alignment.centerLeft,
                  widthFactor: progress,
                  child: Container(
                    decoration: BoxDecoration(
                      color: isNearThreshold ? Colors.green : Colors.white,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 8),
              // 提示文字
              Text(
                isNearThreshold ? 'Release to Close' : 'Swipe Down to Close',
                style: TextStyle(
                  color: isNearThreshold ? Colors.green : Colors.white,
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: widget.backgroundColor,
      body: GestureDetector(
        onPanStart: _onPanStart,
        onPanUpdate: _onPanUpdate,
        onPanEnd: _onPanEnd,
        child: Stack(
          children: [
            // 主要内容，应用拖拽偏移
            Transform.translate(
              offset: Offset(0, _dragOffset),
              child: widget.child,
            ),
            // 拖拽指示器
            _buildDragIndicator(),
          ],
        ),
      ),
    );
  }
}