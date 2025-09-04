import 'audio_item.dart';

class ApiResponse<T> {
  final T? data;
  final int errNo;

  ApiResponse({required this.data, required this.errNo});

  factory ApiResponse.success({required T data, int errNo = 0}) {
    return ApiResponse<T>(data: data, errNo: errNo);
  }

  factory ApiResponse.error({int errNo = -1}) {
    return ApiResponse<T>(data: null, errNo: errNo);
  }

  /// 统一的JSON处理函数
  static ApiResponse<T> fromJson<T>(
    Map<String, dynamic> json,
    T Function(Map<String, dynamic>) fromMapT,
  ) {
    final int errNo = json['errNo'] ?? -1;

    // 检查errNo，只有为0时才处理data
    if (errNo != 0) {
      return ApiResponse.error(errNo: errNo);
    }

    // errNo == 0，处理data
    try {
      final dynamic dataJson = json['data'];
      if (dataJson == null) {
        return ApiResponse.error(errNo: errNo);
      }

      final T data = fromMapT(dataJson as Map<String, dynamic>);
      return ApiResponse.success(data: data, errNo: errNo);
    } catch (e) {
      return ApiResponse.error(errNo: errNo);
    }
  }

  Map<String, dynamic> toMap() {
    return {'errNo': errNo, 'data': data};
  }

  @override
  String toString() {
    return 'ApiResponse(errNo: $errNo, data: $data)';
  }
}

class PaginatedResponse<T> {
  final List<T> items;
  final int currentPage;
  final int totalPages;
  final int totalItems;
  final int pageSize;
  final bool hasNextPage;
  final bool hasPreviousPage;

  PaginatedResponse({
    required this.items,
    required this.currentPage,
    required this.totalPages,
    required this.totalItems,
    required this.pageSize,
    required this.hasNextPage,
    required this.hasPreviousPage,
  });

  factory PaginatedResponse.fromMap(
    Map<String, dynamic> map,
    T Function(Map<String, dynamic>) fromMapT,
  ) {
    final List<dynamic> itemsData = map['items'] ?? [];
    final List<T> items = itemsData
        .map((item) => fromMapT(item as Map<String, dynamic>))
        .toList();

    return PaginatedResponse<T>(
      items: items,
      currentPage: map['current_page'] ?? 1,
      totalPages: map['total_pages'] ?? 1,
      totalItems: map['total_items'] ?? items.length,
      pageSize: map['page_size'] ?? items.length,
      hasNextPage: map['has_next_page'] ?? false,
      hasPreviousPage: map['has_previous_page'] ?? false,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'items': items,
      'current_page': currentPage,
      'total_pages': totalPages,
      'total_items': totalItems,
      'page_size': pageSize,
      'has_next_page': hasNextPage,
      'has_previous_page': hasPreviousPage,
    };
  }
}

class SimpleResponse<T> {
  final List<T> items;

  SimpleResponse({required this.items});

  factory SimpleResponse.fromMap(
    Map<String, dynamic> map,
    T Function(Map<String, dynamic>) fromMapT,
  ) {
    final List<dynamic> itemsData = map['items'] ?? [];
    final List<T> items = itemsData
        .map((item) => fromMapT(item as Map<String, dynamic>))
        .toList();

    return SimpleResponse<T>(items: items);
  }

  Map<String, dynamic> toMap() {
    return {'items': items};
  }
}

/// 用户播放历史响应模型
class UserHistoryResponse {
  final List<AudioItem> history;

  UserHistoryResponse({required this.history});

  factory UserHistoryResponse.fromJson(List<AudioItem> history) {
    return UserHistoryResponse(
      history: history
        ..sort(
          (a, b) =>
              (b.lastPlayedAt?.compareTo(a.lastPlayedAt ?? DateTime.now()) ??
              0),
        ),
    );
  }
}
