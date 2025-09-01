class TabItemModel {
  final String id;
  final String label;

  const TabItemModel({required this.id, required this.label});

  factory TabItemModel.fromMap(Map<String, dynamic> map) {
    return TabItemModel(id: map['id'] ?? '', label: map['label'] ?? '');
  }

  Map<String, dynamic> toMap() {
    return {'id': id, 'label': label};
  }

  @override
  String toString() {
    return 'TabItemModel(id: $id, label: $label)';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is TabItemModel && other.id == id;
  }

  @override
  int get hashCode => id.hashCode;
}
