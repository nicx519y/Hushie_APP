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
          isLoggedIn
              ? 'assets/icons/me_selected.svg'
              : 'assets/icons/me_default.svg',
          width: 23,
          height: 27,
          colorFilter: isLoggedIn
              ? const ColorFilter.mode(Color(0xFF333333), BlendMode.srcIn)
              : const ColorFilter.mode(Color(0xFF999999), BlendMode.srcIn),
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
                color: Color(0xFF333333),
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
