import 'package:flutter/material.dart';
import '../models/tab_item.dart';

class CustomTabBar extends StatelessWidget {
  final TabController controller;
  final List<TabItem> tabItems;
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
  });

  @override
  Widget build(BuildContext context) {
    return TabBar(
      controller: controller,
      tabAlignment: TabAlignment.start,
      tabs: tabItems.map((tab) => Tab(text: tab.title)).toList(),
      labelColor: labelColor ?? const Color(0xFF333333),
      unselectedLabelColor: unselectedLabelColor ?? const Color(0xFF787878),
      indicator: UnderlineTabIndicator(
        insets: const EdgeInsets.only(bottom: 5),
        borderRadius: BorderRadius.circular(2),
        borderSide: BorderSide(
          color: indicatorColor ?? const Color(0xFFF359AA),
          width: indicatorWeight ?? 4,
          style: BorderStyle.solid,
        ),
      ),
      indicatorWeight: 0, // 使用自定义 indicator
      indicatorSize: indicatorSize ?? TabBarIndicatorSize.label,
      labelStyle:
          labelStyle ??
          const TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
      unselectedLabelStyle:
          unselectedLabelStyle ?? const TextStyle(fontSize: 14),
      isScrollable: isScrollable,
      dividerColor: dividerColor ?? Colors.transparent,
      onTap: onTabChanged,
    );
  }
}
