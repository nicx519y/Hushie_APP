import 'dart:convert';
import 'package:flutter/foundation.dart';
import '../../models/api_response.dart';
import '../../config/api_config.dart';
import '../http_client_service.dart';

/// 追踪打点服务
class TrackingService {
  static Duration get _defaultTimeout => ApiConfig.defaultTimeout;

  /// 提交打点
  static Future<ApiResponse<TrackingResponse>> track({
    required String actionType,
    String? audioId,
    Map<String, dynamic>? extraData,
  }) async {
    return _postTracking(
      actionType: actionType,
      audioId: audioId,
      extraData: extraData,
    );
  }

  /// 真实接口 - 提交追踪打点
  static Future<ApiResponse<TrackingResponse>> _postTracking({
    required String actionType,
    String? audioId,
    Map<String, dynamic>? extraData,
  }) async {
    try {
      final uri = Uri.parse(ApiConfig.getFullUrl(ApiEndpoints.tracking));

      final Map<String, dynamic> body = {
        'action_type': actionType,
      };
      if (audioId != null) body['audio_id'] = audioId;
      if (extraData != null) body['extra_data'] = extraData;

      debugPrint('📍 [TRACKING] POST $uri');
      debugPrint('📍 [TRACKING] body keys: ${body.keys.toList()}');

      final response = await HttpClientService.postJson(
        uri,
        body: body,
        timeout: _defaultTimeout,
      );

      debugPrint('📍 [TRACKING] status: ${response.statusCode}');
      final Map<String, dynamic> jsonData = json.decode(response.body);
      debugPrint('📍 [TRACKING] errNo: ${jsonData['errNo']}');

      return ApiResponse.fromJson<TrackingResponse>(
        jsonData,
        (dataJson) => TrackingResponse.fromMap(dataJson),
      );
    } catch (e) {
      debugPrint('📍 [TRACKING] request error: $e');
      return ApiResponse.error(errNo: -1);
    }
  }

  // ===================== 便捷方法与事件类型 =====================
  static Future<ApiResponse<TrackingResponse>> trackMembershipOverlay({
    required String scene,
  }) async {
    return track(
      actionType: TrackingEvents.membershipOverlayShow,
      extraData: {'scene': scene},
    );
  }

  // 登录触发（支持可选场景）
  static Future<ApiResponse<TrackingResponse>> trackSubscribeClickLogin({String? scene}) async {
    final extra = <String, dynamic>{'trigger': 'login'};
    if (scene != null && scene.isNotEmpty) {
      extra['scene'] = scene;
    }
    return track(
      actionType: TrackingEvents.subscribeClick,
      extraData: extra,
    );
  }

  // 支付触发（包含可选的基础计划/优惠）
  static Future<ApiResponse<TrackingResponse>> trackSubscribeClickPayment({
    String? basePlanId,
    String? offerId,
  }) async {
    final extra = <String, dynamic>{'trigger': 'payment'};
    if (basePlanId != null && basePlanId.isNotEmpty) {
      extra['base_plan_id'] = basePlanId;
    }
    if (offerId != null && offerId.isNotEmpty) {
      extra['offer_id'] = offerId;
    }
    return track(
      actionType: TrackingEvents.subscribeClick,
      extraData: extra,
    );
  }

  // 支付触发（支持场景）
  static Future<ApiResponse<TrackingResponse>> trackSubscribeClickPay({
    required String scene,
  }) async {
    return track(
      actionType: TrackingEvents.subscribeClick,
      extraData: {
        'trigger': 'payment',
        'scene': scene,
      },
    );
  }

  // 主页进入后台（改为：应用进入后台）
  static Future<ApiResponse<TrackingResponse>> trackHomeBackground() async {
    return track(actionType: TrackingEvents.appBackground);
  }

  // 别名：与调用处命名一致
  static Future<ApiResponse<TrackingResponse>> trackHomeToBackground() async {
    return trackHomeBackground();
  }

  // 主页 Tab 点击
  static Future<ApiResponse<TrackingResponse>> trackHomepageTabTap(String tabName) async {
    return track(
      actionType: TrackingEvents.homepageTabTap,
      extraData: {'tab': tabName},
    );
  }

  // 别名：与调用处命名一致（命名参数）
  static Future<ApiResponse<TrackingResponse>> trackHomeTabTap({required String tabName}) async {
    return trackHomepageTabTap(tabName);
  }

  // 搜索输入（命名参数 keyword）
  static Future<ApiResponse<TrackingResponse>> trackSearchInput({
    required String keyword,
  }) async {
    return track(
      actionType: TrackingEvents.searchInput,
      extraData: {
        'query': keyword,
        'len': keyword.length,
      },
    );
  }

  // 搜索结果点击（仅 audioId）
  static Future<ApiResponse<TrackingResponse>> trackSearchResultTap(String audioId) async {
    return track(
      actionType: TrackingEvents.searchResultTap,
      audioId: audioId,
    );
  }

  // 搜索结果点击（包含 keyword 与 resultId）
  static Future<ApiResponse<TrackingResponse>> trackSearchResultClick({
    required String keyword,
    required String resultId,
  }) async {
    return track(
      actionType: TrackingEvents.searchResultTap,
      audioId: resultId,
      extraData: {'query': keyword},
    );
  }
}

/// Tracking 事件常量
class TrackingEvents {
  static const String membershipOverlayShow = 'membership_overlay_show';
  static const String subscribeClick = 'subscribe_click';
  static const String appBackground = 'app_background';
  static const String searchInput = 'search_input';
  static const String searchResultTap = 'search_result_tap';
  static const String homepageTabTap = 'homepage_tab_tap';
}

/// Tracking 响应模型
class TrackingResponse {
  final String message;

  TrackingResponse({required this.message});

  factory TrackingResponse.fromMap(Map<String, dynamic> map) {
    return TrackingResponse(message: map['message'] ?? '');
  }

  Map<String, dynamic> toMap() {
    return {'message': message};
  }

  @override
  String toString() => 'TrackingResponse(message: $message)';
}