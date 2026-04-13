// ignore_for_file: avoid_web_libraries_in_flutter, deprecated_member_use

import 'dart:html' as html;

const _kCartsJson = 'shop_carts_by_owner_v1';

Future<String?> getCartsJson() async => html.window.localStorage[_kCartsJson];

Future<void> setCartsJson(String json) async {
  html.window.localStorage[_kCartsJson] = json;
}
