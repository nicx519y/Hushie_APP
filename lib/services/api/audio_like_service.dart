import 'dart:convert';
import '../../models/api_response.dart';
import '../../config/api_config.dart';
import '../api_service.dart';
import '../mock/audio_like_mock.dart';
import '../http_client_service.dart';

/// 音频点赞服务
class AudioLikeService {
  static Duration get _defaultTimeout => ApiConfig.defaultTimeout;

  /// 点赞/取消点赞音频
  static Future<ApiResponse<Map<String, dynamic>>> likeAudio({
    required String cid,
    required String action, // "like" | "unlike"
  }) async {
    if (ApiService.currentMode == ApiMode.mock) {
      return AudioLikeMock.getMockLikeResponse(cid: cid, action: action);
    } else {
      return _getRealLikeResponse(cid: cid, action: action);
    }
  }

  /// 真实接口 - 点赞/取消点赞音频
  static Future<ApiResponse<Map<String, dynamic>>> _getRealLikeResponse({
    required String cid,
    required String action,
  }) async {
    try {
      final uri = Uri.parse(ApiConfig.getFullUrl(ApiEndpoints.audioLike));

      // 构建请求体
      final requestBody = {'cid': cid, 'action': action};

      final response = await HttpClientService.post(
        uri,
        body: json.encode(requestBody),
        timeout: _defaultTimeout,
      );

      if (response.statusCode == 200) {
        final Map<String, dynamic> jsonData = json.decode(response.body);

        // 使用统一的JSON处理函数
        return ApiResponse.fromJson(
          jsonData,
          (dataJson) => dataJson, // 直接返回Map<String, dynamic>
        );
      } else {
        return ApiResponse.error(errNo: response.statusCode);
      }
    } catch (e) {
      return ApiResponse.error(errNo: -1);
    }
  }
}
