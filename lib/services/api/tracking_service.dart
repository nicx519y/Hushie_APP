import 'dart:convert';
import 'package:flutter/foundation.dart';
import '../../models/api_response.dart';
import '../../config/api_config.dart';
import '../http_client_service.dart';

/// 追踪打点服务
class TrackingService {
  static Duration get _defaultTimeout => ApiConfig.defaultTimeout;

  /// 提交打点
  ///
  /// 参数说明：
  /// - actionType: 必需，行为类型
  /// - audioId: 可选，音频ID（音频相关行为时使用）
  /// - extraData: 可选，额外数据（JSON 对象）
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

      // 构建请求体（只包含有效字段）
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

      // 统一响应处理
      return ApiResponse.fromJson<TrackingResponse>(
        jsonData,
        (dataJson) => TrackingResponse.fromMap(dataJson),
      );
    } catch (e) {
      debugPrint('📍 [TRACKING] request error: $e');
      return ApiResponse.error(errNo: -1);
    }
  }
}

/// Tracking 响应模型
class TrackingResponse {
  final String message;

  TrackingResponse({required this.message});

  factory TrackingResponse.fromMap(Map<String, dynamic> map) {
    return TrackingResponse(
      message: map['message'] ?? '',
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'message': message,
    };
  }

  @override
  String toString() => 'TrackingResponse(message: $message)';
}