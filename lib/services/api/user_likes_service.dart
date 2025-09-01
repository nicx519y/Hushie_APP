import 'dart:convert';
import '../../models/api_response.dart';
import '../../models/audio_item.dart';
import '../../config/api_config.dart';
import '../api_service.dart';
import '../mock/user_likes_mock.dart';
import '../http_client_service.dart';

/// 用户喜欢音频服务
class UserLikesService {
  static Duration get _defaultTimeout => ApiConfig.defaultTimeout;

  /// 获取用户喜欢的音频列表
  static Future<ApiResponse<SimpleResponse<AudioItem>>> getUserLikedAudios({
    String? cid,
    int count = 20,
  }) async {
    if (ApiService.currentMode == ApiMode.mock) {
      return UserLikesMock.getMockUserLikedAudios(cid: cid, count: count);
    } else {
      return _getRealUserLikedAudios(cid: cid, count: count);
    }
  }

  /// 真实接口 - 获取用户喜欢的音频列表
  static Future<ApiResponse<SimpleResponse<AudioItem>>>
  _getRealUserLikedAudios({String? cid, int count = 20}) async {
    try {
      final queryParams = <String, String>{'count': count.toString()};

      if (cid != null && cid.isNotEmpty) {
        queryParams['cid'] = cid;
      }

      final uri = Uri.parse(
        ApiConfig.getFullUrl(ApiEndpoints.userLikes),
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
