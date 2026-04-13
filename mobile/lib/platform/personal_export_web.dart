// ignore_for_file: avoid_web_libraries_in_flutter

import 'dart:html' as html;

Future<void> downloadOrCopyPersonalJson(String filename, String json) async {
  final blob = html.Blob([json], 'application/json');
  final url = html.Url.createObjectUrlFromBlob(blob);
  html.AnchorElement(href: url)
    ..setAttribute('download', filename)
    ..click();
  html.Url.revokeObjectUrl(url);
}
