/// 优惠信息模型
class Offer {
  final String offerId;
  final String name;
  final double price;
  final String currency;
  final String description;

  const Offer({
    required this.offerId,
    required this.name,
    required this.price,
    required this.currency,
    required this.description,
  });

  factory Offer.fromJson(Map<String, dynamic> json) {
    return Offer(
      offerId: json['offer_id'] as String,
      name: json['name'] as String,
      price: (json['price'] as num).toDouble(),
      currency: json['currency'] as String,
      description: json['description'] as String,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'offer_id': offerId,
      'name': name,
      'price': price,
      'currency': currency,
      'description': description,
    };
  }

  @override
  String toString() {
    return 'Offer{offerId: $offerId, name: $name, price: $price, currency: $currency, description: $description}';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is Offer &&
        other.offerId == offerId &&
        other.name == name &&
        other.price == price &&
        other.currency == currency &&
        other.description == description;
  }

  @override
  int get hashCode {
    return Object.hash(offerId, name, price, currency, description);
  }
}

/// 基础计划模型
class BasePlan {
  final String googlePlayBasePlanId;
  final String name;
  final double price;
  final String currency;
  final String billingPeriod;
  final int durationDays;
  final List<Offer> offers;

  const BasePlan({
    required this.googlePlayBasePlanId,
    required this.name,
    required this.price,
    required this.currency,
    required this.billingPeriod,
    required this.durationDays,
    required this.offers,
  });

  factory BasePlan.fromJson(Map<String, dynamic> json) {
    final offersList = json['offers'] as List<dynamic>? ?? [];
    return BasePlan(
      googlePlayBasePlanId: json['google_play_base_plan_id'] as String,
      name: json['name'] as String,
      price: (json['price'] as num).toDouble(),
      currency: json['currency'] as String,
      billingPeriod: json['billing_period'] as String,
      durationDays: json['duration_days'] as int,
      offers: offersList
          .map((item) => Offer.fromJson(item as Map<String, dynamic>))
          .toList(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'google_play_base_plan_id': googlePlayBasePlanId,
      'name': name,
      'price': price,
      'currency': currency,
      'billing_period': billingPeriod,
      'duration_days': durationDays,
      'offers': offers.map((offer) => offer.toJson()).toList(),
    };
  }

  @override
  String toString() {
    return 'BasePlan{googlePlayBasePlanId: $googlePlayBasePlanId, name: $name, price: $price, currency: $currency, billingPeriod: $billingPeriod, durationDays: $durationDays, offers: $offers}';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is BasePlan &&
        other.googlePlayBasePlanId == googlePlayBasePlanId &&
        other.name == name &&
        other.price == price &&
        other.currency == currency &&
        other.billingPeriod == billingPeriod &&
        other.durationDays == durationDays &&
        _listEquals(other.offers, offers);
  }

  @override
  int get hashCode {
    return Object.hash(
      googlePlayBasePlanId,
      name,
      price,
      currency,
      billingPeriod,
      durationDays,
      offers,
    );
  }

  bool _listEquals<T>(List<T> a, List<T> b) {
    if (a.length != b.length) return false;
    for (int i = 0; i < a.length; i++) {
      if (a[i] != b[i]) return false;
    }
    return true;
  }
}

/// 产品模型
class Product {
  final String googlePlayProductId;
  final String name;
  final String description;
  final String productType;
  final List<BasePlan> basePlans;

  const Product({
    required this.googlePlayProductId,
    required this.name,
    required this.description,
    required this.productType,
    required this.basePlans,
  });

  factory Product.fromJson(Map<String, dynamic> json) {
    final basePlansList = json['base_plans'] as List<dynamic>? ?? [];
    return Product(
      googlePlayProductId: json['google_play_product_id'] as String,
      name: json['name'] as String,
      description: json['description'] as String,
      productType: json['product_type'] as String,
      basePlans: basePlansList
          .map((item) => BasePlan.fromJson(item as Map<String, dynamic>))
          .toList(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'google_play_product_id': googlePlayProductId,
      'name': name,
      'description': description,
      'product_type': productType,
      'base_plans': basePlans.map((plan) => plan.toJson()).toList(),
    };
  }

  @override
  String toString() {
    return 'Product{googlePlayProductId: $googlePlayProductId, name: $name, description: $description, productType: $productType, basePlans: $basePlans}';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is Product &&
        other.googlePlayProductId == googlePlayProductId &&
        other.name == name &&
        other.description == description &&
        other.productType == productType &&
        _listEquals(other.basePlans, basePlans);
  }

  @override
  int get hashCode {
    return Object.hash(
      googlePlayProductId,
      name,
      description,
      productType,
      basePlans,
    );
  }

  bool _listEquals<T>(List<T> a, List<T> b) {
    if (a.length != b.length) return false;
    for (int i = 0; i < a.length; i++) {
      if (a[i] != b[i]) return false;
    }
    return true;
  }
}

/// API响应数据模型
class ProductData {
  final List<Product> products;

  const ProductData({
    required this.products,
  });

  factory ProductData.fromJson(Map<String, dynamic> json) {
    final productsList = json['products'] as List<dynamic>? ?? [];
    return ProductData(
      products: productsList
          .map((item) => Product.fromJson(item as Map<String, dynamic>))
          .toList(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'products': products.map((product) => product.toJson()).toList(),
    };
  }
}