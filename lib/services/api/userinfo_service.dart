import 'dart:convert';
import '../../models/userinfo_model.dart';
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
        throw Exception('HTTP错误: ${response.statusCode}');
      }

      final Map<String, dynamic> jsonData = json.decode(response.body);

      final int errNo = jsonData['errNo'] ?? -1;
      if (errNo != 0) {
        throw Exception('API错误: errNo=$errNo');
      }

      final dynamic dataJson = jsonData['data'];
      if (dataJson == null) {
        throw Exception('响应数据为空');
      }

      return UserInfoModel.fromMap(dataJson as Map<String, dynamic>);
    } catch (e) {
      if (e is Exception) {
        rethrow;
      }
      throw Exception('获取用户信息失败: $e');
    }
  }
}
