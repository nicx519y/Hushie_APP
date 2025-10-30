// 新手引导相关数据模型

/// 标签选项模型
class TagOption {
  final String value;
  final String label;
  final String? url;

  TagOption({
    required this.value,
    required this.label,
    this.url,
  });

  factory TagOption.fromMap(Map<String, dynamic> map) {
    return TagOption(
      value: map['value'] ?? '',
      label: map['label'] ?? '',
      url: map['url'],
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'value': value,
      'label': label,
      if (url != null) 'url': url,
    };
  }

  @override
  String toString() => 'TagOption(value: $value, label: $label, url: $url)';
}

/// 新手引导数据模型
class OnboardingGuideData {
  final bool vippageenabled;
  final List<TagOption> tagGender;
  final List<TagOption> tagTone;
  final List<TagOption> tagScene;

  OnboardingGuideData({
    required this.vippageenabled,
    required this.tagGender,
    required this.tagTone,
    required this.tagScene,
  });

  factory OnboardingGuideData.fromMap(Map<String, dynamic> map) {
    return OnboardingGuideData(
      vippageenabled: map['vippageenabled'] ?? false,
      tagGender: (map['tags_gender'] as List<dynamic>?)
              ?.map((item) => TagOption.fromMap(item as Map<String, dynamic>))
              .toList() ??
          [],
      tagTone: (map['tags_tone'] as List<dynamic>?)
              ?.map((item) => TagOption.fromMap(item as Map<String, dynamic>))
              .toList() ??
          [],
      tagScene: (map['tags_scene'] as List<dynamic>?)
              ?.map((item) => TagOption.fromMap(item as Map<String, dynamic>))
              .toList() ??
          [],
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'vippageenabled': vippageenabled,
      'tags_gender': tagGender.map((item) => item.toMap()).toList(),
      'tags_tone': tagTone.map((item) => item.toMap()).toList(),
      'tags_scene': tagScene.map((item) => item.toMap()).toList(),
    };
  }

  @override
  String toString() =>
      'OnboardingGuideData(vippageenabled: $vippageenabled, tagGender: $tagGender, tagTone: $tagTone, tagScene: $tagScene)';
}

/// 用户偏好设置请求模型
class UserPreferencesRequest {
  final List<String> tagGender;
  final List<String> tagTone;
  final List<String> tagScene;

  UserPreferencesRequest({
    required this.tagGender,
    required this.tagTone,
    required this.tagScene,
  });

  Map<String, dynamic> toMap() {
    return {
      'tags_gender': tagGender,
      'tags_tone': tagTone,
      'tags_scene': tagScene,
    };
  }

  @override
  String toString() =>
      'UserPreferencesRequest(tagGender: $tagGender, tagTone: $tagTone, tagScene: $tagScene)';
}

/// 用户偏好设置响应模型
class UserPreferencesResponse {
  final bool success;

  UserPreferencesResponse({required this.success});

  factory UserPreferencesResponse.fromMap(Map<String, dynamic> map) {
    return UserPreferencesResponse(
      success: map['success'] ?? false,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'success': success,
    };
  }

  @override
  String toString() => 'UserPreferencesResponse(success: $success)';
}