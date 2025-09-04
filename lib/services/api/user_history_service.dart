import 'dart:convert';
import '../../models/api_response.dart';
import '../../models/audio_item.dart';
import '../../config/api_config.dart';
import '../api_service.dart';
import '../mock/user_history_mock.dart';
import '../http_client_service.dart';

/// 用户播放历史服务
class UserHistoryService {
  static Duration get _defaultTimeout => ApiConfig.defaultTimeout;

  /// 获取用户播放历史列表
  static Future<UserHistoryResponse> getUserHistoryList() async {
    if (ApiService.currentMode == ApiMode.mock) {
      return UserHistoryMock.getMockUserHistoryList();
    } else {
      return _getRealUserHistoryList();
    }
  }

  /// 提交用户播放进度
  static Future<ApiResponse<UserHistoryResponse>> submitPlayProgress({
    required String audioId,
    required int playDurationMs,
    required int playProgressMs,
  }) async {
    if (ApiService.currentMode == ApiMode.mock) {
      return UserHistoryMock.submitMockPlayProgress(
        audioId: audioId,
        playDurationMs: playDurationMs,
        playProgressMs: playProgressMs,
      );
    } else {
      return _submitRealPlayProgress(
        audioId: audioId,
        playDurationMs: playDurationMs,
        playProgressMs: playProgressMs,
      );
    }
  }

  /// 真实接口 - 获取用户播放历史列表
  static Future<UserHistoryResponse> _getRealUserHistoryList() async {
    try {
      final uri = Uri.parse(ApiConfig.getFullUrl(ApiEndpoints.userHistoryList));

      final response = await HttpClientService.get(
        uri,
        timeout: _defaultTimeout,
      );

      if (response.statusCode == 200) {
        final Map<String, dynamic> jsonData = json.decode(response.body);

        return UserHistoryResponse.fromJson(
          (jsonData['history'] as List<dynamic>?)
                  ?.map(
                    (item) => AudioItem.fromMap(item as Map<String, dynamic>),
                  )
                  .toList() ??
              [],
        );
      } else {
        throw Exception('获取用户播放历史列表失败: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('获取用户播放历史列表失败: $e');
    }
  }

  /// 真实接口 - 提交用户播放进度
  static Future<ApiResponse<UserHistoryResponse>> _submitRealPlayProgress({
    required String audioId,
    required int playDurationMs,
    required int playProgressMs,
  }) async {
    try {
      final uri = Uri.parse(
        ApiConfig.getFullUrl(ApiEndpoints.userPlayProgress),
      );

      final requestBody = {
        "id": audioId,
        'play_duration_ms': playDurationMs,
        'play_progress_ms': playProgressMs,
      };

      final response = await HttpClientService.postJson(
        uri,
        body: requestBody,
        timeout: _defaultTimeout,
      );

      if (response.statusCode == 200 &&
          response.body.isNotEmpty &&
          json.decode(response.body)['errNo'] == 0) {
        final Map<String, dynamic> jsonData = json.decode(response.body);
        return ApiResponse.fromJson(
          jsonData,
          (data) => UserHistoryResponse.fromJson(
            (data['history'] as List<dynamic>?)
                    ?.map(
                      (item) => AudioItem.fromMap(item as Map<String, dynamic>),
                    )
                    .toList() ??
                [],
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
