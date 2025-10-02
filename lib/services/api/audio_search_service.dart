import 'dart:convert';
import '../../models/audio_item.dart';
import '../../models/api_response.dart';
import '../../config/api_config.dart';
import '../http_client_service.dart';
import '../performance_service.dart';
import 'package:firebase_performance/firebase_performance.dart';

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
    Trace? trace;
    final startMs = DateTime.now().millisecondsSinceEpoch;
    try {
      trace = await PerformanceService().startTrace('audio_search');
      trace?.putAttribute('query', query);
      if (cid != null && cid.isNotEmpty) trace?.putAttribute('cid', cid);
      trace?.putAttribute('count', '$count');
      final queryParams = <String, String>{
        'q': query,
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

      final Map<String, dynamic> jsonData = json.decode(response.body);

      final apiResponse = ApiResponse.fromJson<Map<String, dynamic>>(
        jsonData,
        (data) => data,
      );

      if (apiResponse.data == null) {
        throw Exception('API failed: errNo=${apiResponse.errNo}');
      }

      final List<dynamic> itemsData = apiResponse.data!['items'] ?? [];
      final List<AudioItem> audioItems = itemsData
          .map((item) => AudioItem.fromMap(item as Map<String, dynamic>))
          .toList();

      final elapsed = DateTime.now().millisecondsSinceEpoch - startMs;
      trace?.setMetric('elapsed_ms', elapsed);
      trace?.setMetric('item_count', audioItems.length);
      await PerformanceService().stopTrace(trace);

      return audioItems;
    } catch (e) {
      if (e is Exception) {
        rethrow;
      }
      throw Exception('Failed to search audio: $e');
    } finally {
      await PerformanceService().stopTrace(trace);
    }
  }
}
