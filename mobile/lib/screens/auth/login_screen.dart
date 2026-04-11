import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../config/app_config.dart';
import '../../config/dev_mock_accounts.dart';
import '../../providers/auth_session.dart';
import '../../theme/app_theme.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key, required this.onGoToRegister});

  final VoidCallback onGoToRegister;

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

void _popIfModal(BuildContext context) {
  try {
    final root = Navigator.of(context, rootNavigator: true);
    if (root.canPop()) {
      root.pop();
      return;
    }
    final nav = Navigator.maybeOf(context);
    if (nav != null && nav.canPop()) nav.pop();
  } catch (_) {
    // Route mogła zostać zdjęta w tej samej klatce co przełączenie home (OWNER → AdminDashboard).
  }
}

class _LoginScreenState extends State<LoginScreen> {
  final _email = TextEditingController();
  final _password = TextEditingController();
  final _emailFocus = FocusNode();
  final _passwordFocus = FocusNode();
  final _formKey = GlobalKey<FormState>();
  bool _loading = false;

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    _emailFocus.dispose();
    _passwordFocus.dispose();
    super.dispose();
  }

  void _onEnterKey() {
    if (!mounted || _loading) return;
    if (_passwordFocus.hasFocus) {
      _submit();
      return;
    }
    if (_emailFocus.hasFocus) {
      _passwordFocus.requestFocus();
      return;
    }
    _submit();
  }

  Future<void> _submit() async {
    if (_loading) return;
    final form = _formKey.currentState;
    if (form == null || !form.validate()) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Uzupełnij poprawnie login i hasło (patrz podpowiedzi pod polami).'),
        ),
      );
      return;
    }

    // Para z listy dev-mock — zawsze token offline (nie zależy od dart-define Supabase ani ?devMock=1).
    final devToken = resolveDevMockBearerToken(_email.text, _password.text);
    if (devToken != null) {
      setState(() => _loading = true);
      try {
        await context.read<AuthSession>().setAccessToken(devToken);
        if (!mounted) return;
        // Po notifyListeners przełączenie home może być w tej samej klatce — pop poza build/sync.
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (!context.mounted) return;
          _popIfModal(context);
        });
      } finally {
        if (mounted) setState(() => _loading = false);
      }
      return;
    }

    if (AppConfig.useDevMockAuth) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Błędne dane — użyj jednej z par z listy powyżej (tryb dev-mock).',
          ),
        ),
      );
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
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!context.mounted) return;
        _popIfModal(context);
      });
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
    return Align(
      alignment: Alignment.topCenter,
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(24, 24, 24, 48),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 420),
          child: CallbackShortcuts(
            bindings: <ShortcutActivator, VoidCallback>{
              const SingleActivator(LogicalKeyboardKey.enter): _onEnterKey,
              const SingleActivator(LogicalKeyboardKey.numpadEnter): _onEnterKey,
            },
            child: Form(
            key: _formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
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
                    kDevMockAccountsHint,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: const Color(0xFF6B6B6B),
                          height: 1.35,
                        ),
                    textAlign: TextAlign.left,
                  ),
                ],
                const SizedBox(height: 28),
                TextFormField(
                  controller: _email,
                  focusNode: _emailFocus,
                  keyboardType: AppConfig.useDevMockAuth
                      ? TextInputType.text
                      : TextInputType.emailAddress,
                  textInputAction: TextInputAction.next,
                  onFieldSubmitted: (_) =>
                      FocusScope.of(context).requestFocus(_passwordFocus),
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
                  focusNode: _passwordFocus,
                  obscureText: true,
                  textInputAction: TextInputAction.done,
                  onFieldSubmitted: (_) => _submit(),
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
                  onPressed: _loading
                      ? null
                      : () {
                          _submit();
                        },
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
                TextButton(
                  onPressed: () {
                    if (AppConfig.useDevMockAuth) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text(
                            'Rejestracja jest wyłączona w trybie podglądu (dev-mock).',
                          ),
                        ),
                      );
                      return;
                    }
                    widget.onGoToRegister();
                  },
                  child: const Text('Nie masz konta? Zarejestruj się'),
                ),
              ],
            ),
          ),
          ),
        ),
      ),
    );
  }
}
