import 'package:flutter/material.dart';
import 'tab_item.dart';

class ProfileTabHeader extends StatelessWidget {
  final int currentIndex;
  final Function(int)? onTabChanged;
  final bool isLoggedIn;

  const ProfileTabHeader({
    super.key,
    this.currentIndex = 0,
    this.onTabChanged,
    this.isLoggedIn = true,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      child: Row(
        children: [
          TabItem(
            text: 'History',
            isSelected: currentIndex == 0,
            isEnabled: isLoggedIn,
            onTap: () => onTabChanged?.call(0),
          ),
          const SizedBox(width: 30),
          TabItem(
            text: 'Like',
            isSelected: currentIndex == 1,
            isEnabled: isLoggedIn,
            onTap: () => onTabChanged?.call(1),
          ),
        ],
      ),
    );
  }
}
