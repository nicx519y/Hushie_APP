import 'dart:convert';
import '../../models/audio_item.dart';
import '../../models/api_response.dart';
import '../../config/api_config.dart';
import '../http_client_service.dart';

/// 音频详情服务
class AudioDetailService {
  static Duration get _defaultTimeout => ApiConfig.defaultTimeout;

  /// 获取音频详情
  static Future<AudioItem> getAudioDetail(String audioId) async {
    return _getRealAudioDetail(audioId);
  }

  /// 真实接口 - 获取音频详情
  static Future<AudioItem> _getRealAudioDetail(String audioId) async {
    try {
      if (audioId.isEmpty) {
        throw Exception('Audio ID cannot be empty');
      }

      final uri = Uri.parse(
        ApiConfig.getFullUrl('${ApiEndpoints.audioDetail}/$audioId'),
      );

      final response = await HttpClientService.get(
        uri,
        timeout: _defaultTimeout,
      );

      final Map<String, dynamic> jsonData = json.decode(response.body);

      // 使用ApiResponse统一处理响应
      final apiResponse = ApiResponse.fromJson<AudioItem>(
        jsonData,
        (data) => AudioItem.fromMap(data),
      );

      if (apiResponse.data != null) {
        return apiResponse.data!;
      } else {
        throw Exception('API failed: errNo=${apiResponse.errNo}');
      }
    } catch (e) {
      if (e is Exception) {
        rethrow;
      }
      throw Exception('Failed to get audio detail: $e');
    }
  }
}