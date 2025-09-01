import 'dart:math';
import '../../data/mock_data.dart';
import '../../models/audio_item.dart';
import '../../models/api_response.dart';

/// 音频列表接口的Mock数据
class AudioListMock {
  static const int _totalMockItems = 100; // 模拟总共有100条数据
  static final Map<String, int> _lastIndexMap = {}; // 记录每个tag的最后索引

  /// 获取Mock音频列表数据
  static Future<ApiResponse<SimpleResponse<AudioItem>>> getMockAudioList({
    String? tag,
    String? cid,
    int count = 10,
  }) async {
    try {
      // 模拟网络延迟
      await MockData.simulateNetworkDelay(Random().nextInt(800) + 200);

      // 获取基础mock数据
      final baseItems = MockData.getAllAudioItems();

      // 生成分页数据
      final paginatedItems = _generatePaginatedItems(
        baseItems: baseItems,
        tag: tag,
        cid: cid,
        count: count,
      );

      final simpleResponse = SimpleResponse<AudioItem>(items: paginatedItems);
      return ApiResponse.success(data: simpleResponse, errNo: 0);
    } catch (e) {
      return ApiResponse.error(errNo: 500);
    }
  }

  /// 生成分页数据
  static List<AudioItem> _generatePaginatedItems({
    required List<AudioItem> baseItems,
    String? tag,
    String? cid,
    required int count,
  }) {
    final String cacheKey = tag ?? 'default';
    int startIndex = 0;

    // 如果提供了cid，找到对应的起始位置
    if (cid != null && cid.isNotEmpty) {
      // 在已生成的数据中找到cid对应的位置
      final existingIndex = _lastIndexMap[cacheKey] ?? 0;
      startIndex = existingIndex;
    } else {
      // 重置分页
      _lastIndexMap[cacheKey] = 0;
      startIndex = 0;
    }

    List<AudioItem> result = [];
    final Random random = Random(startIndex); // 使用startIndex作为随机种子确保一致性

    for (int i = 0; i < count && startIndex + i < _totalMockItems; i++) {
      final baseItem = baseItems[i % baseItems.length];

      // 创建唯一的ID和数据
      final uniqueId = '${baseItem.id}_page_${startIndex + i}';
      final modifiedItem = AudioItem(
        id: uniqueId,
        cover: baseItem.cover,
        bgImage: baseItem.bgImage,
        title: '${baseItem.title} #${startIndex + i + 1}',
        desc: baseItem.desc,
        author: baseItem.author,
        avatar: baseItem.avatar,
        playTimes: baseItem.playTimes + random.nextInt(10000),
        likesCount: baseItem.likesCount + random.nextInt(1000),
        audioUrl: baseItem.audioUrl,
        duration: baseItem.duration,
        createdAt: baseItem.createdAt,
        tags: baseItem.tags,
        playbackPosition: baseItem.playbackPosition,
        lastPlayedAt: baseItem.lastPlayedAt,
        previewStart: baseItem.previewStart,
        previewDuration: baseItem.previewDuration,
      );

      result.add(modifiedItem);
    }

    // 更新最后索引
    _lastIndexMap[cacheKey] = startIndex + result.length;

    return result;
  }
}
