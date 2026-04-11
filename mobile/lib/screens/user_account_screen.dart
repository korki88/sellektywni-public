import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../config/app_config.dart';
import '../providers/auth_session.dart';
import '../widgets/auth_shell.dart';

/// Panel użytkownika: rola, punkty, ranga, wylogowanie. Gość widzi zaproszenie do logowania.
class UserAccountScreen extends StatelessWidget {
  const UserAccountScreen({super.key});

  String _roleLabel(String? r) {
    switch (r) {
      case 'STAFF':
        return 'Pracownik';
      case 'OWNER':
        return 'Właściciel';
      case 'CUSTOMER':
        return 'Klient';
      default:
        return '—';
    }
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthSession>();

    if (!auth.isAuthenticated) {
      return ListView(
        padding: const EdgeInsets.all(24),
        children: [
          Text(
            'Twoje konto',
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
          ),
          const SizedBox(height: 16),
          Text(
            'Przeglądasz sklep jako gość. Zaloguj się, aby zapisać konto, '
            'zobaczyć punkty lojalnościowe i rangę.',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: const Color(0xFF6B6B6B),
                ),
          ),
          const SizedBox(height: 28),
          FilledButton(
            onPressed: () {
              Navigator.of(context, rootNavigator: true).push<void>(
                MaterialPageRoute<void>(
                  builder: (ctx) => Scaffold(
                    appBar: AppBar(
                      title: const Text('Logowanie'),
                    ),
                    body: const AuthShell(),
                  ),
                ),
              );
            },
            style: FilledButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 16),
            ),
            child: const Text('Zaloguj się lub zarejestruj'),
          ),
        ],
      );
    }

    final supaEmail =
        AppConfig.shouldUseSupabaseClient
            ? Supabase.instance.client.auth.currentUser?.email
            : null;
    final email = supaEmail ?? auth.profileEmail ?? '—';

    return ListView(
      padding: const EdgeInsets.all(24),
      children: [
        Text(
          'Twoje konto',
          style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.w600,
              ),
        ),
        const SizedBox(height: 20),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('E-mail', style: Theme.of(context).textTheme.labelMedium),
                const SizedBox(height: 4),
                Text(email, style: Theme.of(context).textTheme.titleMedium),
                const SizedBox(height: 20),
                Text('Rola w sklepie', style: Theme.of(context).textTheme.labelMedium),
                const SizedBox(height: 4),
                Text(
                  _roleLabel(auth.role),
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                ),
                if (auth.role != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: Text(
                      auth.role!,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: const Color(0xFF6B6B6B),
                          ),
                    ),
                  ),
                const SizedBox(height: 20),
                Text('Program lojalnościowy', style: Theme.of(context).textTheme.labelMedium),
                const SizedBox(height: 8),
                Text(
                  'Punkty: ${auth.points ?? '—'}',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: 4),
                Text(
                  'Ranga: ${auth.rank ?? '—'}',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 24),
        if (auth.isOwner)
          Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: Text(
              'Konto właściciela — pełne uprawnienia administracyjne po stronie API.',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: const Color(0xFF6B6B6B),
                  ),
            ),
          ),
        if (auth.isStaff)
          Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: Text(
              'Tryb pracownika: kolejka rezerwacji i profile klientów są w sekcjach obok.',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: const Color(0xFF6B6B6B),
                  ),
            ),
          ),
        FilledButton.tonal(
          onPressed: () async {
            final sess = context.read<AuthSession>();
            if (AppConfig.shouldUseSupabaseClient) {
              await Supabase.instance.client.auth.signOut();
            }
            if (!context.mounted) return;
            await sess.setAccessToken(null);
          },
          style: FilledButton.styleFrom(
            padding: const EdgeInsets.symmetric(vertical: 16),
          ),
          child: const Text('Wyloguj się'),
        ),
      ],
    );
  }
}
