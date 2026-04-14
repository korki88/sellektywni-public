import 'dart:js_interop';
import 'dart:typed_data';

import 'package:http/http.dart' as http;
import 'package:web/web.dart' as web;

Future<void> downloadPdfWithAuth({
  required String url,
  required String bearerToken,
  required String filename,
}) async {
  final r = await http.get(
    Uri.parse(url),
    headers: {'Authorization': 'Bearer $bearerToken'},
  );
  if (r.statusCode != 200) {
    throw Exception('HTTP ${r.statusCode}');
  }
  final bytes = Uint8List.fromList(r.bodyBytes);
  final blob = web.Blob(
    [bytes.toJS].toJS,
    web.BlobPropertyBag(type: 'application/pdf'),
  );
  final objectUrl = web.URL.createObjectURL(blob);
  (web.HTMLAnchorElement()
        ..href = objectUrl
        ..download = filename)
      .click();
  web.URL.revokeObjectURL(objectUrl);
}
