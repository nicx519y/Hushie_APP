import 'package:flutter/material.dart';
import '../pages/login_page.dart';
import '../pages/audio_player_page.dart';
import '../pages/setting_page.dart';
import '../pages/account_page.dart';
import '../pages/about_us_page.dart';
import '../pages/search_page.dart';
import '../models/audio_item.dart';

class NavigationUtils {
  // 记录当前是否已经打开了登录页面
  static bool _isLoginPageOpen = false;
  
  /// 确保同时只能打开一个登录页面实例
  static Future<void> navigateToLogin(BuildContext context) async {
    // 如果登录页面已经打开，直接返回
    if (_isLoginPageOpen) {
      debugPrint('🔐 [LOGIN] 登录页面已经打开，忽略重复导航');
      return;
    }
    
    // 检查当前路由是否已经是登录页面
    final currentRoute = ModalRoute.of(context);
    if (currentRoute?.settings.name == '/login') {
      debugPrint('🔐 [LOGIN] 当前已在登录页面，忽略重复导航');
      return;
    }
    
    // 标记登录页面为打开状态
    _isLoginPageOpen = true;
    
    try {
      debugPrint('🔐 [LOGIN] 打开登录页面');
      // 导航到登录页面
      await Navigator.of(context, rootNavigator: true).push(
        MaterialPageRoute(
          builder: (context) => const LoginPage(),
          settings: const RouteSettings(name: '/login'),
        ),
      );
      debugPrint('🔐 [LOGIN] 登录页面已关闭');
    } catch (e) {
      debugPrint('🔐 [LOGIN] 导航到登录页面时发生错误: $e');
    } finally {
      // 页面关闭后重置状态
      _isLoginPageOpen = false;
    }
  }
  
  /// 检查登录页面是否已经打开
  static bool get isLoginPageOpen => _isLoginPageOpen;
  
  /// 手动重置登录页面状态（在特殊情况下使用）
  static void resetLoginPageState() {
    _isLoginPageOpen = false;
    debugPrint('🔐 [LOGIN] 手动重置登录页面状态');
  }
  
  /// 导航到音频播放器页面
  /// 使用上滑动画效果
  /// [initialAudio] 可选的初始音频，如果提供则会自动播放该音频
  static Future<T?> navigateToAudioPlayer<T extends Object?>(BuildContext context, {AudioItem? initialAudio}) async {
    try {
      debugPrint('🎵 [AUDIO_PLAYER] 打开音频播放器页面${initialAudio != null ? '，初始音频: ${initialAudio.title}' : ''}');
      return await Navigator.of(context, rootNavigator: true).push(
        SlideUpPageRoute(page: AudioPlayerPage(initialAudio: initialAudio)),
      );
    } catch (e) {
      debugPrint('🎵 [AUDIO_PLAYER] 导航到音频播放器页面时发生错误: $e');
      return null;
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