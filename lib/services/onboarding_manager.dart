import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// 新手引导管理服务
/// 负责管理新手引导的完成状态
class OnboardingManager {
  static final OnboardingManager _instance = OnboardingManager._internal();
  factory OnboardingManager() => _instance;
  OnboardingManager._internal();

  static const String _onboardingCompletedKey = 'onboarding_completed';
  bool? _isCompleted;

  /// 检查新手引导是否已完成
  Future<bool> isOnboardingCompleted() async {
    if (_isCompleted != null) {
      return _isCompleted!;
    }

    try {
      final prefs = await SharedPreferences.getInstance();
      _isCompleted = prefs.getBool(_onboardingCompletedKey) ?? false;
      debugPrint('🎯 [ONBOARDING] 检查引导状态: ${_isCompleted! ? '已完成' : '未完成'}');
      return _isCompleted!;
    } catch (e) {
      debugPrint('🎯 [ONBOARDING] 检查引导状态失败: $e');
      _isCompleted = false;
      return false;
    }
  }

  /// 标记新手引导为已完成
  Future<void> markOnboardingCompleted() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_onboardingCompletedKey, true);
      _isCompleted = true;
      debugPrint('🎯 [ONBOARDING] 已标记引导完成');
    } catch (e) {
      debugPrint('🎯 [ONBOARDING] 标记引导完成失败: $e');
    }
  }

  /// 重置新手引导状态（用于测试）
  Future<void> resetOnboardingStatus() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_onboardingCompletedKey, false);
      _isCompleted = false;
      debugPrint('🎯 [ONBOARDING] 已重置引导状态');
    } catch (e) {
      debugPrint('🎯 [ONBOARDING] 重置引导状态失败: $e');
    }
  }

  /// 清除缓存状态（强制重新检查）
  void clearCache() {
    _isCompleted = null;
  }
}