import 'personal_export_stub.dart'
    if (dart.library.html) 'personal_export_web.dart' as impl;

/// WWW: pobieranie pliku JSON; mobile: kopiowanie do schowka.
Future<void> sharePersonalDataExport(String filename, String json) async {
  await impl.downloadOrCopyPersonalJson(filename, json);
}
