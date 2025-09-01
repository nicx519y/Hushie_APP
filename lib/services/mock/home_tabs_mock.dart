import '../../data/mock_data.dart';
import '../../models/tab_item.dart';
import '../../models/api_response.dart';

/// 首页tabs接口的Mock数据
class HomeTabsMock {
  /// 获取Mock首页tabs数据
  static Future<ApiResponse<List<TabItemModel>>> getMockHomeTabs() async {
    try {
      await MockData.simulateNetworkDelay(300);

      // Mock 数据：返回一些示例 tabs
      final tabs = [
        const TabItemModel(id: 'mf', label: 'M/F'),
        const TabItemModel(id: 'fm', label: 'F/M'),
        const TabItemModel(id: 'asmr', label: 'ASMR'),
        const TabItemModel(id: 'nsfw', label: 'NSFW'),
        const TabItemModel(id: 'fmu', label: 'F/MU'),
        const TabItemModel(id: 'asmur', label: 'ASMUR'),
        const TabItemModel(id: 'nsfwsw', label: 'NSFWSW'),
      ];

      return ApiResponse.success(data: tabs, errNo: 0);
    } catch (e) {
      return ApiResponse.error(errNo: 500);
    }
  }
}
