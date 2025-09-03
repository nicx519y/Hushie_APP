import 'dart:convert';
import '../../models/api_response.dart';
import '../../models/audio_item.dart';
import '../../config/api_config.dart';
import '../api_service.dart';
import '../mock/audio_search_mock.dart';
import '../http_client_service.dart';

/// 音频搜索服务
class AudioSearchService {
  static Duration get _defaultTimeout => ApiConfig.defaultTimeout;

  /// 搜索音频列表
  static Future<ApiResponse<SimpleResponse<AudioItem>>> getAudioSearchList({
    required String searchQuery,
    String? cid,
    int count = 20,
  }) async {
    if (ApiService.currentMode == ApiMode.mock) {
      return AudioSearchMock.getMockAudioSearchList(
        searchQuery: searchQuery,
        cid: cid,
        count: count,
      );
    } else {
      return _getRealAudioSearchList(
        searchQuery: searchQuery,
        cid: cid,
        count: count,
      );
    }
  }

  /// 真实接口 - 搜索音频列表
  static Future<ApiResponse<SimpleResponse<AudioItem>>>
  _getRealAudioSearchList({
    required String searchQuery,
    String? cid,
    int count = 20,
  }) async {
    try {
      final queryParams = <String, String>{
        'q': searchQuery,
        'count': count.toString(),
      };

      if (cid != null && cid.isNotEmpty) {
        queryParams['cid'] = cid;
      }

      final uri = Uri.parse(
        ApiConfig.getFullUrl(ApiEndpoints.audioSearch),
      ).replace(queryParameters: queryParams);

      final response = await HttpClientService.get(
        uri,
        timeout: _defaultTimeout,
      );

      if (response.statusCode == 200) {
        final Map<String, dynamic> jsonData = json.decode(response.body);

        // 使用统一的JSON处理函数
        return ApiResponse.fromJson(
          jsonData,
          (dataJson) => SimpleResponse<AudioItem>.fromMap(
            dataJson,
            (itemJson) => AudioItem.fromMap(itemJson),
          ),
        );
      } else {
        return ApiResponse.error(errNo: response.statusCode);
      }
    } catch (e) {
      return ApiResponse.error(errNo: -1);
    }
  }
}
