import 'dart:async';

import 'package:flutter/foundation.dart';

import 'recent_viewed_storage.dart';

/// Ostatnio oglądane produkty (jak w Shopify / Amazon) — max [maxItems] ID.
class RecentlyViewedNotifier extends ChangeNotifier {
  RecentlyViewedNotifier() {
    unawaited(_load());
  }

  static const int maxItems = 15;

  List<String> _ids = [];
  bool _ready = false;

  List<String> get ids => List.unmodifiable(_ids);

  Future<void> _load() async {
    try {
      final raw = await recentViewedGetIds();
      _ids = raw.take(maxItems).toList();
    } catch (_) {
      _ids = [];
    }
    _ready = true;
    notifyListeners();
  }

  Future<void> recordView(String productId) async {
    final id = productId.trim();
    if (id.isEmpty) return;
    if (!_ready) await _load();
    final next = <String>[id];
    for (final x in _ids) {
      if (x == id) continue;
      next.add(x);
      if (next.length >= maxItems) break;
    }
    _ids = next.take(maxItems).toList();
    notifyListeners();
    try {
      await recentViewedSetIds(_ids);
    } catch (_) {}
  }
}
