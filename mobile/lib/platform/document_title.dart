import 'document_title_stub.dart'
    if (dart.library.html) 'document_title_web.dart' as impl;

void setBrowserDocumentTitle(String? title) => impl.setBrowserDocumentTitle(title);
