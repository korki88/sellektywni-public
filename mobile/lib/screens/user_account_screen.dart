import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../data/product_details.dart';
import '../config/app_config.dart';
import '../config/shop_catalog.dart';
import '../providers/app_navigation.dart';
import '../providers/auth_session.dart';
import '../providers/cart_notifier.dart';
import '../providers/wishlist_notifier.dart';
import 'product_details_screen.dart';
import 'help_screen.dart';
import '../widgets/auth_shell.dart';

/// Panel użytkownika: rola, punkty, ranga, wylogowanie. Gość widzi zaproszenie do logowania.
class UserAccountScreen extends StatelessWidget {
  const UserAccountScreen({
    super.key,
    this.activationTick = 0,
  });

  final int activationTick;

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
        const SizedBox(height: 8),
        Align(
          alignment: Alignment.centerLeft,
          child: TextButton.icon(
            onPressed: () {
              Navigator.of(context).push(
                MaterialPageRoute<void>(builder: (_) => const HelpScreen()),
              );
            },
            icon: const Icon(Icons.help_outline, size: 20),
            label: const Text('Pomoc, zwroty, kontakt'),
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
        if (auth.isCustomer) ...[
          const SizedBox(height: 20),
          const _WishlistSummaryCard(),
          const SizedBox(height: 20),
          const _CustomerShopInfoCard(),
          const SizedBox(height: 20),
          _CheckoutSettingsPanel(auth: auth),
          const SizedBox(height: 20),
          _CustomerNotificationsPanel(
            auth: auth,
            refreshToken: activationTick,
          ),
          const SizedBox(height: 20),
          _CustomerOrdersPanel(
            auth: auth,
            refreshToken: activationTick,
          ),
        ],
        const SizedBox(height: 24),
        if (auth.isOwner)
          Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: Text(
              'Właściciel: panel administracyjny — statystyki, finanse (metody płatności), pracownicy, '
              'uprawnienia STAFF, zamówienia z checklistą paragonu Dotykačka i etykiety kurierskiej.',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: const Color(0xFF6B6B6B),
                  ),
            ),
          ),
        if (auth.isStaff)
          Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: Text(
              'Pracownik: rezerwacje, zamówienia, klienci, dostawy i symulacje integracji w trybie dev — '
              'bez zakładki uprawnień (tylko OWNER).',
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

/// Dostępne metody płatności i dostawy — zgodnie z backendem (checkout).
class _CustomerShopInfoCard extends StatelessWidget {
  const _CustomerShopInfoCard();

  @override
  Widget build(BuildContext context) {
    final dev = AppConfig.useDevMockAuth;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Płatności i dostawa',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
            ),
            const SizedBox(height: 10),
            Text(
              'Metody płatności w koszyku:',
              style: Theme.of(context).textTheme.labelLarge,
            ),
            const SizedBox(height: 6),
            ...kSupportedPaymentMethodCodes.map(
              (c) => Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: Text('• ${paymentMethodLabelPl(c)}'),
              ),
            ),
            const SizedBox(height: 12),
            Text(
              'Dostawa: ${shippingMethodLabelPl('COURIER')}; '
              '${shippingMethodLabelPl('PARCEL_LOCKER_INPOST')}; '
              '${shippingMethodLabelPl('STORE_PICKUP')}.',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: const Color(0xFF3D3D3D),
                  ),
            ),
            const SizedBox(height: 8),
            Text(
              'Przewoźnicy obsługiwani przez API sklepu: '
              '${kCourierIntegrationRows.map((e) => e['code']).join(', ')}.',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: const Color(0xFF6B6B6B),
                  ),
            ),
            if (dev) ...[
              const SizedBox(height: 10),
              Text(
                'Tryb deweloperski: część płatności i linków kurierskich jest symulowana — '
                'przycisk „Symuluj opłacenie” przy oczekującej płatności w zamówieniach.',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: Theme.of(context).colorScheme.primary,
                      fontWeight: FontWeight.w600,
                    ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _WishlistSummaryCard extends StatelessWidget {
  const _WishlistSummaryCard();

  @override
  Widget build(BuildContext context) {
    final wl = context.watch<WishlistNotifier>();
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Ulubione', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 8),
            if (wl.loading)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 8),
                child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
              )
            else if (wl.rows.isEmpty)
              Text(
                'Brak produktów — dodaj serce na karcie w sklepie.',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: const Color(0xFF6B6B6B),
                    ),
              )
            else
              ...wl.rows.map(
                (r) => Padding(
                  padding: const EdgeInsets.only(bottom: 6),
                  child: Text(
                    (r['name'] as String?) ?? (r['productId'] as String? ?? ''),
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _CustomerOrdersPanel extends StatefulWidget {
  const _CustomerOrdersPanel({
    required this.auth,
    required this.refreshToken,
  });

  final AuthSession auth;
  final int refreshToken;

  @override
  State<_CustomerOrdersPanel> createState() => _CustomerOrdersPanelState();
}

class _CheckoutSettingsPanel extends StatefulWidget {
  const _CheckoutSettingsPanel({required this.auth});

  final AuthSession auth;

  @override
  State<_CheckoutSettingsPanel> createState() => _CheckoutSettingsPanelState();
}

class _CheckoutSettingsPanelState extends State<_CheckoutSettingsPanel> {
  bool _loading = true;
  String? _payment;
  String? _shipping;
  String? _addressId;
  List<String> _paymentMethods = const [];
  List<String> _shippingMethods = const [];
  List<Map<String, dynamic>> _addressBook = const [];

  @override
  void initState() {
    super.initState();
    _refresh();
  }

  Future<void> _refresh() async {
    final cart = context.read<CartNotifier>();
    final options = await cart.fetchCheckoutOptions();
    final prefs = await cart.fetchCheckoutPreferences();
    if (!mounted) return;
    setState(() {
      _paymentMethods = (options?['paymentMethods'] as List<dynamic>? ?? const [])
          .map((e) => e.toString())
          .toList();
      _shippingMethods = (options?['shippingMethods'] as List<dynamic>? ?? const [])
          .map((e) => e.toString())
          .toList();
      _addressBook = (options?['addressBook'] as List<dynamic>? ?? const [])
          .whereType<Map<String, dynamic>>()
          .toList();
      final resolved = prefs?['resolvedDefaults'] as Map<String, dynamic>? ?? const {};
      _payment = (prefs?['preferredPaymentMethod']?.toString().isNotEmpty == true)
          ? prefs!['preferredPaymentMethod'].toString()
          : resolved['paymentMethod']?.toString();
      _shipping = (prefs?['preferredShippingMethod']?.toString().isNotEmpty == true)
          ? prefs!['preferredShippingMethod'].toString()
          : resolved['shippingMethod']?.toString();
      _addressId = (prefs?['preferredAddressId']?.toString().isNotEmpty == true)
          ? prefs!['preferredAddressId'].toString()
          : resolved['preferredAddressId']?.toString();
      _loading = false;
    });
  }

  Future<void> _savePreferences() async {
    final cart = context.read<CartNotifier>();
    final ok = await cart.saveCheckoutPreferences(
      preferredPaymentMethod: _payment,
      preferredShippingMethod: _shipping,
      preferredAddressId: _addressId,
    );
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          ok ? 'Preferencje zapisane.' : 'Nie udało się zapisać preferencji.',
        ),
      ),
    );
    if (ok) {
      await _refresh();
    }
  }

  Future<void> _editAddress([Map<String, dynamic>? existing]) async {
    final cart = context.read<CartNotifier>();
    final payload = await _showAddressEditor(existing: existing);
    if (payload == null) return;
    final saved = await cart.upsertAddressBookEntry(payload);
    if (!mounted) return;
    if (saved == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Nie udało się zapisać wpisu adresowego.')),
      );
      return;
    }
    await _refresh();
  }

  Future<void> _deleteAddress(String id) async {
    final cart = context.read<CartNotifier>();
    final ok = await cart.deleteAddressBookEntry(id);
    if (!mounted) return;
    if (!ok) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Nie udało się usunąć wpisu.')),
      );
      return;
    }
    await _refresh();
  }

  Future<Map<String, dynamic>?> _showAddressEditor({Map<String, dynamic>? existing}) {
    final labelCtrl = TextEditingController(text: existing?['label']?.toString() ?? '');
    final recipientCtrl =
        TextEditingController(text: existing?['recipientName']?.toString() ?? '');
    final phoneCtrl = TextEditingController(text: existing?['phone']?.toString() ?? '');
    final emailCtrl = TextEditingController(text: existing?['email']?.toString() ?? '');
    final postalCtrl = TextEditingController(text: existing?['postalCode']?.toString() ?? '');
    final cityCtrl = TextEditingController(text: existing?['city']?.toString() ?? '');
    final streetCtrl = TextEditingController(text: existing?['street']?.toString() ?? '');
    final buildingCtrl =
        TextEditingController(text: existing?['buildingNumber']?.toString() ?? '');
    final apartmentCtrl =
        TextEditingController(text: existing?['apartmentNumber']?.toString() ?? '');
    final lockerIdCtrl =
        TextEditingController(text: existing?['parcelLockerId']?.toString() ?? '');
    final lockerLabelCtrl =
        TextEditingController(text: existing?['parcelLockerLabel']?.toString() ?? '');
    var entryType = existing?['entryType']?.toString() ?? 'ADDRESS';
    var isDefault = existing?['isDefault'] == true;

    return showDialog<Map<String, dynamic>>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setModalState) => AlertDialog(
          title: Text(existing == null ? 'Nowy adres' : 'Edytuj adres'),
          content: SizedBox(
            width: 520,
            child: SingleChildScrollView(
              child: Column(
                children: [
                  DropdownButtonFormField<String>(
                    initialValue: entryType,
                    decoration: const InputDecoration(labelText: 'Typ wpisu'),
                    items: const [
                      DropdownMenuItem(value: 'ADDRESS', child: Text('Adres')),
                      DropdownMenuItem(
                        value: 'PARCEL_LOCKER',
                        child: Text('Paczkomat InPost'),
                      ),
                    ],
                    onChanged: (v) => setModalState(() => entryType = v ?? 'ADDRESS'),
                  ),
                  TextField(
                    controller: labelCtrl,
                    decoration: const InputDecoration(labelText: 'Etykieta'),
                  ),
                  TextField(
                    controller: recipientCtrl,
                    decoration: const InputDecoration(labelText: 'Odbiorca'),
                  ),
                  TextField(
                    controller: phoneCtrl,
                    decoration: const InputDecoration(labelText: 'Telefon'),
                  ),
                  TextField(
                    controller: emailCtrl,
                    decoration: const InputDecoration(labelText: 'E-mail'),
                  ),
                  if (entryType == 'PARCEL_LOCKER') ...[
                    TextField(
                      controller: lockerIdCtrl,
                      decoration: const InputDecoration(labelText: 'ID paczkomatu'),
                    ),
                    TextField(
                      controller: lockerLabelCtrl,
                      decoration: const InputDecoration(labelText: 'Opis paczkomatu'),
                    ),
                  ] else ...[
                    TextField(
                      controller: postalCtrl,
                      decoration: const InputDecoration(labelText: 'Kod pocztowy'),
                    ),
                    TextField(
                      controller: cityCtrl,
                      decoration: const InputDecoration(labelText: 'Miasto'),
                    ),
                    TextField(
                      controller: streetCtrl,
                      decoration: const InputDecoration(labelText: 'Ulica'),
                    ),
                    TextField(
                      controller: buildingCtrl,
                      decoration: const InputDecoration(labelText: 'Nr budynku'),
                    ),
                    TextField(
                      controller: apartmentCtrl,
                      decoration: const InputDecoration(labelText: 'Nr lokalu'),
                    ),
                  ],
                  CheckboxListTile(
                    value: isDefault,
                    onChanged: (v) => setModalState(() => isDefault = v ?? false),
                    title: const Text('Ustaw jako domyślny'),
                    contentPadding: EdgeInsets.zero,
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: const Text('Anuluj'),
            ),
            FilledButton(
              onPressed: () {
                Navigator.of(ctx).pop({
                  if (existing?['id'] != null) 'id': existing!['id'],
                  'entryType': entryType,
                  'label': labelCtrl.text.trim(),
                  'recipientName': recipientCtrl.text.trim(),
                  'phone': phoneCtrl.text.trim(),
                  'email': emailCtrl.text.trim(),
                  'country': 'PL',
                  'postalCode': postalCtrl.text.trim(),
                  'city': cityCtrl.text.trim(),
                  'street': streetCtrl.text.trim(),
                  'buildingNumber': buildingCtrl.text.trim(),
                  'apartmentNumber': apartmentCtrl.text.trim(),
                  'parcelLockerId': lockerIdCtrl.text.trim(),
                  'parcelLockerLabel': lockerLabelCtrl.text.trim(),
                  'isDefault': isDefault,
                });
              },
              child: const Text('Zapisz'),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Card(
        child: Padding(
          padding: EdgeInsets.all(20),
          child: LinearProgressIndicator(minHeight: 2),
        ),
      );
    }
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text(
                  'Ustawienia dostawy i płatności',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                ),
                const Spacer(),
                IconButton(
                  onPressed: _refresh,
                  icon: const Icon(Icons.refresh_rounded),
                  tooltip: 'Odśwież',
                ),
              ],
            ),
            DropdownButtonFormField<String>(
              initialValue: _payment,
              decoration: const InputDecoration(labelText: 'Domyślna płatność'),
              items: _paymentMethods
                  .map((m) => DropdownMenuItem(value: m, child: Text(m)))
                  .toList(),
              onChanged: (v) => setState(() => _payment = v),
            ),
            const SizedBox(height: 10),
            DropdownButtonFormField<String>(
              initialValue: _shipping,
              decoration: const InputDecoration(labelText: 'Domyślna dostawa'),
              items: _shippingMethods
                  .map((m) => DropdownMenuItem(value: m, child: Text(m)))
                  .toList(),
              onChanged: (v) => setState(() => _shipping = v),
            ),
            const SizedBox(height: 10),
            DropdownButtonFormField<String>(
              initialValue: _addressId,
              decoration: const InputDecoration(labelText: 'Domyślny adres / paczkomat'),
              items: _addressBook
                  .map(
                    (a) => DropdownMenuItem(
                      value: a['id']?.toString(),
                      child: Text(
                        (a['label']?.toString().isNotEmpty == true)
                            ? a['label'].toString()
                            : (a['parcelLockerId']?.toString().isNotEmpty == true)
                                ? 'Paczkomat ${a['parcelLockerId']}'
                                : '${a['city'] ?? ''}, ${a['street'] ?? ''}',
                      ),
                    ),
                  )
                  .toList(),
              onChanged: (v) => setState(() => _addressId = v),
            ),
            const SizedBox(height: 10),
            Align(
              alignment: Alignment.centerRight,
              child: FilledButton.tonal(
                onPressed: _savePreferences,
                child: const Text('Zapisz preferencje'),
              ),
            ),
            const Divider(height: 24),
            Row(
              children: [
                Text(
                  'Książka teleadresowa',
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                ),
                const Spacer(),
                TextButton.icon(
                  onPressed: () => _editAddress(),
                  icon: const Icon(Icons.add_rounded),
                  label: const Text('Dodaj'),
                ),
              ],
            ),
            if (_addressBook.isEmpty)
              const Padding(
                padding: EdgeInsets.only(top: 6),
                child: Text('Brak zapisanych adresów.'),
              )
            else
              ..._addressBook.map((a) => ListTile(
                    contentPadding: EdgeInsets.zero,
                    title: Text(
                      (a['label']?.toString().isNotEmpty == true)
                          ? a['label'].toString()
                          : (a['parcelLockerId']?.toString().isNotEmpty == true)
                              ? 'Paczkomat ${a['parcelLockerId']}'
                              : '${a['city'] ?? ''}, ${a['street'] ?? ''}',
                    ),
                    subtitle: Text(
                      '${a['recipientName'] ?? ''} ${a['phone'] ?? ''}'.trim(),
                    ),
                    trailing: Wrap(
                      spacing: 8,
                      children: [
                        IconButton(
                          onPressed: () => _editAddress(a),
                          icon: const Icon(Icons.edit_outlined),
                        ),
                        IconButton(
                          onPressed: () => _deleteAddress(a['id']?.toString() ?? ''),
                          icon: const Icon(Icons.delete_outline),
                        ),
                      ],
                    ),
                  )),
          ],
        ),
      ),
    );
  }
}

class _CustomerNotificationsPanel extends StatefulWidget {
  const _CustomerNotificationsPanel({
    required this.auth,
    required this.refreshToken,
  });

  final AuthSession auth;
  final int refreshToken;

  @override
  State<_CustomerNotificationsPanel> createState() =>
      _CustomerNotificationsPanelState();
}

class _CustomerNotificationsPanelState extends State<_CustomerNotificationsPanel> {
  late Future<List<Map<String, dynamic>>> _future;

  @override
  void initState() {
    super.initState();
    _future = _fetch();
  }

  @override
  void didUpdateWidget(covariant _CustomerNotificationsPanel oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.refreshToken != oldWidget.refreshToken) {
      setState(() => _future = _fetch());
    }
  }

  Future<List<Map<String, dynamic>>> _fetch() async {
    final token = widget.auth.accessToken;
    if (token == null || token.isEmpty) return const [];
    final uri = Uri.parse('${widget.auth.apiBase}/order/my-notifications');
    final r = await http.get(
      uri,
      headers: {'Authorization': 'Bearer $token'},
    );
    if (r.statusCode != 200) return const [];
    final j = jsonDecode(r.body);
    if (j is! List) return const [];
    return j.whereType<Map<String, dynamic>>().toList();
  }

  String _dateFmt(String raw) {
    final dt = DateTime.tryParse(raw)?.toLocal();
    if (dt == null) return raw;
    return '${dt.year.toString().padLeft(4, '0')}-${dt.month.toString().padLeft(2, '0')}-${dt.day.toString().padLeft(2, '0')} ${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
  }

  Color _levelColor(String level) {
    switch (level) {
      case 'success':
        return const Color(0xFFE8F5E9);
      case 'warning':
        return const Color(0xFFFFF3E0);
      default:
        return const Color(0xFFE8F0FE);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text(
                  'Centrum powiadomień',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                ),
                const Spacer(),
                IconButton(
                  onPressed: () => setState(() => _future = _fetch()),
                  tooltip: 'Odśwież',
                  icon: const Icon(Icons.refresh_rounded),
                ),
              ],
            ),
            FutureBuilder<List<Map<String, dynamic>>>(
              future: _future,
              builder: (context, snap) {
                if (snap.connectionState == ConnectionState.waiting) {
                  return const Padding(
                    padding: EdgeInsets.all(8),
                    child: LinearProgressIndicator(minHeight: 2),
                  );
                }
                final rows = snap.data ?? const [];
                if (rows.isEmpty) {
                  return Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: Text(
                      'Na ten moment nie masz nowych powiadomień.',
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                  );
                }
                return Column(
                  children: rows.take(20).map((n) {
                    final title = n['title']?.toString() ?? 'Powiadomienie';
                    final message = n['message']?.toString() ?? '';
                    final level = n['level']?.toString() ?? 'info';
                    final at = _dateFmt(n['at']?.toString() ?? '');
                    final productName = n['productName']?.toString();
                    return Container(
                      margin: const EdgeInsets.only(top: 10),
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: _levelColor(level),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            title,
                            style: Theme.of(context).textTheme.titleSmall?.copyWith(
                                  fontWeight: FontWeight.w700,
                                ),
                          ),
                          const SizedBox(height: 4),
                          Text(message),
                          if (productName != null && productName.isNotEmpty) ...[
                            const SizedBox(height: 4),
                            Text('Produkt: $productName'),
                          ],
                          const SizedBox(height: 4),
                          Text(
                            at,
                            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                  color: const Color(0xFF6B6B6B),
                                ),
                          ),
                        ],
                      ),
                    );
                  }).toList(),
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}

class _CustomerOrdersPanelState extends State<_CustomerOrdersPanel> {
  late Future<List<Map<String, dynamic>>> _future;
  final Set<String> _expandedOrders = {};

  @override
  void initState() {
    super.initState();
    _future = _fetch();
  }

  @override
  void didUpdateWidget(covariant _CustomerOrdersPanel oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.refreshToken != oldWidget.refreshToken) {
      setState(() => _future = _fetch());
    }
  }

  Future<List<Map<String, dynamic>>> _fetch() async {
    final token = widget.auth.accessToken;
    if (token == null || token.isEmpty) return const [];
    final uri = Uri.parse('${widget.auth.apiBase}/order/my-orders');
    final r = await http.get(
      uri,
      headers: {'Authorization': 'Bearer $token'},
    );
    if (r.statusCode != 200) return const [];
    final j = jsonDecode(r.body);
    if (j is! List) return const [];
    return j.whereType<Map<String, dynamic>>().toList();
  }

  String _dateFmt(String raw) {
    final dt = DateTime.tryParse(raw)?.toLocal();
    if (dt == null) return raw;
    return '${dt.year.toString().padLeft(4, '0')}-${dt.month.toString().padLeft(2, '0')}-${dt.day.toString().padLeft(2, '0')} ${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text(
                  'Twoje zamówienia',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                ),
                const Spacer(),
                IconButton(
                  onPressed: () => setState(() => _future = _fetch()),
                  tooltip: 'Odśwież',
                  icon: const Icon(Icons.refresh_rounded),
                ),
              ],
            ),
            FutureBuilder<List<Map<String, dynamic>>>(
              future: _future,
              builder: (context, snap) {
                if (snap.connectionState == ConnectionState.waiting) {
                  return const Padding(
                    padding: EdgeInsets.all(8),
                    child: LinearProgressIndicator(minHeight: 2),
                  );
                }
                final rows = snap.data ?? const [];
                if (rows.isEmpty) {
                  return Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: Text(
                      'Brak zamówień.',
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                  );
                }
                final totalSpent = rows.fold<double>(
                  0,
                  (sum, o) =>
                      sum + (double.tryParse(o['totalAmount']?.toString() ?? '0') ?? 0),
                );
                final avgOrder = rows.isEmpty ? 0 : totalSpent / rows.length;
                return Column(
                  children: [
                    Container(
                      width: double.infinity,
                      margin: const EdgeInsets.only(top: 10),
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF7F9FC),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        'Łączne wydatki: ${totalSpent.toStringAsFixed(0)} zł · Średnia wartość zamówienia: ${avgOrder.toStringAsFixed(0)} zł',
                        style: Theme.of(context).textTheme.bodyMedium,
                      ),
                    ),
                    ...rows.map((o) {
                    final statusRaw = o['status']?.toString() ?? '—';
                    final status = '${orderStatusLabelPl(statusRaw)} ($statusRaw)';
                    final total = o['totalAmount']?.toString() ?? '0';
                    final itemCount = (o['itemCount'] as num?)?.toInt() ?? 0;
                    final paymentStatus = o['paymentStatus']?.toString() ?? '—';
                    final paymentMethod = o['paymentMethod']?.toString() ?? '—';
                    final paymentReference = o['paymentReference']?.toString();
                    final paymentSessionUrl = o['paymentSessionUrl']?.toString();
                    final paymentBankAccount = o['paymentBankAccount']?.toString();
                    final createdAt = _dateFmt(o['createdAt']?.toString() ?? '');
                    return Container(
                      margin: const EdgeInsets.only(top: 10),
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        border: Border.all(color: const Color(0xFFEAEAEA)),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: InkWell(
                        onTap: () {
                          setState(() {
                            if (_expandedOrders.contains(o['id'])) {
                              _expandedOrders.remove(o['id']);
                            } else {
                              _expandedOrders.add(o['id']?.toString() ?? '');
                            }
                          });
                        },
                        borderRadius: BorderRadius.circular(12),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('Data: $createdAt'),
                            const SizedBox(height: 4),
                            Text('Status: $status'),
                            const SizedBox(height: 4),
                            Text('Pozycji: $itemCount'),
                            const SizedBox(height: 4),
                            Text('Kwota: $total zł'),
                            const SizedBox(height: 4),
                            Text('Płatność: $paymentMethod · status: $paymentStatus'),
                            if (paymentReference != null && paymentReference.isNotEmpty) ...[
                              const SizedBox(height: 4),
                              Text('Referencja: $paymentReference'),
                            ],
                            if (paymentBankAccount != null && paymentBankAccount.isNotEmpty) ...[
                              const SizedBox(height: 4),
                              Text('Rachunek (dev): $paymentBankAccount'),
                            ],
                            if (paymentSessionUrl != null && paymentSessionUrl.isNotEmpty) ...[
                              const SizedBox(height: 4),
                              Text(
                                'Link płatności (symulacja): $paymentSessionUrl',
                                style: Theme.of(context).textTheme.bodySmall,
                              ),
                            ],
                            if (paymentStatus == 'PENDING') ...[
                              const SizedBox(height: 8),
                              FilledButton.tonal(
                                onPressed: () async {
                                  final err = await context
                                      .read<CartNotifier>()
                                      .simulateOrderPaymentSuccess(o['id']?.toString() ?? '');
                                  if (!context.mounted) return;
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(
                                      content: Text(
                                        err ?? 'Płatność zaksięgowana w trybie deweloperskim.',
                                      ),
                                    ),
                                  );
                                  if (err == null) {
                                    setState(() => _future = _fetch());
                                  }
                                },
                                child: const Text('Symuluj opłacenie'),
                              ),
                            ],
                            if (_expandedOrders.contains(o['id'])) ...[
                              const Divider(height: 20),
                              Align(
                                alignment: Alignment.centerLeft,
                                child: Text(
                                  'Dostawa: ${shippingMethodLabelPl(o['shippingMethod']?.toString() ?? '')}',
                                  style: Theme.of(context).textTheme.titleSmall?.copyWith(
                                        fontWeight: FontWeight.w600,
                                      ),
                                ),
                              ),
                              if (o['shippingSnapshot'] != null) ...[
                                const SizedBox(height: 6),
                                SelectableText(
                                  JsonEncoder.withIndent('  ').convert(o['shippingSnapshot']),
                                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                        color: const Color(0xFF4A4A4A),
                                      ),
                                ),
                                const SizedBox(height: 12),
                              ],
                              ...(o['items'] as List<dynamic>? ?? const []).map((rawItem) {
                                if (rawItem is! Map<String, dynamic>) {
                                  return const SizedBox.shrink();
                                }
                                final productId = rawItem['productId']?.toString() ?? '';
                                final name = rawItem['name']?.toString() ?? 'Produkt';
                                final qty = (rawItem['quantity'] as num?)?.toInt() ?? 0;
                                final price =
                                    double.tryParse(rawItem['price']?.toString() ?? '0') ?? 0;
                                final product =
                                    lookupProductById(productId) ??
                                        fallbackProductForOrderItem(
                                          productId: productId,
                                          name: name,
                                          pricePln: price,
                                        );
                                return ListTile(
                                  dense: true,
                                  contentPadding: EdgeInsets.zero,
                                  title: Text(name),
                                  subtitle: Text('$qty szt. · ${price.toStringAsFixed(0)} zł'),
                                  trailing: const Icon(Icons.chevron_right_rounded),
                                  onTap: () => Navigator.of(context).push(
                                    MaterialPageRoute<void>(
                                      builder: (_) => ProductDetailsScreen(product: product),
                                    ),
                                  ),
                                );
                              }),
                            ],
                          ],
                        ),
                      ),
                    );
                  }),
                  ],
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}
