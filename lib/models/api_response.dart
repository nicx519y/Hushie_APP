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
          (a, b) {
            final aTime = a.lastPlayedAt ?? DateTime.now();
            final bTime = b.lastPlayedAt ?? DateTime.now();
            return bTime.compareTo(aTime);
          },
        ),
    );
  }
}

/// Google认证响应模型
class GoogleAuthResponse {
  final String userId;
  final String email;
  final String displayName;
  final String? photoUrl;
  final String authCode;
  final String authType;

  GoogleAuthResponse({
    required this.userId,
    required this.email,
    required this.displayName,
    this.photoUrl,
    required this.authCode,
    required this.authType,
  });

  factory GoogleAuthResponse.fromMap(Map<String, dynamic> map) {
    return GoogleAuthResponse(
      userId: map['user_id'] ?? '',
      email: map['email'] ?? '',
      displayName: map['display_name'] ?? '',
      photoUrl: map['photo_url'],
      authCode: map['auth_code'] ?? '',
      authType: map['auth_type'] ?? '',
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'user_id': userId,
      'email': email,
      'display_name': displayName,
      'photo_url': photoUrl,
      'auth_code': authCode,
      'auth_type': authType,
    };
  }

  @override
  String toString() {
    return 'GoogleAuthResponse(userId: $userId, email: $email, displayName: $displayName, photoUrl: $photoUrl, authCode: $authCode, authType: $authType)';
  }
}

/// 访问令牌响应模型
class AccessTokenResponse {
  final String accessToken;
  final String refreshToken;
  final int expiresIn;
  final String tokenType;
  final int expiresAt;

  AccessTokenResponse({
    required this.accessToken,
    required this.refreshToken,
    required this.expiresIn,
    required this.tokenType,
    required this.expiresAt,
  });

  factory AccessTokenResponse.fromMap(Map<String, dynamic> map) {
    return AccessTokenResponse(
      accessToken: map['access_token'] ?? '',
      refreshToken: map['refresh_token'] ?? '',
      expiresIn: map['expires_in'] ?? 0,
      tokenType: map['token_type'] ?? 'Bearer',
      expiresAt: map['expires_at'] ?? 0,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'access_token': accessToken,
      'refresh_token': refreshToken,
      'expires_in': expiresIn,
      'token_type': tokenType,
      'expires_at': expiresAt,
    };
  }

  /// 检查Token是否即将过期（30分钟内）
  bool get isExpiringSoon {
    final now = DateTime.now().millisecondsSinceEpoch ~/ 1000;
    return (expiresAt - now) < 1800; // 30分钟 = 1800秒
  }

  @override
  String toString() {
    return 'AccessTokenResponse(accessToken: ${accessToken.substring(0, 10)}..., refreshToken: ${refreshToken.substring(0, 10)}..., expiresIn: $expiresIn, tokenType: $tokenType, expiresAt: $expiresAt)';
  }
}

/// 令牌验证响应模型
class TokenValidationResponse {
  final bool isValid;
  final int expiresAt;
  final String userId;
  final String email;
  final List<String> scopes;

  TokenValidationResponse({
    required this.isValid,
    required this.expiresAt,
    required this.userId,
    required this.email,
    required this.scopes,
  });

  factory TokenValidationResponse.fromMap(Map<String, dynamic> map) {
    return TokenValidationResponse(
      isValid: map['is_valid'] ?? false,
      expiresAt: map['expires_at'] ?? 0,
      userId: map['user_id'] ?? '',
      email: map['email'] ?? '',
      scopes: List<String>.from(map['scopes'] ?? []),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'is_valid': isValid,
      'expires_at': expiresAt,
      'user_id': userId,
      'email': email,
      'scopes': scopes,
    };
  }

  @override
  String toString() {
    return 'TokenValidationResponse(isValid: $isValid, expiresAt: $expiresAt, userId: $userId, email: $email, scopes: $scopes)';
  }
}
