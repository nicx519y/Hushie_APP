import 'package:flutter/foundation.dart';
import '../../config/api_config.dart';
import '../http_client_service.dart';

/// 追踪打点服务
class TrackingService {
  static Duration get _defaultTimeout => ApiConfig.defaultTimeout;

  /// 提交打点
  static Future<void> track({
    required String actionType,
    String? audioId,
    Map<String, dynamic>? extraData,
  }) async {
    await _postTracking(
      actionType: actionType,
      audioId: audioId,
      extraData: extraData,
    );
  }

  /// 真实接口 - 提交追踪打点
  static Future<void> _postTracking({
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
      // 不再关心响应体，只要请求成功即可
    } catch (e) {
      debugPrint('📍 [TRACKING] request error: $e');
      // 即使失败，也不向上抛出异常，避免影响主流程
    }
  }

  // ===================== 便捷方法与事件类型 =====================
  static Future<void> trackMembershipOverlay({
    required String scene,
  }) async {
    await track(
      actionType: TrackingEvents.membershipOverlayShow,
      extraData: {'scene': scene},
    );
  }

  // 登录触发（支持可选场景）
  static Future<void> trackSubscribeClickLogin({String? scene}) async {
    final extra = <String, dynamic>{'trigger': 'login'};
    if (scene != null && scene.isNotEmpty) {
      extra['scene'] = scene;
    }
    await track(
      actionType: TrackingEvents.subscribeClick,
      extraData: extra,
    );
  }

  // 支付触发（包含可选的基础计划/优惠）
  static Future<void> trackSubscribeClickPayment({
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
    await track(
      actionType: TrackingEvents.subscribeClick,
      extraData: extra,
    );
  }

  // 支付触发（支持场景）
  static Future<void> trackSubscribeClickPay({
    required String scene,
  }) async {
    await track(
      actionType: TrackingEvents.subscribeClick,
      extraData: {
        'trigger': 'payment',
        'scene': scene,
      },
    );
  }

  static Future<void> trackSubscribeFlowStart({
    String? productId,
    String? basePlanId,
    String? offerId,
    String? scene,
  }) async {
    final extra = {
      'product_id': productId,
      'base_plan_id': basePlanId,
      'offer_id': offerId,
      'scene': scene,
    };
    extra.removeWhere((key, value) => value == null);
    await track(actionType: TrackingEvents.subscribeFlowStart, extraData: extra);
  }

  static Future<void> trackSubscribeResult({
    required String status, // e.g. success, failed, canceled
    String? productId,
    String? basePlanId,
    String? offerId,
    String? purchaseToken,
    String? currency,
    String? price,
    String? errorMessage,
  }) async {
    final extra = {
      'status': status,
      'product_id': productId,
      'base_plan_id': basePlanId,
      'offer_id': offerId,
      'purchase_token': purchaseToken,
      'currency': currency,
      'price': price,
      'error_message': errorMessage,
    };
    extra.removeWhere((key, value) => value == null);
    await track(actionType: TrackingEvents.subscribeResult, extraData: extra);
  }
  // 主页进入后台（改为：应用进入后台）
  static Future<void> trackHomeBackground() async {
    await track(actionType: TrackingEvents.appBackground);
  }

  // 别名：与调用处命名一致
  static Future<void> trackHomeToBackground() async {
    await trackHomeBackground();
  }

  // 主页 Tab 点击
  static Future<void> trackHomepageTabTap(String tabName) async {
    await track(
      actionType: TrackingEvents.homepageTabTap,
      extraData: {'tab': tabName},
    );
  }

  // 别名：与调用处命名一致（命名参数）
  static Future<void> trackHomeTabTap({required String tabName}) async {
    await trackHomepageTabTap(tabName);
  }

  // 搜索输入（命名参数 keyword）
  static Future<void> trackSearchInput({
    required String keyword,
  }) async {
    await track(
      actionType: TrackingEvents.searchInput,
      extraData: {
        'query': keyword,
        'len': keyword.length,
      },
    );
  }

  // 搜索结果点击（仅 audioId）
  static Future<void> trackSearchResultTap(String audioId) async {
    await track(
      actionType: TrackingEvents.searchResultTap,
      audioId: audioId,
    );
  }

  // 搜索结果点击（包含 keyword 与 resultId）
  static Future<void> trackSearchResultClick({
    required String keyword,
    required String resultId,
  }) async {
    await track(
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
  static const String subscribeFlowStart = 'subscribe_flow_start';
  static const String subscribeResult = 'subscribe_result';
}