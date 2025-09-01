import 'dart:convert';
import '../../models/api_response.dart';
import '../../models/userinfo_model.dart';
import '../../config/api_config.dart';
import '../api_service.dart';
import '../mock/userinfo_mock.dart';
import '../http_client_service.dart';

/// 用户信息服务
class UserInfoService {
  static Duration get _defaultTimeout => ApiConfig.defaultTimeout;

  /// 获取用户信息
  static Future<ApiResponse<UserInfoModel>> getUserInfo() async {
    if (ApiService.currentMode == ApiMode.mock) {
      return UserInfoMock.getMockUserInfo();
    } else {
      return _getRealUserInfo();
    }
  }

  /// 真实接口 - 获取用户信息
  static Future<ApiResponse<UserInfoModel>> _getRealUserInfo() async {
    try {
      final uri = Uri.parse(ApiConfig.getFullUrl(ApiEndpoints.userInfo));

      final response = await HttpClientService.get(
        uri,
        timeout: _defaultTimeout,
      );

      if (response.statusCode == 200) {
        final Map<String, dynamic> jsonData = json.decode(response.body);

        // 使用统一的JSON处理函数
        return ApiResponse.fromJson(
          jsonData,
          (dataJson) => UserInfoModel.fromMap(dataJson),
        );
      } else {
        return ApiResponse.error(errNo: response.statusCode);
      }
    } catch (e) {
      return ApiResponse.error(errNo: -1);
    }
  }
}
