import 'auth_storage_io.dart' if (dart.library.html) 'auth_storage_web.dart' as impl;

/// Trwałe dane sesji: SharedPreferences (mobile/desktop) albo localStorage (web),
/// żeby uniknąć MissingPluginException przy staticznym serwowaniu `www/app`.
Future<String?> authStorageGetToken() => impl.getToken();

Future<String?> authStorageGetApiBase() => impl.getApiBase();

Future<void> authStorageSetToken(String? token) => impl.setToken(token);

Future<void> authStorageSetApiBase(String value) => impl.setApiBase(value);
