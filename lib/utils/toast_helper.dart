import 'package:flutter/material.dart';
import 'package:fluttertoast/fluttertoast.dart';

/// Toast工具类，提供统一的toast样式
class ToastHelper {
  // 私有构造函数，防止实例化
  ToastHelper._();

  /// 显示成功提示toast
  static void showSuccess(String message) {
    Fluttertoast.showToast(
      msg: message,
      toastLength: Toast.LENGTH_SHORT,
      gravity: ToastGravity.CENTER,
      backgroundColor: const Color(0xFF4CAF50).withAlpha(128), // 绿色
      textColor: Colors.white,
      fontSize: 12.0,
    );
  }

  /// 显示错误提示toast
  static void showError(String message) {
    Fluttertoast.showToast(
      msg: message,
      toastLength: Toast.LENGTH_SHORT,
      gravity: ToastGravity.CENTER,
      backgroundColor: const Color(0xFFFF0000).withAlpha(128), // 红色
      textColor: Colors.white,
      fontSize: 12.0,
    );
  }

  /// 显示警告提示toast
  static void showWarning(String message) {
    Fluttertoast.showToast(
      msg: message,
      toastLength: Toast.LENGTH_SHORT,
      gravity: ToastGravity.CENTER,
      backgroundColor: const Color(0xFFFF9800).withAlpha(128), // 橙色
      textColor: Colors.white,
      fontSize: 12.0,
    );
  }

  /// 显示信息提示toast
  static void showInfo(String message) {
    Fluttertoast.showToast(
      msg: message,
      toastLength: Toast.LENGTH_SHORT,
      gravity: ToastGravity.CENTER,
      backgroundColor: const Color(0xFF2196F3).withAlpha(128), // 蓝色
      textColor: Colors.white,
      fontSize: 12.0,
    );
  }

  /// 显示默认样式toast
  static void show(String message) {
    Fluttertoast.showToast(
      msg: message,
      toastLength: Toast.LENGTH_SHORT,
      gravity: ToastGravity.CENTER,
      backgroundColor: const Color(0xFF000000).withAlpha(128), // 深灰色
      textColor: Colors.white,
      fontSize: 12.0,
    );
  }

  /// 显示长时间toast
  static void showLong(String message) {
    Fluttertoast.showToast(
      msg: message,
      toastLength: Toast.LENGTH_LONG,
      gravity: ToastGravity.CENTER,
      backgroundColor: const Color(0xFF323232).withAlpha(128), // 深灰色
      textColor: Colors.white,
      fontSize: 12.0,
    );
  }

  /// 自定义样式toast
  static void showCustom({
    required String message,
    Toast toastLength = Toast.LENGTH_SHORT,
    ToastGravity gravity = ToastGravity.CENTER,
    Color? backgroundColor,
    Color? textColor,
    double fontSize = 12.0,
  }) {
    Fluttertoast.showToast(
      msg: message,
      toastLength: toastLength,
      gravity: gravity,
      backgroundColor: backgroundColor ?? const Color(0xFF323232),
      textColor: textColor ?? Colors.white,
      fontSize: fontSize,
    );
  }
}