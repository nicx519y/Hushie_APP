import 'dart:math';
import '../../data/mock_data.dart';
import '../../models/audio_item.dart';
import '../../models/api_response.dart';

/// 用户喜欢音频接口的Mock数据
class UserLikesMock {
  /// 获取Mock用户喜欢音频数据
  static Future<ApiResponse<PaginatedResponse<AudioItem>>>
  getMockUserLikedAudios({int page = 1, int pageSize = 20}) async {
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
        ),
      ];

      // 模拟分页
      final startIndex = (page - 1) * pageSize;
      final endIndex = startIndex + pageSize;
      final paginatedAudios = likedAudios.sublist(
        startIndex.clamp(0, likedAudios.length),
        endIndex.clamp(0, likedAudios.length),
      );

      final paginatedResponse = PaginatedResponse<AudioItem>(
        items: paginatedAudios,
        currentPage: page,
        totalPages: (likedAudios.length / pageSize).ceil(),
        totalItems: likedAudios.length,
        pageSize: pageSize,
        hasNextPage: endIndex < likedAudios.length,
        hasPreviousPage: page > 1,
      );

      return ApiResponse.success(data: paginatedResponse, errNo: 0);
    } catch (e) {
      return ApiResponse.error(errNo: 500);
    }
  }
}
