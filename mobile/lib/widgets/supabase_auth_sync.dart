import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../config/app_config.dart';
import '../providers/auth_session.dart';

/// Nasłuchuje zmian sesji Supabase i aktualizuje [AuthSession].
class SupabaseAuthSync extends StatefulWidget {
  const SupabaseAuthSync({super.key, required this.child});

  final Widget child;

  @override
  State<SupabaseAuthSync> createState() => _SupabaseAuthSyncState();
}

class _SupabaseAuthSyncState extends State<SupabaseAuthSync> {
  StreamSubscription<AuthState>? _sub;

  @override
  void initState() {
    super.initState();
    if (!AppConfig.shouldUseSupabaseClient) return;
    _sub = Supabase.instance.client.auth.onAuthStateChange.listen((data) {
      if (!mounted) return;
      final token = data.session?.accessToken;
      unawaited(
        context.read<AuthSession>().syncFromSupabaseAccessToken(token),
      );
    });
  }

  @override
  void dispose() {
    _sub?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
