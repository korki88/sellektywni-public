import 'invoice_download_stub.dart'
    if (dart.library.html) 'invoice_download_web.dart' as impl;

Future<void> downloadPdfWithAuth({
  required String url,
  required String bearerToken,
  required String filename,
}) =>
    impl.downloadPdfWithAuth(
      url: url,
      bearerToken: bearerToken,
      filename: filename,
    );
