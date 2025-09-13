import 'package:flutter/material.dart';
import 'package:fluttertoast/fluttertoast.dart';

/// Toast工具类，提供统一的toast样式
class ToastHelper {
  // 私有构造函数，防止实例化
  ToastHelper._();

  static double fontSize = 14.0;
  static int alpha  = 128;
  static Color textColor = Colors.white;
  static Color backgroundColor = Colors.black;
  static ToastGravity gravity = ToastGravity.CENTER;

  /// 显示成功提示toast
  static void showSuccess(String message) {
    Fluttertoast.showToast(
      msg: message,
      toastLength: Toast.LENGTH_SHORT,
      gravity: gravity,
      backgroundColor: backgroundColor.withAlpha(alpha), // 绿色
      textColor: textColor,
      fontSize: fontSize,
    );
  }

  /// 显示错误提示toast
  static void showError(String message) {
    Fluttertoast.showToast(
      msg: message,
      toastLength: Toast.LENGTH_SHORT,
      gravity: gravity,
      backgroundColor: backgroundColor.withAlpha(alpha), // 红色
      textColor: textColor,
      fontSize: fontSize,
    );
  }

  /// 显示警告提示toast
  static void showWarning(String message) {
    Fluttertoast.showToast(
      msg: message,
      toastLength: Toast.LENGTH_SHORT,
      gravity: gravity,
      backgroundColor: backgroundColor.withAlpha(alpha), // 橙色
      textColor: textColor,
      fontSize: fontSize,
    );
  }

  /// 显示信息提示toast
  static void showInfo(String message) {
    Fluttertoast.showToast(
      msg: message,
      toastLength: Toast.LENGTH_SHORT,
      gravity: gravity,
      backgroundColor: backgroundColor.withAlpha(alpha), // 蓝色
      textColor: textColor,
      fontSize: fontSize,
    );
  }

  /// 显示默认样式toast
  static void show(String message) {
    Fluttertoast.showToast(
      msg: message,
      toastLength: Toast.LENGTH_SHORT,
      gravity: gravity,
      backgroundColor: backgroundColor.withAlpha(alpha), // 深灰色
      textColor: textColor,
      fontSize: fontSize,
    );
  }

  /// 显示长时间toast
  static void showLong(String message) {
    Fluttertoast.showToast(
      msg: message,
      toastLength: Toast.LENGTH_LONG,
      gravity: gravity,
      backgroundColor: backgroundColor.withAlpha(alpha), // 深灰色
      textColor: textColor,
      fontSize: fontSize,
    );
  }

  /// 自定义样式toast
  static void showCustom({
    required String message,
    Toast toastLength = Toast.LENGTH_SHORT,
    ToastGravity? gravity,
    Color? backgroundColor,
    Color? textColor,
    double fontSize = 14.0,
  }) {
    Fluttertoast.showToast(
      msg: message,
      toastLength: toastLength,
      gravity: gravity,
      fontSize: fontSize,
      backgroundColor: backgroundColor ?? const Color(0xFF323232),
      textColor: textColor ?? Colors.white,
    );
  }
}