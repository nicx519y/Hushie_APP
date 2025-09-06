import 'dart:convert';
import '../../models/audio_item.dart';
import '../../config/api_config.dart';
import '../http_client_service.dart';

/// 用户播放历史服务
class UserHistoryService {
  static Duration get _defaultTimeout => ApiConfig.defaultTimeout;

  /// 获取用户播放历史列表
  static Future<List<AudioItem>> getUserHistoryList() async {
    return _getRealUserHistoryList();
  }

  /// 提交用户播放进度
  static Future<List<AudioItem>> submitPlayProgress({
    required String audioId,
    required int playDurationMs,
    required int playProgressMs,
  }) async {
    return _submitRealPlayProgress(
      audioId: audioId,
      playDurationMs: playDurationMs,
      playProgressMs: playProgressMs,
    );
  }

  /// 真实接口 - 获取用户播放历史列表
  static Future<List<AudioItem>> _getRealUserHistoryList() async {
    try {
      final queryParameters = {'count': '10000'};

      final baseUrl = ApiConfig.getFullUrl(ApiEndpoints.userHistoryList);

      Uri uri;
      try {
        final parsedUri = Uri.parse(baseUrl);
        uri = parsedUri.replace(queryParameters: queryParameters);
      } catch (e) {
        throw Exception('URI构建失败: $e');
      }

      final response = await HttpClientService.get(
        uri,
        timeout: _defaultTimeout,
      );

      if (response.statusCode != 200) {
        throw Exception('HTTP failed: ${response.statusCode}');
      }

      final Map<String, dynamic> jsonData = json.decode(response.body);

      final int errNo = jsonData['errNo'] ?? -1;
      if (errNo != 0) {
        throw Exception('API failed: errNo=$errNo');
      }

      final dynamic dataJson = jsonData['data'];
      if (dataJson == null) {
        throw Exception('Response data is empty');
      }

      // 检查history字段的类型
      final dynamic historyData = dataJson['history'];
      List<dynamic> itemsData = [];
      
      if (historyData is List) {
        itemsData = historyData;
      } else if (historyData is int) {
        // 如果返回的是int类型（可能表示数量或错误码），则返回空列表
        itemsData = [];
      } else {
        itemsData = [];
      }
      
      final List<AudioItem> historyItems = itemsData
          .map((item) => AudioItem.fromMap(item as Map<String, dynamic>))
          .toList();

      return historyItems;
    } catch (e) {
      if (e is Exception) {
        rethrow;
      }
      throw Exception('Failed to get user history: $e');
    }
  }

  /// 真实接口 - 提交用户播放进度
  static Future<List<AudioItem>> _submitRealPlayProgress({
    required String audioId,
    required int playDurationMs,
    required int playProgressMs,
  }) async {
    try {
      final uri = Uri.parse(
        ApiConfig.getFullUrl(ApiEndpoints.userPlayProgress),
      );

      final response = await HttpClientService.postJson(
        uri,
        body: {
          'id': audioId,
          'play_duration_ms': playDurationMs,
          'play_progress_ms': playProgressMs,
          'cid': '', //
          'count': 10000, // 默认全返回
        },
        timeout: _defaultTimeout,
      );

      if (response.statusCode != 200) {
        throw Exception('HTTP failed: ${response.statusCode}');
      }

      final Map<String, dynamic> jsonData = json.decode(response.body);

      final int errNo = jsonData['errNo'] ?? -1;
      if (errNo != 0) {
        throw Exception('API failed: errNo=$errNo');
      }

      final dynamic dataJson = jsonData['data'];
      if (dataJson == null) {
        throw Exception('Response data is empty');
      }

      // 检查history字段的类型
      final dynamic historyData = dataJson['history'];
      List<dynamic> itemsData = [];
      
      if (historyData is List) {
        itemsData = historyData;
      } else if (historyData is int) {
        // 如果返回的是int类型（可能表示数量或错误码），则返回空列表
        print('🎵 [HISTORY] 提交进度API返回的history字段是int类型: $historyData，返回空列表');
        itemsData = [];
      } else {
        print('🎵 [HISTORY] 提交进度API返回的history字段类型异常: ${historyData.runtimeType}，返回空列表');
        itemsData = [];
      }
      
      final List<AudioItem> historyItems = itemsData
          .map((item) => AudioItem.fromMap(item as Map<String, dynamic>))
          .toList();

      return historyItems;
    } catch (e) {
      if (e is Exception) {
        rethrow;
      }
      throw Exception('Failed to submit play progress: $e');
    }
  }
}
