import 'package:flutter/material.dart';

import '../screens/auth/login_screen.dart';
import '../screens/auth/register_screen.dart';

/// Logowanie / rejestracja (bez Supabase — tylko przełączanie ekranów).
class AuthShell extends StatefulWidget {
  const AuthShell({super.key, this.embedded = false});

  /// Bez własnego [Scaffold] — do osadzenia w zakładce (np. Konto gościa).
  final bool embedded;

  @override
  State<AuthShell> createState() => _AuthShellState();
}

class _AuthShellState extends State<AuthShell> {
  bool _register = false;

  @override
  Widget build(BuildContext context) {
    final body = SafeArea(
      child: _register
          ? RegisterScreen(
              onBackToLogin: () => setState(() => _register = false),
            )
          : LoginScreen(
              onGoToRegister: () => setState(() => _register = true),
            ),
    );
    if (widget.embedded) {
      return body;
    }
    return Scaffold(body: body);
  }
}
