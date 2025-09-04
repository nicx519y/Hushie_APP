import 'dart:async';
import '../models/audio_item.dart';
import 'api/user_likes_service.dart';
import 'api/audio_like_service.dart';
import 'auth_service.dart';

/// 用户喜欢音频管理器
/// 管理用户喜欢的音频列表，提供本地缓存和服务端同步功能
class UserLikesManager {
  static final UserLikesManager _instance = UserLikesManager._internal();
  static UserLikesManager get instance => _instance;

  List<AudioItem> _likesCache = []; // 本地内存缓存
  Set<String> _likedAudioIds = {}; // 快速查询用的音频ID集合
  bool _isInitialized = false;
  StreamSubscription<AuthStatusChangeEvent>? _authSubscription;

  UserLikesManager._internal();

  /// 初始化用户喜欢音频管理器
  Future<void> initialize() async {
    if (_isInitialized) return;

    try {
      print('💖 [LIKES] 开始初始化用户喜欢音频管理器');

      // 订阅认证状态变化事件
      _subscribeToAuthChanges();

      // 检查用户登录状态
      final bool isLogin = await AuthService.isSignedIn();
      if (!isLogin) {
        print('💖 [LIKES] 用户未登录，跳过喜欢列表初始化');
        _likesCache = [];
        _likedAudioIds = {};
        _isInitialized = true;
        return;
      }

      // 从服务端拉取喜欢列表
      final likesList = await UserLikesService.getUserLikedAudios();

      // 缓存到本地内存
      _updateLocalCache(likesList);
      _isInitialized = true;

      print('💖 [LIKES] 初始化完成，缓存了 ${_likesCache.length} 条喜欢记录');
    } catch (e) {
      print('💖 [LIKES] 初始化失败: $e');
      _likesCache = [];
      _likedAudioIds = {};
      _isInitialized = true; // 即使失败也标记为已初始化
    }
  }

  /// 订阅认证状态变化事件
  void _subscribeToAuthChanges() {
    _authSubscription?.cancel(); // 取消之前的订阅

    _authSubscription = AuthService.authStatusChanges.listen((event) {
      print('💖 [LIKES] 收到认证状态变化事件: ${event.status}');

      switch (event.status) {
        case AuthStatus.authenticated:
          // 用户登录，重新初始化喜欢列表
          _reinitializeAfterLogin();
          break;
        case AuthStatus.unauthenticated:
          // 用户登出，清空缓存
          _clearCacheAfterLogout();
          break;
        case AuthStatus.unknown:
          // 状态未知，暂不处理
          break;
      }
    });

    print('💖 [LIKES] 已订阅认证状态变化事件');
  }

  /// 登录后重新初始化
  Future<void> _reinitializeAfterLogin() async {
    try {
      print('💖 [LIKES] 用户已登录，重新初始化喜欢列表');

      // 从服务端拉取最新的喜欢列表
      final likesList = await UserLikesService.getUserLikedAudios();
      _updateLocalCache(likesList);

      print('💖 [LIKES] 登录后重新初始化完成，缓存了 ${_likesCache.length} 条喜欢记录');
    } catch (e) {
      print('💖 [LIKES] 登录后重新初始化失败: $e');
      // 初始化失败，清空缓存
      _likesCache = [];
      _likedAudioIds = {};
    }
  }

  /// 登出后清空缓存
  void _clearCacheAfterLogout() {
    print('💖 [LIKES] 用户已登出，清空喜欢列表缓存');
    _likesCache.clear();
    _likedAudioIds.clear();
  }

  /// 获取用户喜欢的音频列表（优先从缓存，缓存为空时从服务端拉取）
  Future<List<AudioItem>> getLikedAudios({bool forceRefresh = false}) async {
    try {
      // 检查用户登录状态
      final bool isLogin = await AuthService.isSignedIn();
      if (!isLogin) {
        print('💖 [LIKES] 用户未登录，返回空列表');
        return [];
      }

      // 如果强制刷新或缓存为空，从服务端拉取
      if (forceRefresh || _likesCache.isEmpty) {
        print('💖 [LIKES] 从服务端拉取喜欢列表');
        final likesList = await UserLikesService.getUserLikedAudios();
        _updateLocalCache(likesList);
        return _likesCache;
      }

      // 返回缓存数据
      print('💖 [LIKES] 返回缓存喜欢列表: ${_likesCache.length} 条');
      return _likesCache;
    } catch (e) {
      print('💖 [LIKES] 获取喜欢列表失败: $e');
      return _likesCache; // 返回缓存数据作为降级方案
    }
  }

  /// 刷新喜欢列表
  Future<List<AudioItem>> refreshLikedAudios() async {
    return await getLikedAudios(forceRefresh: true);
  }

  /// 查询音频是否在喜欢列表中
  bool isAudioLiked(String audioId) {
    return _likedAudioIds.contains(audioId);
  }

  /// 查询音频是否在喜欢列表中（异步版本，确保数据是最新的）
  Future<bool> isAudioLikedAsync(
    String audioId, {
    bool checkServer = false,
  }) async {
    try {
      // 如果需要检查服务端或缓存为空，先更新缓存
      if (checkServer || _likesCache.isEmpty) {
        await getLikedAudios(forceRefresh: checkServer);
      }

      return _likedAudioIds.contains(audioId);
    } catch (e) {
      print('💖 [LIKES] 查询音频喜欢状态失败: $e');
      return _likedAudioIds.contains(audioId); // 降级到本地缓存
    }
  }

  /// 喜欢音频
  Future<bool> likeAudio(String audioId) async {
    try {
      // 检查用户登录状态
      final bool isLogin = await AuthService.isSignedIn();
      if (!isLogin) {
        throw Exception('用户未登录');
      }

      print('💖 [LIKES] 正在喜欢音频: $audioId');

      // 调用服务端接口
      await AudioLikeService.likeAudio(audioId: audioId, isLiked: true);

      // 操作成功，更新本地缓存
      _likedAudioIds.add(audioId);

      // 如果缓存中有这个音频，更新其喜欢状态
      final audioIndex = _likesCache.indexWhere((audio) => audio.id == audioId);
      if (audioIndex != -1) {
        _likesCache[audioIndex] = _likesCache[audioIndex].copyWith(
          isLiked: true,
        );
      }

      print('💖 [LIKES] 喜欢音频成功: $audioId');
      return true;
    } catch (e) {
      print('💖 [LIKES] 喜欢音频失败: $e');
      return false;
    }
  }

  /// 取消喜欢音频
  Future<bool> unlikeAudio(String audioId) async {
    try {
      // 检查用户登录状态
      final bool isLogin = await AuthService.isSignedIn();
      if (!isLogin) {
        throw Exception('用户未登录');
      }

      print('💖 [LIKES] 正在取消喜欢音频: $audioId');

      // 调用服务端接口
      await AudioLikeService.likeAudio(audioId: audioId, isLiked: false);

      // 操作成功，更新本地缓存
      _likedAudioIds.remove(audioId);

      // 从缓存列表中移除这个音频
      _likesCache.removeWhere((audio) => audio.id == audioId);

      print('💖 [LIKES] 取消喜欢音频成功: $audioId');
      return true;
    } catch (e) {
      print('💖 [LIKES] 取消喜欢音频失败: $e');
      return false;
    }
  }

  /// 切换音频喜欢状态
  Future<bool> toggleLike(String audioId) async {
    final isCurrentlyLiked = isAudioLiked(audioId);

    if (isCurrentlyLiked) {
      return await unlikeAudio(audioId);
    } else {
      return await likeAudio(audioId);
    }
  }

  /// 获取缓存的喜欢列表（不触发网络请求）
  List<AudioItem> getCachedLikedAudios() {
    return List.from(_likesCache);
  }

  /// 获取喜欢的音频ID集合（不触发网络请求）
  Set<String> getLikedAudioIds() {
    return Set.from(_likedAudioIds);
  }

  /// 更新本地内存缓存
  void _updateLocalCache(List<AudioItem> newLikedAudios) {
    _likesCache = List.from(newLikedAudios);

    // 更新音频ID集合，用于快速查询
    _likedAudioIds = _likesCache.map((audio) => audio.id).toSet();

    print('💖 [LIKES] 本地缓存已更新: ${_likesCache.length} 条喜欢记录');
  }

  /// 清空缓存（用户登出时调用）
  void clearCache() {
    _likesCache.clear();
    _likedAudioIds.clear();
    _isInitialized = false;
    print('💖 [LIKES] 喜欢列表缓存已清空');
  }

  /// 获取管理器状态信息
  Map<String, dynamic> getManagerStatus() {
    return {
      'isInitialized': _isInitialized,
      'cacheSize': _likesCache.length,
      'likedIdsCount': _likedAudioIds.length,
    };
  }

  /// 清理资源
  Future<void> dispose() async {
    // 取消认证状态订阅
    _authSubscription?.cancel();
    _authSubscription = null;

    clearCache();
    print('💖 [LIKES] 用户喜欢音频管理器资源已清理');
  }
}
