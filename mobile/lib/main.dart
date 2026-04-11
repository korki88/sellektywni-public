import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'app.dart';
import 'config/app_config.dart';
import 'providers/auth_session.dart';
import 'providers/cart_notifier.dart';
import 'providers/catalog_filter_notifier.dart';
import 'services/push_service.dart';
import 'overlay_main.dart' show runStaffOverlayApp;

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

  if (AppConfig.shouldUseSupabaseClient) {
    await Supabase.initialize(
      url: AppConfig.supabaseUrl,
      anonKey: AppConfig.supabaseAnonKey,
    );
  }

  final auth = AuthSession();
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
  await auth.init();
  if (AppConfig.shouldUseSupabaseClient) {
    final s = Supabase.instance.client.auth.currentSession;
    if (s != null) {
      await auth.syncFromSupabaseAccessToken(s.accessToken);
    }
  }
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

/// Punkt wejścia okna overlay (Android — [flutter_overlay_window]).
@pragma('vm:entry-point')
void overlayMain() {
  runStaffOverlayApp();
}
