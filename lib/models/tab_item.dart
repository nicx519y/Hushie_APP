class TabItem {
  final String id;
  final String title;
  final String? icon;
  final String? tag; // 用于 API 请求的标签
  final bool isDefault; // 是否为默认 tab
  final int order; // 排序
  final bool isEnabled; // 是否启用

  const TabItem({
    required this.id,
    required this.title,
    this.icon,
    this.tag,
    this.isDefault = false,
    this.order = 0,
    this.isEnabled = true,
  });

  factory TabItem.fromMap(Map<String, dynamic> map) {
    return TabItem(
      id: map['id'] ?? '',
      title: map['title'] ?? '',
      icon: map['icon'],
      tag: map['tag'],
      isDefault: map['is_default'] ?? false,
      order: map['order'] ?? 0,
      isEnabled: map['is_enabled'] ?? true,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'title': title,
      'icon': icon,
      'tag': tag,
      'is_default': isDefault,
      'order': order,
      'is_enabled': isEnabled,
    };
  }

  @override
  String toString() {
    return 'TabItem(id: $id, title: $title, tag: $tag, order: $order)';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is TabItem && other.id == id;
  }

  @override
  int get hashCode => id.hashCode;
}
