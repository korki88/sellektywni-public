import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'app.dart';
import 'providers/cart_notifier.dart';
import 'providers/catalog_filter_notifier.dart';
import 'services/push_service.dart';

/// Musi być funkcją top-level (Firebase Messaging w tle).
@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp();
}

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await _initFirebaseSafely();
  FirebaseMessaging.onBackgroundMessage(firebaseMessagingBackgroundHandler);

  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => CatalogFilterNotifier()),
        ChangeNotifierProvider(create: (_) => CartNotifier()),
      ],
      child: const SellektywniApp(),
    ),
  );
}

Future<void> _initFirebaseSafely() async {
  try {
    await Firebase.initializeApp();
    await PushService.instance.init();
  } catch (e, st) {
    debugPrint('Firebase niedostępny (dodaj konfigurację projektu): $e\n$st');
  }
}
