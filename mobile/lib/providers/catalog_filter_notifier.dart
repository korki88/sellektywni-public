import 'package:flutter/foundation.dart';

import '../models/product.dart';
import '../models/product_category.dart';
import '../data/mock_catalog.dart';

class CatalogFilterNotifier extends ChangeNotifier {
  ProductCategory? _category;
  ProductCondition? _condition;

  ProductCategory? get category => _category;
  ProductCondition? get condition => _condition;

  void setCategory(ProductCategory? value) {
    _category = value;
    notifyListeners();
  }

  void setCondition(ProductCondition? value) {
    _condition = value;
    notifyListeners();
  }

  List<Product> get visibleProducts {
    return mockProducts.where((p) {
      final catOk = _category == null || p.category == _category;
      final condOk = _condition == null || p.condition == _condition;
      return catOk && condOk;
    }).toList();
  }
}
