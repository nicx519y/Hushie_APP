import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/audio_item.dart';
import '../services/api/user_likes_service.dart';
import '../services/api/audio_like_service.dart';
import 'auth_manager.dart';

/// 音频点赞管理器
/// 整合本地内存缓存和服务端数据同步，提供统一的点赞音频管理接口
class AudioLikesManager {
  static final AudioLikesManager _instance = AudioLikesManager._internal();
  static AudioLikesManager get instance => _instance;

  List<AudioItem> _likesCache = []; // 本地内存缓存
  bool _isInitialized = false;
  StreamSubscription<AuthStatusChangeEvent>? _authSubscription;
  SharedPreferences? _prefs; // 本地存储实例

  // ValueNotifier 用于状态变更通知
  final ValueNotifier<List<AudioItem>> _likesNotifier =
      ValueNotifier<List<AudioItem>>([]);

  // 点赞记录事件流控制器
  final StreamController<List<AudioItem>> _likesStreamController =
      StreamController<List<AudioItem>>.broadcast();

  // 防止重复请求的状态标识
  bool _isLoadingLikesFromServer = false;
  bool _isLoadingMore = false;

  // 分页相关
  String? _lastCid; // 最后一个音频的ID，用于分页
  bool _hasMoreData = true; // 是否还有更多数据
  static const int _defaultPageSize = 20; // 默认每页数量

  static const String _likesCacheKey = 'audio_likes_cache'; // 本地存储键名

  AudioLikesManager._internal();

  /// 获取点赞缓存状态通知器
  ValueNotifier<List<AudioItem>> get likesNotifier => _likesNotifier;

  /// 获取点赞记录事件流
  Stream<List<AudioItem>> get likesStream => _likesStreamController.stream;

  /// 是否还有更多数据
  bool get hasMoreData => _hasMoreData;

  /// 是否正在加载更多
  bool get isLoadingMore => _isLoadingMore;

  /// 初始化点赞管理器 - 从服务端拉取点赞列表并缓存到本地内存
  Future<void> initialize() async {
    if (_isInitialized) return;

    try {
      debugPrint('🎵 [LIKES] 开始初始化音频点赞管理器');

      // 初始化本地存储
      _prefs = await SharedPreferences.getInstance();

      // 订阅认证状态变化事件
      _subscribeToAuthChanges();

      // 先从本地存储加载缓存（无论是否登录都加载）
      await _loadCachedLikes();

      // 检查用户登录状态
      final bool isLogin = await AuthManager.instance.isSignedIn();
      if (!isLogin) {
        _clearCacheAfterLogout();
        _isInitialized = true;
        return;
      }

      // 刷新服务端数据
      await _reinitializeAfterLogin();
      _isInitialized = true;

      debugPrint('🎵 [LIKES] 初始化完成，缓存了 ${_likesCache.length} 条点赞记录');
    } catch (e) {
      debugPrint('🎵 [LIKES] 初始化失败: $e');
      _likesCache = [];
      _likesNotifier.value = [];
      _isInitialized = true; // 即使失败也标记为已初始化
    }
  }

  /// 订阅认证状态变化事件
  void _subscribeToAuthChanges() {
    _authSubscription?.cancel(); // 取消之前的订阅

    _authSubscription = AuthManager.instance.authStatusChanges.listen((event) {
      debugPrint('🎵 [LIKES] 收到认证状态变化事件: ${event.status}');

      switch (event.status) {
        case AuthStatus.authenticated:
          // 用户登录，重新初始化点赞数据
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

    debugPrint('🎵 [LIKES] 已订阅认证状态变化事件');
  }

  /// 登录后重新初始化
  Future<void> _reinitializeAfterLogin() async {
    // 防止重复请求
    if (_isLoadingLikesFromServer) {
      debugPrint('🎵 [LIKES] 正在从服务端加载点赞数据，跳过重复请求');
      return;
    }

    try {
      _isLoadingLikesFromServer = true;
      debugPrint('🎵 [LIKES] 用户已登录，重新初始化点赞数据');

      // 重置分页状态
      _lastCid = null;
      _hasMoreData = true;

      // 从服务端拉取最新的点赞列表
      final likesList = await UserLikesService.getUserLikedAudios(
        count: _defaultPageSize,
      );

      // 更新分页状态
      if (likesList.isNotEmpty) {
        _lastCid = likesList.last.id;
        _hasMoreData = likesList.length >= _defaultPageSize;
      } else {
        _hasMoreData = false;
      }

      debugPrint('🎵 [LIKES] 从服务端拉取到的点赞列表数量: ${likesList.length}');

      await _updateLocalCache(likesList);

      debugPrint('🎵 [LIKES] 登录后重新初始化完成，缓存了 ${_likesCache.length} 条点赞记录');
    } catch (e) {
      debugPrint('🎵 [LIKES] 登录后重新初始化失败: $e');
      // 初始化失败，清空缓存
      _likesCache = [];
      _likesNotifier.value = [];
      _hasMoreData = false;
    } finally {
      _isLoadingLikesFromServer = false;
    }
  }

  /// 登出后清空缓存
  void _clearCacheAfterLogout() {
    debugPrint('🎵 [LIKES] 用户已登出，清空点赞缓存');

    // 清空内存缓存
    _likesCache.clear();
    _likesNotifier.value = [];
    
    // 重置分页状态
    _lastCid = null;
    _hasMoreData = true;
    
    // 清空本地存储
    _clearLocalStorage();
    
    // 推送空点赞记录事件
    _likesStreamController.add([]);
  }

  /// 刷新点赞列表（从头开始加载）
  Future<List<AudioItem>> refresh() async {
    try {
      debugPrint('🎵 [LIKES] 刷新点赞列表');

      // 检查登录状态
      final bool isLogin = await AuthManager.instance.isSignedIn();
      if (!isLogin) {
        _clearCacheAfterLogout();
        return [];
      }

      // 防止重复请求
      if (_isLoadingLikesFromServer) {
        debugPrint('🎵 [LIKES] 正在从服务端加载点赞数据，等待完成...');
        while (_isLoadingLikesFromServer) {
          await Future.delayed(const Duration(milliseconds: 100));
        }
        return _likesCache;
      }

      try {
        _isLoadingLikesFromServer = true;
        
        // 重置分页状态
        _lastCid = null;
        _hasMoreData = true;

        // 从服务端拉取最新数据
        final likesList = await UserLikesService.getUserLikedAudios(
          count: _defaultPageSize,
        );

        // 更新分页状态
        if (likesList.isNotEmpty) {
          _lastCid = likesList.last.id;
          _hasMoreData = likesList.length >= _defaultPageSize;
        } else {
          _hasMoreData = false;
        }

        await _updateLocalCache(likesList);
        return _likesCache;
      } finally {
        _isLoadingLikesFromServer = false;
      }
    } catch (e) {
      debugPrint('🎵 [LIKES] 刷新点赞列表失败: $e');
      return _likesCache; // 返回缓存数据作为降级方案
    }
  }

  /// 加载更多点赞数据
  Future<List<AudioItem>> loadMore() async {
    try {
      // 检查是否还有更多数据
      if (!_hasMoreData) {
        debugPrint('🎵 [LIKES] 没有更多点赞数据可加载');
        return [];
      }

      // 检查登录状态
      final bool isLogin = await AuthManager.instance.isSignedIn();
      if (!isLogin) {
        debugPrint('🎵 [LIKES] 用户未登录，无法加载更多');
        return [];
      }

      // 防止重复请求
      if (_isLoadingMore) {
        debugPrint('🎵 [LIKES] 正在加载更多数据，跳过重复请求');
        return [];
      }

      try {
        _isLoadingMore = true;
        debugPrint('🎵 [LIKES] 加载更多点赞数据，从 cid: $_lastCid');

        // 从服务端拉取更多数据
        final moreData = await UserLikesService.getUserLikedAudios(
          cid: _lastCid,
          count: _defaultPageSize,
        );

        if (moreData.isNotEmpty) {
          // 合并新数据到现有缓存
          final updatedCache = List<AudioItem>.from(_likesCache);
          
          // 去重合并（基于ID）
          for (final newItem in moreData) {
            if (!updatedCache.any((item) => item.id == newItem.id)) {
              updatedCache.add(newItem);
            }
          }

          // 更新分页状态
          _lastCid = moreData.last.id;
          _hasMoreData = moreData.length >= _defaultPageSize;

          await _updateLocalCache(updatedCache);
          
          debugPrint('🎵 [LIKES] 加载更多完成，新增 ${moreData.length} 条，总计 ${_likesCache.length} 条');

          return moreData;
        } else {
          _hasMoreData = false;
          debugPrint('🎵 [LIKES] 没有更多数据');

          return [];
        }

      } finally {
        _isLoadingMore = false;
      }
    } catch (e) {
      debugPrint('🎵 [LIKES] 加载更多点赞数据失败: $e');
      _isLoadingMore = false;
      return []; 
    }
  }

  /// 获取音频点赞列表（优先从缓存，缓存为空时从服务端拉取）
  Future<List<AudioItem>> getLikedAudios({bool forceRefresh = false}) async {
    try {
      // 如果强制刷新或缓存为空，从服务端拉取
      if (forceRefresh || _likesCache.isEmpty) {
        return await refresh();
      }

      // 返回缓存数据
      debugPrint('🎵 [LIKES] 返回缓存点赞数据: ${_likesCache.length} 条');
      return _likesCache;
    } catch (e) {
      debugPrint('🎵 [LIKES] 获取音频点赞列表失败: $e');
      return _likesCache; // 返回缓存数据作为降级方案
    }
  }

  /// 根据ID更新缓存中的音频数据
  Future<void> updateAudioById(String audioId, AudioItem updatedAudio) async {
    try {
      final index = _likesCache.indexWhere((item) => item.id == audioId);
      if (index != -1) {
        _likesCache[index] = updatedAudio;
        
        // 保存到本地存储
        await _saveLikesToStorage(_likesCache);
        
        // 通知状态变更
        _likesNotifier.value = List.from(_likesCache);
        _likesStreamController.add(List.from(_likesCache));
        
        debugPrint('🎵 [LIKES] 已更新缓存中的音频数据: $audioId');
      } else {
        debugPrint('🎵 [LIKES] 在缓存中未找到要更新的音频: $audioId');
      }
    } catch (e) {
      debugPrint('🎵 [LIKES] 更新缓存中的音频数据失败: $e');
    }
  }

  /// 根据ID从缓存中移除音频（取消点赞时使用）
  Future<void> removeAudioById(String audioId) async {
    try {
      final index = _likesCache.indexWhere((item) => item.id == audioId);
      if (index != -1) {
        _likesCache.removeAt(index);
        
        // 保存到本地存储
        await _saveLikesToStorage(_likesCache);
        
        // 通知状态变更
        _likesNotifier.value = List.from(_likesCache);
        _likesStreamController.add(List.from(_likesCache));
        
        debugPrint('🎵 [LIKES] 已从缓存中移除音频: $audioId');
      } else {
        debugPrint('🎵 [LIKES] 在缓存中未找到要移除的音频: $audioId');
      }
    } catch (e) {
      debugPrint('🎵 [LIKES] 从缓存中移除音频失败: $e');
    }
  }

  /// 添加音频到缓存（点赞时使用）
  Future<void> addAudioToCache(AudioItem audio) async {
    try {
      // 检查是否已存在
      if (!_likesCache.any((item) => item.id == audio.id)) {
        // 添加到列表开头（最新的在前面）
        _likesCache.insert(0, audio);
        
        // 保存到本地存储
        await _saveLikesToStorage(_likesCache);
        
        // 通知状态变更
        _likesNotifier.value = List.from(_likesCache);
        _likesStreamController.add(List.from(_likesCache));
        
        debugPrint('🎵 [LIKES] 已添加音频到缓存: ${audio.id}');
      } else {
        debugPrint('🎵 [LIKES] 音频已存在于缓存中: ${audio.id}');
      }
    } catch (e) {
      debugPrint('🎵 [LIKES] 添加音频到缓存失败: $e');
    }
  }

  /// 检查音频是否已点赞
  bool isAudioLiked(String audioId) {
    return _likesCache.any((item) => item.id == audioId);
  }

  /// 搜索点赞记录中的音频
  AudioItem? searchLikedAudio(String audioId) {
    try {
      return _likesCache.firstWhere((item) => item.id == audioId);
    } catch (e) {
      return null;
    }
  }

  /// 更新本地内存缓存和本地存储
  Future<void> _updateLocalCache(List<AudioItem> newLikes) async {
    _likesCache = List.from(newLikes);
    
    // 保存到本地存储
    await _saveLikesToStorage(_likesCache);
    
    // 通知状态变更
    _likesNotifier.value = List.from(_likesCache);
    
    // 推送点赞记录变更事件
    _likesStreamController.add(List.from(_likesCache));
    
    debugPrint('🎵 [LIKES] 本地缓存已更新: ${_likesCache.length} 条记录');
  }

  /// 保存点赞记录到本地存储
  Future<void> _saveLikesToStorage(List<AudioItem> likes) async {
    try {
      final likesJson = json.encode(likes.map((item) => item.toMap()).toList());
      await _prefs?.setString(_likesCacheKey, likesJson);
      debugPrint('🎵 [LIKES] 点赞记录已保存到本地存储，共${likes.length}条');
    } catch (e) {
      debugPrint('🎵 [LIKES] 保存点赞记录到本地存储失败: $e');
    }
  }

  /// 从本地存储加载点赞记录
  Future<void> _loadCachedLikes() async {
    try {
      final likesJson = _prefs?.getString(_likesCacheKey);
      if (likesJson != null && likesJson.isNotEmpty) {
        final List<dynamic> likesData = json.decode(likesJson);
        final List<AudioItem> cachedLikes = likesData
            .map((item) => AudioItem.fromMap(item as Map<String, dynamic>))
            .toList();
        
        _likesCache = cachedLikes;
        _likesNotifier.value = List.from(_likesCache);
        
        debugPrint('🎵 [LIKES] 从本地存储加载点赞记录，共${_likesCache.length}条');
      }
    } catch (e) {
      debugPrint('🎵 [LIKES] 从本地存储加载点赞记录失败: $e');
      _likesCache = [];
      _likesNotifier.value = [];
    }
  }

  /// 清空本地存储
  Future<void> _clearLocalStorage() async {
    try {
      await _prefs?.remove(_likesCacheKey);
      debugPrint('🎵 [LIKES] 本地存储已清空');
    } catch (e) {
      debugPrint('🎵 [LIKES] 清空本地存储失败: $e');
    }
  }

  /// 清理资源
  Future<void> dispose() async {
    // 取消认证状态订阅
    _authSubscription?.cancel();
    _authSubscription = null;

    // 清空缓存和通知器
    _likesCache.clear();
    _likesNotifier.value = [];
    _likesNotifier.dispose();
    
    // 关闭点赞记录事件流
    await _likesStreamController.close();
    
    _isInitialized = false;

    debugPrint('🎵 [LIKES] 音频点赞管理器资源已清理');
  }
}