import 'package:flutter/material.dart';
import 'package:flutter_svg/svg.dart';
import 'play_arrow_icon.dart';

class CustomBottomNavigationBar extends StatelessWidget {
  final int currentIndex;
  final Function(int) onTap;

  const CustomBottomNavigationBar({
    super.key,
    required this.currentIndex,
    required this.onTap,
  });

  static const Color activeColor = Color(0xFF333333);
  static const Color inactiveColor = Color(0xFFD0D3DE);

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 120,
      color: Colors.white,
      child: Container(
        padding: EdgeInsets.only(left: 18, right: 18, bottom: 15),
        child: Row(
          children: [
            // Home Tab
            Expanded(
              child: _buildTab(
                index: 0,
                icon: SvgPicture.asset(
                  'assets/icons/home.svg',
                  width: 24,
                  height: 24,
                  color: currentIndex == 0 ? activeColor : inactiveColor,
                ),
                label: 'Home',
                isSelected: currentIndex == 0,
              ),
            ),

            // 中间播放按钮
            _buildPlayButton(),

            // Profile Tab
            Expanded(
              child: _buildTab(
                index: 1,
                icon: SvgPicture.asset(
                  'assets/icons/profile.svg',
                  width: 24,
                  height: 24,
                  color: currentIndex == 1 ? activeColor : inactiveColor,
                ),
                label: 'Profile',
                isSelected: currentIndex == 1,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTab({
    required int index,
    required Widget icon, // 改为 Widget 类型，支持 SVG
    required String label,
    required bool isSelected,
  }) {
    return InkWell(
      onTap: () => onTap(index),
      splashColor: Colors.transparent,
      highlightColor: Colors.transparent,
      child: Container(
        width: double.infinity,
        height: double.infinity,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            icon, // 直接使用传入的 Widget
            const SizedBox(height: 2),
            Text(
              label,
              style: TextStyle(
                fontSize: 10,
                height: 1,
                fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
                color: isSelected ? activeColor : inactiveColor,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPlayButton() {
    return Transform.translate(
      offset: const Offset(0, -11), // 向上偏移10像素
      child: InkWell(
        onTap: () => onTap(2), // 播放按钮的索引
        splashColor: Colors.transparent,
        highlightColor: Colors.transparent,
        child: Container(
          width: 64,
          height: 64,
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              begin: Alignment.centerLeft,
              end: Alignment.centerRight,
              colors: [
                Color(0xFF4A90E2), // 蓝色
                Color(0xFF5B37F9), // 紫色
              ],
            ),
            borderRadius: BorderRadius.circular(32),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFF5B37F9).withOpacity(0.3),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: const PlayArrowIcon(
            size: 64,
            triangleSize: 32.0,
            cornerRadius: 5.0,
            color: Colors.white,
          ),
        ),
      ),
    );
  }
}
