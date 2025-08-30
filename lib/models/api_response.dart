class ApiResponse<T> {
  final bool success;
  final String message;
  final T? data;
  final int? code;
  final Map<String, dynamic>? meta;

  ApiResponse({
    required this.success,
    required this.message,
    this.data,
    this.code,
    this.meta,
  });

  factory ApiResponse.fromMap(
    Map<String, dynamic> map,
    T Function(dynamic)? fromMapT,
  ) {
    return ApiResponse<T>(
      success: map['success'] ?? false,
      message: map['message'] ?? '',
      data: map['data'] != null && fromMapT != null
          ? fromMapT(map['data'])
          : map['data'],
      code: map['code'],
      meta: map['meta'],
    );
  }

  factory ApiResponse.success({
    required T data,
    String message = 'Success',
    int? code,
    Map<String, dynamic>? meta,
  }) {
    return ApiResponse<T>(
      success: true,
      message: message,
      data: data,
      code: code,
      meta: meta,
    );
  }

  factory ApiResponse.error({
    required String message,
    int? code,
    T? data,
    Map<String, dynamic>? meta,
  }) {
    return ApiResponse<T>(
      success: false,
      message: message,
      data: data,
      code: code,
      meta: meta,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'success': success,
      'message': message,
      'data': data,
      'code': code,
      'meta': meta,
    };
  }

  @override
  String toString() {
    return 'ApiResponse(success: $success, message: $message, data: $data)';
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
