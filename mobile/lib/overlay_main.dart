import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'admin_dashboard/admin_dashboard.dart';
import 'config/app_config.dart';
import 'providers/auth_session.dart';
import 'theme/app_theme.dart';

/// Wywoływane z [overlayMain] w `main.dart` (wymagany `@pragma` na top-level w głównym pliku).
void runStaffOverlayApp() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const _StaffOverlayApp());
}

class _StaffOverlayApp extends StatefulWidget {
  const _StaffOverlayApp();

  @override
  State<_StaffOverlayApp> createState() => _StaffOverlayAppState();
}

class _StaffOverlayAppState extends State<_StaffOverlayApp> {
  late final AuthSession _auth = AuthSession();
  bool _ready = false;

  @override
  void initState() {
    super.initState();
    _boot();
  }

  Future<void> _boot() async {
    if (AppConfig.shouldUseSupabaseClient) {
      await Supabase.initialize(
        url: AppConfig.supabaseUrl,
        anonKey: AppConfig.supabaseAnonKey,
      );
    }
    await _auth.init();
    if (AppConfig.shouldUseSupabaseClient) {
      final s = Supabase.instance.client.auth.currentSession;
      if (s != null) {
        await _auth.syncFromSupabaseAccessToken(s.accessToken);
      }
    }
    if (mounted) setState(() => _ready = true);
  }

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider.value(
      value: _auth,
      child: MaterialApp(
        debugShowCheckedModeBanner: false,
        theme: AppTheme.light,
        home: _ready
            ? const AdminDashboard(
                presentation: AdminDashboardPresentation.overlaySidebar,
              )
            : const Scaffold(
                body: Center(child: CircularProgressIndicator()),
              ),
      ),
    );
  }
}
