class Product {
  final int id;
  final String name;
  final String description;
  final String productType;
  final double price;
  final String currency;
  final int durationDays;
  final bool isCurrentState;

  const Product({
    required this.id,
    required this.name,
    required this.description,
    required this.productType,
    required this.price,
    required this.currency,
    required this.durationDays,
    required this.isCurrentState,
  });

  factory Product.fromJson(Map<String, dynamic> json) {
    return Product(
      id: json['id'] as int,
      name: json['name'] as String,
      description: json['description'] as String,
      productType: json['product_type'] as String,
      price: (json['price'] as num).toDouble(),
      currency: json['currency'] as String,
      durationDays: json['duration_days'] as int,
      isCurrentState: json['is_current_state'] ?? false,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'description': description,
      'product_type': productType,
      'price': price,
      'currency': currency,
      'duration_days': durationDays,
      'is_current_state': isCurrentState,
    };
  }

  @override
  String toString() {
    return 'Product{id: $id, name: $name, description: $description, productType: $productType, price: $price, currency: $currency, durationDays: $durationDays, isCurrentState: $isCurrentState}';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is Product &&
        other.id == id &&
        other.name == name &&
        other.description == description &&
        other.productType == productType &&
        other.price == price &&
        other.currency == currency &&
        other.durationDays == durationDays &&
        other.isCurrentState == isCurrentState;
  }

  @override
  int get hashCode {
    return Object.hash(
      id,
      name,
      description,
      productType,
      price,
      currency,
      durationDays,
      isCurrentState,
    );
  }
}

class ProductListResponse {
  final int errNo;
  final String errMsg;
  final ProductData data;

  const ProductListResponse({
    required this.errNo,
    required this.errMsg,
    required this.data,
  });

  factory ProductListResponse.fromJson(Map<String, dynamic> json) {
    return ProductListResponse(
      errNo: json['errNo'] as int,
      errMsg: json['errMsg'] as String,
      data: ProductData.fromJson(json['data'] as Map<String, dynamic>),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'errNo': errNo,
      'errMsg': errMsg,
      'data': data.toJson(),
    };
  }

  bool get isSuccess => errNo == 0;
}

class ProductData {
  final List<Product> products;

  const ProductData({
    required this.products,
  });

  factory ProductData.fromJson(Map<String, dynamic> json) {
    final productsList = json['products'] as List<dynamic>;
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