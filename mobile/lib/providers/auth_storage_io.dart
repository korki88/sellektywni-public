import 'package:shared_preferences/shared_preferences.dart';

const _kToken = 'auth_access_token';
const _kApiBase = 'auth_api_base';

Future<String?> getToken() async {
  final p = await SharedPreferences.getInstance();
  return p.getString(_kToken);
}

Future<String?> getApiBase() async {
  final p = await SharedPreferences.getInstance();
  return p.getString(_kApiBase);
}

Future<void> setToken(String? token) async {
  final p = await SharedPreferences.getInstance();
  if (token == null || token.isEmpty) {
    await p.remove(_kToken);
  } else {
    await p.setString(_kToken, token);
  }
}

Future<void> setApiBase(String value) async {
  final p = await SharedPreferences.getInstance();
  await p.setString(_kApiBase, value);
}
