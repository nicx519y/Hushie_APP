import 'dart:convert';
import '../../models/audio_item.dart';
import '../../models/api_response.dart';
import '../../config/api_config.dart';
import '../http_client_service.dart';

/// 音频详情服务
class AudioDetailService {
  static Duration get _defaultTimeout => ApiConfig.defaultTimeout;

  // 已移除假SRT数据构造函数，统一使用接口返回的真实数据。

  // 新增：音频详情内存缓存
  static final Map<String, AudioItem> _detailCache = {};
  // 新增：缓存条目最大数量限制
  static const int _maxCacheEntries = 10;

  // 新增：溢出时移除最早插入的条目（近似 FIFO）
  static void _enforceCacheLimit() {
    if (_detailCache.length <= _maxCacheEntries) return;
    final overflow = _detailCache.length - _maxCacheEntries;
    for (int i = 0; i < overflow; i++) {
      final String firstKey = _detailCache.keys.first;
      _detailCache.remove(firstKey);
    }
  }

  /// 获取缓存的音频详情（若存在）
  static AudioItem? getCachedDetail(String audioId) {
    return _detailCache[audioId];
  }

  /// 获取音频详情（优先返回缓存）
  static Future<AudioItem> getAudioDetail(String audioId) async {
    final cached = _detailCache[audioId];
    if (cached != null) {
      // 命中缓存时，移除并重新插入，保持较新的插入顺序（近似 LRU）
      _detailCache.remove(audioId);
      _detailCache[audioId] = cached;
      return cached;
    }
    final item = await _getRealAudioDetail(audioId);
    _detailCache[audioId] = item;
    _enforceCacheLimit();
    return item;
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