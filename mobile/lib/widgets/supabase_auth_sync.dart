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

  bool _isGoogleSignIn(AuthState data) {
    if (data.event != AuthChangeEvent.signedIn) return false;
    final appMeta = data.session?.user.appMetadata;
    if (appMeta == null) return false;
    final provider = appMeta['provider']?.toString().toLowerCase();
    if (provider == 'google') return true;
    final providers = appMeta['providers'];
    if (providers is List) {
      return providers.any((p) => p.toString().toLowerCase() == 'google');
    }
    return false;
  }

  @override
  void initState() {
    super.initState();
    if (!AppConfig.shouldUseSupabaseClient) return;
    _sub = Supabase.instance.client.auth.onAuthStateChange.listen((data) {
      if (!mounted) return;
      final token = data.session?.accessToken;
      final shouldBootstrapGoogle = _isGoogleSignIn(data);
      unawaited(
        context.read<AuthSession>().syncFromSupabaseAccessToken(
              token,
              bootstrapGoogle: shouldBootstrapGoogle,
            ),
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
