import 'package:flutter/material.dart';
import 'dart:math' as math;
import '../models/tab_item.dart';

/// 自定义弹簧滚动物理效果，提供更强的弹性回弹
class EnhancedBouncingScrollPhysics extends BouncingScrollPhysics {
  const EnhancedBouncingScrollPhysics({super.parent});

  @override
  EnhancedBouncingScrollPhysics applyTo(ScrollPhysics? ancestor) {
    return EnhancedBouncingScrollPhysics(parent: buildParent(ancestor));
  }

  @override
  double get minFlingVelocity => 50.0; // 降低最小滑动速度，更容易触发弹簧效果

  @override
  double get maxFlingVelocity => 5000.0; // 提高最大滑动速度

  @override
  double frictionFactor(double overscrollFraction) {
    // 增强过度滚动时的摩擦力，让弹簧效果更明显
    return 0.15 * math.pow(1 - overscrollFraction, 2);
  }

  @override
  double carriedMomentum(double existingVelocity) {
    // 增强惯性传递，让滚动更流畅
    return existingVelocity.sign *
        (existingVelocity.abs() * 0.8).clamp(0.0, maxFlingVelocity);
  }
}

class CustomTabBar extends StatefulWidget {
  final TabController controller;
  final List<TabItemModel> tabItems;
  final Function(int)? onTabChanged;
  final Color? labelColor;
  final Color? unselectedLabelColor;
  final Color? indicatorColor;
  final double? indicatorWeight;
  final EdgeInsets? indicatorPadding;
  final TabBarIndicatorSize? indicatorSize;
  final TextStyle? labelStyle;
  final TextStyle? unselectedLabelStyle;
  final bool isScrollable;
  final Color? dividerColor;
  final Color? backgroundColor; // 背景色，用于渐变遮罩
  final double gradientWidth; // 渐变遮罩宽度
  final ScrollPhysics? scrollPhysics; // 自定义滚动物理效果
  final bool enableSpringEffect; // 是否启用增强弹簧效果

  const CustomTabBar({
    super.key,
    required this.controller,
    required this.tabItems,
    this.onTabChanged,
    this.labelColor,
    this.unselectedLabelColor,
    this.indicatorColor,
    this.indicatorWeight,
    this.indicatorPadding,
    this.indicatorSize,
    this.labelStyle,
    this.unselectedLabelStyle,
    this.isScrollable = true,
    this.dividerColor,
    this.backgroundColor,
    this.gradientWidth = 20.0,
    this.scrollPhysics,
    this.enableSpringEffect = true,
  });

  @override
  State<CustomTabBar> createState() => _CustomTabBarState();
}

class _CustomTabBarState extends State<CustomTabBar> {
  bool _showLeftGradient = false;
  bool _showRightGradient = false;

  @override
  void initState() {
    super.initState();

    // 延迟检查初始状态
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _updateGradientVisibility();
    });
  }

  void _updateGradientVisibility() {
    // 简化逻辑：根据标签数量和是否可滚动来判断
    if (!widget.isScrollable) {
      setState(() {
        _showLeftGradient = false;
        _showRightGradient = false;
      });
      return;
    }

    setState(() {
      // 如果标签数量较多，可能需要滚动，则显示渐变
      _showLeftGradient = false; // 初始时不显示左侧渐变
      _showRightGradient = widget.tabItems.length > 3; // 标签多于3个时显示右侧渐变
    });
  }

  void _onScrollNotification(ScrollNotification notification) {
    if (!widget.isScrollable) return;

    if (notification is ScrollUpdateNotification) {
      final position = notification.metrics;
      setState(() {
        // 左侧渐变：当滚动位置大于一定值时显示
        _showLeftGradient = position.pixels > 10;

        // 右侧渐变：当还可以继续向右滚动时显示
        _showRightGradient = position.pixels < position.maxScrollExtent - 10;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final bgColor =
        widget.backgroundColor ?? Theme.of(context).scaffoldBackgroundColor;

    if (!widget.isScrollable) {
      // 不可滚动时，直接返回原始TabBar
      return _buildTabBar();
    }

    return Stack(
      children: [
        // 主要的TabBar
        _buildTabBar(),

        // 左侧渐变遮罩
        if (_showLeftGradient)
          Positioned(
            left: 0,
            top: 0,
            bottom: 0,
            width: widget.gradientWidth,
            child: Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.centerLeft,

                  end: Alignment.centerRight,
                  colors: [bgColor.withOpacity(1), bgColor.withOpacity(0)],
                ),
              ),
            ),
          ),

        // 右侧渐变遮罩
        if (_showRightGradient)
          Positioned(
            right: 0,
            top: 0,
            bottom: 0,
            width: widget.gradientWidth,
            child: Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.centerRight,
                  end: Alignment.centerLeft,
                  colors: [bgColor, bgColor.withOpacity(0)],
                ),
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildTabBar() {
    return NotificationListener<ScrollNotification>(
      onNotification: (notification) {
        if (notification.depth == 0) {
          _onScrollNotification(notification);
        }
        return false;
      },
      child: Theme(
        data: Theme.of(context).copyWith(
          // 自定义滚动行为，添加弹簧效果
          scrollbarTheme: ScrollbarThemeData(
            thumbVisibility: WidgetStateProperty.all(false),
          ),
        ),
        child: TabBar(
          controller: widget.controller,
          tabAlignment: TabAlignment.start,
          tabs: widget.tabItems.map((tab) => Tab(text: tab.label)).toList(),
          labelColor: widget.labelColor ?? const Color(0xFF333333),
          unselectedLabelColor:
              widget.unselectedLabelColor ?? const Color(0xFF787878),
          indicator: UnderlineTabIndicator(
            insets: const EdgeInsets.only(bottom: 5),
            borderRadius: BorderRadius.circular(2),
            borderSide: BorderSide(
              color: widget.indicatorColor ?? const Color(0xFFF359AA),
              width: widget.indicatorWeight ?? 4,
              style: BorderStyle.solid,
            ),
          ),
          indicatorWeight: 0, // 使用自定义 indicator
          indicatorSize: widget.indicatorSize ?? TabBarIndicatorSize.label,
          labelStyle:
              widget.labelStyle ??
              const TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
          unselectedLabelStyle:
              widget.unselectedLabelStyle ?? const TextStyle(fontSize: 14),
          isScrollable: widget.isScrollable,
          dividerColor: widget.dividerColor ?? Colors.transparent,
          onTap: widget.onTabChanged,
          // 添加自定义滚动物理效果
          physics: widget.isScrollable
              ? (widget.scrollPhysics ??
                    (widget.enableSpringEffect
                        ? const EnhancedBouncingScrollPhysics(
                            parent: AlwaysScrollableScrollPhysics(),
                          )
                        : const BouncingScrollPhysics(
                            parent: AlwaysScrollableScrollPhysics(),
                          )))
              : const NeverScrollableScrollPhysics(),
        ),
      ),
    );
  }
}
