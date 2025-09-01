import 'dart:math';
import '../../data/mock_data.dart';
import '../../models/audio_item.dart';
import '../../models/api_response.dart';

/// 音频列表接口的Mock数据
class AudioListMock {
  /// 获取Mock音频列表数据
  static Future<ApiResponse<SimpleResponse<AudioItem>>> getMockAudioList({
    String? tag,
    String? cid,
    int count = 10,
  }) async {
    try {
      // 模拟网络延迟
      await MockData.simulateNetworkDelay(Random().nextInt(800) + 200);

      // 简化逻辑：直接返回所有mock数据
      final allItems = MockData.getAllAudioItems();
      final simpleResponse = SimpleResponse<AudioItem>(items: allItems);

      return ApiResponse.success(data: simpleResponse, errNo: 0);
    } catch (e) {
      return ApiResponse.error(errNo: 500);
    }
  }
}
