import 'dart:convert';
import '../../models/audio_item.dart';
import '../../models/api_response.dart';
import '../../config/api_config.dart';
import '../http_client_service.dart';

/// 音频列表服务
class AudioListService {
  static Duration get _defaultTimeout => ApiConfig.defaultTimeout;

  /// 获取音频列表
  static Future<List<AudioItem>> getAudioList({
    String? tag,
    String? cid,
    int count = 20,
  }) async {
    return _getRealAudioList(tag: tag, cid: cid, count: count);
  }

  /// 真实接口 - 获取音频列表
  static Future<List<AudioItem>> _getRealAudioList({
    String? tag,
    String? cid,
    int count = 20,
  }) async {
    try {
      final queryParams = <String, String>{'count': count.toString()};

      if (tag != null && tag.isNotEmpty) {
        queryParams['tag'] = tag;
      }

      if (cid != null && cid.isNotEmpty) {
        queryParams['cid'] = cid;
      }

      final uri = Uri.parse(
        ApiConfig.getFullUrl(ApiEndpoints.audioList),
      ).replace(queryParameters: queryParams);

      final response = await HttpClientService.get(
        uri,
        timeout: _defaultTimeout,
      );

      if (response.statusCode != 200) {
        throw Exception('HTTP failed: ${response.statusCode}');
      }

      final Map<String, dynamic> jsonData = json.decode(response.body);

      // 使用ApiResponse统一处理响应
      final apiResponse = ApiResponse.fromJson<Map<String, dynamic>>(
        jsonData,
        (data) => data,
      );

      if (apiResponse.errNo != 0 || apiResponse.data == null) {
        throw Exception('API failed: errNo=${apiResponse.errNo}');
      }

      final List<dynamic> itemsData = apiResponse.data!['items'] ?? [];
      final List<AudioItem> audioItems = itemsData
          .whereType<Map<String, dynamic>>()
          .map((item) => AudioItem.fromMap(item))
          .toList();

      return audioItems;
    } catch (e) {
      if (e is Exception) {
        rethrow;
      }
      throw Exception('Failed to get audio list: $e');
    }
  }
}
