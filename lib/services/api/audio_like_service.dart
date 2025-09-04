import 'dart:convert';
import '../../config/api_config.dart';
import '../http_client_service.dart';

/// 音频点赞服务
class AudioLikeService {
  static Duration get _defaultTimeout => ApiConfig.defaultTimeout;

  /// 点赞或取消点赞音频
  static Future<Map<String, dynamic>> likeAudio({
    required String audioId,
    required bool isLiked,
  }) async {
    return _getRealLikeAudio(audioId: audioId, isLiked: isLiked);
  }

  /// 真实接口 - 点赞或取消点赞音频
  static Future<Map<String, dynamic>> _getRealLikeAudio({
    required String audioId,
    required bool isLiked,
  }) async {
    try {
      final uri = Uri.parse(ApiConfig.getFullUrl(ApiEndpoints.audioLike));

      final response = await HttpClientService.postJson(
        uri,
        body: {'cid': audioId, 'action': isLiked ? 'like' : 'unlike'},
        timeout: _defaultTimeout,
      );

      if (response.statusCode != 200) {
        throw Exception('HTTP failed: ${response.statusCode}');
      }

      final Map<String, dynamic> jsonData = json.decode(response.body);

      final int errNo = jsonData['errNo'] ?? -1;
      if (errNo != 0) {
        throw Exception('API failed: errNo=$errNo');
      }

      return jsonData['data'] ?? {};
    } catch (e) {
      if (e is Exception) {
        rethrow;
      }
      throw Exception('Audio like operation failed: $e');
    }
  }
}
