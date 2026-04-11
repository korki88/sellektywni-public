enum ProductCategory {
  clothing,
  shoes,
  accessories,
}

extension ProductCategoryX on ProductCategory {
  String get label => switch (this) {
        ProductCategory.clothing => 'Odzież',
        ProductCategory.shoes => 'Buty',
        ProductCategory.accessories => 'Akcesoria',
      };
}
