import 'dart:convert';
import 'package:flutter/foundation.dart';
import '../../models/user_privilege_model.dart';
import '../../models/api_response.dart';
import '../../config/api_config.dart';
import '../http_client_service.dart';

class UserPrivilegeService {
  static final UserPrivilegeService _instance = UserPrivilegeService._internal();
  factory UserPrivilegeService() => _instance;
  UserPrivilegeService._internal();

  static UserPrivilegeService get instance => _instance;

  // 缓存用户权限信息
  UserPrivilege? _cachedPrivilege;
  DateTime? _lastFetchTime;
  static const Duration _cacheExpiration = Duration(minutes: 5); // 缓存5分钟

  /// 检查用户权限
  /// 
  /// 返回用户的高级权限状态信息
  /// 自动包含设备ID、访问令牌和签名验证
  Future<UserPrivilege> checkUserPrivilege({bool forceRefresh = false}) async {
    try {
      debugPrint('👑 [USER_PRIVILEGE_SERVICE] 开始检查用户权限');
      
      // 检查缓存是否有效
      if (!forceRefresh && _isCacheValid()) {
        debugPrint('👑 [USER_PRIVILEGE_SERVICE] 使用缓存的权限信息');
        return _cachedPrivilege!;
      }
      
      // 构建请求URL
      final url = Uri.parse('${ApiConfig.baseUrl}${ApiEndpoints.userPrivilegeCheck}');
      debugPrint('👑 [USER_PRIVILEGE_SERVICE] 请求URL: $url');
      
      // 使用HttpClientService发送GET请求（自动处理请求头、签名等）
      final response = await HttpClientService.get(
        url,
        timeout: const Duration(seconds: 30),
      );
      
      debugPrint('👑 [USER_PRIVILEGE_SERVICE] 响应状态码: ${response.statusCode}');
      debugPrint('👑 [USER_PRIVILEGE_SERVICE] 响应内容: ${response.body}');
      
      // 检查HTTP状态码
      if (response.statusCode == 200) {
        // 解析JSON响应并使用ApiResponse统一处理
        final jsonData = json.decode(response.body) as Map<String, dynamic>;
        final apiResponse = ApiResponse.fromJson<UserPrivilege>(
          jsonData,
          (data) => UserPrivilege.fromJson(data),
        );
        
        if (apiResponse.errNo == 0 && apiResponse.data != null) {
          final privilege = apiResponse.data!;
          
          // 更新缓存
          _cachedPrivilege = privilege;
          _lastFetchTime = DateTime.now();
          
          debugPrint('👑 [USER_PRIVILEGE_SERVICE] 成功获取用户权限: hasPremium=${privilege.hasPremium}, endDate=${privilege.premiumEndDate}');
          return privilege;
        } else {
          debugPrint('👑 [USER_PRIVILEGE_SERVICE] API返回错误: errNo=${apiResponse.errNo}');
          throw Exception('检查用户权限失败: errNo=${apiResponse.errNo}');
        }
      } else {
        debugPrint('👑 [USER_PRIVILEGE_SERVICE] HTTP请求失败: ${response.statusCode}');
        throw Exception('检查用户权限失败: HTTP ${response.statusCode}');
      }
      
    } catch (e) {
      debugPrint('👑 [USER_PRIVILEGE_SERVICE] 检查用户权限异常: $e');
      rethrow;
    }
  }
  
  /// 检查用户是否拥有有效的高级权限
  /// 
  /// 返回true表示用户拥有有效的高级权限
  Future<bool> hasValidPremium({bool forceRefresh = false}) async {
    try {
      final privilege = await checkUserPrivilege(forceRefresh: forceRefresh);
      return privilege.isValidPremium;
    } catch (e) {
      debugPrint('👑 [USER_PRIVILEGE_SERVICE] 检查有效权限失败: $e');
      // 发生错误时，默认返回false（无权限）
      return false;
    }
  }
  
  /// 获取高级权限剩余天数
  /// 
  /// 返回剩余天数，如果没有权限或已过期返回0
  Future<int> getRemainingDays({bool forceRefresh = false}) async {
    try {
      final privilege = await checkUserPrivilege(forceRefresh: forceRefresh);
      return privilege.remainingDays;
    } catch (e) {
      debugPrint('👑 [USER_PRIVILEGE_SERVICE] 获取剩余天数失败: $e');
      return 0;
    }
  }
  
  /// 获取格式化的权限到期时间
  /// 
  /// 返回友好的时间显示格式
  Future<String> getFormattedEndDate({bool forceRefresh = false}) async {
    try {
      final privilege = await checkUserPrivilege(forceRefresh: forceRefresh);
      return privilege.formattedEndDate;
    } catch (e) {
      debugPrint('👑 [USER_PRIVILEGE_SERVICE] 获取格式化时间失败: $e');
      return '未知';
    }
  }
  
  /// 获取权限状态描述
  /// 
  /// 返回权限状态的中文描述
  Future<String> getPrivilegeStatusDescription({bool forceRefresh = false}) async {
    try {
      final privilege = await checkUserPrivilege(forceRefresh: forceRefresh);
      
      if (!privilege.hasPremium) {
        return '未开通高级权限';
      }
      
      if (privilege.isValidPremium) {
        final remainingDays = privilege.remainingDays;
        if (remainingDays > 30) {
          return '高级权限有效';
        } else if (remainingDays > 7) {
          return '高级权限即将到期（剩余$remainingDays天）';
        } else if (remainingDays > 0) {
          return '高级权限即将到期（剩余$remainingDays天）';
        } else {
          return '高级权限今日到期';
        }
      } else {
        return '高级权限已过期';
      }
    } catch (e) {
      debugPrint('👑 [USER_PRIVILEGE_SERVICE] 获取权限状态描述失败: $e');
      return '权限状态未知';
    }
  }
  
  /// 清除缓存
  /// 
  /// 强制下次请求重新从服务器获取数据
  void clearCache() {
    _cachedPrivilege = null;
    _lastFetchTime = null;
    debugPrint('👑 [USER_PRIVILEGE_SERVICE] 已清除权限缓存');
  }
  
  /// 检查缓存是否有效
  bool _isCacheValid() {
    if (_cachedPrivilege == null || _lastFetchTime == null) {
      return false;
    }
    
    final now = DateTime.now();
    final cacheAge = now.difference(_lastFetchTime!);
    return cacheAge < _cacheExpiration;
  }
  
  /// 获取缓存的权限信息（如果有的话）
  /// 
  /// 返回缓存的权限信息，如果没有缓存则返回null
  UserPrivilege? getCachedPrivilege() {
    if (_isCacheValid()) {
      return _cachedPrivilege;
    }
    return null;
  }
  
  /// 预加载用户权限信息
  /// 
  /// 在后台预先获取权限信息，不阻塞UI
  void preloadPrivilege() {
    checkUserPrivilege().catchError((error) {
      debugPrint('👑 [USER_PRIVILEGE_SERVICE] 预加载权限信息失败: $error');
      // 返回默认的权限信息，表示无权限状态
      return const UserPrivilege(hasPremium: false);
    });
  }
}