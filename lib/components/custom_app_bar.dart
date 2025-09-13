import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'search_box.dart';

class CustomAppBar extends StatelessWidget {
  final String hintText;
  final Function(String)? onSearchChanged;
  final VoidCallback? onSearchSubmitted;
  final VoidCallback? onSearchTap;

  const CustomAppBar({
    super.key,
    this.hintText = '',
    this.onSearchChanged,
    this.onSearchSubmitted,
    this.onSearchTap,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.only(top: 10, left: 16, right: 16, bottom: 4),
      child: Column(
        children: [
          Row(
            children: [
              Transform.translate(
                offset: const Offset(0, 3),
                child: SvgPicture.asset(
                  'assets/icons/logo.svg',
                  height: 30,
                  width: 120,
                  // height: 25,
                ),
              ),
              // 搜索框
              Expanded(
                child: SearchBox(
                  hintText: hintText,
                  onSearchChanged: onSearchChanged,
                  onSearchSubmitted: onSearchSubmitted,
                  onTap: onSearchTap,
                  canFocus: false,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
