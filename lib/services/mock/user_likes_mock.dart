import 'dart:math';
import '../../data/mock_data.dart';
import '../../models/audio_item.dart';
import '../../models/api_response.dart';
import '../../models/image_model.dart';

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
          cover: ImageModel(
            id: 'cover_liked_1',
            urls: ImageResolutions(
              x1: ImageResolution(
                url: 'https://picsum.photos/400/600?random=201',
                width: 400,
                height: 600,
              ),
              x2: ImageResolution(
                url: 'https://picsum.photos/800/1200?random=201',
                width: 800,
                height: 1200,
              ),
            ),
          ),
          title: 'Music in the Wires - From A to Z ...',
          desc: 'The dark pop-rock track opens extended +22',
          author: 'Buddha',
          avatar: '',
          playTimes: 1300123,
          likesCount: 22933,
          bgImage: ImageModel(
            id: 'bg_liked_1',
            urls: ImageResolutions(
              x1: ImageResolution(
                url: 'https://picsum.photos/800/600?random=301',
                width: 800,
                height: 600,
              ),
              x2: ImageResolution(
                url: 'https://picsum.photos/1600/1200?random=301',
                width: 1600,
                height: 1200,
              ),
            ),
          ),
          previewStart: Duration(milliseconds: 30000), // 从30秒开始预览
          previewDuration: Duration(milliseconds: 15000), // 预览15秒
        ),
        AudioItem(
          id: '2',
          cover: ImageModel(
            id: 'cover_liked_2',
            urls: ImageResolutions(
              x1: ImageResolution(
                url: 'https://picsum.photos/400/500?random=202',
                width: 400,
                height: 500,
              ),
              x2: ImageResolution(
                url: 'https://picsum.photos/800/1000?random=202',
                width: 800,
                height: 1000,
              ),
              x3: ImageResolution(
                url: 'https://picsum.photos/1200/1500?random=202',
                width: 1200,
                height: 1500,
              ),
            ),
          ),
          title: 'Sticky Situation',
          desc: 'A female vocalist sings a monster related +19',
          author: 'Misha G',
          avatar: '',
          playTimes: 1303130,
          likesCount: 229312513,
          bgImage: ImageModel(
            id: 'bg_liked_2',
            urls: ImageResolutions(
              x1: ImageResolution(
                url: 'https://picsum.photos/800/600?random=302',
                width: 800,
                height: 600,
              ),
              x2: ImageResolution(
                url: 'https://picsum.photos/1600/1200?random=302',
                width: 1600,
                height: 1200,
              ),
            ),
          ),
          previewStart: Duration(milliseconds: 25000), // 从25秒开始预览
          previewDuration: Duration(milliseconds: 18000), // 预览18秒
        ),
        AudioItem(
          id: '3',
          cover: ImageModel(
            id: 'cover_liked_3',
            urls: ImageResolutions(
              x1: ImageResolution(
                url: 'https://picsum.photos/400/700?random=203',
                width: 400,
                height: 700,
              ),
              x2: ImageResolution(
                url: 'https://picsum.photos/800/1400?random=203',
                width: 800,
                height: 1400,
              ),
            ),
          ),
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
          cover: ImageModel(
            id: 'cover_liked_4',
            urls: ImageResolutions(
              x1: ImageResolution(
                url: 'https://picsum.photos/400/480?random=204',
                width: 400,
                height: 480,
              ),
              x2: ImageResolution(
                url: 'https://picsum.photos/800/960?random=204',
                width: 800,
                height: 960,
              ),
              x3: ImageResolution(
                url: 'https://picsum.photos/1200/1440?random=204',
                width: 1200,
                height: 1440,
              ),
            ),
          ),
          title: 'Matched Yours (rock) from Scratch',
          desc: 'Lo-fi, electronics, nostalgic, and reggaeton',
          author: 'ElJay',
          avatar: '',
          playTimes: 1300,
          likesCount: 2293,
          bgImage: ImageModel(
            id: 'bg_liked_4',
            urls: ImageResolutions(
              x1: ImageResolution(
                url: 'https://picsum.photos/800/600?random=304',
                width: 800,
                height: 600,
              ),
              x2: ImageResolution(
                url: 'https://picsum.photos/1600/1200?random=304',
                width: 1600,
                height: 1200,
              ),
            ),
          ),
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
