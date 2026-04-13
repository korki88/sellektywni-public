import 'package:shared_preferences/shared_preferences.dart';

const _kCartsJson = 'shop_carts_by_owner_v1';

Future<String?> getCartsJson() async {
  final p = await SharedPreferences.getInstance();
  return p.getString(_kCartsJson);
}

Future<void> setCartsJson(String json) async {
  final p = await SharedPreferences.getInstance();
  await p.setString(_kCartsJson, json);
}
