import 'package:shared_preferences/shared_preferences.dart';

const _kIds = 'shop_recently_viewed_ids_v1';

Future<List<String>> recentViewedGetIds() async {
  final p = await SharedPreferences.getInstance();
  return p.getStringList(_kIds) ?? [];
}

Future<void> recentViewedSetIds(List<String> ids) async {
  final p = await SharedPreferences.getInstance();
  await p.setStringList(_kIds, ids);
}
