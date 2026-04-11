import 'package:flutter/foundation.dart';

/// Dopasowanie do pierwszego podglądu HTML: 2 kolumny poniżej 900px, 3 od 900px.
int catalogGridColumnCount(double viewportWidth) {
  if (kIsWeb) {
    return viewportWidth >= 900 ? 3 : 2;
  }
  return 2;
}
