import 'package:firebase_analytics/firebase_analytics.dart';
import 'package:flutter/foundation.dart';

/// Firebase Analytics 服务类
/// 提供统一的数据分析事件追踪接口
class AnalyticsService {
  static final AnalyticsService _instance = AnalyticsService._internal();
  factory AnalyticsService() => _instance;
  AnalyticsService._internal();

  late final FirebaseAnalytics _analytics;
  late final FirebaseAnalyticsObserver _observer;

  /// 初始化 Analytics 服务
  void initialize() {
    _analytics = FirebaseAnalytics.instance;
    _observer = FirebaseAnalyticsObserver(analytics: _analytics);
    debugPrint('📊 [ANALYTICS] Analytics服务初始化完成');
  }

  /// 获取 Analytics Observer，用于路由追踪
  FirebaseAnalyticsObserver get observer => _observer;

  /// 设置用户属性
  Future<void> setUserProperty({
    required String name,
    required String value,
  }) async {
    try {
      await _analytics.setUserProperty(name: name, value: value);
      debugPrint('📊 [ANALYTICS] 用户属性设置: $name = $value');
    } catch (e) {
      debugPrint('❌ [ANALYTICS] 用户属性设置失败: $e');
    }
  }

  /// 设置用户ID
  Future<void> setUserId(String userId) async {
    try {
      await _analytics.setUserId(id: userId);
      debugPrint('📊 [ANALYTICS] 用户ID设置: $userId');
    } catch (e) {
      debugPrint('❌ [ANALYTICS] 用户ID设置失败: $e');
    }
  }

  /// 记录页面访问事件
  Future<void> logScreenView({
    required String screenName,
    String? screenClass,
  }) async {
    try {
      await _analytics.logScreenView(
        screenName: screenName,
        screenClass: screenClass,
      );
      debugPrint('📊 [ANALYTICS] 页面访问: $screenName');
    } catch (e) {
      debugPrint('❌ [ANALYTICS] 页面访问记录失败: $e');
    }
  }

  /// 记录音频播放事件
  Future<void> logAudioPlay({
    required String audioId,
    required String audioTitle,
    String? category,
    int? duration,
  }) async {
    try {
      await _analytics.logEvent(
        name: 'audio_play',
        parameters: {
          'audio_id': audioId,
          'audio_title': audioTitle,
          if (category != null) 'category': category,
          if (duration != null) 'duration': duration,
        },
      );
      debugPrint('📊 [ANALYTICS] 音频播放: $audioTitle');
    } catch (e) {
      debugPrint('❌ [ANALYTICS] 音频播放事件记录失败: $e');
    }
  }

  /// 记录音频暂停事件
  Future<void> logAudioPause({
    required String audioId,
    required String audioTitle,
    int? position,
  }) async {
    try {
      await _analytics.logEvent(
        name: 'audio_pause',
        parameters: {
          'audio_id': audioId,
          'audio_title': audioTitle,
          if (position != null) 'position': position,
        },
      );
      debugPrint('📊 [ANALYTICS] 音频暂停: $audioTitle');
    } catch (e) {
      debugPrint('❌ [ANALYTICS] 音频暂停事件记录失败: $e');
    }
  }

  /// 记录音频完成事件
  Future<void> logAudioComplete({
    required String audioId,
    required String audioTitle,
    int? duration,
  }) async {
    try {
      await _analytics.logEvent(
        name: 'audio_complete',
        parameters: {
          'audio_id': audioId,
          'audio_title': audioTitle,
          if (duration != null) 'duration': duration,
        },
      );
      debugPrint('📊 [ANALYTICS] 音频完成: $audioTitle');
    } catch (e) {
      debugPrint('❌ [ANALYTICS] 音频完成事件记录失败: $e');
    }
  }

  /// 记录搜索事件
  Future<void> logSearch({
    required String searchTerm,
    int? resultCount,
  }) async {
    try {
      await _analytics.logSearch(
        searchTerm: searchTerm,
      );
      debugPrint('📊 [ANALYTICS] 搜索: $searchTerm');
    } catch (e) {
      debugPrint('❌ [ANALYTICS] 搜索事件记录失败: $e');
    }
  }

  /// 记录分享事件
  Future<void> logShare({
    required String contentType,
    required String itemId,
    String? method,
  }) async {
    try {
      await _analytics.logShare(
        contentType: contentType,
        itemId: itemId,
        method: method ?? 'unknown',
      );
      debugPrint('📊 [ANALYTICS] 分享: $contentType - $itemId');
    } catch (e) {
      debugPrint('❌ [ANALYTICS] 分享事件记录失败: $e');
    }
  }

  /// 记录登录事件
  Future<void> logLogin({
    required String loginMethod,
  }) async {
    try {
      await _analytics.logLogin(loginMethod: loginMethod);
      debugPrint('📊 [ANALYTICS] 登录: $loginMethod');
    } catch (e) {
      debugPrint('❌ [ANALYTICS] 登录事件记录失败: $e');
    }
  }

  /// 记录注册事件
  Future<void> logSignUp({
    required String signUpMethod,
  }) async {
    try {
      await _analytics.logSignUp(signUpMethod: signUpMethod);
      debugPrint('📊 [ANALYTICS] 注册: $signUpMethod');
    } catch (e) {
      debugPrint('❌ [ANALYTICS] 注册事件记录失败: $e');
    }
  }

  /// 记录音频点赞事件
  Future<void> logAudioLike({
    required String audioId,
    required String audioTitle,
    required bool isLiked,
  }) async {
    try {
      await _analytics.logEvent(
        name: 'audio_like',
        parameters: {
          'audio_id': audioId,
          'audio_title': audioTitle,
          'is_liked': isLiked,
        },
      );
      debugPrint('📊 [ANALYTICS] 音频点赞: $audioTitle');
    } catch (e) {
      debugPrint('❌ [ANALYTICS] 音频点赞事件记录失败: $e');
    }
  }

  /// 记录自定义事件
  Future<void> logCustomEvent({
    required String eventName,
    Map<String, Object>? parameters,
  }) async {
    try {
      await _analytics.logEvent(
        name: eventName,
        parameters: parameters,
      );
      debugPrint('📊 [ANALYTICS] 自定义事件: $eventName');
    } catch (e) {
      debugPrint('❌ [ANALYTICS] 自定义事件记录失败: $e');
    }
  }

  /// 记录应用启动事件
  Future<void> logAppOpen() async {
    try {
      await _analytics.logAppOpen();
      debugPrint('📊 [ANALYTICS] 应用启动');
    } catch (e) {
      debugPrint('❌ [ANALYTICS] 应用启动事件记录失败: $e');
    }
  }

  /// 记录错误事件
  Future<void> logError({
    required String errorType,
    required String errorMessage,
    String? stackTrace,
  }) async {
    try {
      await _analytics.logEvent(
        name: 'app_error',
        parameters: {
          'error_type': errorType,
          'error_message': errorMessage,
          if (stackTrace != null) 'stack_trace': stackTrace,
        },
      );
      debugPrint('📊 [ANALYTICS] 错误记录: $errorType');
    } catch (e) {
      debugPrint('❌ [ANALYTICS] 错误事件记录失败: $e');
    }
  }
}