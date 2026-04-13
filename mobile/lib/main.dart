import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'app.dart';
import 'config/app_config.dart';
import 'providers/app_navigation.dart';
import 'providers/auth_session.dart';
import 'providers/cart_notifier.dart';
import 'providers/catalog_filter_notifier.dart';
import 'services/push_service.dart';
import 'overlay_main.dart' show runStaffOverlayApp;
import 'platform/web_global_errors_stub.dart'
    if (dart.library.html) 'platform/web_global_errors_web.dart';

/// Musi być funkcją top-level (Firebase Messaging w tle; tylko iOS/Android).
@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp();
}

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  if (kIsWeb) {
    registerWebGlobalErrorHandler();
  }

  // W release web debugPrint często nie widać w konsoli — print zostaje.
  FlutterError.onError = (details) {
    FlutterError.presentError(details);
    // ignore: avoid_print
    print('[FlutterError] ${details.exceptionAsString()}');
    // ignore: avoid_print
    print('${details.stack}');
  };
  PlatformDispatcher.instance.onError = (error, stack) {
    // ignore: avoid_print
    print('[async] $error\n$stack');
    return false;
  };
  // Na WWW: czerwony ekran z treścią zamiast tylko „Uncaught Error” w JS.
  if (kIsWeb) {
    ErrorWidget.builder = (FlutterErrorDetails details) {
      // ignore: avoid_print
      print('[ErrorWidget] ${details.exceptionAsString()}\n${details.stack}');
      return Directionality(
        textDirection: TextDirection.ltr,
        child: Material(
          color: Colors.white,
          child: Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: SelectableText(
                'Błąd budowania widoku:\n${details.exceptionAsString()}',
                style: const TextStyle(color: Colors.red, fontSize: 14),
              ),
            ),
          ),
        ),
      );
    };
  }

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
  await auth.init();
  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider<AuthSession>.value(value: auth),
        ChangeNotifierProxyProvider<AuthSession, CatalogFilterNotifier>(
          create: (_) => CatalogFilterNotifier(),
          update: (_, authSession, catalog) {
            final c = catalog ?? CatalogFilterNotifier();
            c.bindAuth(authSession);
            return c;
          },
        ),
        ChangeNotifierProxyProvider<AuthSession, CartNotifier>(
          create: (_) => CartNotifier(),
          update: (_, authSession, cart) {
            final c = cart ?? CartNotifier();
            c.bindAuth(authSession);
            return c;
          },
        ),
        ChangeNotifierProvider(create: (_) => AppNavigation()),
      ],
      child: const SellektywniApp(),
    ),
  );
  if (AppConfig.shouldUseSupabaseClient) {
    final s = Supabase.instance.client.auth.currentSession;
    if (s != null) {
      await auth.syncFromSupabaseAccessToken(s.accessToken);
    }
  }
}

Future<void> _initFirebaseSafely() async {
  if (kIsWeb) {
    // FCM na www wymaga osobnej konfiguracji — bez szumu w konsoli przy każdym starcie.
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
