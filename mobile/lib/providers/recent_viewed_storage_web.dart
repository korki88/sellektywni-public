import 'dart:convert';

import 'package:web/web.dart' as web;

const _kIds = 'shop_recently_viewed_ids_v1';

Future<List<String>> recentViewedGetIds() async {
  final raw = web.window.localStorage.getItem(_kIds);
  if (raw == null || raw.isEmpty) return [];
  try {
    final j = jsonDecode(raw);
    if (j is! List) return [];
    return j.map((e) => e.toString()).where((s) => s.isNotEmpty).toList();
  } catch (_) {
    return [];
  }
}

Future<void> recentViewedSetIds(List<String> ids) async {
  web.window.localStorage.setItem(_kIds, jsonEncode(ids));
}
