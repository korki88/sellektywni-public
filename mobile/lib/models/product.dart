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
  });

  final String id;
  final String name;
  final double pricePln;
  final String imageUrl;
  final ProductCategory category;
  final ProductCondition condition;
}
