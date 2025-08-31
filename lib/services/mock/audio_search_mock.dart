import 'dart:math';
import '../../data/mock_data.dart';
import '../../models/audio_item.dart';
import '../../models/api_response.dart';

/// 音频搜索接口的Mock数据
class AudioSearchMock {
  /// 获取Mock音频搜索数据
  static Future<ApiResponse<SimpleResponse<AudioItem>>> getMockAudioSearchList({
    required String searchQuery,
    String? cid,
    int count = 10,
  }) async {
    try {
      // 模拟网络延迟
      await MockData.simulateNetworkDelay(Random().nextInt(800) + 200);

      final audioItems = MockData.getAudioItems(
        page: 1,
        pageSize: count,
        searchQuery: searchQuery,
        tags: null,
      );

      // 如果指定了 cid，从该 ID 开始查找
      List<AudioItem> filteredItems = audioItems;
      if (cid != null) {
        final allItems = MockData.getAllAudioItems();
        final cidIndex = allItems.indexWhere((item) => item.id == cid);
        if (cidIndex != -1 && cidIndex < allItems.length - 1) {
          // 从 cid 下一个位置开始，取 count 条数据
          final startIndex = cidIndex + 1;
          final endIndex = (startIndex + count).clamp(0, allItems.length);
          filteredItems = allItems.sublist(startIndex, endIndex);
        } else {
          // 如果找不到 cid 或已经是最后一条，返回空列表
          filteredItems = [];
        }
      }

      final simpleResponse = SimpleResponse<AudioItem>(items: filteredItems);

      // 随机模拟一些错误情况用于测试
      if (Random().nextDouble() < 0.05) {
        // 5% 概率失败
        return ApiResponse.error(errNo: 500);
      }

      return ApiResponse.success(data: simpleResponse, errNo: 0);
    } catch (e) {
      return ApiResponse.error(errNo: 500);
    }
  }
}
