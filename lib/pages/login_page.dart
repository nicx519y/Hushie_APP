import 'package:flutter/material.dart';
import 'package:flutter/gestures.dart';
import '../services/auth_service.dart';
import '../models/api_response.dart';

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

const linkColor = Color(0xFF2A4EFF);

class _LoginPageState extends State<LoginPage> {
  bool _isLoading = false;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      extendBodyBehindAppBar: true,
      body: Container(
        decoration: BoxDecoration(
          image: DecorationImage(
            image: AssetImage('assets/images/luster_bg.png'),
            colorFilter: ColorFilter.mode(Colors.transparent, BlendMode.color),
            fit: BoxFit.fill,
            alignment: Alignment.topCenter,
          ),
        ),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Column(
              children: [
                // 顶部关闭按钮
                Align(
                  alignment: Alignment.centerLeft,
                  child: IconButton(
                    padding: EdgeInsets.zero,
                    onPressed: () => Navigator.of(context).pop(),
                    style: IconButton.styleFrom(
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      backgroundColor: const Color(0x66000000),
                      minimumSize: const Size(40, 40),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(20),
                      ),
                    ),
                    icon: const Icon(
                      Icons.close,
                      color: Colors.white,
                      size: 24,
                    ),
                  ),
                ),

                const SizedBox(height: 70),

                // 标题
                Align(
                  alignment: Alignment.centerLeft,
                  child: const Text(
                    'Log in / Sign up',
                    style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.w500,
                      height: 1.4,
                      color: Color(0xFF000000),
                    ),
                  ),
                ),

                const SizedBox(height: 14),

                // 副标题
                Align(
                  alignment: Alignment.centerLeft,
                  child: const Text(
                    'An account will be automatically created if you haven\'t registered yet.',
                    style: TextStyle(
                      fontSize: 14,
                      color: Color(0xFF666666),
                      height: 1.4,
                    ),
                  ),
                ),

                const SizedBox(height: 70),

                // Google登录按钮
                Container(
                  width: double.infinity,
                  height: 56,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(28),
                    border: Border.all(
                      width: 2,
                      style: BorderStyle.solid,
                      color: Colors.transparent,
                    ),
                    gradient: const LinearGradient(
                      colors: [
                        Color(0xFF45E0FF),
                        Color(0xFF1869FF),
                        Color(0xFF6500FF), // 浅蓝色
                        Color(0xFFFF50A5), // 紫色
                      ],
                    ),
                  ),
                  child: Container(
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(26),
                    ),
                    margin: const EdgeInsets.all(2),
                    child: InkWell(
                      onTap: _isLoading
                          ? null
                          : () {
                              // 处理Google登录逻辑
                              _handleGoogleLogin();
                            },
                      borderRadius: BorderRadius.circular(26),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          // Google Logo
                          Container(
                            width: 24,
                            height: 24,
                            decoration: const BoxDecoration(
                              shape: BoxShape.circle,
                            ),
                            child: Image.asset(
                              'assets/images/GMS_logo.png',
                              width: 24,
                              height: 24,
                            ),
                          ),
                          const SizedBox(width: 8),
                          // 按钮文字或加载指示器
                          _isLoading
                              ? const SizedBox(
                                  width: 20,
                                  height: 20,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    valueColor: AlwaysStoppedAnimation<Color>(
                                      Color(0xFF333333),
                                    ),
                                  ),
                                )
                              : const Text(
                                  'Continue with Google',
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w500,
                                    color: Color(0xFF333333),
                                  ),
                                ),
                        ],
                      ),
                    ),
                  ),
                ),

                const Spacer(),

                // 法律条款
                Padding(
                  padding: const EdgeInsets.only(bottom: 40),
                  child: RichText(
                    textAlign: TextAlign.center,
                    text: TextSpan(
                      style: const TextStyle(
                        fontSize: 12,
                        color: Color(0xFF333333),
                        height: 1.6,
                      ),
                      children: [
                        const TextSpan(
                          text: 'By continuing, I agree to Hushie\'s ',
                        ),
                        TextSpan(
                          text: 'Term of Use',
                          style: const TextStyle(
                            color: linkColor,
                            decoration: TextDecoration.none,
                          ),
                          recognizer: TapGestureRecognizer()
                            ..onTap = () => _showTermsOfUse(),
                        ),
                        const TextSpan(text: ', '),
                        TextSpan(
                          text: 'End User License Agreement',
                          style: const TextStyle(
                            color: linkColor,
                            decoration: TextDecoration.none,
                          ),
                          recognizer: TapGestureRecognizer()
                            ..onTap = () => _showLicenseAgreement(),
                        ),
                        const TextSpan(text: ' and '),
                        TextSpan(
                          text: 'Privacy Policy',
                          style: const TextStyle(
                            color: linkColor,
                            decoration: TextDecoration.none,
                          ),
                          recognizer: TapGestureRecognizer()
                            ..onTap = () => _showPrivacyPolicy(),
                        ),
                        const TextSpan(text: '.'),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _handleGoogleLogin() async {
    try {
      // 显示加载状态
      setState(() {
        _isLoading = true;
      });

      // 调用AuthService进行Google登录
      final result = await AuthService.signInWithGoogle();

      if (result.errNo == 0 && result.data != null) {
        // 登录成功
        _showSnackBar('登录成功！');

        // 延迟一下让用户看到成功消息，然后关闭登录页面
        await Future.delayed(const Duration(milliseconds: 500));

        // 关闭登录页面，返回上一页
        if (mounted) {
          Navigator.of(context).pop();
        }
      } else {
        // 登录失败
        final errorMessage = _getErrorMessage(result.errNo);
        _showSnackBar(errorMessage);
      }
    } catch (e) {
      // 处理异常
      print('Google登录异常: $e');
      _showSnackBar('登录过程中发生错误，请重试');
    } finally {
      // 隐藏加载状态
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  void _showTermsOfUse() {
    _showSnackBar('打开服务条款页面');
    // 这里可以导航到服务条款页面
  }

  void _showLicenseAgreement() {
    _showSnackBar('打开用户许可协议页面');
    // 这里可以导航到许可协议页面
  }

  void _showPrivacyPolicy() {
    _showSnackBar('打开隐私政策页面');
    // 这里可以导航到隐私政策页面
  }

  void _showSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        duration: const Duration(seconds: 2),
        backgroundColor: const Color(0xFF4A90E2),
      ),
    );
  }

  /// 根据错误码获取错误消息
  String _getErrorMessage(int errNo) {
    switch (errNo) {
      case -1:
        return '登录失败，请重试';
      case 1:
        return '用户取消登录';
      case 2:
        return '网络连接失败';
      case 3:
        return 'Google服务不可用';
      default:
        return '登录失败，错误码: $errNo';
    }
  }
}
