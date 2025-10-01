import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'dart:async';
import '../services/subscribe_privilege_manager.dart';

class UserHeader extends StatefulWidget {
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
  State<UserHeader> createState() => _UserHeaderState();
}

class _UserHeaderState extends State<UserHeader> {
  bool hasPremium =
      SubscribePrivilegeManager.instance.getCachedPrivilege()?.hasPremium ??
      false;
  StreamSubscription<PrivilegeChangeEvent>? _privilegeSubscription;

  @override
  void initState() {
    super.initState();
    _initializePrivilegeState();
  }

  /// 初始化权限状态并订阅权限变化事件
  Future<void> _initializePrivilegeState() async {
    try {
      // 获取当前权限状态
      final privilege = SubscribePrivilegeManager.instance.getCachedPrivilege();
      if (mounted) {
        setState(() {
          hasPremium = privilege?.hasPremium ?? false;
        });
      }

      // 订阅权限变化事件
      _privilegeSubscription = SubscribePrivilegeManager
          .instance
          .privilegeChanges
          .listen(
            (event) {
              if (mounted) {
                setState(() {
                  hasPremium = event.hasPremium;
                });
              }
            },
            onError: (error) {
              debugPrint('🏆 [USER_HEADER] 权限变化事件监听异常: $error');
            },
          );
    } catch (e) {
      debugPrint('🏆 [USER_HEADER] 初始化权限状态失败: $e');
    }
  }

  @override
  void dispose() {
    _privilegeSubscription?.cancel();
    _privilegeSubscription = null;
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.start,
      children: [
        const SizedBox(width: 10),
        SvgPicture.asset(
          widget.isLoggedIn
              ? 'assets/icons/me_selected.svg'
              : 'assets/icons/me_default.svg',
          width: 23,
          height: 27,
          colorFilter: widget.isLoggedIn
              ? const ColorFilter.mode(Color(0xFF333333), BlendMode.srcIn)
              : const ColorFilter.mode(Color(0xFF999999), BlendMode.srcIn),
        ),
        const SizedBox(width: 15),
        Expanded(
          child: InkWell(
            onTap: widget.isLoggedIn ? null : widget.onLoginTap,
            child: Row(
              children: [
                Text(
                  _getDisplayText(),
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w500,
                    height: 2,
                    color: (widget.isLoggedIn && hasPremium)
                        ? const Color(0xFFA16B0D) // 会员用户 金色
                        : const Color(0xFF333333),
                  ),
                ),
                if (widget.isLoggedIn && hasPremium) const SizedBox(width: 5),
                if (widget.isLoggedIn && hasPremium)
                  Image.asset(
                    'assets/images/crown_mini.png',
                    width: 29,
                    height: 21.5,
                  ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  String _getDisplayText() {
    if (widget.isLoggedIn &&
        widget.userName != null &&
        widget.userName!.isNotEmpty) {
      return widget.userName!;
    }
    return 'Sign up / Log in >';
  }
}
