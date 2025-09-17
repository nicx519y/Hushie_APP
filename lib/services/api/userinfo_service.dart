import 'dart:convert';
import '../../models/userinfo_model.dart';
import '../../models/api_response.dart';
import '../../config/api_config.dart';
import '../http_client_service.dart';

/// 用户信息服务
class UserInfoService {
  static Duration get _defaultTimeout => ApiConfig.defaultTimeout;

  /// 获取用户信息
  static Future<UserInfoModel> getUserInfo() async {
    return _getRealUserInfo();
  }

  /// 真实接口 - 获取用户信息
  static Future<UserInfoModel> _getRealUserInfo() async {
    try {
      final uri = Uri.parse(ApiConfig.getFullUrl(ApiEndpoints.userInfo));

      final response = await HttpClientService.get(
        uri,
        timeout: _defaultTimeout,
      );

      if (response.statusCode != 200) {
        throw Exception('HTTP failed: ${response.statusCode}');
      }

      // 使用ApiResponse统一处理响应
      final Map<String, dynamic> jsonData = json.decode(response.body);
      final apiResponse = ApiResponse.fromJson<UserInfoModel>(
        jsonData,
        (data) => UserInfoModel.fromMap(data),
      );

      if (apiResponse.errNo == 0 && apiResponse.data != null) {
        return apiResponse.data!;
      } else {
        throw Exception('API failed: errNo=${apiResponse.errNo}');
      }
    } catch (e) {
      if (e is Exception) {
        rethrow;
      }
      throw Exception('Failed to get user info: $e');
    }
  }
}
