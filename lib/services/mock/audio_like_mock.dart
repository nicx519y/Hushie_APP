import 'dart:math';
import '../../models/api_response.dart';
import '../../config/api_config.dart';

/// 音频点赞Mock服务
class AudioLikeMock {
  static final Random _random = Random();

  /// 模拟点赞/取消点赞响应
  static Future<ApiResponse<Map<String, dynamic>>> getMockLikeResponse({
    required String cid,
    required String action,
  }) async {
    // 模拟网络延迟
    await Future.delayed(Duration(milliseconds: ApiConfig.mockNetworkDelayMs));

    // 模拟错误率
    if (_random.nextDouble() < ApiConfig.mockErrorRate) {
      return ApiResponse.error(errNo: 500);
    }

    // 验证参数
    if (cid.isEmpty) {
      return ApiResponse.error(errNo: 400);
    }

    if (action != 'like' && action != 'unlike') {
      return ApiResponse.error(errNo: 400);
    }

    // 模拟成功响应
    final responseData = {'cid': cid, 'likes_count': 124451, 'is_liked': true};

    return ApiResponse.success(data: responseData);
  }
}
