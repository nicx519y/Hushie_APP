import 'dart:convert';
import '../../models/tab_item.dart';
import '../../models/api_response.dart';
import '../../config/api_config.dart';
import '../http_client_service.dart';
import 'package:flutter/foundation.dart';

/// 首页Tabs服务
class HomeTabsService {
  static Duration get _defaultTimeout => ApiConfig.defaultTimeout;

  /// 获取首页tabs
  static Future<List<TabItemModel>> getHomeTabs() async {
    return _getRealHomeTabs();
  }

  /// 真实接口 - 获取首页tabs
  static Future<List<TabItemModel>> _getRealHomeTabs() async {
    try {
      debugPrint("开始获取 tabs 数据");

      final uri = Uri.parse(ApiConfig.getFullUrl(ApiEndpoints.homeTabs));

      final response = await HttpClientService.get(
        uri,
        timeout: _defaultTimeout,
      );
      debugPrint("获取 tabs 数据完成 $response");

      final Map<String, dynamic> jsonData = json.decode(response.body);
      debugPrint("🏠 [HOME_TABS] API响应成功，errNo: ${jsonData['errNo']}");

      final apiResponse = ApiResponse.fromJson<Map<String, dynamic>>(
        jsonData,
        (data) => data,
      );

      if (apiResponse.data == null) {
        throw Exception('API failed: errNo=${apiResponse.errNo}');
      }

      final Map<String, dynamic> data = apiResponse.data!;
      final List<dynamic> tabsData = data['tabs'] ?? [];

      // 读取并缓存预览音频配置（并列字段）
      bool? enabled;
      double? ratio;
      try {
        final dynamic enabledRaw = data['preview_audio_enabled'];
        if (enabledRaw is bool) {
          enabled = enabledRaw;
        } else if (enabledRaw is num) {
          enabled = enabledRaw != 0;
        } else if (enabledRaw is String) {
          final v = enabledRaw.trim().toLowerCase();
          if (v == 'true' || v == '1') enabled = true;
          if (v == 'false' || v == '0') enabled = false;
        }

        final dynamic ratioRaw = data['preview_audio_ratio'];
        if (ratioRaw is double) {
          ratio = ratioRaw;
        } else if (ratioRaw is int) {
          ratio = ratioRaw.toDouble();
        } else if (ratioRaw is String) {
          ratio = double.tryParse(ratioRaw);
        }
      } catch (e) {
        debugPrint('解析预览音频配置失败: $e');
      }

      await ApiConfig.setPreviewAudioConfig(
        enabled: enabled ?? ApiConfig.defaultPreviewAudioEnabled,
        ratio: ratio ?? ApiConfig.defaultPreviewAudioRatio,
      );
      final List<TabItemModel> tabs = tabsData
          .map((tab) => TabItemModel.fromMap(tab as Map<String, dynamic>))
          .toList();
      return tabs;
    } catch (e) {
      debugPrint("tabs 数据获取失败 $e");
      if (e is Exception) {
        rethrow;
      }
      throw Exception('Failed to get home tabs: $e');
    }
  }
}
