import 'dart:math';
import '../../models/api_response.dart';
import '../../models/userinfo_model.dart';
import '../../config/api_config.dart';

/// 用户信息Mock服务
class UserInfoMock {
  static final Random _random = Random();

  /// 模拟用户信息响应
  static Future<ApiResponse<UserInfoModel>> getMockUserInfo() async {
    // 模拟网络延迟
    await Future.delayed(Duration(milliseconds: ApiConfig.mockNetworkDelayMs));

    // 模拟错误率
    if (_random.nextDouble() < ApiConfig.mockErrorRate) {
      return ApiResponse.error(errNo: 500);
    }

    // 模拟成功响应
    final mockUserInfo = UserInfoModel(
      uid: 'user_${_random.nextInt(100000).toString().padLeft(5, '0')}',
      nickname: _getMockNickname(),
      avatar: 'https://example.com/avatars/user_${_random.nextInt(50) + 1}.jpg',
      isVip: _random.nextBool(),
    );

    return ApiResponse.success(data: mockUserInfo);
  }

  /// 获取模拟昵称
  static String _getMockNickname() {
    final nicknames = [
      '音乐爱好者',
      '旋律追踪者',
      '节拍大师',
      '音符收集家',
      '韵律探索者',
      '声音猎人',
      '音乐漫步者',
      '和声梦想家',
      '节奏掌控者',
      '音乐魔法师',
    ];
    return nicknames[_random.nextInt(nicknames.length)];
  }
}
