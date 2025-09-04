import 'dart:math';
import '../../data/mock_data.dart';
import '../../models/audio_item.dart';
import '../../models/api_response.dart';

/// 用户播放历史接口的Mock数据
class UserHistoryMock {
  static const int _totalMockHistoryItems = 20; // 模拟历史记录数量

  /// 获取Mock用户播放历史数据
  static Future<ApiResponse<UserHistoryResponse>>
  getMockUserHistoryList() async {
    try {
      // 模拟网络延迟
      await MockData.simulateNetworkDelay(Random().nextInt(800) + 200);

      // 获取基础mock数据
      final baseItems = MockData.getAllAudioItems();

      // 生成播放历史数据（包含播放进度信息）
      final historyItems = _generateHistoryItems(baseItems);

      final historyResponse = UserHistoryResponse(history: historyItems);
      return ApiResponse.success(data: historyResponse, errNo: 0);
    } catch (e) {
      return ApiResponse.error(errNo: 500);
    }
  }

  /// 提交Mock播放进度
  static Future<ApiResponse<UserHistoryResponse>> submitMockPlayProgress({
    required String audioId,
    required int playDurationMs,
    required int playProgressMs,
  }) async {
    try {
      // 模拟网络延迟
      await MockData.simulateNetworkDelay(Random().nextInt(500) + 100);

      // 模拟提交成功
      // print('Mock: 提交播放进度 - AudioId: $audioId, Duration: ${playDurationMs}ms, Progress: ${playProgressMs}ms');

      return ApiResponse.success(
        data: UserHistoryResponse(
          history: _generateHistoryItems(MockData.getAllAudioItems()),
        ),
        errNo: 0,
      );
    } catch (e) {
      return ApiResponse.error(errNo: 500);
    }
  }

  /// 生成播放历史数据
  static List<AudioItem> _generateHistoryItems(List<AudioItem> baseItems) {
    final Random random = Random();
    final List<AudioItem> historyItems = [];

    // 从基础数据中随机选择一些作为历史记录
    final selectedItems = baseItems.take(_totalMockHistoryItems).toList();

    for (int i = 0; i < selectedItems.length; i++) {
      final baseItem = selectedItems[i];

      // 生成播放进度信息
      final totalDuration =
          int.tryParse(baseItem.duration ?? '180000') ?? 180000; // 默认3分钟
      final playProgressMs = random.nextInt(totalDuration); // 随机播放进度
      final playDurationMs = random.nextInt(playProgressMs + 1); // 播放时长不超过进度

      // 创建包含播放历史信息的音频项
      final historyItem = AudioItem(
        id: baseItem.id,
        cover: baseItem.cover,
        bgImage: baseItem.bgImage,
        title: baseItem.title,
        desc: baseItem.desc,
        author: baseItem.author,
        avatar: baseItem.avatar,
        playTimes: baseItem.playTimes,
        likesCount: baseItem.likesCount,
        audioUrl: baseItem.audioUrl,
        duration: baseItem.duration,
        createdAt: baseItem.createdAt,
        tags: baseItem.tags,
        playbackPosition: Duration(milliseconds: playProgressMs), // 播放进度位置
        lastPlayedAt: DateTime.now().subtract(
          Duration(milliseconds: random.nextInt(86400000)),
        ), // 最近播放时间（24小时内）
        previewStart: baseItem.previewStart,
        previewDuration: baseItem.previewDuration,
        isLiked: random.nextBool(), // 随机点赞状态
      );

      historyItems.add(historyItem);
    }

    // 按最后播放时间排序（最新的在前）
    historyItems.sort(
      (a, b) =>
          (b.lastPlayedAt?.compareTo(a.lastPlayedAt ?? DateTime.now()) ?? 0),
    );

    return historyItems;
  }
}
