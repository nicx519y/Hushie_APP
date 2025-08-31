import 'dart:math';
import '../../data/mock_data.dart';
import '../../models/tab_item.dart';
import '../../models/api_response.dart';

/// 首页tabs接口的Mock数据
class HomeTabsMock {
  /// 获取Mock首页tabs数据
  static Future<ApiResponse<List<TabItem>>> getMockHomeTabs() async {
    try {
      await MockData.simulateNetworkDelay(300);

      // Mock 数据：返回一些示例 tabs
      final tabs = [
        const TabItem(id: 'mf', title: 'M/F', tag: 'M/F', order: 1),
        const TabItem(id: 'fm', title: 'F/M', tag: 'F/M', order: 2),
        const TabItem(id: 'asmr', title: 'ASMR', tag: 'ASMR', order: 3),
        const TabItem(id: 'nsfw', title: 'NSFW', tag: 'NSFW', order: 4),
        const TabItem(id: 'fmu', title: 'F/MU', tag: 'F/MU', order: 5),
        const TabItem(id: 'asmur', title: 'ASMUR', tag: 'ASMUR', order: 6),
        const TabItem(id: 'nsfwsw', title: 'NSFWSW', tag: 'NSFWSW', order: 7),
      ];

      return ApiResponse.success(data: tabs, errNo: 0);
    } catch (e) {
      return ApiResponse.error(errNo: 500);
    }
  }
}
