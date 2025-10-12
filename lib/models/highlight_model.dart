class HighlightModel {
  final List<String> title;
  final List<String> tags;

  HighlightModel({
    required this.title,
    required this.tags,
  });

  /// 从Map创建HighlightModel实例
  factory HighlightModel.fromMap(Map<String, dynamic> map) {
    return HighlightModel(
      title: List<String>.from(map['title'] ?? []),
      tags: List<String>.from(map['tags'] ?? []) + List<String>.from(map['tags_gender'] ?? []),
    );
  }

  /// 将HighlightModel转换为Map
  Map<String, dynamic> toMap() {
    return {
      'title': title,
      'tags': tags,
    };
  }
  
}
  
