import 'cart_storage_io.dart' if (dart.library.html) 'cart_storage_web.dart'
    as impl;

/// Trwały zapis koszyków per użytkownik.
Future<String?> cartStorageGetCartsJson() => impl.getCartsJson();

Future<void> cartStorageSetCartsJson(String json) => impl.setCartsJson(json);
