/// 用户权限信息模型
class UserPrivilege {
  final bool hasPremium;

  const UserPrivilege({
    required this.hasPremium,
  });

  factory UserPrivilege.fromJson(Map<String, dynamic> json) {
    return UserPrivilege(
      hasPremium: json['has_premium'] ?? json['has_privilege'] ?? false,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'has_premium': hasPremium,
    };
  }

  @override
  String toString() {
    return 'UserPrivilege{hasPremium: $hasPremium}';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is UserPrivilege &&
        other.hasPremium == hasPremium;
  }

  @override
  int get hashCode {
    return hasPremium.hashCode;
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
    
    return 0;
  }

}
