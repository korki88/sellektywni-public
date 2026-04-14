// ignore_for_file: avoid_web_libraries_in_flutter

import 'dart:convert';
import 'dart:html' as html;

const _kIds = 'shop_recently_viewed_ids_v1';

Future<List<String>> recentViewedGetIds() async {
  final raw = html.window.localStorage[_kIds];
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
  html.window.localStorage[_kIds] = jsonEncode(ids);
}
