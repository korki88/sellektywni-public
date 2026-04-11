import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'admin_dashboard/admin_dashboard.dart';
import 'main_store.dart';
import 'providers/app_navigation.dart';
import 'providers/auth_session.dart';
import 'theme/app_theme.dart';
import 'widgets/supabase_auth_sync.dart';

class SellektywniApp extends StatelessWidget {
  const SellektywniApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'SELLEKTYWNI',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light,
      home: SupabaseAuthSync(
        child: Consumer2<AuthSession, AppNavigation>(
          builder: (context, auth, nav, _) {
            if (!auth.isReady) {
              return const Scaffold(
                body: Center(child: CircularProgressIndicator()),
              );
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
