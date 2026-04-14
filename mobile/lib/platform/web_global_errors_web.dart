import 'dart:js_interop';
import 'package:web/web.dart' as web;

/// Łapie błędy JS / silnika, które nie przechodzą przez [FlutterError.onError].
void registerWebGlobalErrorHandler() {
  // Streamy Flutter nie łapią wszystkiego na WWW, więc dokładamy listener DOM.
  web.window.addEventListener(
    'error',
    ((web.Event event) {
      // ignore: avoid_print
      print('[DOM error] $event');
    }).toJS,
    true.toJS,
  );

  web.window.addEventListener(
    'unhandledrejection',
    ((web.Event e) {
      // ignore: avoid_print
      print('[unhandledrejection] $e');
    }).toJS,
  );
}
