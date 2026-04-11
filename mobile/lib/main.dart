import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'app.dart';
import 'providers/auth_session.dart';
import 'providers/cart_notifier.dart';
import 'providers/catalog_filter_notifier.dart';
import 'services/push_service.dart';

/// Musi być funkcją top-level (Firebase Messaging w tle; tylko iOS/Android).
@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp();
}

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  if (!kIsWeb) {
    FirebaseMessaging.onBackgroundMessage(firebaseMessagingBackgroundHandler);
  }
  await _initFirebaseSafely();

  final auth = AuthSession();
  await auth.init();

  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => CatalogFilterNotifier()),
        ChangeNotifierProvider(create: (_) => CartNotifier()),
        ChangeNotifierProvider<AuthSession>.value(value: auth),
      ],
      child: const SellektywniApp(),
    ),
  );
}

Future<void> _initFirebaseSafely() async {
  if (kIsWeb) {
    debugPrint(
      'WWW: Firebase/FCM pominięte — dodaj FlutterFire (firebase_options) + VAPID dla web.',
    );
    return;
  }
  try {
    await Firebase.initializeApp();
    await PushService.instance.init();
  } catch (e, st) {
    debugPrint('Firebase niedostępny (dodaj konfigurację projektu): $e\n$st');
  }
}
