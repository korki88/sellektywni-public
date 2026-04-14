import 'dart:convert';

import 'package:flutter/material.dart';
import '../theme/design_tokens.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:provider/provider.dart';

import '../config/app_config.dart';
import '../providers/auth_session.dart';
import 'cms_page_screen.dart';

/// Pomoc, kontakt, podstawowe zasady oraz linki do stron CMS (regulamin, o nas).
class HelpScreen extends StatefulWidget {
  const HelpScreen({super.key});

  @override
  State<HelpScreen> createState() => _HelpScreenState();
}

class _HelpScreenState extends State<HelpScreen> {
  String? _apiBaseCached;
  Future<List<Map<String, dynamic>>>? _cmsFuture;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final b = context.read<AuthSession>().apiBase;
    if (_apiBaseCached != b) {
      _apiBaseCached = b;
      _cmsFuture = _fetchCmsPages(b);
    }
  }

  Future<List<Map<String, dynamic>>> _fetchCmsPages(String apiBase) async {
    final uri = Uri.parse('$apiBase/cms/pages');
    try {
      final r = await http.get(uri).timeout(const Duration(seconds: 12));
      if (r.statusCode != 200) return const [];
      final j = jsonDecode(r.body);
      if (j is! List) return const [];
      return j.whereType<Map<String, dynamic>>().toList();
    } catch (_) {
      return const [];
    }
  }

  Future<void> _copyEmail(BuildContext context) async {
    await Clipboard.setData(ClipboardData(text: AppConfig.shopSupportEmail));
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Skopiowano adres e-mail do schowka')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final apiBase = context.watch<AuthSession>().apiBase;
    return Scaffold(
      appBar: AppBar(title: const Text('Pomoc i informacje')),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          Text(
            'Obsługa klienta',
            style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 8),
          Text(
            'Masz pytanie o zamówienie, zwrot lub produkt? Napisz na adres poniżej — '
            'podaj numer zamówienia lub nazwę produktu, ułatwi to odpowiedź.',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: DesignTokens.mutedText),
          ),
          const SizedBox(height: 12),
          SelectableText(
            AppConfig.shopSupportEmail,
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                  color: Theme.of(context).colorScheme.primary,
                ),
          ),
          const SizedBox(height: 12),
          FilledButton.tonal(
            onPressed: () => _copyEmail(context),
            child: const Text('Kopiuj adres e-mail'),
          ),
          const SizedBox(height: 28),
          Text(
            'Strony informacyjne',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 8),
          FutureBuilder<List<Map<String, dynamic>>>(
            future: _cmsFuture ?? _fetchCmsPages(apiBase),
            builder: (context, snap) {
              if (snap.connectionState == ConnectionState.waiting) {
                return const Padding(
                  padding: EdgeInsets.symmetric(vertical: 8),
                  child: LinearProgressIndicator(minHeight: 2),
                );
              }
              final pages = snap.data ?? const <Map<String, dynamic>>[];
              if (pages.isEmpty) {
                return Text(
                  'Brak opublikowanych stron CMS (skonfiguruj w panelu).',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: DesignTokens.mutedText,
                      ),
                );
              }
              return Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: pages.map((p) {
                  final slug = p['slug']?.toString() ?? '';
                  final title = p['title']?.toString() ?? slug;
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: OutlinedButton(
                      onPressed: slug.isEmpty
                          ? null
                          : () {
                              Navigator.of(context).push(
                                MaterialPageRoute<void>(
                                  builder: (_) => CmsPageScreen(
                                    apiBase: apiBase,
                                    slug: slug,
                                    titleFallback: title,
                                  ),
                                ),
                              );
                            },
                      child: Align(
                        alignment: Alignment.centerLeft,
                        child: Text(title),
                      ),
                    ),
                  );
                }).toList(),
              );
            },
          ),
          const SizedBox(height: 28),
          Text(
            'Dostawa i płatności',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 8),
          const _Bullet('Dostępne metody płatności i dostawy wybierzesz w koszyku przy składaniu zamówienia.'),
          const _Bullet('Po złożeniu zamówienia status płatności i realizacji widzisz w zakładce Konto → Twoje zamówienia.'),
          const SizedBox(height: 24),
          Text(
            'Zwroty i reklamacje',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 8),
          const _Bullet('Zgłoszenie zwrotu lub reklamacji — mail na adres obsługi z opisem i numerem zamówienia.'),
          const _Bullet('Produkty z rezerwacji w sklepie stacjonarnym — zasady zgodnie z regulaminem salonu i obowiązującym prawem.'),
          const SizedBox(height: 24),
          Text(
            'Polityka prywatności',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 8),
          Text(
            'Konto i logowanie są obsługiwane przez bezpiecznego dostawcę uwierzytelniania (Supabase). '
            'Dane zamówień przechowuje sklep w celu realizacji sprzedaży.',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: DesignTokens.mutedText),
          ),
        ],
      ),
    );
  }
}

class _Bullet extends StatelessWidget {
  const _Bullet(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('• ', style: Theme.of(context).textTheme.bodyLarge),
          Expanded(
            child: Text(
              text,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: DesignTokens.mutedText),
            ),
          ),
        ],
      ),
    );
  }
}
