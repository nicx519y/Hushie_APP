import 'dart:convert';
import 'package:flutter/foundation.dart';
import '../../models/onboarding_model.dart';
import '../../models/api_response.dart';
import '../../config/api_config.dart';
import '../http_client_service.dart';

/// 新手引导服务
class OnboardingService {
  static Duration get _defaultTimeout => ApiConfig.defaultTimeout;

  /// 是否使用Mock模式（开发测试用）
  static bool _useMockMode = false; // 默认使用Mock模式

  /// 设置Mock模式
  static void setMockMode(bool enabled) {
    _useMockMode = enabled;
    debugPrint('🎯 [ONBOARDING] Mock模式: ${enabled ? '开启' : '关闭'}');
  }

  /// 获取新手引导数据
  /// 
  /// 返回包含性别、语调、场景等标签选项的引导数据
  /// 认证: 可选认证
  /// 必需头部: X-Device-ID (由HttpClientService自动添加)
  static Future<OnboardingGuideData> getGuideData() async {

    // 真实API调用
    try {
      final uri = Uri.parse(ApiConfig.getFullUrl(ApiEndpoints.onboardingGuideData));

      debugPrint('🎯 [ONBOARDING] GET $uri');

      final response = await HttpClientService.get(
        uri,
        timeout: _defaultTimeout,
      );

      debugPrint('🎯 [ONBOARDING] status: ${response.statusCode}');
      final Map<String, dynamic> jsonData = json.decode(response.body);
      debugPrint('🎯 [ONBOARDING] errNo: ${jsonData['errNo']}');

      // 使用ApiResponse统一处理响应
      final apiResponse = ApiResponse.fromJson<OnboardingGuideData>(
        jsonData,
        (dataJson) => OnboardingGuideData.fromMap(dataJson),
      );

      if (apiResponse.data == null) {
        throw Exception('API failed: errNo=${apiResponse.errNo}');
      }

      return apiResponse.data!;
    } catch (e) {
      debugPrint('🎯 [ONBOARDING] getGuideData error: $e');
      if (e is Exception) {
        rethrow;
      }
      throw Exception('Failed to get onboarding guide data: $e');
    }
  }

  /// 设置用户偏好
  /// 
  /// 保存用户偏好设置并生成个性化推荐列表
  /// 认证: 可选认证
  /// 必需头部: X-Device-ID (由HttpClientService自动添加)
  /// 
  /// 参数:
  /// - request: 包含用户选择的性别、语调、场景偏好
  static Future<UserPreferencesResponse> setPreferences(
    UserPreferencesRequest request,
  ) async {
    // Mock模式：返回成功响应
    if (_useMockMode) {
      debugPrint('🎯 [ONBOARDING] Mock模式设置偏好: $request');
      // 模拟网络延迟
      await Future.delayed(const Duration(milliseconds: 300));
      return UserPreferencesResponse(success: true);
    }

    // 真实API调用
    try {
      final uri = Uri.parse(ApiConfig.getFullUrl(ApiEndpoints.onboardingSetPreferences));

      debugPrint('🎯 [ONBOARDING] POST $uri');
      debugPrint('🎯 [ONBOARDING] request: $request');

      final response = await HttpClientService.postJson(
        uri,
        body: request.toMap(),
        timeout: _defaultTimeout,
      );

      debugPrint('🎯 [ONBOARDING] status: ${response.statusCode}');
      final Map<String, dynamic> jsonData = json.decode(response.body);
      debugPrint('🎯 [ONBOARDING] errNo: ${jsonData['errNo']}');

      // 使用ApiResponse统一处理响应
      final apiResponse = ApiResponse.fromJson<UserPreferencesResponse>(
        jsonData,
        (dataJson) => UserPreferencesResponse.fromMap(dataJson),
      );

      if (apiResponse.data == null) {
        throw Exception('API failed: errNo=${apiResponse.errNo}');
      }

      return apiResponse.data!;
    } catch (e) {
      debugPrint('🎯 [ONBOARDING] setPreferences error: $e');
      if (e is Exception) {
        rethrow;
      }
      throw Exception('Failed to set user preferences: $e');
    }
  }
}