import 'dart:convert';
import '../../models/tab_item.dart';
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

      if (response.statusCode != 200) {
        throw Exception('HTTP failed: ${response.statusCode}');
      }

      final Map<String, dynamic> jsonData = json.decode(response.body);
      debugPrint("🏠 [HOME_TABS] API响应成功，errNo: ${jsonData['errNo']}");

      final int errNo = jsonData['errNo'] ?? -1;
      if (errNo != 0) {
        throw Exception('API failed: errNo=$errNo');
      }

      final dynamic dataJson = jsonData['data'];
      if (dataJson == null) {
        throw Exception('Response data is empty');
      }

      final List<dynamic> tabsData = dataJson['tabs'] ?? [];
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
