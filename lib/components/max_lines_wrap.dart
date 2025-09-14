import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';

/// 支持最大行数限制的Wrap组件
class MaxLinesWrap extends StatelessWidget {
  final List<Widget> children;
  final double spacing;
  final double runSpacing;
  final int maxLines;
  final WrapAlignment alignment;
  final WrapCrossAlignment crossAxisAlignment;
  final WrapAlignment runAlignment;
  final TextDirection? textDirection;
  final VerticalDirection verticalDirection;
  final Clip clipBehavior;

  const MaxLinesWrap({
    Key? key,
    required this.children,
    this.spacing = 0.0,
    this.runSpacing = 0.0,
    this.maxLines = 2,
    this.alignment = WrapAlignment.start,
    this.crossAxisAlignment = WrapCrossAlignment.start,
    this.runAlignment = WrapAlignment.start,
    this.textDirection,
    this.verticalDirection = VerticalDirection.down,
    this.clipBehavior = Clip.none,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        return _MaxLinesWrapRenderWidget(
          children: children,
          spacing: spacing,
          runSpacing: runSpacing,
          maxLines: maxLines,
          alignment: alignment,
          crossAxisAlignment: crossAxisAlignment,
          runAlignment: runAlignment,
          textDirection: textDirection,
          verticalDirection: verticalDirection,
          clipBehavior: clipBehavior,
          constraints: constraints,
        );
      },
    );
  }
}

class _MaxLinesWrapRenderWidget extends MultiChildRenderObjectWidget {
  final double spacing;
  final double runSpacing;
  final int maxLines;
  final WrapAlignment alignment;
  final WrapCrossAlignment crossAxisAlignment;
  final WrapAlignment runAlignment;
  final TextDirection? textDirection;
  final VerticalDirection verticalDirection;
  final Clip clipBehavior;
  final BoxConstraints constraints;

  const _MaxLinesWrapRenderWidget({
    required List<Widget> children,
    required this.spacing,
    required this.runSpacing,
    required this.maxLines,
    required this.alignment,
    required this.crossAxisAlignment,
    required this.runAlignment,
    required this.textDirection,
    required this.verticalDirection,
    required this.clipBehavior,
    required this.constraints,
  }) : super(children: children);

  @override
  RenderObject createRenderObject(BuildContext context) {
    return _RenderMaxLinesWrap(
      spacing: spacing,
      runSpacing: runSpacing,
      maxLines: maxLines,
      alignment: alignment,
      crossAxisAlignment: crossAxisAlignment,
      runAlignment: runAlignment,
      textDirection: textDirection ?? Directionality.of(context),
      verticalDirection: verticalDirection,
      clipBehavior: clipBehavior,
    );
  }

  @override
  void updateRenderObject(BuildContext context, _RenderMaxLinesWrap renderObject) {
    renderObject
      ..spacing = spacing
      ..runSpacing = runSpacing
      ..maxLines = maxLines
      ..alignment = alignment
      ..crossAxisAlignment = crossAxisAlignment
      ..runAlignment = runAlignment
      ..textDirection = textDirection ?? Directionality.of(context)
      ..verticalDirection = verticalDirection
      ..clipBehavior = clipBehavior;
  }
}

class _RenderMaxLinesWrap extends RenderWrap {
  int _maxLines;

  _RenderMaxLinesWrap({
    required double spacing,
    required double runSpacing,
    required int maxLines,
    required WrapAlignment alignment,
    required WrapCrossAlignment crossAxisAlignment,
    required WrapAlignment runAlignment,
    required TextDirection textDirection,
    required VerticalDirection verticalDirection,
    required Clip clipBehavior,
  }) : _maxLines = maxLines,
       super(
         spacing: spacing,
         runSpacing: runSpacing,
         alignment: alignment,
         crossAxisAlignment: crossAxisAlignment,
         runAlignment: runAlignment,
         textDirection: textDirection,
         verticalDirection: verticalDirection,
         clipBehavior: clipBehavior,
       );

  int get maxLines => _maxLines;
  set maxLines(int value) {
    if (_maxLines != value) {
      _maxLines = value;
      markNeedsLayout();
    }
  }

  @override
  void performLayout() {
    // 先执行正常的Wrap布局
    super.performLayout();
    
    // 计算实际行数
    if (firstChild == null) return;
    
    final runs = <List<RenderBox>>[];
    var currentRun = <RenderBox>[];
    var currentRunWidth = 0.0;
    
    RenderBox? child = firstChild;
    while (child != null) {
      final childParentData = child.parentData as WrapParentData;
      final childSize = child.size;
      
      if (currentRun.isEmpty || currentRunWidth + spacing + childSize.width <= constraints.maxWidth) {
        currentRun.add(child);
        currentRunWidth += (currentRun.length > 1 ? spacing : 0) + childSize.width;
      } else {
        runs.add(currentRun);
        currentRun = [child];
        currentRunWidth = childSize.width;
      }
      
      child = childParentData.nextSibling;
    }
    
    if (currentRun.isNotEmpty) {
      runs.add(currentRun);
    }
    
    // 如果行数超过最大行数，重新计算大小
    if (runs.length > maxLines) {
      var totalHeight = 0.0;
      for (int i = 0; i < maxLines; i++) {
        if (i > 0) totalHeight += runSpacing;
        final runHeight = runs[i].map((child) => child.size.height).reduce((a, b) => a > b ? a : b);
        totalHeight += runHeight;
      }
      
      size = Size(constraints.maxWidth, totalHeight);
      
      // 隐藏超出最大行数的子组件
      child = firstChild;
      int currentRunIndex = 0;
      int currentChildInRun = 0;
      
      while (child != null) {
        final childParentData = child.parentData as WrapParentData;
        
        if (currentRunIndex >= maxLines) {
          // 隐藏超出行数的子组件
          childParentData.offset = const Offset(-10000, -10000);
        }
        
        currentChildInRun++;
        if (currentRunIndex < runs.length && currentChildInRun >= runs[currentRunIndex].length) {
          currentRunIndex++;
          currentChildInRun = 0;
        }
        
        child = childParentData.nextSibling;
      }
    }
  }
}