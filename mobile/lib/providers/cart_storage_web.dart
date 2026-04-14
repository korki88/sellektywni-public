import 'package:web/web.dart' as web;

const _kCartsJson = 'shop_carts_by_owner_v1';

Future<String?> getCartsJson() async =>
    web.window.localStorage.getItem(_kCartsJson);

Future<void> setCartsJson(String json) async {
  web.window.localStorage.setItem(_kCartsJson, json);
}
