import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

class UserHeader extends StatelessWidget {
  final bool isLoggedIn;
  final String? userName;
  final VoidCallback? onLoginTap;

  const UserHeader({
    super.key,
    required this.isLoggedIn,
    this.userName,
    this.onLoginTap,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.start,
      children: [
        const SizedBox(width: 10),
        SvgPicture.asset(
          'assets/icons/user.svg',
          width: 20,
          height: 22,
          colorFilter: const ColorFilter.mode(
            Color(0xFF28303F),
            BlendMode.srcIn,
          ),
        ),
        const SizedBox(width: 15),
        Expanded(
          child: InkWell(
            onTap: isLoggedIn ? null : onLoginTap,
            child: Text(
              _getDisplayText(),
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w500,
                height: 1,
                color: isLoggedIn ? Colors.black : Colors.grey[600],
              ),
            ),
          ),
        ),
      ],
    );
  }

  String _getDisplayText() {
    if (isLoggedIn && userName != null && userName!.isNotEmpty) {
      return userName!;
    }
    return 'Sign up / Log in >';
  }
}
