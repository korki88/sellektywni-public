// ignore_for_file: avoid_web_libraries_in_flutter

import 'dart:html' as html;
import 'dart:typed_data';

import 'package:http/http.dart' as http;

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
  final blob = html.Blob([bytes], 'application/pdf');
  final objectUrl = html.Url.createObjectUrlFromBlob(blob);
  html.AnchorElement(href: objectUrl)
    ..setAttribute('download', filename)
    ..click();
  html.Url.revokeObjectUrl(objectUrl);
}
