import 'package:flutter/foundation.dart';

import '../models/product.dart';

class CartNotifier extends ChangeNotifier {
  final Map<String, int> _qtyById = {};
  final Map<String, Product> _products = {};

  int get itemCount => _qtyById.values.fold(0, (a, b) => a + b);

  double get subtotalPln {
    var sum = 0.0;
    for (final e in _qtyById.entries) {
      final p = _products[e.key];
      if (p != null) {
        sum += p.pricePln * e.value;
      }
    }
    return sum;
  }

  List<({Product product, int qty})> get lines {
    return _qtyById.entries
        .map((e) {
          final p = _products[e.key];
          if (p == null) return null;
          return (product: p, qty: e.value);
        })
        .whereType<({Product product, int qty})>()
        .toList();
  }

  bool contains(Product product) => (_qtyById[product.id] ?? 0) > 0;

  void add(Product product, {int qty = 1}) {
    _products[product.id] = product;
    _qtyById[product.id] = (_qtyById[product.id] ?? 0) + qty;
    notifyListeners();
  }

  void removeLine(String productId) {
    _qtyById.remove(productId);
    _products.remove(productId);
    notifyListeners();
  }

  void decrement(String productId) {
    final q = _qtyById[productId] ?? 0;
    if (q <= 1) {
      removeLine(productId);
      return;
    }
    _qtyById[productId] = q - 1;
    notifyListeners();
  }

  void clear() {
    _qtyById.clear();
    _products.clear();
    notifyListeners();
  }
}
