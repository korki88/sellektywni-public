import 'dart:js_interop';

import 'package:web/web.dart' as web;

Future<void> downloadOrCopyPersonalJson(String filename, String json) async {
  final blob = web.Blob(
    [json.toJS].toJS,
    web.BlobPropertyBag(type: 'application/json'),
  );
  final url = web.URL.createObjectURL(blob);
  (web.HTMLAnchorElement()
        ..href = url
        ..download = filename)
      .click();
  web.URL.revokeObjectURL(url);
}
