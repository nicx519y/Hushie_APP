import 'audio_item.dart';

class TabItemModel {
  final String id;
  final String label;
  final List<AudioItem> items;

  const TabItemModel({
    required this.id,
    required this.label,
    required this.items,
  });

  factory TabItemModel.fromMap(Map<String, dynamic> map) {
    return TabItemModel(
      id: map['id'] ?? '',
      label: map['label'] ?? '',
      items: (map['items'] as List<dynamic>?)
          ?.map((e) => AudioItem.fromMap(e as Map<String, dynamic>))
          .toList() ??
          [],
    );
  }

  Map<String, dynamic> toMap() {
    return {'id': id, 'label': label, 'items': items.map((e) => e.toMap()).toList()};
  }

  @override
  String toString() {
    return 'TabItemModel(id: $id, label: $label, items: $items)';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is TabItemModel && other.id == id;
  }

  @override
  int get hashCode => id.hashCode;
}
