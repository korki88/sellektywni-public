import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'main_sidebar.dart';
import 'main_store.dart';
import 'providers/auth_session.dart';
import 'theme/app_theme.dart';

class SellektywniApp extends StatelessWidget {
  const SellektywniApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'SELLEKTYWNI',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light,
      home: Consumer<AuthSession>(
        builder: (context, auth, _) {
          if (!auth.isReady) {
            return const Scaffold(
              body: Center(child: CircularProgressIndicator()),
            );
          }
          if (auth.isStaff) {
            return const MainSidebar();
          }
          return const MainStore();
        },
      ),
    );
  }
}
