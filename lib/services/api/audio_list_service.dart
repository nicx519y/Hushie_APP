import 'dart:convert';
import '../../models/api_response.dart';
import '../../models/audio_item.dart';
import '../../config/api_config.dart';
import '../api_service.dart';
import '../mock/audio_list_mock.dart';
import '../http_client_service.dart';

/// 音频列表服务
class AudioListService {
  static Duration get _defaultTimeout => ApiConfig.defaultTimeout;

  /// 获取音频列表
  static Future<ApiResponse<SimpleResponse<AudioItem>>> getAudioList({
    String? tag,
    String? cid,
    int count = 10,
  }) async {
    if (ApiService.currentMode == ApiMode.mock) {
      return AudioListMock.getMockAudioList(tag: tag, cid: cid, count: count);
    } else {
      return _getRealAudioList(tag: tag, cid: cid, count: count);
    }
  }

  /// 真实接口 - 获取音频列表
  static Future<ApiResponse<SimpleResponse<AudioItem>>> _getRealAudioList({
    String? tag,
    String? cid,
    int count = 10,
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
