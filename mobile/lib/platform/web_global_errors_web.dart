// Tylko web; dart:html — stabilne API do window.onError (package:web można później).
// ignore_for_file: avoid_web_libraries_in_flutter, deprecated_member_use

import 'dart:html' as html;

/// Łapie błędy JS / silnika, które nie przechodzą przez [FlutterError.onError].
void registerWebGlobalErrorHandler() {
  // Stream bywa pusty dla części błędów z silnika — dokładamy capture na DOM.
  html.window.addEventListener(
    'error',
    (html.Event event) {
      if (event is html.ErrorEvent) {
        // ignore: avoid_print
        print(
          '[DOM error] message=${event.message} '
          'at ${event.filename}:${event.lineno}:${event.colno} '
          'error=${event.error}',
        );
      } else {
        // ignore: avoid_print
        print('[DOM error] (non-ErrorEvent) $event');
      }
    },
    true,
  );

  html.window.addEventListener('unhandledrejection', (html.Event e) {
    // ignore: avoid_print
    print('[unhandledrejection] $e');
  });

  html.window.onError.listen((event) {
    if (event is! html.ErrorEvent) return;
    // ignore: avoid_print
    print(
      '[window.onError stream] message=${event.message} '
      'filename=${event.filename}:${event.lineno}:${event.colno} '
      'error=${event.error}',
    );
  });
}
