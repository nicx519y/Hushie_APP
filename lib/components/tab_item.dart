import 'package:flutter/material.dart';

class TabItem extends StatelessWidget {
  final String text;
  final bool isSelected;
  final bool isEnabled;
  final VoidCallback? onTap;
  final EdgeInsetsGeometry? padding;
  final double indicatorWidth;
  final Color? selectedColor;
  final Color? unselectedColor;
  final Color? indicatorColor;

  const TabItem({
    super.key,
    required this.text,
    this.isSelected = false,
    this.isEnabled = true,
    this.onTap,
    this.padding = const EdgeInsets.symmetric(vertical: 5),
    this.indicatorWidth = 4,
    this.selectedColor = const Color(0xFF0B1526),
    this.unselectedColor,
    this.indicatorColor = const Color(0xFF5B37F9),
  });

  @override
  Widget build(BuildContext context) {
    final defaultUnselectedColor = const Color(0xFF8D93A6);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 0),
      child: GestureDetector(
        onTap: isEnabled ? onTap : null,
        child: Container(
          padding: padding,
          decoration: BoxDecoration(
            border: Border(
              bottom: BorderSide(
                color: isSelected
                    ? (indicatorColor ?? Colors.blue)
                    : Colors.transparent,
                width: indicatorWidth,
              ),
            ),
          ),
          child: Text(
            text,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: isSelected ? 20 : 16,
              fontWeight: FontWeight.w500,
              height: 1.2,
              color: isSelected ? selectedColor : defaultUnselectedColor,
            ),
          ),
        ),
      ),
    );
  }
}
