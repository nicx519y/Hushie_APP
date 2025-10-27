import 'package:flutter/material.dart';
import 'package:flutter/gestures.dart';
import 'dart:async';
import '../services/auth_manager.dart';
import '../router/navigation_utils.dart';
// import '../router/slide_up_page_route.dart';
import '../utils/toast_helper.dart';
import '../utils/toast_messages.dart';
import '../utils/webview_navigator.dart';
import '../services/analytics_service.dart';
// import '../components/overlay_sheet.dart';
import '../services/dialog_state_manager.dart';

class LoginPage extends StatefulWidget {
  const LoginPage({super.key, this.onClose});

  final VoidCallback? onClose;

  @override
  State<LoginPage> createState() => _LoginPageState();

  /// 显示登录页面的静态方法（统一 Overlay 方案）
  // static Future<void> show(BuildContext context) async {
  //   return showOverlay(context);
  // }

  // /// 以 Overlay 方式显示登录页面，使用统一开关动画
  // static Future<void> showOverlay(BuildContext context) async {
  //   await OverlaySheet.show(
  //     context,
  //     builder: (close) => LoginPage(onClose: close),
  //   );
  // }

  /// 检查登录页面是否已经打开（已移除，使用标准Navigator管理）
  static bool get isOpen => false;
}

const linkColor = Color(0xFF2A4EFF);

class _LoginPageState extends State<LoginPage> with WidgetsBindingObserver {
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    // 添加系统事件观察者
    WidgetsBinding.instance.addObserver(this);
    // 确保状态正确标记为已打开
    debugPrint('🔐 [LOGIN] LoginPage initState');
  }

  @override
  void dispose() {
    // 取消系统事件观察者
    WidgetsBinding.instance.removeObserver(this);
    // 页面销毁时重置状态（已移除，使用标准Navigator管理）
    debugPrint('🔐 [LOGIN] LoginPage dispose');
    super.dispose();
  }

  @override
  Future<bool> didPopRoute() async {
    // 拦截系统返回键，使用标准Navigator.pop关闭页面
    Navigator.of(context).pop();
    return true; // 表示已处理返回键事件
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      extendBodyBehindAppBar: true,
      body: Container(
        decoration: BoxDecoration(
          image: DecorationImage(
            image: AssetImage('assets/images/luster_bg.png'),
            colorFilter: ColorFilter.mode(
              Colors.transparent,
              BlendMode.color,
            ),
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
                      onPressed: () => widget.onClose != null
                          ? widget.onClose!()
                          : Navigator.of(context).pop(),
                      style: IconButton.styleFrom(
                        // tapTargetSize: MaterialTapTargetSize.shrinkWrap,
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
                            text: 'Terms of Use',
                            style: const TextStyle(
                              color: linkColor,
                              decoration: TextDecoration.none,
                            ),
                            recognizer: TapGestureRecognizer()
                              ..onTap = () => WebViewNavigator.showTermsOfUse(
                                context,
                                clearCache: true,
                              ),
                          ),
                          const TextSpan(text: ', '),
                          TextSpan(
                            text: 'End User License Agreement',
                            style: const TextStyle(
                              color: linkColor,
                              decoration: TextDecoration.none,
                            ),
                            recognizer: TapGestureRecognizer()
                              ..onTap = () =>
                                  WebViewNavigator.showLicenseAgreement(
                                    context,
                                    clearCache: true,
                                  ),
                          ),
                          const TextSpan(text: ' and '),
                          TextSpan(
                            text: 'Privacy Policy',
                            style: const TextStyle(
                              color: linkColor,
                              decoration: TextDecoration.none,
                            ),
                            recognizer: TapGestureRecognizer()
                              ..onTap = () =>
                                  WebViewNavigator.showPrivacyPolicy(
                                    context,
                                    clearCache: true,
                                  ),
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
      final result = await AuthManager.instance.signInWithGoogle();

      if (result.errNo == 0 && result.data != null) {
        // 登录成功
        ToastHelper.showSuccess(ToastMessages.loginSuccess);

        // 记录登录事件
        AnalyticsService().logLogin(loginMethod: 'google');

        // 延迟一下让用户看到成功消息，然后关闭登录页面
        await Future.delayed(const Duration(milliseconds: 500));

        // 关闭登录页面，返回上一页
        if (mounted) {
          // 使用新的关闭方法
          if (widget.onClose != null) {
            widget.onClose!();
          } else {
            Navigator.of(context).pop();
          }
        }
      } else {
        if ([-1, 1, 2, 3].contains(result.errNo)) {
          // 登录失败 - 添加调试日志
          final errorMessage = _getErrorMessage(result.errNo);
          debugPrint(
            '🔐 [LOGIN] 准备显示错误toast: errNo=${result.errNo}, message=$errorMessage',
          );
          debugPrint(
            '🔐 [LOGIN] 当前路由状态: isCurrent=${ModalRoute.of(context)?.isCurrent}',
          );

          // 延迟显示toast，确保用户已回到应用
          Future.delayed(const Duration(milliseconds: 500), () {
            if (mounted) {
              debugPrint('🔐 [LOGIN] 延迟后显示toast: $errorMessage');
              ToastHelper.showError(errorMessage);
            }
          });
        }
      }
    } catch (e) {
      // 处理异常
      debugPrint('Google登录异常: $e');
      ToastHelper.showError(ToastMessages.loginFailed);
    } finally {
      // 隐藏加载状态
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  /// 根据错误码获取错误消息
  String _getErrorMessage(int errNo) {
    switch (errNo) {
      case -1:
        return 'Login failed, retry please.';
      case 1:
        return 'User cancelled login or timeout.';
      case 2:
        return 'Network connection failed.';
      case 3:
        return 'Google service unavailable.';
      default:
        return 'Login failed, error code: $errNo';
    }
  }
}
