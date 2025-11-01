import 'package:flutter/material.dart';
import 'dart:async';
import '../pages/login_page.dart';
import '../pages/audio_player_page.dart';
import '../pages/setting_page.dart';
import '../pages/account_page.dart';
import '../pages/about_us_page.dart';
import '../pages/search_page.dart';
import '../pages/environment_setting_page.dart';
import '../pages/onboarding_page.dart';
import '../models/audio_item.dart';

class NavigationUtils {
  // 登录页面相关变量（已移除Overlay方案，改用标准Navigator）

  /// 导航到音频播放器（使用标准Navigator.push，支持页面持久化）
  /// AudioPlayerPage通过AutomaticKeepAliveClientMixin保持状态不被销毁
  static Future<T?> navigateToAudioPlayer<T extends Object?>(BuildContext context) async {
    try {
      debugPrint('🎵 [AUDIO_PLAYER] 使用Navigator.push打开播放器页面');
      
      // 使用标准的页面路由，让AudioPlayerPage在导航栈中保持活跃
      return await Navigator.of(context).push<T>(
        PageRouteBuilder<T>(
          pageBuilder: (context, animation, secondaryAnimation) => AudioPlayerPage(),
          transitionsBuilder: (context, animation, secondaryAnimation, child) {
            // 上滑动画效果
            const begin = Offset(0.0, 1.0);
            const end = Offset.zero;
            const curve = Curves.easeInOut;

            var tween = Tween(begin: begin, end: end).chain(CurveTween(curve: curve));
            var offsetAnimation = animation.drive(tween);

            return SlideTransition(position: offsetAnimation, child: child);
          },
          transitionDuration: const Duration(milliseconds: 300),
          reverseTransitionDuration: const Duration(milliseconds: 300),
          opaque: false, // 允许透明背景
        ),
      );
    } catch (e) {
      debugPrint('🎵 [AUDIO_PLAYER] 打开播放器页面失败: $e');
      return null;
    }
  }

  /// 检查音频播放器是否打开（已移除，使用标准Navigator管理）
  static bool get isAudioPlayerOpen => false;

  /// 确保同时只能打开一个登录页面实例
  /// 导航到登录页面（使用标准Navigator.push）
  static Future<void> navigateToLogin(BuildContext context) async {
    try {
      debugPrint('🔐 [LOGIN] 使用Navigator.push打开登录页面');
      
      // 使用系统默认的页面路由动画
      await Navigator.of(context).push(
        MaterialPageRoute(
          builder: (context) => const LoginPage(),
        ),
      );
      
      debugPrint('🔐 [LOGIN] 登录页面已关闭');
    } catch (e) {
      debugPrint('🔐 [LOGIN] 导航到登录页面时发生错误: $e');
    }
  }

  /// 导航到设置页面
  static Future<void> navigateToSettings(BuildContext context) async {
    try {
      debugPrint('⚙️ [SETTINGS] 打开设置页面');
      await Navigator.of(context, rootNavigator: true).push(
        MaterialPageRoute(
          builder: (context) => const SettingPage(),
          settings: const RouteSettings(name: '/settings'),
        ),
      );
      debugPrint('⚙️ [SETTINGS] 设置页面已关闭');
    } catch (e) {
      debugPrint('⚙️ [SETTINGS] 导航到设置页面时发生错误: $e');
    }
  }

  /// 导航到账户页面
  static Future<void> navigateToAccount(BuildContext context) async {
    try {
      debugPrint('👤 [ACCOUNT] 打开账户页面');
      await Navigator.of(context, rootNavigator: true).push(
        MaterialPageRoute(
          builder: (context) => const AccountPage(),
          settings: const RouteSettings(name: '/account'),
        ),
      );
      debugPrint('👤 [ACCOUNT] 账户页面已关闭');
    } catch (e) {
      debugPrint('👤 [ACCOUNT] 导航到账户页面时发生错误: $e');
    }
  }

  /// 导航到关于我们页面
  static Future<void> navigateToAboutUs(BuildContext context) async {
    try {
      debugPrint('ℹ️ [ABOUT_US] 打开关于我们页面');
      await Navigator.of(context, rootNavigator: true).push(
        MaterialPageRoute(
          builder: (context) => const AboutUsPage(),
          settings: const RouteSettings(name: '/about_us'),
        ),
      );
      debugPrint('ℹ️ [ABOUT_US] 关于我们页面已关闭');
    } catch (e) {
      debugPrint('ℹ️ [ABOUT_US] 导航到关于我们页面时发生错误: $e');
    }
  }

  /// 导航到搜索页面
  static Future<void> navigateToSearch(BuildContext context) async {
    try {
      debugPrint('🔍 [SEARCH] 打开搜索页面');
      await Navigator.of(context, rootNavigator: true).push(
        MaterialPageRoute(
          builder: (context) => const SearchPage(),
          settings: const RouteSettings(name: '/search'),
        ),
      );
      debugPrint('🔍 [SEARCH] 搜索页面已关闭');
    } catch (e) {
      debugPrint('🔍 [SEARCH] 导航到搜索页面时发生错误: $e');
    }
  }


  /// 导航到环境设置页面
  static Future<void> navigateToEnvironmentSetting(BuildContext context) async {
    try {
      debugPrint('🌐 [ENV] 打开环境设置页面');
      await Navigator.of(context, rootNavigator: true).push(
        MaterialPageRoute(
          builder: (context) => const EnvironmentSettingPage(),
          settings: const RouteSettings(name: '/environment_setting'),
        ),
      );
      debugPrint('🌐 [ENV] 环境设置页面已关闭');
    } catch (e) {
      debugPrint('🌐 [ENV] 导航到环境设置页面时发生错误: $e');
    }
  }

  /// 导航到新手引导页面
  static Future<void> navigateToOnboarding(BuildContext context) async {
    try {
      debugPrint('🎯 [ONBOARDING] 打开新手引导页面');
      await Navigator.of(context, rootNavigator: true).push(
        MaterialPageRoute(
          builder: (context) => const OnboardingPage(),
          settings: const RouteSettings(name: '/onboarding'),
        ),
      );
      debugPrint('🎯 [ONBOARDING] 新手引导页面已关闭');
    } catch (e) {
      debugPrint('🎯 [ONBOARDING] 导航到新手引导页面时发生错误: $e');
    }
  }

  /// 导航到主应用页面（用于启动页跳转）
  /// 使用pushReplacement替换当前页面
  static Future<void> navigateToMainApp(BuildContext context, Widget mainApp) async {
    try {
      debugPrint('🏠 [MAIN_APP] 跳转到主应用页面');
      await Navigator.of(context).pushReplacement(
        PageRouteBuilder(
          pageBuilder: (context, animation, secondaryAnimation) => mainApp,
          transitionDuration: Duration.zero, // 无过渡动画
          reverseTransitionDuration: Duration.zero,
          settings: const RouteSettings(name: '/main'),
        ),
      );
      debugPrint('🏠 [MAIN_APP] 主应用页面跳转完成');
    } catch (e) {
      debugPrint('🏠 [MAIN_APP] 导航到主应用页面时发生错误: $e');
    }
  }
}