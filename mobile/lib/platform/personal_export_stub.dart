import 'package:flutter/services.dart';

Future<void> downloadOrCopyPersonalJson(String filename, String json) async {
  await Clipboard.setData(ClipboardData(text: json));
}
