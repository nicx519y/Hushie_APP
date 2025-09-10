import 'package:flutter/material.dart';
import '../utils/custom_icons.dart';

class SearchBox extends StatelessWidget {
  final String hintText;
  final Function(String)? onSearchChanged;
  final VoidCallback? onSearchSubmitted;
  final TextEditingController? controller;
  final FocusNode? focusNode;
  final VoidCallback? onTap;
  final VoidCallback? onFocusGained;
  final bool canFocus;
  final bool showClearButton;
  final VoidCallback? onClear;

  const SearchBox({
    super.key,
    this.hintText = 'Search songs, users',
    this.onSearchChanged,
    this.onSearchSubmitted,
    this.controller,
    this.focusNode,
    this.onTap,
    this.onFocusGained,
    this.canFocus = false,
    this.showClearButton = false,
    this.onClear,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {
        onTap?.call();
      },
      child: Container(
        height: 40,
        decoration: BoxDecoration(
          color: const Color(0xFFF2F4F5),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            const SizedBox(width: 16),
            Icon(CustomIcons.search, size: 16, color: Color(0xFF666666)),
            const SizedBox(width: 12),
            Expanded(
              child: Container(
                height: 40,
                alignment: Alignment.centerLeft,
                child: TextField(
                  controller: controller,
                  focusNode: focusNode,
                  enabled: canFocus,
                  onChanged: onSearchChanged,
                  onSubmitted: (_) => onSearchSubmitted?.call(),
                  decoration: InputDecoration(
                    hintText: hintText,
                    hintStyle: const TextStyle(
                      color: Colors.grey,
                      fontSize: 16,
                      height: 1,
                    ),
                    border: InputBorder.none,
                    contentPadding: EdgeInsets.zero,
                    isDense: true,
                  ),
                  style: const TextStyle(
                    fontSize: 16,
                    color: Color(0xFF333333),
                    height: 1.2,
                  ),
                ),
              ),
            ),
            if (showClearButton)
              InkWell(
                onTap: onClear,
                child: Container(
                  padding: const EdgeInsets.all(3),
                  decoration: BoxDecoration(
                    color: Color(0x55000000),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(
                    Icons.clear,
                    size: 12,
                    color: Colors.white,
                  ),
                ),
              ),
            const SizedBox(width: 10),
          ],
        ),
      ),
    );
  }
}
