// ignore_for_file: avoid_web_libraries_in_flutter, deprecated_member_use

import 'dart:html' as html;

const _kToken = 'auth_access_token';
const _kApiBase = 'auth_api_base';

Future<String?> getToken() async => html.window.localStorage[_kToken];

Future<String?> getApiBase() async => html.window.localStorage[_kApiBase];

Future<void> setToken(String? token) async {
  if (token == null || token.isEmpty) {
    html.window.localStorage.remove(_kToken);
  } else {
    html.window.localStorage[_kToken] = token;
  }
}

Future<void> setApiBase(String value) async {
  html.window.localStorage[_kApiBase] = value;
}
