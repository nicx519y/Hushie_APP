import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

class CustomAppBar extends StatelessWidget {
  final String hintText;
  final Function(String)? onSearchChanged;
  final VoidCallback? onSearchSubmitted;

  const CustomAppBar({
    super.key,
    this.hintText = 'Search songs, users',
    this.onSearchChanged,
    this.onSearchSubmitted,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Colors.white,
      padding: EdgeInsets.only(
        top: MediaQuery.of(context).padding.top + 10,
        left: 16,
        right: 16,
        bottom: 24,
      ),
      child: Column(
        children: [
          // 搜索框
          Container(
            height: 40,
            decoration: BoxDecoration(
              color: const Color(0xFFF2F4F5),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.center, // 添加这行
              children: [
                const SizedBox(width: 16),
                SvgPicture.asset(
                  'assets/icons/search.svg',
                  width: 16,
                  height: 16,
                  colorFilter: const ColorFilter.mode(
                    Color(0xFF666666),
                    BlendMode.srcIn,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Container(
                    height: 40,
                    alignment: Alignment.centerLeft,
                    child: TextField(
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
                        isDense: true, // 添加这行
                      ),
                      style: const TextStyle(
                        fontSize: 16,
                        color: Color(0xFF333333),
                        height: 1.2, // 调整行高
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 16),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
