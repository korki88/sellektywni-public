import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'admin_dashboard/admin_dashboard.dart';
import 'main_store.dart';
import 'providers/app_navigation.dart';
import 'providers/auth_session.dart';
import 'theme/app_theme.dart';
import 'widgets/brand_splash_screen.dart';
import 'widgets/supabase_auth_sync.dart';

class SellektywniApp extends StatefulWidget {
  const SellektywniApp({super.key});

  @override
  State<SellektywniApp> createState() => _SellektywniAppState();
}

class _SellektywniAppState extends State<SellektywniApp> {
  bool _splashDone = false;

  @override
  void initState() {
    super.initState();
    Future<void>.delayed(const Duration(milliseconds: 1700), () {
      if (!mounted) return;
      setState(() => _splashDone = true);
    });
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'SELLEKTYWNI',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light,
      home: !_splashDone
          ? const BrandSplashScreen()
          : SupabaseAuthSync(
              child: Consumer2<AuthSession, AppNavigation>(
                builder: (context, auth, nav, _) {
                  if (!auth.isReady) {
                    return const BrandSplashScreen();
                  }
                  if (auth.isAuthenticated &&
                      auth.isAdminDashboardRole &&
                      !nav.staffViewingShop) {
                    return const AdminDashboard();
                  }
                  return const MainStore();
                },
              ),
            ),
    );
  }
}