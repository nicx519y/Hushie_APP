import 'dart:convert';
import '../../models/api_response.dart';
import '../../models/tab_item.dart';
import '../../config/api_config.dart';
import '../api_service.dart';
import '../mock/home_tabs_mock.dart';
import '../http_client_service.dart';

/// 首页Tabs服务
class HomeTabsService {
  static Duration get _defaultTimeout => ApiConfig.defaultTimeout;

  /// 获取首页tabs
  static Future<ApiResponse<List<TabItemModel>>> getHomeTabs() async {
    if (ApiService.currentMode == ApiMode.mock) {
      return HomeTabsMock.getMockHomeTabs();
    } else {
      return _getRealHomeTabs();
    }
  }

  /// 真实接口 - 获取首页tabs
  static Future<ApiResponse<List<TabItemModel>>> _getRealHomeTabs() async {
    try {
      final uri = Uri.parse(ApiConfig.getFullUrl(ApiEndpoints.homeTabs));

      final response = await HttpClientService.get(
        uri,
        timeout: _defaultTimeout,
      );

      if (response.statusCode == 200) {
        final Map<String, dynamic> jsonData = json.decode(response.body);

        // 使用统一的JSON处理函数
        return ApiResponse.fromJson(jsonData, (dataJson) {
          final List<dynamic> tabsData = dataJson['tabs'] ?? [];
          final List<TabItemModel> tabs = tabsData
              .map((tab) => TabItemModel.fromMap(tab as Map<String, dynamic>))
              .toList();
          return tabs;
        });
      } else {
        return ApiResponse.error(errNo: response.statusCode);
      }
    } catch (e) {
      return ApiResponse.error(errNo: -1);
    }
  }
}
