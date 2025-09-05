import 'dart:convert';
import '../../models/audio_item.dart';
import '../../config/api_config.dart';
import '../http_client_service.dart';

/// 用户喜欢音频服务
class UserLikesService {
  static Duration get _defaultTimeout => ApiConfig.defaultTimeout;

  /// 获取用户喜欢的音频列表
  static Future<List<AudioItem>> getUserLikedAudios({
    String? cid,
    int? count = 20,
  }) async {
    return _getRealUserLikedAudios(cid: cid, count: count ?? 20);
  }

  /// 真实接口 - 获取用户喜欢的音频列表
  static Future<List<AudioItem>> _getRealUserLikedAudios({
    String? cid,
    int count = 20,
  }) async {
    try {
      final queryParams = <String, String>{
        'count': count.toString(),
        'cid': cid ?? '',
      };

      final uri = Uri.parse(
        ApiConfig.getFullUrl(ApiEndpoints.userLikes),
      ).replace(queryParameters: queryParams);

      final response = await HttpClientService.get(
        uri,
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

      final dynamic dataJson = jsonData['data'];
      if (dataJson == null) {
        throw Exception('Response data is empty');
      }

      final List<dynamic> itemsData = dataJson['items'] ?? [];
      final List<AudioItem> likedAudios = itemsData
          .map((item) => AudioItem.fromMap(item as Map<String, dynamic>))
          .toList();

      return likedAudios;
    } catch (e) {
      if (e is Exception) {
        rethrow;
      }
      throw Exception('Failed to get user liked audios: $e');
    }
  }
}
