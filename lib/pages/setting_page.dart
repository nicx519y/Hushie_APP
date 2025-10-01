import 'package:flutter/material.dart';
import 'package:hushie_app/components/confirm_dialog.dart';
import '../services/auth_manager.dart';
import '../components/custom_outline_button.dart';
import '../router/navigation_utils.dart';
import '../utils/toast_helper.dart';
import '../utils/toast_messages.dart';

class SettingPage extends StatefulWidget {
  const SettingPage({super.key});

  @override
  State<SettingPage> createState() => _SettingPageState();
}

class _SettingPageState extends State<SettingPage> {
  bool _isLoggedIn = false;
  bool _isLogoutting = false;

  @override
  void initState() {
    super.initState();
    _checkLoginStatus();
  }

  Future<void> _checkLoginStatus() async {
    try {
      final isSignedIn = await AuthManager.instance.isSignedIn();
      setState(() {
        _isLoggedIn = isSignedIn;
      });
    } catch (e) {
      debugPrint('Check login status failed: $e');
      setState(() {
        _isLoggedIn = false;
      });
    }
  }

  Future<void> _handleLogout() async {
    if (_isLogoutting || !_isLoggedIn) return;

    setState(() {
      _isLogoutting = true;
    });

    try {
      ConfirmDialog.showWithLoading(
        context: context,
        title: 'Log out of your account?',
        confirmText: 'Log out',
        cancelText: 'Cancel',
        onConfirm: () async {
          await AuthManager.instance.signOut();
          if (mounted) {
            Navigator.of(context).pop();
            ToastHelper.showSuccess(ToastMessages.logoutSuccess);
          }
        },
      );
    } catch (e) {
      if (mounted) {
        ToastHelper.showError(ToastMessages.logoutFailed(e.toString()));
      }
    } finally {
      setState(() {
        _isLogoutting = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
        backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios, color: Colors.black),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: const Text(
          'Setting',
          style: TextStyle(
            color: Colors.black,
            fontSize: 18,
            fontWeight: FontWeight.w500,
          ),
        ),
        centerTitle: true,
      ),
      body: Container(
        padding: const EdgeInsets.all(0),
        decoration: const BoxDecoration(color: Color(0xFFF8F7F7)),
        child: Column(
          children: [
            // About Us 选项
            _buildSettingItem(
              title: 'About Us',
              onTap: () {
                NavigationUtils.navigateToAboutUs(context);
              },
            ),
            

            // Account 选项（仅登录状态显示）
            if (_isLoggedIn) ...[
              _buildSettingItem(
                title: 'Account',
                onTap: () {
                  NavigationUtils.navigateToAccount(context);
                },
              ),
            ],


            // App Version Setting 选项
            // _buildSettingItem(
            //   title: 'App Version Setting',
            //   onTap: () {
            //     NavigationUtils.navigateToAppVersionSetting(context);
            //   },
            // ),

            const SizedBox(height: 30),

            // 登出按钮（仅登录状态显示）
            if (_isLoggedIn)
              CustomOutlineButton(
                disabled: _isLogoutting,
                padding: const EdgeInsets.symmetric(horizontal: 16),
                onPressed: _handleLogout,
                text: 'Log out',
              ),
          ],
        ),
      ),
    );  
  }

  Widget _buildSettingItem({
    required String title,
    required VoidCallback onTap,
  }) {
    return Container(
      height: 54,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 0),
      decoration: const BoxDecoration(color: Colors.white),
      child: ListTile(
        onTap: onTap,
        contentPadding: const EdgeInsets.symmetric(horizontal: 0, vertical: 0),
        title: Text(
          title,
          style: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w500,
            color: Color(0xFF333333),
          ),
        ),
        trailing: const Icon(
          Icons.arrow_forward_ios,
          color: Color(0xFFDFDFDF),
          size: 16,
        ),
      ),
    );
  }
}
