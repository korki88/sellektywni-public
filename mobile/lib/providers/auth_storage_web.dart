import 'package:web/web.dart' as web;

const _kToken = 'auth_access_token';
const _kApiBase = 'auth_api_base';

Future<String?> getToken() async => web.window.localStorage.getItem(_kToken);

Future<String?> getApiBase() async =>
    web.window.localStorage.getItem(_kApiBase);

Future<void> setToken(String? token) async {
  if (token == null || token.isEmpty) {
    web.window.localStorage.removeItem(_kToken);
  } else {
    web.window.localStorage.setItem(_kToken, token);
  }
}

Future<void> setApiBase(String value) async {
  web.window.localStorage.setItem(_kApiBase, value);
}
