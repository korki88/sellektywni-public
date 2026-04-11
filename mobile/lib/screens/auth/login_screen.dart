import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../config/app_config.dart';
import '../../providers/auth_session.dart';
import '../../theme/app_theme.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key, required this.onGoToRegister});

  final VoidCallback onGoToRegister;

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

void _popIfModal(BuildContext context) {
  final nav = Navigator.of(context);
  if (nav.canPop()) nav.pop();
}

class _LoginScreenState extends State<LoginScreen> {
  final _email = TextEditingController();
  final _password = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  bool _loading = false;

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    if (AppConfig.useDevMockAuth) {
      final login = _email.text.trim().toLowerCase();
      final pass = _password.text;
      String? token;
      if (login == 'admin' && pass == 'admin') {
        token = 'dev-mock:OWNER';
      } else if (login == 'user' && pass == 'user') {
        token = 'dev-mock:STAFF';
      } else if (login == 'client' && pass == 'client') {
        token = 'dev-mock:CUSTOMER';
      }
      if (token == null) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Błędne dane. Użyj: admin/admin (właściciel), user/user (personel), '
              'client/client (klient).',
            ),
          ),
        );
        return;
      }
      setState(() => _loading = true);
      try {
        await context.read<AuthSession>().setAccessToken(token);
        _popIfModal(context);
      } finally {
        if (mounted) setState(() => _loading = false);
      }
      return;
    }

    if (!AppConfig.hasSupabase) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Ustaw SUPABASE_URL i SUPABASE_ANON_KEY (dart-define) lub uruchom z poprawną konfiguracją.',
          ),
        ),
      );
      return;
    }
    setState(() => _loading = true);
    try {
      await Supabase.instance.client.auth.signInWithPassword(
        email: _email.text.trim(),
        password: _password.text,
      );
      if (!mounted) return;
      _popIfModal(context);
    } on AuthException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.message)),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('$e')),
      );
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 420),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Form(
            key: _formKey,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  'SELLEKTYWNI',
                  style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                        letterSpacing: -0.5,
                      ),
                ),
                const SizedBox(height: 8),
                Text(
                  AppConfig.useDevMockAuth
                      ? 'Logowanie (tryb dev-mock — bez Supabase)'
                      : 'Logowanie',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        color: const Color(0xFF6B6B6B),
                      ),
                ),
                if (AppConfig.useDevMockAuth) ...[
                  const SizedBox(height: 12),
                  Text(
                    'Konta testowe: admin/admin · user/user · client/client',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: const Color(0xFF6B6B6B),
                        ),
                    textAlign: TextAlign.center,
                  ),
                ],
                const SizedBox(height: 28),
                TextFormField(
                  controller: _email,
                  keyboardType: AppConfig.useDevMockAuth
                      ? TextInputType.text
                      : TextInputType.emailAddress,
                  autofillHints: const [AutofillHints.email],
                  decoration: InputDecoration(
                    labelText:
                        AppConfig.useDevMockAuth ? 'Login' : 'E-mail',
                    border: const OutlineInputBorder(),
                  ),
                  validator: (v) {
                    if (v == null || v.trim().isEmpty) {
                      return AppConfig.useDevMockAuth
                          ? 'Podaj login'
                          : 'Podaj e-mail';
                    }
                    if (!AppConfig.useDevMockAuth && !v.contains('@')) {
                      return 'Nieprawidłowy e-mail';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _password,
                  obscureText: true,
                  autofillHints: const [AutofillHints.password],
                  decoration: const InputDecoration(
                    labelText: 'Hasło',
                    border: OutlineInputBorder(),
                  ),
                  validator: (v) {
                    if (v == null || v.isEmpty) return 'Podaj hasło';
                    return null;
                  },
                ),
                const SizedBox(height: 24),
                FilledButton(
                  onPressed: _loading ? null : _submit,
                  style: FilledButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    backgroundColor: AppTheme.light.colorScheme.primary,
                  ),
                  child: _loading
                      ? const SizedBox(
                          height: 22,
                          width: 22,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Text('Zaloguj się'),
                ),
                const SizedBox(height: 16),
                if (!AppConfig.useDevMockAuth)
                  TextButton(
                    onPressed: widget.onGoToRegister,
                    child: const Text('Nie masz konta? Zarejestruj się'),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
