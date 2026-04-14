import 'package:flutter/foundation.dart';

import '../models/product.dart';

/// Porównywarka produktów (jak w wielu sklepach SaaS) — max [maxItems] pozycji.
class CompareNotifier extends ChangeNotifier {
  static const int maxItems = 4;

  final List<Product> _items = [];

  List<Product> get items => List.unmodifiable(_items);

  bool contains(Product p) => _items.any((x) => x.id == p.id);

  void toggle(Product p) {
    if (contains(p)) {
      _items.removeWhere((x) => x.id == p.id);
    } else {
      if (_items.length >= maxItems) {
        _items.removeAt(0);
      }
      _items.add(p);
    }
    notifyListeners();
  }

  void remove(String productId) {
    _items.removeWhere((x) => x.id == productId);
    notifyListeners();
  }

  void clear() {
    _items.clear();
    notifyListeners();
  }
}
