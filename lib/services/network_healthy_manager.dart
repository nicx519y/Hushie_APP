import 'dart:async';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'api/health_check_service.dart';

/// 网络健康管理器
/// 用于检测和管理网络连接状态和服务器健康状态
class NetworkHealthyManager {
  static final NetworkHealthyManager _instance = NetworkHealthyManager._internal();
  
  /// 获取单例实例
  static NetworkHealthyManager get instance => _instance;
  
  factory NetworkHealthyManager() => _instance;
  NetworkHealthyManager._internal();

  final Connectivity _connectivity = Connectivity();
  StreamSubscription<List<ConnectivityResult>>? _connectivitySubscription;
  
  // 网络状态流控制器
  final StreamController<NetworkHealthStatus> _networkStatusController = 
      StreamController<NetworkHealthStatus>.broadcast();
  
  // 当前网络健康状态
  NetworkHealthStatus _currentStatus = NetworkHealthStatus.unknown;
  
  /// 获取网络健康状态流
  Stream<NetworkHealthStatus> get networkStatusStream => _networkStatusController.stream;
  
  /// 获取当前网络健康状态
  NetworkHealthStatus get currentStatus => _currentStatus;

  /// 初始化网络健康管理器
  Future<void> initialize() async {
    // 检查初始网络状态
    await _checkNetworkHealth();
    
    // 监听网络连接变化
    _connectivitySubscription = _connectivity.onConnectivityChanged.listen(
      (List<ConnectivityResult> results) async {
        await _checkNetworkHealth();
      },
    );
  }

  /// 手动检查网络健康状态
  Future<NetworkHealthStatus> checkNetworkHealth() async {
    return await _checkNetworkHealth();
  }

  /// 内部检查网络健康状态的方法
  Future<NetworkHealthStatus> _checkNetworkHealth() async {
    try {
      // 第一步：检查系统网络连接状态
      final List<ConnectivityResult> connectivityResults = await _connectivity.checkConnectivity();
      
      // 如果没有网络连接
      if (connectivityResults.contains(ConnectivityResult.none)) {
        _updateStatus(NetworkHealthStatus.noConnection);
        return _currentStatus;
      }
      
      // 第二步：通过健康检查服务ping服务器
      final healthCheckResult = await HealthCheckService.checkHealthWithDetails();
      
      if (healthCheckResult['isHealthy'] == true) {
        _updateStatus(NetworkHealthStatus.healthy);
      } else {
        // 有网络连接但服务器不健康
        _updateStatus(NetworkHealthStatus.serverUnhealthy);
      }
      
      return _currentStatus;
    } catch (e) {
      // 检查过程中出现异常
      _updateStatus(NetworkHealthStatus.error);
      return _currentStatus;
    }
  }

  /// 更新网络状态并通知监听者
  void _updateStatus(NetworkHealthStatus newStatus) {
    if (_currentStatus != newStatus) {
      _currentStatus = newStatus;
      _networkStatusController.add(_currentStatus);
    }
  }

  /// 获取网络连接类型
  Future<List<ConnectivityResult>> getConnectivityTypes() async {
    return await _connectivity.checkConnectivity();
  }

  /// 获取网络连接类型的描述
  Future<String> getConnectivityDescription() async {
    final results = await getConnectivityTypes();
    if (results.contains(ConnectivityResult.none)) {
      return '无网络连接';
    } else if (results.contains(ConnectivityResult.wifi)) {
      return 'WiFi连接';
    } else if (results.contains(ConnectivityResult.mobile)) {
      return '移动网络连接';
    } else if (results.contains(ConnectivityResult.ethernet)) {
      return '以太网连接';
    } else {
      return '其他网络连接';
    }
  }

  /// 获取详细的网络健康信息
  Future<Map<String, dynamic>> getDetailedNetworkInfo() async {
    final connectivityTypes = await getConnectivityTypes();
    final connectivityDescription = await getConnectivityDescription();
    final healthDetails = await HealthCheckService.checkHealthWithDetails();
    
    return {
      'networkStatus': _currentStatus.toString(),
      'connectivityTypes': connectivityTypes.map((e) => e.toString()).toList(),
      'connectivityDescription': connectivityDescription,
      'serverHealth': healthDetails,
      'timestamp': DateTime.now().toIso8601String(),
    };
  }

  /// 释放资源
  void dispose() {
    _connectivitySubscription?.cancel();
    _networkStatusController.close();
  }
}

/// 网络健康状态枚举
enum NetworkHealthStatus {
  /// 未知状态
  unknown,
  /// 网络健康（有网络连接且服务器正常）
  healthy,
  /// 无网络连接
  noConnection,
  /// 有网络连接但服务器不健康
  serverUnhealthy,
  /// 检查过程中出现错误
  error,
}

/// 网络健康状态扩展方法
extension NetworkHealthStatusExtension on NetworkHealthStatus {
  /// 获取状态描述
  String get description {
    switch (this) {
      case NetworkHealthStatus.unknown:
        return 'Unkown Network Status';
      case NetworkHealthStatus.healthy:
        return 'Network Healthy';
      case NetworkHealthStatus.noConnection:
        return 'No Network Connection';
      case NetworkHealthStatus.serverUnhealthy:
        return 'Server Unhealthy';
      case NetworkHealthStatus.error:
        return 'Check Error';
    }
  }

  /// 是否为健康状态
  bool get isHealthy => this == NetworkHealthStatus.healthy;

  /// 是否有网络连接
  bool get hasConnection => this != NetworkHealthStatus.noConnection;
}