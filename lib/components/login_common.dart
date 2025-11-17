import 'package:flutter/material.dart';
import '../services/auth_manager.dart';
import '../services/analytics_service.dart';
import '../utils/toast_helper.dart';
import '../utils/toast_messages.dart';

class LoginCommon {
  static Future<void> handleGoogleLogin(
    BuildContext context, {
    VoidCallback? onClose,
    ValueSetter<bool>? setLoading,
  }) async {
    try {
      setLoading?.call(true);
      final result = await AuthManager.instance.signInWithGoogle();
      if (result.errNo == 0 && result.data != null) {
        ToastHelper.showSuccess(ToastMessages.loginSuccess);
        AnalyticsService().logLogin(loginMethod: 'google');
        await Future.delayed(const Duration(milliseconds: 500));
        if (onClose != null) {
          onClose();
        } else {
          if (Navigator.of(context).canPop()) {
            Navigator.of(context).pop();
          }
        }
      } else {
        final errorMessage = _getErrorMessage(result.errNo);
        ToastHelper.showError(errorMessage);
      }
    } catch (_) {
      ToastHelper.showError(ToastMessages.loginFailed);
    } finally {
      setLoading?.call(false);
    }
  }

  static String _getErrorMessage(int errNo) {
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