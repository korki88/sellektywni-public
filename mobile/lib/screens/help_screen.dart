import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../config/app_config.dart';

/// Pomoc, kontakt, podstawowe zasady (jak w dużych sklepach — jasna ścieżka dla klienta).
class HelpScreen extends StatelessWidget {
  const HelpScreen({super.key});

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
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: const Color(0xFF4A4A4A)),
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
            'Konto i logowanie są obsługiwane przez bezpieczny dostawcę uwierzytelniania (Supabase). '
            'Dane zamówień przechowuje sklep w celu realizacji sprzedaży.',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: const Color(0xFF4A4A4A)),
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
          const Text('•  '),
          Expanded(
            child: Text(
              text,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: const Color(0xFF4A4A4A)),
            ),
          ),
        ],
      ),
    );
  }
}
