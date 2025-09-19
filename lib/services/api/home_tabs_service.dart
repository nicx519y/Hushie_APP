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

      final List<dynamic> tabsData = apiResponse.data!['tabs'] ?? [];
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
