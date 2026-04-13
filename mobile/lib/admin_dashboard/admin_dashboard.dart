import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../config/app_config.dart';
import '../data/product_details.dart';
import '../layout/web_app_frame.dart';
import '../providers/app_navigation.dart';
import '../providers/auth_session.dart';
import '../screens/product_details_screen.dart';
import '../screens/user_account_screen.dart';
import '../staff/staff_api.dart';
import '../staff/staff_models.dart';
import '../theme/app_theme.dart';
import 'hid_qr_scanner_layer.dart';
import 'staff_overlay_launcher.dart';

enum AdminDashboardPresentation {
  /// WWW + aplikacja — pełny ekran w [WebAppFrame] na webie.
  fullscreen,

  /// Pływający panel (Android, drugi silnik — [overlayMain]).
  overlaySidebar,
}

/// Jednolity panel OWNER/STAFF: menu wg roli, skaner HID na całym stosie.
class AdminDashboard extends StatefulWidget {
  const AdminDashboard({
    super.key,
    this.presentation = AdminDashboardPresentation.fullscreen,
  });

  final AdminDashboardPresentation presentation;

  @override
  State<AdminDashboard> createState() => _AdminDashboardState();
}

enum _MenuId {
  stats,
  finance,
  aiAgents,
  employees,
  reservations,
  orders,
  shipping,
  permissions,
  dotykackaDev,
  scanner,
  loyalty,
}

class _AdminDashboardState extends State<AdminDashboard> {
  int _railIndex = 0;
  final _scanFocus = FocusNode();
  final _scanController = TextEditingController();
  final _manualIdController = TextEditingController();
  final _dotykackaIdController = TextEditingController();
  final _dotykackaQtyController = TextEditingController(text: '0');

  List<StaffProduct> _queue = [];
  List<StaffOrder> _orders = [];
  final Set<String> _expandedOrderIds = {};
  List<StaffPermissionUser> _permissionUsers = [];
  List<String> _availablePermissions = [];
  StaffCustomerProfile? _customer;
  bool _loadingQueue = false;
  bool _loadingOrders = false;
  bool _loadingPermissions = false;
  bool _loadingShipping = false;
  bool _loadingCustomer = false;
  bool _loadingDotykackaDev = false;
  bool _dotykackaDevEnabled = false;
  String? _error;
  List<DotykackaDevStockRow> _dotykackaRows = [];
  List<Map<String, dynamic>> _shippingProviders = [];
  /// Klucze: INPOST, DPD, DHL, POCZTA_POLSKA — lista punktów z API (live-first + fallback).
  Map<String, dynamic>? _shippingSuggest;
  _MenuId? _lastAutoLoadedMenu;

  List<_MenuId> _menuForRole(AuthSession auth) {
    final menu = <_MenuId>[];
    if (auth.hasPermission('view.analytics')) {
      menu.addAll(const [_MenuId.stats, _MenuId.finance]);
    }
    if (auth.isOwner) {
      menu.addAll(const [_MenuId.aiAgents, _MenuId.employees]);
    }
    if (auth.hasPermission('manage.reservations')) {
      menu.add(_MenuId.reservations);
    }
    if (auth.hasPermission('manage.orders')) {
      menu.add(_MenuId.orders);
    }
    if (auth.hasPermission('manage.orders')) {
      menu.add(_MenuId.shipping);
    }
    if (auth.hasPermission('manage.permissions')) {
      menu.add(_MenuId.permissions);
    }
    if (auth.hasPermission('manage.dotykacka')) {
      menu.add(_MenuId.dotykackaDev);
    }
    if (auth.hasPermission('manage.customers')) {
      menu.addAll(const [_MenuId.scanner, _MenuId.loyalty]);
    }
    return menu;
  }

  String _label(_MenuId id) {
    switch (id) {
      case _MenuId.stats:
        return 'Statystyki';
      case _MenuId.finance:
        return 'Finanse';
      case _MenuId.aiAgents:
        return 'Agenci AI';
      case _MenuId.employees:
        return 'Pracownicy';
      case _MenuId.reservations:
        return 'Rezerwacje';
      case _MenuId.orders:
        return 'Zamówienia';
      case _MenuId.permissions:
        return 'Uprawnienia';
      case _MenuId.shipping:
        return 'Dostawy';
      case _MenuId.dotykackaDev:
        return 'Dotykačka DEV';
      case _MenuId.scanner:
        return 'Skaner';
      case _MenuId.loyalty:
        return 'Lojalność';
    }
  }

  IconData _icon(_MenuId id, {required bool selected}) {
    switch (id) {
      case _MenuId.stats:
        return selected ? Icons.insights : Icons.insights_outlined;
      case _MenuId.finance:
        return selected ? Icons.account_balance : Icons.account_balance_outlined;
      case _MenuId.aiAgents:
        return selected ? Icons.smart_toy : Icons.smart_toy_outlined;
      case _MenuId.employees:
        return selected ? Icons.groups : Icons.groups_outlined;
      case _MenuId.reservations:
        return selected ? Icons.event_note : Icons.event_note_outlined;
      case _MenuId.orders:
        return selected ? Icons.receipt_long : Icons.receipt_long_outlined;
      case _MenuId.permissions:
        return selected ? Icons.admin_panel_settings : Icons.admin_panel_settings_outlined;
      case _MenuId.shipping:
        return selected ? Icons.local_shipping : Icons.local_shipping_outlined;
      case _MenuId.dotykackaDev:
        return selected ? Icons.sync_alt : Icons.sync_alt_outlined;
      case _MenuId.scanner:
        return selected ? Icons.qr_code_scanner : Icons.qr_code_scanner_outlined;
      case _MenuId.loyalty:
        return selected ? Icons.card_giftcard : Icons.card_giftcard_outlined;
    }
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _refreshCurrentSectionIfNeeded(force: true);
      _requestScanFocus();
    });
  }

  @override
  void dispose() {
    _scanFocus.dispose();
    _scanController.dispose();
    _manualIdController.dispose();
    _dotykackaIdController.dispose();
    _dotykackaQtyController.dispose();
    super.dispose();
  }

  void _requestScanFocus() {
    if (kIsWeb) return;
    Future<void>.delayed(const Duration(milliseconds: 50), () {
      if (mounted) _scanFocus.requestFocus();
    });
  }

  StaffApi get _api => StaffApi(context.read<AuthSession>());

  void _autoRefreshMenu(_MenuId menuId) {
    switch (menuId) {
      case _MenuId.reservations:
        _loadQueue();
      case _MenuId.orders:
        _loadOrders();
      case _MenuId.shipping:
        _loadShipping();
      case _MenuId.permissions:
        _loadPermissions();
      case _MenuId.dotykackaDev:
        _loadDotykackaDev();
      default:
        break;
    }
  }

  void _refreshCurrentSectionIfNeeded({bool force = false}) {
    final auth = context.read<AuthSession>();
    final menu = _menuForRole(auth);
    if (menu.isEmpty) return;
    final safeIndex =
        _railIndex < 0 ? 0 : (_railIndex >= menu.length ? menu.length - 1 : _railIndex);
    final current = menu[safeIndex];
    if (_lastAutoLoadedMenu != current) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        _refreshCurrentSectionIfNeeded();
      });
    }
    if (!force && _lastAutoLoadedMenu == current) {
      return;
    }
    _lastAutoLoadedMenu = current;
    _autoRefreshMenu(current);
  }

  Future<void> _loadQueue() async {
    final auth = context.read<AuthSession>();
    if (!auth.hasToken) {
      setState(() => _error = 'Ustaw token Bearer (Supabase access token).');
      return;
    }
    setState(() {
      _loadingQueue = true;
      _error = null;
    });
    try {
      final list = await _api.fetchPendingProducts();
      if (!mounted) return;
      setState(() {
        _queue = list;
        _loadingQueue = false;
      });
    } on StaffApiException catch (e) {
      if (!mounted) return;
      setState(() {
        _loadingQueue = false;
        _error = e.toString();
      });
    }
    _requestScanFocus();
  }

  Future<void> _loadOrders() async {
    setState(() {
      _loadingOrders = true;
      _error = null;
    });
    try {
      final rows = await _api.fetchOrders();
      if (!mounted) return;
      setState(() {
        _orders = rows;
        _loadingOrders = false;
      });
    } on StaffApiException catch (e) {
      if (!mounted) return;
      setState(() {
        _loadingOrders = false;
        _error = e.toString();
      });
    }
  }

  Future<void> _loadShipping() async {
    setState(() {
      _loadingShipping = true;
      _error = null;
    });
    try {
      final providers = await _api.fetchShippingProviders();
      final suggest = await _api.fetchShippingPointsSuggest();
      if (!mounted) return;
      setState(() {
        _shippingProviders = providers;
        _shippingSuggest = suggest;
        _loadingShipping = false;
      });
    } on StaffApiException catch (e) {
      if (!mounted) return;
      setState(() {
        _loadingShipping = false;
        _error = e.toString();
      });
    }
  }

  Future<void> _setOrderStatus(StaffOrder order, String nextStatus) async {
    try {
      await _api.patchOrderStatus(order.id, nextStatus);
      await _loadOrders();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Zmieniono status zamówienia ${order.id} na $nextStatus')),
      );
    } on StaffApiException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.toString())),
      );
    }
  }

  Future<void> _setOrderPaymentStatus(StaffOrder order, String nextPaymentStatus) async {
    try {
      await _api.patchOrderPaymentStatus(order.id, nextPaymentStatus);
      await _loadOrders();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Zmieniono status płatności zamówienia ${order.id} na $nextPaymentStatus',
          ),
        ),
      );
    } on StaffApiException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.toString())),
      );
    }
  }

  Future<void> _loadPermissions() async {
    setState(() {
      _loadingPermissions = true;
      _error = null;
    });
    try {
      final data = await _api.fetchPermissionUsers();
      if (!mounted) return;
      setState(() {
        _availablePermissions = data.availablePermissions;
        _permissionUsers = data.users;
        _loadingPermissions = false;
      });
    } on StaffApiException catch (e) {
      if (!mounted) return;
      setState(() {
        _loadingPermissions = false;
        _error = e.toString();
      });
    }
  }

  Future<void> _togglePermission(
    StaffPermissionUser user,
    String permission,
    bool enabled,
  ) async {
    final updated = [...user.permissions];
    if (enabled) {
      if (!updated.contains(permission)) updated.add(permission);
    } else {
      updated.remove(permission);
    }
    try {
      await _api.updatePermissions(user.userId, updated);
      await _loadPermissions();
      if (!mounted) return;
      await context.read<AuthSession>().refreshProfile();
    } on StaffApiException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.toString())),
      );
    }
  }

  Future<void> _accept(StaffProduct p) async {
    try {
      await _api.acceptProduct(p.id);
      await _loadQueue();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Zaakceptowano: ${p.name}')),
      );
    } on StaffApiException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.toString())),
      );
    }
    _requestScanFocus();
  }

  Future<void> _reject(StaffProduct p) async {
    try {
      await _api.rejectProduct(p.id);
      await _loadQueue();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Odrzucono: ${p.name}')),
      );
    } on StaffApiException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.toString())),
      );
    }
    _requestScanFocus();
  }

  Future<void> _openCustomer(String rawInput) async {
    final id = extractCustomerUuid(rawInput);
    if (id == null) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Nie znaleziono UUID klienta w zeskanowanym tekście.'),
        ),
      );
      _requestScanFocus();
      return;
    }
    await _loadCustomer(id);
  }

  Future<void> _loadCustomer(String userId) async {
    final auth = context.read<AuthSession>();
    if (!auth.hasToken) {
      setState(() => _error = 'Ustaw token Bearer.');
      return;
    }
    setState(() {
      _loadingCustomer = true;
      _error = null;
    });
    try {
      final c = await _api.fetchCustomer(userId);
      if (!mounted) return;
      setState(() {
        _customer = c;
        _loadingCustomer = false;
      });
      _focusTabAfterScan();
    } on StaffApiException catch (e) {
      if (!mounted) return;
      setState(() {
        _loadingCustomer = false;
        _error = e.toString();
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.toString())),
      );
    }
    _requestScanFocus();
  }

  Future<void> _loadDotykackaDev() async {
    setState(() {
      _loadingDotykackaDev = true;
      _error = null;
    });
    try {
      final data = await _api.fetchDotykackaDevStock();
      if (!mounted) return;
      setState(() {
        _loadingDotykackaDev = false;
        _dotykackaDevEnabled = data.enabled;
        _dotykackaRows = data.rows;
      });
    } on StaffApiException catch (e) {
      if (!mounted) return;
      setState(() {
        _loadingDotykackaDev = false;
        _error = e.toString();
      });
    }
  }

  Future<void> _setDotykackaStock() async {
    final id = _dotykackaIdController.text.trim();
    final qty = int.tryParse(_dotykackaQtyController.text.trim());
    if (id.isEmpty || qty == null) return;
    try {
      await _api.setDotykackaDevStock(id, qty);
      await _loadDotykackaDev();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Ustawiono stan $id = $qty')),
      );
    } on StaffApiException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.toString())),
      );
    }
  }

  void _focusTabAfterScan() {
    final menu = _menuForRole(context.read<AuthSession>());
    final loyalty = menu.indexOf(_MenuId.loyalty);
    final scanner = menu.indexOf(_MenuId.scanner);
    if (loyalty >= 0) {
      setState(() => _railIndex = loyalty);
    } else if (scanner >= 0) {
      setState(() => _railIndex = scanner);
    }
  }

  Future<void> _setVintage() async {
    final c = _customer;
    if (c == null) return;
    try {
      final u = await _api.patchCustomer(c.userId, rank: 'VINTAGE');
      if (!mounted) return;
      setState(() => _customer = u);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Ranga ustawiona: VINTAGE')),
      );
    } on StaffApiException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.toString())),
      );
    }
    _requestScanFocus();
  }

  Future<void> _addPoints(int n) async {
    final c = _customer;
    if (c == null) return;
    try {
      final u = await _api.patchCustomer(c.userId, addPoints: n);
      if (!mounted) return;
      setState(() => _customer = u);
    } on StaffApiException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.toString())),
      );
    }
    _requestScanFocus();
  }

  Widget _buildPlaceholder(String title, String body) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.construction_outlined, size: 48, color: Colors.grey.shade600),
            const SizedBox(height: 16),
            Text(title, style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 8),
            Text(
              body,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: const Color(0xFF6B6B6B),
                  ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildQueueTab() {
    if (_loadingQueue) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_queue.isEmpty) {
      return Center(
        child: Text(
          'Brak produktów oczekujących na akceptację.',
          style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                color: const Color(0xFF6B6B6B),
              ),
        ),
      );
    }
    return ListView.separated(
      padding: const EdgeInsets.all(16),
      itemCount: _queue.length,
      separatorBuilder: (_, __) => const SizedBox(height: 12),
      itemBuilder: (context, i) {
        final p = _queue[i];
        return Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                InkWell(
                  onTap: () {
                    final product =
                        lookupProductById(p.id) ??
                        fallbackProductForOrderItem(
                          productId: p.id,
                          name: p.name,
                          pricePln: double.tryParse(p.priceRaw) ?? 0,
                        );
                    Navigator.of(context).push(
                      MaterialPageRoute<void>(
                        builder: (_) => ProductDetailsScreen(product: product),
                      ),
                    );
                  },
                  child: Text(
                    p.name,
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  '${p.priceRaw} zł · ${p.pendingQuantity} szt. · ${p.status}',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: const Color(0xFF6B6B6B),
                      ),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: FilledButton(
                        onPressed: () => _accept(p),
                        style: FilledButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          backgroundColor: AppTheme.light.colorScheme.primary,
                        ),
                        child: const Text('AKCEPTUJ'),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () => _reject(p),
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 16),
                        ),
                        child: const Text('ODRZUĆ'),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildScannerTab({required bool showFullCustomerCard}) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: ListView(
        children: [
          Text(
            'Skaner HID: urządzenie symuluje klawiaturę — pole nasłuchu ma fokus w tle '
            '(działa także w oknie overlay i na WWW).',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: const Color(0xFF6B6B6B),
                ),
          ),
          const SizedBox(height: 12),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: TextField(
                  controller: _manualIdController,
                  decoration: const InputDecoration(
                    labelText: 'Ręczne UUID klienta',
                    border: OutlineInputBorder(),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              FilledButton(
                onPressed: () {
                  final t = _manualIdController.text;
                  if (t.trim().isNotEmpty) _loadCustomer(t.trim());
                },
                child: const Text('Otwórz'),
              ),
            ],
          ),
          const SizedBox(height: 24),
          if (showFullCustomerCard) ...[
            if (_loadingCustomer)
              const Center(child: CircularProgressIndicator())
            else if (_customer == null)
              Text(
                'Brak wybranego klienta — zeskanuj kod lub wpisz UUID.',
                style: Theme.of(context).textTheme.bodyLarge,
              )
            else
              _buildCustomerCard(_customer!),
          ] else
            Text(
              _customer != null
                  ? 'Klient wczytany — przejdź do „Lojalność”, aby edytować punkty.'
                  : 'Zeskanuj kod klienta lub wpisz UUID.',
              style: Theme.of(context).textTheme.bodyMedium,
            ),
        ],
      ),
    );
  }

  Widget _buildLoyaltyTab() {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: ListView(
        children: [
          Text(
            'Program lojalnościowy — profil po skanie QR.',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: const Color(0xFF6B6B6B),
                ),
          ),
          const SizedBox(height: 16),
          if (_loadingCustomer)
            const Center(child: CircularProgressIndicator())
          else if (_customer == null)
            Text(
              'Brak klienta — użyj zakładki Skaner lub zeskanuj kod (HID).',
              style: Theme.of(context).textTheme.bodyLarge,
            )
          else
            _buildCustomerCard(_customer!),
        ],
      ),
    );
  }

  Widget _buildOrdersTab() {
    if (_loadingOrders) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_orders.isEmpty) {
      return Center(
        child: Text(
          'Brak zamówień do obsługi.',
          style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                color: const Color(0xFF6B6B6B),
              ),
        ),
      );
    }
    return ListView.separated(
      padding: const EdgeInsets.all(16),
      itemCount: _orders.length,
      separatorBuilder: (_, __) => const SizedBox(height: 10),
      itemBuilder: (context, i) {
        final o = _orders[i];
        final expanded = _expandedOrderIds.contains(o.id);
        return Card(
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: InkWell(
              onTap: () {
                setState(() {
                  if (expanded) {
                    _expandedOrderIds.remove(o.id);
                  } else {
                    _expandedOrderIds.add(o.id);
                  }
                });
              },
              borderRadius: BorderRadius.circular(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    o.customerEmail ?? o.userId,
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Status: ${o.status} · Pozycji: ${o.itemCount} · Kwota: ${o.totalAmountRaw} zł',
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: const Color(0xFF6B6B6B),
                        ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Płatność: ${o.paymentMethod} (${o.paymentProvider}) · status: ${o.paymentStatus}',
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: const Color(0xFF6B6B6B),
                        ),
                  ),
                  if (o.paymentReference != null && o.paymentReference!.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(top: 4),
                      child: Text(
                        'Ref: ${o.paymentReference}',
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              color: const Color(0xFF6B6B6B),
                            ),
                      ),
                    ),
                  const SizedBox(height: 4),
                  Text(
                    'Data: ${o.createdAt}',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: const Color(0xFF6B6B6B),
                        ),
                  ),
                  const SizedBox(height: 10),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      FilledButton.tonal(
                        onPressed: () => _setOrderStatus(o, 'PROCESSING'),
                        child: const Text('W realizacji'),
                      ),
                      FilledButton.tonal(
                        onPressed: () => _setOrderStatus(o, 'READY'),
                        child: const Text('Gotowe'),
                      ),
                      FilledButton.tonal(
                        onPressed: () => _setOrderStatus(o, 'COMPLETED'),
                        child: const Text('Zakończone'),
                      ),
                      OutlinedButton(
                        onPressed: () => _setOrderStatus(o, 'CANCELED'),
                        child: const Text('Anuluj'),
                      ),
                      FilledButton.tonal(
                        onPressed: () => _setOrderPaymentStatus(o, 'PAID'),
                        child: const Text('Płatność: opłacone'),
                      ),
                      OutlinedButton(
                        onPressed: () => _setOrderPaymentStatus(o, 'FAILED'),
                        child: const Text('Płatność: błąd'),
                      ),
                    ],
                  ),
                  if (expanded) ...[
                    const Divider(height: 20),
                    ...o.items.map((item) {
                      final product =
                          lookupProductById(item.productId) ??
                          fallbackProductForOrderItem(
                            productId: item.productId,
                            name: item.name,
                            pricePln: double.tryParse(item.priceRaw) ?? 0,
                          );
                      return ListTile(
                        dense: true,
                        contentPadding: EdgeInsets.zero,
                        title: Text(item.name),
                        subtitle: Text(
                          '${item.quantity} szt. · ${item.priceRaw} zł · suma ${item.lineTotalRaw} zł',
                        ),
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
          ),
        );
      },
    );
  }

  Widget _buildPermissionsTab() {
    if (_loadingPermissions) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_permissionUsers.isEmpty) {
      return Center(
        child: Text(
          'Brak użytkowników do zarządzania uprawnieniami.',
          style: Theme.of(context).textTheme.bodyMedium,
        ),
      );
    }
    return ListView.separated(
      padding: const EdgeInsets.all(16),
      itemCount: _permissionUsers.length,
      separatorBuilder: (_, __) => const SizedBox(height: 10),
      itemBuilder: (context, i) {
        final u = _permissionUsers[i];
        return Card(
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(u.email ?? u.userId, style: Theme.of(context).textTheme.titleMedium),
                const SizedBox(height: 4),
                Text('Rola: ${u.role}', style: Theme.of(context).textTheme.bodySmall),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 6,
                  children: _availablePermissions
                      .map(
                        (p) => FilterChip(
                          label: Text(p),
                          selected: u.permissions.contains(p),
                          selectedColor: const Color(0xFFE8F0FE),
                          labelStyle: TextStyle(
                            color: u.permissions.contains(p)
                                ? const Color(0xFF0D1B2A)
                                : const Color(0xFF111111),
                            fontWeight: FontWeight.w600,
                          ),
                          onSelected: u.role == 'OWNER'
                              ? null
                              : (v) => _togglePermission(u, p, v),
                        ),
                      )
                      .toList(),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildDotykackaDevTab() {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: ListView(
        children: [
          Text(
            'Symulator Dotykačka (dev): ustawiaj stany magazynowe po idDotykacka.',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: const Color(0xFF6B6B6B),
                ),
          ),
          const SizedBox(height: 10),
          Text(
            _dotykackaDevEnabled
                ? 'Tryb symulacji: aktywny'
                : 'Tryb symulacji: wyłączony (AUTH_DEV_MOCK=false)',
            style: Theme.of(context).textTheme.bodyMedium,
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _dotykackaIdController,
                  decoration: const InputDecoration(
                    labelText: 'idDotykacka (np. DOTY-1)',
                    border: OutlineInputBorder(),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              SizedBox(
                width: 120,
                child: TextField(
                  controller: _dotykackaQtyController,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                    labelText: 'Stan',
                    border: OutlineInputBorder(),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              FilledButton(
                onPressed: _dotykackaDevEnabled ? _setDotykackaStock : null,
                child: const Text('Ustaw'),
              ),
            ],
          ),
          const SizedBox(height: 14),
          FilledButton.tonal(
            onPressed: _loadDotykackaDev,
            child: const Text('Odśwież stany'),
          ),
          const SizedBox(height: 14),
          if (_loadingDotykackaDev)
            const Center(child: CircularProgressIndicator())
          else if (_dotykackaRows.isEmpty)
            Text(
              'Brak wpisów symulatora. Dodaj pierwszy stan.',
              style: Theme.of(context).textTheme.bodyMedium,
            )
          else
            ..._dotykackaRows.map(
              (r) => ListTile(
                dense: true,
                title: Text(r.idDotykacka),
                trailing: Text('${r.stockQty} szt.'),
              ),
            ),
        ],
      ),
    );
  }

  List<Widget> _buildShippingSuggestSections(Map<String, dynamic> suggest) {
    const order = <List<String>>[
      ['INPOST', 'InPost'],
      ['DPD', 'DPD Pickup'],
      ['DHL', 'DHL POP / punkt'],
      ['POCZTA_POLSKA', 'Poczta Polska'],
    ];
    final out = <Widget>[];
    for (final entry in order) {
      final key = entry[0];
      final label = entry[1];
      final raw = suggest[key];
      final list = raw is List<dynamic> ? raw : const <dynamic>[];
      out.add(
        Padding(
          padding: const EdgeInsets.only(top: 4, bottom: 6),
          child: Text(
            '$label (${list.length})',
            style: Theme.of(context).textTheme.titleSmall,
          ),
        ),
      );
      if (list.isEmpty) {
        out.add(
          Text(
            'Brak punktów (sprawdź konfigurację API lub sieć).',
            style: Theme.of(context).textTheme.bodySmall,
          ),
        );
        continue;
      }
      for (final p in list) {
        if (p is! Map) continue;
        final m = Map<String, dynamic>.from(p);
        out.add(
          ListTile(
            dense: true,
            title: Text('${m['id']} · ${m['name'] ?? ''}'),
            subtitle: Text(
              '${m['address'] ?? ''}, ${m['postalCode'] ?? ''} ${m['city'] ?? ''}',
            ),
          ),
        );
      }
    }
    return out;
  }

  Widget _buildShippingTab() {
    if (_loadingShipping) {
      return const Center(child: CircularProgressIndicator());
    }
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Text(
          'Moduły przewoźników (API-ready): cenniki, punkty odbioru i szybkie sugestie checkout.',
          style: Theme.of(context).textTheme.bodyMedium,
        ),
        const SizedBox(height: 12),
        FilledButton.tonal(
          onPressed: _loadShipping,
          child: const Text('Odśwież dane przewoźników'),
        ),
        const SizedBox(height: 16),
        Text('Dostępni przewoźnicy', style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 8),
        if (_shippingProviders.isEmpty)
          const Text('Brak danych')
        else
          ..._shippingProviders.map(
            (p) => Card(
              child: ListTile(
                title: Text('${p['name'] ?? p['code'] ?? 'Przewoźnik'}'),
                subtitle: Text(
                  'Code: ${p['code'] ?? '-'} · '
                  'Punkty: ${p['supportsMapPoints'] == true ? 'tak' : 'nie'} · '
                  'Paczkomat: ${p['supportsParcelLocker'] == true ? 'tak' : 'nie'} · '
                  'API: ${p['apiConfigured'] == true ? 'skonfigurowane' : 'symulacja / offline'}',
                ),
              ),
            ),
          ),
        const SizedBox(height: 16),
        Text(
          'Sugestie punktów (live-first: InPost z sieci; DPD/DHL/Poczta po podaniu URL + klucza w .env)',
          style: Theme.of(context).textTheme.titleMedium,
        ),
        const SizedBox(height: 8),
        if (_shippingSuggest == null)
          const Text('Brak danych')
        else
          ..._buildShippingSuggestSections(_shippingSuggest!),
      ],
    );
  }

  Widget _buildCustomerCard(StaffCustomerProfile c) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              c.email ?? '—',
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
            ),
            const SizedBox(height: 8),
            Text('UUID: ${c.userId}', style: Theme.of(context).textTheme.bodySmall),
            const SizedBox(height: 16),
            Text(
              'Ranga: ${c.rank}  ·  Punkty: ${c.points}',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 24),
            Text('Ranga', style: Theme.of(context).textTheme.titleSmall),
            const SizedBox(height: 12),
            SizedBox(
              height: 56,
              child: FilledButton(
                onPressed: c.rank == 'VINTAGE' ? null : _setVintage,
                style: FilledButton.styleFrom(
                  textStyle: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                child: const Text('USTAW VINTAGE'),
              ),
            ),
            const SizedBox(height: 28),
            Text('Punkty', style: Theme.of(context).textTheme.titleSmall),
            const SizedBox(height: 12),
            Wrap(
              spacing: 12,
              runSpacing: 12,
              children: [
                _bigPointButton(10),
                _bigPointButton(50),
                _bigPointButton(100),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _bigPointButton(int n) {
    return SizedBox(
      width: kIsWeb ? 140 : 120,
      height: 64,
      child: FilledButton.tonal(
        onPressed: () => _addPoints(n),
        style: FilledButton.styleFrom(
          textStyle: const TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.w700,
          ),
        ),
        child: Text('+$n'),
      ),
    );
  }

  Widget _bodyForMenu(_MenuId id, String? role) {
    switch (id) {
      case _MenuId.stats:
        return _buildPlaceholder(
          'Statystyki',
          'Przykładowe menu — podłącz źródła danych i wykresy.',
        );
      case _MenuId.finance:
        return _buildPlaceholder(
          'Finanse',
          'Przykładowe menu — rozliczenia i raporty.',
        );
      case _MenuId.aiAgents:
        return _buildPlaceholder(
          'Agenci AI',
          'Przykładowe menu — konfiguracja agentów.',
        );
      case _MenuId.employees:
        return _buildPlaceholder(
          'Pracownicy',
          'Przykładowe menu — lista i uprawnienia STAFF.',
        );
      case _MenuId.reservations:
        return _buildQueueTab();
      case _MenuId.orders:
        return _buildOrdersTab();
      case _MenuId.shipping:
        return _buildShippingTab();
      case _MenuId.permissions:
        return _buildPermissionsTab();
      case _MenuId.dotykackaDev:
        return _buildDotykackaDevTab();
      case _MenuId.scanner:
        final owner = role == 'OWNER';
        return _buildScannerTab(showFullCustomerCard: owner);
      case _MenuId.loyalty:
        return _buildLoyaltyTab();
    }
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthSession>();
    final menu = _menuForRole(auth);
    if (menu.isEmpty) {
      const empty = Scaffold(
        body: Center(child: Text('Brak uprawnień panelu.')),
      );
      return widget.presentation == AdminDashboardPresentation.fullscreen
          ? const WebAppFrame(child: empty)
          : empty;
    }
    if (_railIndex >= menu.length) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) setState(() => _railIndex = 0);
      });
    }
    final safeIndex =
        _railIndex < 0 ? 0 : (_railIndex >= menu.length ? menu.length - 1 : _railIndex);
    final current = menu[safeIndex];

    // WWW: pełne etykiety w NavigationRail potrafią wywołać niestabilny układ tekstu
    // w silniku (stack z KV/WY/RenderParagraph). Ikony + tooltip wystarczą.
    final railLabelType = kIsWeb
        ? NavigationRailLabelType.none
        : (widget.presentation == AdminDashboardPresentation.overlaySidebar
            ? NavigationRailLabelType.selected
            : NavigationRailLabelType.all);

    final rail = NavigationRail(
      selectedIndex: safeIndex,
      labelType: railLabelType,
      minWidth: widget.presentation == AdminDashboardPresentation.overlaySidebar ? 56 : 72,
      onDestinationSelected: (i) {
        setState(() => _railIndex = i);
        _refreshCurrentSectionIfNeeded(force: true);
      },
      destinations: [
        for (var i = 0; i < menu.length; i++)
          NavigationRailDestination(
            icon: Icon(_icon(menu[i], selected: false)),
            selectedIcon: Icon(_icon(menu[i], selected: true)),
            label: Text(
              _label(menu[i]),
              overflow: TextOverflow.ellipsis,
            ),
          ),
      ],
    );

    final title = widget.presentation == AdminDashboardPresentation.overlaySidebar
        ? 'Panel'
        : (auth.isOwner ? 'Panel — właściciel' : 'Panel — pracownik');

    final mainPanel = Row(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        rail,
        const VerticalDivider(width: 1),
        Expanded(
          child: Column(
            children: [
              Material(
                color: const Color(0xFFF8F8F8),
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Text(
                        'API: ${auth.apiBase}',
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              color: const Color(0xFF6B6B6B),
                            ),
                      ),
                      if (current == _MenuId.reservations) ...[
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            FilledButton.tonal(
                              onPressed: _loadQueue,
                              child: const Text('Odśwież kolejkę'),
                            ),
                            const SizedBox(width: 12),
                            if (_error != null)
                              Expanded(
                                child: Text(
                                  _error!,
                                  style: const TextStyle(color: Colors.red),
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                          ],
                        ),
                      ],
                      if (current == _MenuId.orders) ...[
                        const SizedBox(height: 8),
                        FilledButton.tonal(
                          onPressed: _loadOrders,
                          child: const Text('Odśwież zamówienia'),
                        ),
                      ],
                      if (current == _MenuId.permissions) ...[
                        const SizedBox(height: 8),
                        FilledButton.tonal(
                          onPressed: _loadPermissions,
                          child: const Text('Odśwież uprawnienia'),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
              Expanded(child: _bodyForMenu(current, auth.role)),
            ],
          ),
        ),
      ],
    );

    final scaffold = Scaffold(
      appBar: AppBar(
        title: Text(title),
        leading: widget.presentation == AdminDashboardPresentation.overlaySidebar
            ? IconButton(
                tooltip: 'Zamknij overlay',
                icon: const Icon(Icons.close),
                onPressed: () => closeStaffSidebarOverlay(),
              )
            : null,
        actions: [
          if (widget.presentation == AdminDashboardPresentation.fullscreen &&
              !kIsWeb &&
              defaultTargetPlatform == TargetPlatform.android)
            IconButton(
              tooltip: 'Panel pływający (overlay)',
              icon: const Icon(Icons.view_sidebar_outlined),
              onPressed: () async {
                await openStaffSidebarOverlay();
                if (!context.mounted) return;
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Uruchomiono overlay — drugi silnik Flutter.'),
                  ),
                );
              },
            ),
          if (widget.presentation != AdminDashboardPresentation.overlaySidebar)
            IconButton(
              tooltip: 'Sklep',
              icon: const Icon(Icons.storefront_outlined),
              onPressed: () => context.read<AppNavigation>().openShop(),
            ),
          IconButton(
            tooltip: 'Moje konto',
            icon: const Icon(Icons.account_circle_outlined),
            onPressed: () {
              Navigator.of(context).push(
                MaterialPageRoute<void>(
                  builder: (_) => Scaffold(
                    appBar: AppBar(title: const Text('Moje konto')),
                    body: const UserAccountScreen(),
                  ),
                ),
              );
            },
          ),
          Padding(
            padding: const EdgeInsets.only(right: 8),
            child: Center(
              child: Text(
                AppConfig.shouldUseSupabaseClient
                    ? (Supabase.instance.client.auth.currentUser?.email ??
                        auth.profileEmail ??
                        '')
                    : (auth.profileEmail ?? ''),
                style: Theme.of(context).textTheme.bodySmall,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ),
          IconButton(
            tooltip: 'Wyloguj',
            icon: const Icon(Icons.logout),
            onPressed: () async {
              final sess = context.read<AuthSession>();
              if (AppConfig.shouldUseSupabaseClient) {
                await Supabase.instance.client.auth.signOut();
              }
              if (!context.mounted) return;
              await sess.setAccessToken(null);
            },
          ),
        ],
      ),
      // WWW: [Stack] z jednym [Row] potrafi dać dziecku luźne maxHeight → ∞ i wywalić
      // wewnętrzny Column+Expanded (Uncaught Error w JS). Bez Stacku jest OK.
      // Mobile/overlay: Stack + Positioned.fill żeby Row miał pełną wysokość + warstwa HID.
      body: kIsWeb
          ? mainPanel
          : Stack(
              fit: StackFit.expand,
              children: [
                Positioned.fill(child: mainPanel),
                HidQrScannerLayer(
                  focusNode: _scanFocus,
                  controller: _scanController,
                  onSubmitted: _openCustomer,
                ),
              ],
            ),
    );

    if (widget.presentation == AdminDashboardPresentation.fullscreen) {
      return WebAppFrame(child: scaffold);
    }
    return Material(
      color: Colors.white,
      child: scaffold,
    );
  }
}
