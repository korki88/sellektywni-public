import 'package:flutter/foundation.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;

import '../providers/auth_session.dart';
import '../models/product.dart';
import '../models/product_category.dart';
import '../data/mock_catalog.dart';

class CatalogFilterNotifier extends ChangeNotifier {
  ProductCategory? _category;
  ProductCondition? _condition;
  String _searchQuery = '';
  AuthSession? _auth;
  bool _loading = false;
  Map<String, ({int stockQty, int reservedQty, bool canAddToCart})> _inventory = {};
  Map<String, ({String? subtitle, bool isFeatured})> _merch = {};

  ProductCategory? get category => _category;
  ProductCondition? get condition => _condition;
  String get searchQuery => _searchQuery;
  bool get loading => _loading;

  void setSearchQuery(String value) {
    _searchQuery = value.trim();
    notifyListeners();
  }

  void setCategory(ProductCategory? value) {
    _category = value;
    notifyListeners();
  }

  void setCondition(ProductCondition? value) {
    _condition = value;
    notifyListeners();
  }

  void bindAuth(AuthSession auth) {
    _auth = auth;
    refreshFromApi();
  }

  Future<void> refreshFromApi() async {
    final auth = _auth;
    if (auth == null) return;
    _loading = true;
    notifyListeners();
    try {
      final q = _searchQuery.trim();
      final uri = Uri.parse('${auth.apiBase}/products').replace(
        queryParameters: q.isEmpty ? null : <String, String>{'q': q},
      );
      final r = await http.get(uri).timeout(const Duration(seconds: 12));
      if (r.statusCode != 200) {
        _loading = false;
        notifyListeners();
        return;
      }
      final arr = jsonDecode(r.body);
      if (arr is! List) {
        _loading = false;
        notifyListeners();
        return;
      }
      final map = <String, ({int stockQty, int reservedQty, bool canAddToCart})>{};
      final merch = <String, ({String? subtitle, bool isFeatured})>{};
      for (final row in arr) {
        if (row is! Map<String, dynamic>) continue;
        final id = row['id'] as String?;
        if (id == null || id.isEmpty) continue;
        map[id] = (
          stockQty: (row['stockQty'] as num?)?.toInt() ?? 0,
          reservedQty: (row['reservedQty'] as num?)?.toInt() ?? 0,
          canAddToCart: row['canAddToCart'] as bool? ?? false,
        );
        final sub = row['subtitle'] as String?;
        final feat = row['isFeatured'] == true;
        if (sub != null && sub.trim().isNotEmpty || feat) {
          merch[id] = (subtitle: sub, isFeatured: feat);
        }
      }
      _inventory = map;
      _merch = merch;
    } catch (_) {
      // Brak API lub błąd sieci: zostaw fallback na statyczny katalog.
    }
    _loading = false;
    notifyListeners();
  }

  /// Produkt z katalogu + bieżący stan magazynu z API (do koszyka / „ostatnio oglądane”).
  Product? offerProductById(String productId) {
    for (final p in mockProducts) {
      if (p.id != productId) continue;
      final inv = _inventory[p.id];
      final m = _merch[p.id];
      if (inv == null) {
        final base = p.stockQty > 0 ? p : null;
        if (base == null) return null;
        if (m == null) return base;
        return base.copyWith(subtitle: m.subtitle, isFeatured: m.isFeatured);
      }
      if (inv.stockQty <= 0) return null;
      return p.copyWith(
        stockQty: inv.stockQty,
        reservedQty: inv.reservedQty,
        canAddToCart: inv.canAddToCart,
        subtitle: m?.subtitle ?? p.subtitle,
        isFeatured: m?.isFeatured ?? p.isFeatured,
      );
    }
    return null;
  }

  /// Produkty oznaczone jako polecane (API) i spełniające filtry listy.
  List<Product> get featuredVisibleProducts {
    return visibleProducts.where((p) => p.isFeatured).toList();
  }

  List<Product> get visibleProducts {
    final merged = mockProducts
        .map((p) {
          final inv = _inventory[p.id];
          final m = _merch[p.id];
          if (inv == null) {
            final q = p.stockQty > 0 ? p : null;
            return q?.copyWith(subtitle: m?.subtitle ?? q.subtitle, isFeatured: m?.isFeatured ?? q.isFeatured);
          }
          if (inv.stockQty <= 0) return null;
          return p.copyWith(
            stockQty: inv.stockQty,
            reservedQty: inv.reservedQty,
            canAddToCart: inv.canAddToCart,
            subtitle: m?.subtitle ?? p.subtitle,
            isFeatured: m?.isFeatured ?? p.isFeatured,
          );
        })
        .whereType<Product>()
        .toList();
    final q = _searchQuery.trim().toLowerCase();
    return merged.where((p) {
      final catOk = _category == null || p.category == _category;
      final condOk = _condition == null || p.condition == _condition;
      final searchOk =
          q.isEmpty || p.name.toLowerCase().contains(q);
      return catOk && condOk && searchOk;
    }).toList();
  }
}
