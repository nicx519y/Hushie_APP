class SubscribeModel {
  final String? name;
  final List<String> featureList;
  final List<SubscriptionOption> optionList;

  const SubscribeModel({
    required this.name,
    required this.featureList,
    required this.optionList,
  });

  factory SubscribeModel.fromJson(Map<String, dynamic> json) {
    return SubscribeModel(
      name: json['name'] as String?,
      featureList: List<String>.from(json['featureList'] as List),
      optionList: (json['optionList'] as List)
          .map((item) => SubscriptionOption.fromJson(item as Map<String, dynamic>))
          .toList(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'name': name ?? '',
      'featureList': featureList,
      'optionList': optionList.map((option) => option.toJson()).toList(),
    };
  }

  @override
  String toString() {
    return 'SubscribeModel(name: $name, featureList: $featureList, optionList: $optionList)';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is SubscribeModel &&
        other.name == name &&
        _listEquals(other.featureList, featureList) &&
        _listEquals(other.optionList, optionList);
  }

  @override
  int get hashCode {
    return name?.hashCode ?? 0 ^ featureList.hashCode ^ optionList.hashCode;
  }

  bool _listEquals<T>(List<T> a, List<T> b) {
    if (a.length != b.length) return false;
    for (int i = 0; i < a.length; i++) {
      if (a[i] != b[i]) return false;
    }
    return true;
  }
}

class SubscriptionOption {
  final String title;
  final String price;
  final String? originalPrice;
  final int planIndex;

  const SubscriptionOption({
    required this.title,
    required this.price,
    this.originalPrice,
    required this.planIndex,
  });

  factory SubscriptionOption.fromJson(Map<String, dynamic> json) {
    return SubscriptionOption(
      title: json['title'] as String,
      price: json['price'] as String,
      originalPrice: json['originalPrice'] as String?,
      planIndex: json['planIndex'] as int,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'title': title,
      'price': price,
      'originalPrice': originalPrice,
      'planIndex': planIndex,
    };
  }

  @override
  String toString() {
    return 'SubscriptionOption(title: $title, price: $price, originalPrice: $originalPrice, planIndex: $planIndex)';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is SubscriptionOption &&
        other.title == title &&
        other.price == price &&
        other.originalPrice == originalPrice &&
        other.planIndex == planIndex;
  }

  @override
  int get hashCode {
    return title.hashCode ^
        price.hashCode ^
        originalPrice.hashCode ^
        planIndex.hashCode;
  }
}