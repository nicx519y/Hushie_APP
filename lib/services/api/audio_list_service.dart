import 'dart:convert';
import '../../models/audio_item.dart';
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

      final int errNo = jsonData['errNo'] ?? -1;
      if (errNo != 0) {
        throw Exception('API failed: errNo=$errNo');
      }

      final dynamic dataJson = jsonData['data'];
      if (dataJson == null) {
        throw Exception('Response data is empty');
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
      throw Exception('Failed to get audio list: $e');
    }
  }
}
