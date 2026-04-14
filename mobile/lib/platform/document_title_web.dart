import 'package:web/web.dart' as web;

void setBrowserDocumentTitle(String? title) {
  if (title == null || title.isEmpty) return;
  web.document.title = title;
}
