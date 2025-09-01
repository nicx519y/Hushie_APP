class UserInfoModel {
  final String uid;
  final String nickname;
  final String avatar;
  final bool isVip;

  const UserInfoModel({
    required this.uid,
    required this.nickname,
    required this.avatar,
    required this.isVip,
  });

  factory UserInfoModel.fromMap(Map<String, dynamic> map) {
    return UserInfoModel(
      uid: map['uid'] ?? '',
      nickname: map['nickname'] ?? '',
      avatar: map['avatar'] ?? '',
      isVip: map['is_vip'] ?? false,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'uid': uid,
      'nickname': nickname,
      'avatar': avatar,
      'is_vip': isVip,
    };
  }

  @override
  String toString() {
    return 'UserInfoModel(uid: $uid, nickname: $nickname, avatar: $avatar, isVip: $isVip)';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is UserInfoModel && other.uid == uid;
  }

  @override
  int get hashCode => uid.hashCode;

  /// 创建一个带有更新字段的副本
  UserInfoModel copyWith({
    String? uid,
    String? nickname,
    String? avatar,
    bool? isVip,
  }) {
    return UserInfoModel(
      uid: uid ?? this.uid,
      nickname: nickname ?? this.nickname,
      avatar: avatar ?? this.avatar,
      isVip: isVip ?? this.isVip,
    );
  }
}
