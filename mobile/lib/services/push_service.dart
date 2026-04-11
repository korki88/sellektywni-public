import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';

/// Rejestracja FCM i nasłuch wiadomości o statusie zamówienia.
class PushService {
  PushService._();
  static final PushService instance = PushService._();

  final FirebaseMessaging _messaging = FirebaseMessaging.instance;

  Future<void> init() async {
    final settings = await _messaging.requestPermission(
      alert: true,
      badge: true,
      sound: true,
      provisional: false,
    );

    if (settings.authorizationStatus == AuthorizationStatus.denied) {
      debugPrint('Powiadomienia push: brak zgody użytkownika');
      return;
    }

    if (kIsWeb) {
      debugPrint('FCM Web wymaga dodatkowej konfiguracji (VAPID).');
    }

    final token = await _messaging.getToken();
    debugPrint('FCM token: $token');

    FirebaseMessaging.onMessage.listen((RemoteMessage message) {
      debugPrint('Push (foreground): ${message.notification?.title} — ${message.notification?.body}');
      debugPrint('Dane: ${message.data}');
    });

    FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) {
      debugPrint('Push (otwarte z tła): ${message.messageId} — ${message.data}');
    });

    final initial = await _messaging.getInitialMessage();
    if (initial != null) {
      debugPrint('Push (cold start): ${initial.data}');
    }
  }
}
