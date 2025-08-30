import 'dart:convert';
import 'dart:math';
import 'package:http/http.dart' as http;
import '../models/audio_item.dart';
import '../models/api_response.dart';
import '../models/tab_item.dart';
import '../data/mock_data.dart';

enum ApiMode {
  mock, // 使用本地 mock 数据
  real, // 使用真实 API
}

class ApiService {
  static const String _baseUrl = 'https://your-api-domain.com/api/v1';
  static const Duration _defaultTimeout = Duration(seconds: 10);

  // 可以通过环境变量或配置文件设置
  static ApiMode _currentMode = ApiMode.mock;

  // 设置 API 模式
  static void setApiMode(ApiMode mode) {
    _currentMode = mode;
    print('API 模式切换为: ${mode == ApiMode.mock ? 'Mock 数据' : '真实接口'}');
  }

  // 获取当前 API 模式
  static ApiMode get currentMode => _currentMode;

  /// 获取首页音频列表
  static Future<ApiResponse<PaginatedResponse<AudioItem>>> getHomeAudioList({
    int page = 1,
    int pageSize = 10,
    String? searchQuery,
    List<String>? tags,
  }) async {
    if (_currentMode == ApiMode.mock) {
      return _getMockHomeAudioList(
        page: page,
        pageSize: pageSize,
        searchQuery: searchQuery,
        tags: tags,
      );
    } else {
      return _getRealHomeAudioList(
        page: page,
        pageSize: pageSize,
        searchQuery: searchQuery,
        tags: tags,
      );
    }
  }

  /// Mock 模式 - 获取首页音频列表
  static Future<ApiResponse<PaginatedResponse<AudioItem>>>
  _getMockHomeAudioList({
    int page = 1,
    int pageSize = 10,
    String? searchQuery,
    List<String>? tags,
  }) async {
    try {
      // 模拟网络延迟
      await MockData.simulateNetworkDelay(Random().nextInt(800) + 200);

      final audioItems = MockData.getAudioItems(
        page: page,
        pageSize: pageSize,
        searchQuery: searchQuery,
        tags: tags,
      );

      // 计算总数据量
      final allItems = MockData.getAllAudioItems();
      final totalItems = allItems.length;
      final totalPages = (totalItems / pageSize).ceil();

      final paginatedResponse = PaginatedResponse<AudioItem>(
        items: audioItems,
        currentPage: page,
        totalPages: totalPages,
        totalItems: totalItems,
        pageSize: pageSize,
        hasNextPage: page < totalPages,
        hasPreviousPage: page > 1,
      );

      // 随机模拟一些错误情况用于测试
      if (Random().nextDouble() < 0.05) {
        // 5% 概率失败
        return ApiResponse.error(message: 'Mock 网络错误', code: 500);
      }

      return ApiResponse.success(data: paginatedResponse, message: '获取数据成功');
    } catch (e) {
      return ApiResponse.error(message: 'Mock 数据处理错误: $e', code: 500);
    }
  }

  /// 真实接口 - 获取首页音频列表
  static Future<ApiResponse<PaginatedResponse<AudioItem>>>
  _getRealHomeAudioList({
    int page = 1,
    int pageSize = 10,
    String? searchQuery,
    List<String>? tags,
  }) async {
    try {
      // 构建查询参数
      final queryParams = <String, String>{
        'page': page.toString(),
        'page_size': pageSize.toString(),
      };

      if (searchQuery != null && searchQuery.isNotEmpty) {
        queryParams['search'] = searchQuery;
      }

      if (tags != null && tags.isNotEmpty) {
        queryParams['tags'] = tags.join(',');
      }

      final uri = Uri.parse(
        '$_baseUrl/audio/list',
      ).replace(queryParameters: queryParams);

      final response = await http
          .get(
            uri,
            headers: {
              'Content-Type': 'application/json',
              'Accept': 'application/json',
            },
          )
          .timeout(_defaultTimeout);

      if (response.statusCode == 200) {
        final Map<String, dynamic> jsonData = json.decode(response.body);

        final paginatedResponse = PaginatedResponse.fromMap(
          jsonData['data'],
          (item) => AudioItem.fromMap(item),
        );

        return ApiResponse.success(
          data: paginatedResponse,
          message: jsonData['message'] ?? '获取数据成功',
        );
      } else {
        return ApiResponse.error(
          message: '服务器错误: ${response.statusCode}',
          code: response.statusCode,
        );
      }
    } catch (e) {
      return ApiResponse.error(message: '网络请求失败: $e', code: -1);
    }
  }

  /// 获取热门音频
  static Future<ApiResponse<List<AudioItem>>> getPopularAudio({
    int limit = 5,
  }) async {
    if (_currentMode == ApiMode.mock) {
      return _getMockPopularAudio(limit: limit);
    } else {
      return _getRealPopularAudio(limit: limit);
    }
  }

  /// Mock 模式 - 获取热门音频
  static Future<ApiResponse<List<AudioItem>>> _getMockPopularAudio({
    int limit = 5,
  }) async {
    try {
      await MockData.simulateNetworkDelay(500);

      final popularItems = MockData.getPopularAudioItems(limit: limit);

      return ApiResponse.success(data: popularItems, message: '获取热门音频成功');
    } catch (e) {
      return ApiResponse.error(message: 'Mock 热门数据错误: $e', code: 500);
    }
  }

  /// 真实接口 - 获取热门音频
  static Future<ApiResponse<List<AudioItem>>> _getRealPopularAudio({
    int limit = 5,
  }) async {
    try {
      final uri = Uri.parse(
        '$_baseUrl/audio/popular',
      ).replace(queryParameters: {'limit': limit.toString()});

      final response = await http
          .get(
            uri,
            headers: {
              'Content-Type': 'application/json',
              'Accept': 'application/json',
            },
          )
          .timeout(_defaultTimeout);

      if (response.statusCode == 200) {
        final Map<String, dynamic> jsonData = json.decode(response.body);
        final List<dynamic> itemsData = jsonData['data'] ?? [];

        final audioItems = itemsData
            .map((item) => AudioItem.fromMap(item))
            .toList();

        return ApiResponse.success(
          data: audioItems,
          message: jsonData['message'] ?? '获取热门音频成功',
        );
      } else {
        return ApiResponse.error(
          message: '服务器错误: ${response.statusCode}',
          code: response.statusCode,
        );
      }
    } catch (e) {
      return ApiResponse.error(message: '网络请求失败: $e', code: -1);
    }
  }

  /// 根据 ID 获取音频详情
  static Future<ApiResponse<AudioItem>> getAudioById(String id) async {
    if (_currentMode == ApiMode.mock) {
      return _getMockAudioById(id);
    } else {
      return _getRealAudioById(id);
    }
  }

  /// Mock 模式 - 根据 ID 获取音频详情
  static Future<ApiResponse<AudioItem>> _getMockAudioById(String id) async {
    try {
      await MockData.simulateNetworkDelay(300);

      final audioItem = MockData.getAudioItemById(id);

      if (audioItem != null) {
        return ApiResponse.success(data: audioItem, message: '获取音频详情成功');
      } else {
        return ApiResponse.error(message: '音频不存在', code: 404);
      }
    } catch (e) {
      return ApiResponse.error(message: 'Mock 详情数据错误: $e', code: 500);
    }
  }

  /// 真实接口 - 根据 ID 获取音频详情
  static Future<ApiResponse<AudioItem>> _getRealAudioById(String id) async {
    try {
      final uri = Uri.parse('$_baseUrl/audio/$id');

      final response = await http
          .get(
            uri,
            headers: {
              'Content-Type': 'application/json',
              'Accept': 'application/json',
            },
          )
          .timeout(_defaultTimeout);

      if (response.statusCode == 200) {
        final Map<String, dynamic> jsonData = json.decode(response.body);
        final audioItem = AudioItem.fromMap(jsonData['data']);

        return ApiResponse.success(
          data: audioItem,
          message: jsonData['message'] ?? '获取音频详情成功',
        );
      } else if (response.statusCode == 404) {
        return ApiResponse.error(message: '音频不存在', code: 404);
      } else {
        return ApiResponse.error(
          message: '服务器错误: ${response.statusCode}',
          code: response.statusCode,
        );
      }
    } catch (e) {
      return ApiResponse.error(message: '网络请求失败: $e', code: -1);
    }
  }

  /// 获取所有标签
  static Future<ApiResponse<List<String>>> getAllTags() async {
    if (_currentMode == ApiMode.mock) {
      try {
        await MockData.simulateNetworkDelay(200);
        final tags = MockData.getAllTags();

        return ApiResponse.success(data: tags, message: '获取标签成功');
      } catch (e) {
        return ApiResponse.error(message: 'Mock 标签数据错误: $e', code: 500);
      }
    } else {
      try {
        final uri = Uri.parse('$_baseUrl/tags');

        final response = await http
            .get(
              uri,
              headers: {
                'Content-Type': 'application/json',
                'Accept': 'application/json',
              },
            )
            .timeout(_defaultTimeout);

        if (response.statusCode == 200) {
          final Map<String, dynamic> jsonData = json.decode(response.body);
          final List<String> tags = List<String>.from(jsonData['data'] ?? []);

          return ApiResponse.success(
            data: tags,
            message: jsonData['message'] ?? '获取标签成功',
          );
        } else {
          return ApiResponse.error(
            message: '服务器错误: ${response.statusCode}',
            code: response.statusCode,
          );
        }
      } catch (e) {
        return ApiResponse.error(message: '网络请求失败: $e', code: -1);
      }
    }
  }

  /// 获取首页 tabs
  static Future<ApiResponse<List<TabItem>>> getHomeTabs() async {
    if (_currentMode == ApiMode.mock) {
      return _getMockHomeTabs();
    } else {
      return _getRealHomeTabs();
    }
  }

  /// Mock 模式 - 获取首页 tabs
  static Future<ApiResponse<List<TabItem>>> _getMockHomeTabs() async {
    try {
      await MockData.simulateNetworkDelay(300);

      // Mock 数据：返回一些示例 tabs
      final tabs = [
        const TabItem(id: 'mf', title: 'M/F', tag: 'M/F', order: 1),
        const TabItem(id: 'fm', title: 'F/M', tag: 'F/M', order: 2),
        const TabItem(id: 'asmr', title: 'ASMR', tag: 'ASMR', order: 3),
        const TabItem(id: 'nsfw', title: 'NSFW', tag: 'NSFW', order: 4),
      ];

      return ApiResponse.success(data: tabs, message: '获取 tabs 成功');
    } catch (e) {
      return ApiResponse.error(message: 'Mock tabs 数据错误: $e', code: 500);
    }
  }

  /// 真实接口 - 获取首页 tabs
  static Future<ApiResponse<List<TabItem>>> _getRealHomeTabs() async {
    try {
      final uri = Uri.parse('$_baseUrl/home/tabs');

      final response = await http
          .get(
            uri,
            headers: {
              'Content-Type': 'application/json',
              'Accept': 'application/json',
            },
          )
          .timeout(_defaultTimeout);

      if (response.statusCode == 200) {
        final Map<String, dynamic> jsonData = json.decode(response.body);
        final List<dynamic> tabsData = jsonData['data'] ?? [];

        final tabs = tabsData.map((item) => TabItem.fromMap(item)).toList();

        return ApiResponse.success(
          data: tabs,
          message: jsonData['message'] ?? '获取 tabs 成功',
        );
      } else {
        return ApiResponse.error(
          message: '服务器错误: ${response.statusCode}',
          code: response.statusCode,
        );
      }
    } catch (e) {
      return ApiResponse.error(message: '网络请求失败: $e', code: -1);
    }
  }
}
