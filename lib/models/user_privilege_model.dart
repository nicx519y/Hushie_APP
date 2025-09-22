/// 用户权限信息模型
class UserPrivilege {
  final bool hasPremium;
  final DateTime? premiumExpireTime;

  const UserPrivilege({
    required this.hasPremium,
    this.premiumExpireTime,
  });

  factory UserPrivilege.fromJson(Map<String, dynamic> json) {
    return UserPrivilege(
      hasPremium: json['has_premium'] ?? json['has_privilege'] ?? false,
      premiumExpireTime: json['expires_at'] != null
          ? DateTime.parse(json['expires_at'])
          : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'has_premium': hasPremium,
      'premium_expire_time': premiumExpireTime?.toIso8601String(),
    };
  }

  @override
  String toString() {
    return 'UserPrivilege{hasPremium: $hasPremium, premiumExpireTime: $premiumExpireTime}';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is UserPrivilege &&
        other.hasPremium == hasPremium &&
        other.premiumExpireTime == premiumExpireTime;
  }

  @override
  int get hashCode {
    return hasPremium.hashCode ^ premiumExpireTime.hashCode;
  }

  /// 检查高级权限是否有效
  /// 如果没有高级权限或者已过期，返回false
  bool get isValidPremium {
    if (!hasPremium) return false;
    
    return true;
  }

  /// 获取剩余天数
  /// 如果没有高级权限或已过期，返回0
  int get remainingDays {
    if (!hasPremium) return 0;
    if (premiumExpireTime == null) return 0;
    
    final now = DateTime.now();
    final diff = premiumExpireTime!.difference(now).inDays;
    return diff.clamp(0, double.maxFinite.toInt());
  }

}
