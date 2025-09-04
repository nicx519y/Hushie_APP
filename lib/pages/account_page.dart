import 'package:flutter/material.dart';
import 'package:hushie_app/components/custom_outline_button.dart';
import '../services/auth_service.dart';
import '../config/api_config.dart';
import '../components/custom_webview.dart';
import '../components/confirm_dialog.dart';

class AccountPage extends StatefulWidget {
  const AccountPage({super.key});

  @override
  State<AccountPage> createState() => _AccountPageState();
}

class _AccountPageState extends State<AccountPage> {
  bool _isDeleting = false;
  bool _agreementChecked = false;

  Future<void> _handleDeleteAccount() async {
    if (_isDeleting) return;

    if (!_agreementChecked) {
      await ConfirmDialog.show(
        context: context,
        title: 'Please read and agree to the account deletion agreement.',
        confirmText: 'OK',
        cancelText: '',
      );
      return;
    }

    // 显示确认对话框
    try {
      await ConfirmDialog.showWithLoading(
        context: context,
        title: 'Delete your account?',
        confirmText: 'Delete',
        cancelText: 'Cancel',
        onConfirm: () async {
          try {
            await AuthService.deleteAccount();
            if (mounted) {
              Navigator.of(context).popUntil((route) => route.isFirst);
            }
          } catch (e) {
            ScaffoldMessenger.of(
              context,
            ).showSnackBar(SnackBar(content: Text('Account delete failed.')));
          }
        },
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Account delete failed.')));
      }
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
          'Account',
          style: TextStyle(
            color: Colors.black,
            fontSize: 18,
            fontWeight: FontWeight.w600,
          ),
        ),
        centerTitle: true,
      ),
      body: SafeArea(
        child: Container(
          color: Color(0xFFF8F8F8),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 当前登录账户信息
              Container(
                width: double.infinity,
                padding: const EdgeInsets.only(
                  left: 16,
                  right: 16,
                  top: 20,
                  bottom: 20,
                ),
                child: Container(
                  decoration: const BoxDecoration(
                    color: Color(0xFFE9EAEB),
                    borderRadius: BorderRadius.all(Radius.circular(12)),
                  ),
                  width: double.infinity,
                  padding: const EdgeInsets.all(27),
                  child: Column(
                    spacing: 10,
                    children: [
                      Text(
                        'Current login account:',
                        style: TextStyle(
                          color: Colors.black,
                          fontSize: 16,
                          height: 1,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      Image.asset(
                        'assets/images/GMS_logo.png',
                        width: 24,
                        height: 24,
                      ),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 20),

              Expanded(
                child: CustomWebView(
                  url: ApiConfig.AccountDeletionAgreement,
                  backgroundColor: const Color(0xFFF5F5F5),
                  loadingBackgroundColor: const Color(0xFFF5F5F5),
                  loadingIndicatorColor: const Color(0xFFF359AA),
                ),
              ),

              const SizedBox(height: 10),

              Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  children: [
                    // 协议确认复选框 - 使用全局主题
                    Row(
                      children: [
                        Checkbox(
                          value: _agreementChecked,
                          onChanged: (value) {
                            setState(() {
                              _agreementChecked = value ?? false;
                            });
                          },
                          // 移除 activeColor，使用全局主题
                        ),
                        const Expanded(
                          child: Text(
                            'I have read the Account Deletion Agreement',
                            style: TextStyle(
                              fontSize: 16,
                              color: Colors.black87,
                            ),
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 15),

                    // 删除按钮
                    CustomOutlineButton(
                      disabled: _isDeleting,
                      padding: EdgeInsets.all(0),
                      onPressed: _handleDeleteAccount,
                      text: 'Delete',
                    ),

                    const SizedBox(height: 20),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
