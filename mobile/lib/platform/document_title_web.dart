// ignore_for_file: avoid_web_libraries_in_flutter

import 'dart:html' as html;

void setBrowserDocumentTitle(String? title) {
  if (title == null || title.isEmpty) return;
  html.document.title = title;
}
