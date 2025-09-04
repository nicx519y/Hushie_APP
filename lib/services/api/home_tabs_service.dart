import 'dart:convert';
import '../../models/tab_item.dart';
import '../../config/api_config.dart';
import '../http_client_service.dart';

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
      print("开始获取 tabs 数据");

      final uri = Uri.parse(ApiConfig.getFullUrl(ApiEndpoints.homeTabs));

      final response = await HttpClientService.get(
        uri,
        timeout: _defaultTimeout,
      );
      print("获取 tabs 数据完成 $response");

      if (response.statusCode != 200) {
        throw Exception('HTTP错误: ${response.statusCode}');
      }

      final Map<String, dynamic> jsonData = json.decode(response.body);
      print("Home tabs service : $jsonData");

      final int errNo = jsonData['errNo'] ?? -1;
      if (errNo != 0) {
        throw Exception('API错误: errNo=$errNo');
      }

      final dynamic dataJson = jsonData['data'];
      if (dataJson == null) {
        throw Exception('响应数据为空');
      }

      final List<dynamic> tabsData = dataJson['tabs'] ?? [];
      final List<TabItemModel> tabs = tabsData
          .map((tab) => TabItemModel.fromMap(tab as Map<String, dynamic>))
          .toList();
      return tabs;
    } catch (e) {
      print("tabs 数据获取失败 $e");
      if (e is Exception) {
        rethrow;
      }
      throw Exception('获取首页tabs失败: $e');
    }
  }
}
