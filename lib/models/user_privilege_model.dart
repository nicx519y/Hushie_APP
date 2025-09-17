/// 用户权限信息模型
class UserPrivilege {
  final bool hasPremium;
  final String? premiumEndDate;

  const UserPrivilege({
    required this.hasPremium,
    this.premiumEndDate,
  });

  factory UserPrivilege.fromJson(Map<String, dynamic> json) {
    return UserPrivilege(
      hasPremium: json['has_premium'] as bool,
      premiumEndDate: json['premium_end_date'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'has_premium': hasPremium,
      'premium_end_date': premiumEndDate,
    };
  }

  @override
  String toString() {
    return 'UserPrivilege{hasPremium: $hasPremium, premiumEndDate: $premiumEndDate}';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is UserPrivilege &&
        other.hasPremium == hasPremium &&
        other.premiumEndDate == premiumEndDate;
  }

  @override
  int get hashCode {
    return Object.hash(hasPremium, premiumEndDate);
  }

  /// 检查高级权限是否有效
  /// 如果没有高级权限或者已过期，返回false
  bool get isValidPremium {
    if (!hasPremium) return false;
    if (premiumEndDate == null) return false;
    
    try {
      final endDate = DateTime.parse(premiumEndDate!);
      return DateTime.now().isBefore(endDate);
    } catch (e) {
      // 如果日期解析失败，认为权限无效
      return false;
    }
  }

  /// 获取剩余天数
  /// 如果没有高级权限或已过期，返回0
  int get remainingDays {
    if (!hasPremium || premiumEndDate == null) return 0;
    
    try {
      final endDate = DateTime.parse(premiumEndDate!);
      final now = DateTime.now();
      if (now.isAfter(endDate)) return 0;
      
      return endDate.difference(now).inDays;
    } catch (e) {
      return 0;
    }
  }

  /// 获取格式化的到期时间
  /// 返回友好的时间显示格式
  String get formattedEndDate {
    if (premiumEndDate == null) return '未知';
    
    try {
      final endDate = DateTime.parse(premiumEndDate!);
      return '${endDate.year}-${endDate.month.toString().padLeft(2, '0')}-${endDate.day.toString().padLeft(2, '0')}';
    } catch (e) {
      return premiumEndDate!;
    }
  }
}