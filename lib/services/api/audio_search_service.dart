import 'dart:convert';
import '../../models/audio_item.dart';
import '../../config/api_config.dart';
import '../http_client_service.dart';

/// 音频搜索服务
class AudioSearchService {
  static Duration get _defaultTimeout => ApiConfig.defaultTimeout;

  /// 搜索音频
  static Future<List<AudioItem>> searchAudio({
    required String query,
    String? cid,
    int count = 20,
  }) async {
    return _getRealAudioSearch(query: query, cid: cid, count: count);
  }

  /// 真实接口 - 搜索音频
  static Future<List<AudioItem>> _getRealAudioSearch({
    required String query,
    String? cid,
    int count = 20,
  }) async {
    try {
      final queryParams = <String, String>{
        'query': query,
        'cid': cid ?? '',
        'count': count.toString(),
      };

      final uri = Uri.parse(
        ApiConfig.getFullUrl(ApiEndpoints.audioSearch),
      ).replace(queryParameters: queryParams);

      final response = await HttpClientService.get(
        uri,
        timeout: _defaultTimeout,
      );

      if (response.statusCode != 200) {
        throw Exception('HTTP错误: ${response.statusCode}');
      }

      final Map<String, dynamic> jsonData = json.decode(response.body);

      final int errNo = jsonData['errNo'] ?? -1;
      if (errNo != 0) {
        throw Exception('API错误: errNo=$errNo');
      }

      final dynamic dataJson = jsonData['data'];
      if (dataJson == null) {
        throw Exception('响应数据为空');
      }

      final List<dynamic> itemsData = dataJson['items'] ?? [];
      final List<AudioItem> audioItems = itemsData
          .map((item) => AudioItem.fromMap(item as Map<String, dynamic>))
          .toList();

      return audioItems;
    } catch (e) {
      if (e is Exception) {
        rethrow;
      }
      throw Exception('搜索音频失败: $e');
    }
  }
}
