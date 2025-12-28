import 'package:flutter/material.dart';
import 'login_common.dart';

class LoginDialog extends StatefulWidget {
  final String title;
  final String subtitle;

  const LoginDialog({
    super.key,
    this.title = 'Membership Purchased Successfully!',
    this.subtitle = 'Please sign in to link your account.',
  });

  static Future<void> show(BuildContext context) {
    return showDialog(
      context: context,
      barrierColor: const Color(0x88000000),
      barrierDismissible: false,
      useRootNavigator: true,
      builder: (_) => PopScope<Object?>(
        canPop: false,
        onPopInvokedWithResult: (didPop, result) {},
        child: const LoginDialog(),
      ),
    );
  }

  @override
  State<LoginDialog> createState() => _LoginDialogState();
}

class _LoginDialogState extends State<LoginDialog> {
  bool _isLoading = false;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: Center(
      child: Container(
        width: 315,
        padding: const EdgeInsets.only(top: 78, bottom: 67, left: 20, right: 20),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(32),
          boxShadow: const [
            BoxShadow(color: Color(0x22000000), blurRadius: 16, offset: Offset(0, 8)),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              widget.title,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w700, color: Color(0xFF333333)),
            ),
            const SizedBox(height: 16),
            Text(
              widget.subtitle,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 16, color: Color(0xFF333333)),
            ),
            const SizedBox(height: 50),
            SizedBox(
              width: 250,
              height: 56,
              child: Container(
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(28),
                  border: Border.all(width: 2, color: Colors.transparent),
                  gradient: const LinearGradient(
                    colors: [
                      Color(0xFF45E0FF),
                      Color(0xFF1869FF),
                      Color(0xFF6500FF),
                      Color(0xFFFF50A5),
                    ],
                  ),
                ),
                child: Container(
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(26),
                  ),
                  margin: const EdgeInsets.all(2),
                  child: Material(
                    color: Colors.transparent,
                    borderRadius: BorderRadius.circular(26),
                    child: InkWell(
                      onTap: _isLoading
                          ? null
                          : () {
                              LoginCommon.handleGoogleLogin(
                                context,
                                onClose: () => Navigator.of(context, rootNavigator: true).pop(),
                                setLoading: (v) => setState(() => _isLoading = v),
                              );
                            },
                      borderRadius: BorderRadius.circular(26),
                     
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Container(
                            width: 24,
                            height: 24,
                            decoration: const BoxDecoration(shape: BoxShape.circle),
                            child: Image.asset('assets/images/GMS_logo.png', width: 24, height: 24),
                          ),
                          const SizedBox(width: 8),
                          _isLoading
                              ? const SizedBox(
                                  width: 20,
                                  height: 20,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF333333)),
                                  ),
                                )
                              : const Text(
                                  'Continue with Google',
                                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500, color: Color(0xFF333333)),
                                ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    ));
  }
}