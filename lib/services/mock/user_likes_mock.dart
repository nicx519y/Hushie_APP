import 'dart:math';
import '../../data/mock_data.dart';
import '../../models/audio_item.dart';
import '../../models/api_response.dart';

/// 用户喜欢音频接口的Mock数据
class UserLikesMock {
  /// 获取Mock用户喜欢音频数据
  static Future<ApiResponse<SimpleResponse<AudioItem>>> getMockUserLikedAudios({
    String? cid,
    int count = 20,
  }) async {
    try {
      await MockData.simulateNetworkDelay(300);

      // Mock 数据：返回一些示例喜欢的音频
      final likedAudios = [
        AudioItem(
          id: '1',
          cover: '',
          title: 'Music in the Wires - From A to Z ...',
          desc: 'The dark pop-rock track opens extended +22',
          author: 'Buddha',
          avatar: '',
          playTimes: 1300123,
          likesCount: 22933,
          previewStart: Duration(milliseconds: 30000), // 从30秒开始预览
          previewDuration: Duration(milliseconds: 15000), // 预览15秒
        ),
        AudioItem(
          id: '2',
          cover: '',
          title: 'Sticky Situation',
          desc: 'A female vocalist sings a monster related +19',
          author: 'Misha G',
          avatar: '',
          playTimes: 1303130,
          likesCount: 229312513,
          previewStart: Duration(milliseconds: 25000), // 从25秒开始预览
          previewDuration: Duration(milliseconds: 18000), // 预览18秒
        ),
        AudioItem(
          id: '3',
          cover: '',
          title: 'Matched Yours (rock) from Scratch',
          desc: 'Lo-fi, electronics, nostalgic, and reggaeton',
          author: 'ElJay',
          avatar: '',
          playTimes: 1300,
          likesCount: 2293,
          previewStart: Duration(milliseconds: 20000), // 从20秒开始预览
          previewDuration: Duration(milliseconds: 12000), // 预览12秒
        ),
        AudioItem(
          id: '4',
          cover: '',
          title: 'Matched Yours (rock) from Scratch',
          desc: 'Lo-fi, electronics, nostalgic, and reggaeton',
          author: 'ElJay',
          avatar: '',
          playTimes: 1300,
          likesCount: 2293,
          previewStart: Duration(milliseconds: 35000), // 从35秒开始预览
          previewDuration: Duration(milliseconds: 20000), // 预览20秒
        ),
      ];

      // 模拟从指定cid开始获取指定数量的音频
      List<AudioItem> resultAudios;
      if (cid != null && cid.isNotEmpty) {
        // 如果有cid，从该ID开始获取
        final startIndex = likedAudios.indexWhere((audio) => audio.id == cid);
        if (startIndex != -1) {
          final endIndex = (startIndex + count).clamp(0, likedAudios.length);
          resultAudios = likedAudios.sublist(startIndex, endIndex);
        } else {
          // 如果找不到指定cid，返回空列表
          resultAudios = [];
        }
      } else {
        // 如果没有cid，返回前count个
        resultAudios = likedAudios.take(count).toList();
      }

      final simpleResponse = SimpleResponse<AudioItem>(items: resultAudios);

      return ApiResponse.success(data: simpleResponse, errNo: 0);
    } catch (e) {
      return ApiResponse.error(errNo: 500);
    }
  }
}
