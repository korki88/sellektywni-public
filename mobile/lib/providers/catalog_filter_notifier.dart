import 'dart:convert';
import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import '../data/mock_catalog.dart';
import '../models/product.dart';
import '../models/product_category.dart';
import '../providers/auth_session.dart';

class CatalogFilterNotifier extends ChangeNotifier {
  static const int _pageSize = 12;

  ProductCategory? _category;
  ProductCondition? _condition;
  String _searchQuery = '';
  Timer? _searchDebounce;
  AuthSession? _auth;

  bool _loading = false;
  bool _loadingMore = false;
  bool _hasMore = true;
  int _offset = 0;

  List<Product> _products = [];

  ProductCategory? get category => _category;
  ProductCondition? get condition => _condition;
  String get searchQuery => _searchQuery;
  bool get loading => _loading;
  bool get loadingMore => _loadingMore;
  bool get hasMore => _hasMore;

  void setSearchQuery(String value) {
    final normalized = value.trim();
    if (_searchQuery == normalized) return;
    _searchQuery = normalized;
    _searchDebounce?.cancel();
    _searchDebounce = Timer(const Duration(milliseconds: 280), () {
      refreshFromApi();
    });
    notifyListeners();
  }

  @override
  void dispose() {
    _searchDebounce?.cancel();
    super.dispose();
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
    _loadingMore = false;
    _hasMore = true;
    _offset = 0;
    _products = [];
    notifyListeners();

    await _fetchPage(reset: true);

    _loading = false;
    notifyListeners();
  }

  Future<void> loadMoreFromApi() async {
    if (_loading || _loadingMore || !_hasMore) return;
    _loadingMore = true;
    notifyListeners();

    await _fetchPage(reset: false);

    _loadingMore = false;
    notifyListeners();
  }

  Future<void> _fetchPage({required bool reset}) async {
    final auth = _auth;
    if (auth == null) return;

    try {
      final q = _searchQuery.trim();
      final query = <String, String>{
        'offset': _offset.toString(),
        'limit': _pageSize.toString(),
      };
      if (q.isNotEmpty) query['q'] = q;

      final uri = Uri.parse('${auth.apiBase}/products').replace(queryParameters: query);
      final r = await http.get(uri).timeout(const Duration(seconds: 12));
      if (r.statusCode != 200) {
        if (reset) {
          _products = _fallbackProducts();
          _hasMore = false;
        }
        return;
      }

      final arr = jsonDecode(r.body);
      if (arr is! List) {
        if (reset) {
          _products = _fallbackProducts();
          _hasMore = false;
        }
        return;
      }

      final chunk = arr
          .whereType<Map<String, dynamic>>()
          .map(_mapApiRowToProduct)
          .whereType<Product>()
          .toList();

      if (reset) {
        _products = chunk;
      } else {
        _products = [..._products, ...chunk];
      }

      _offset = _products.length;
      _hasMore = chunk.length == _pageSize;
    } catch (_) {
      if (reset) {
        _products = _fallbackProducts();
        _hasMore = false;
      }
    }
  }

  Product? _mapApiRowToProduct(Map<String, dynamic> row) {
    final id = row['id']?.toString();
    if (id == null || id.isEmpty) return null;

    final stock = (row['stockQty'] as num?)?.toInt() ?? 0;
    if (stock <= 0) return null;

    final name = (row['name']?.toString() ?? '').trim();
    final price = (row['price'] as num?)?.toDouble() ??
        double.tryParse(row['price']?.toString() ?? '') ??
        0;

    final template = mockProducts.firstWhere(
      (p) => p.id == id,
      orElse: () => Product(
        id: id,
        name: name.isEmpty ? 'Produkt $id' : name,
        pricePln: price,
        imageUrl: 'https://picsum.photos/seed/sellek-$id/900/1200',
        category: _inferCategory(name),
        condition: ProductCondition.newItem,
      ),
    );

    return Product(
      id: id,
      name: name.isEmpty ? template.name : name,
      pricePln: price <= 0 ? template.pricePln : price,
      imageUrl: template.imageUrl,
      category: template.category,
      condition: template.condition,
      stockQty: stock,
      reservedQty: (row['reservedQty'] as num?)?.toInt() ?? 0,
      canAddToCart: row['canAddToCart'] as bool? ?? false,
      subtitle: row['subtitle']?.toString(),
      isFeatured: row['isFeatured'] == true,
    );
  }

  ProductCategory _inferCategory(String name) {
    final v = name.toLowerCase();
    if (v.contains('but') || v.contains('sneaker') || v.contains('loafer')) {
      return ProductCategory.shoes;
    }
    if (v.contains('torb') ||
        v.contains('szalik') ||
        v.contains('okular') ||
        v.contains('czapk') ||
        v.contains('pasek') ||
        v.contains('portfel') ||
        v.contains('zegarek')) {
      return ProductCategory.accessories;
    }
    return ProductCategory.clothing;
  }

  List<Product> _fallbackProducts() {
    return mockProducts.where((p) => p.stockQty > 0).toList();
  }

  Product? offerProductById(String productId) {
    for (final p in _products) {
      if (p.id == productId) return p;
    }
    for (final p in mockProducts) {
      if (p.id == productId) return p.stockQty > 0 ? p : null;
    }
    return null;
  }

  List<Product> get featuredVisibleProducts {
    return visibleProducts.where((p) => p.isFeatured).toList();
  }

  List<Product> get visibleProducts {
    return _products.where((p) {
      final catOk = _category == null || p.category == _category;
      final condOk = _condition == null || p.condition == _condition;
      return catOk && condOk;
    }).toList();
  }
}