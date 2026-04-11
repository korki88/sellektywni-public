import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../config/app_config.dart';
import '../providers/app_navigation.dart';
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
    final nav = context.watch<AppNavigation>();

    if (!auth.isAuthenticated) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(24, 24, 24, 8),
            child: Text(
              'Twoje konto',
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Text(
              'Zaloguj się, aby zapisać konto i korzystać z programu lojalnościowego.',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: const Color(0xFF6B6B6B),
                  ),
            ),
          ),
          const Expanded(child: AuthShell(embedded: true)),
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
        if (auth.isAdminDashboardRole && nav.staffViewingShop) ...[
          const SizedBox(height: 16),
          FilledButton.tonal(
            onPressed: () =>
                context.read<AppNavigation>().openAdminPanel(),
            style: FilledButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 14),
            ),
            child: const Text('Przejdź do panelu administracyjnego'),
          ),
        ],
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
            context.read<AppNavigation>().resetAfterLogout();
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
