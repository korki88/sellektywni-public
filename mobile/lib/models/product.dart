import 'product_category.dart';
import 'product_condition.dart';

export 'product_condition.dart';

class Product {
  const Product({
    required this.id,
    required this.name,
    required this.pricePln,
    required this.imageUrl,
    required this.category,
    required this.condition,
    this.stockQty = 1,
    this.reservedQty = 0,
    this.canAddToCart = true,
  });

  final String id;
  final String name;
  final double pricePln;
  final String imageUrl;
  final ProductCategory category;
  final ProductCondition condition;
  final int stockQty;
  final int reservedQty;
  final bool canAddToCart;

  Product copyWith({
    int? stockQty,
    int? reservedQty,
    bool? canAddToCart,
  }) {
    return Product(
      id: id,
      name: name,
      pricePln: pricePln,
      imageUrl: imageUrl,
      category: category,
      condition: condition,
      stockQty: stockQty ?? this.stockQty,
      reservedQty: reservedQty ?? this.reservedQty,
      canAddToCart: canAddToCart ?? this.canAddToCart,
    );
  }
}
