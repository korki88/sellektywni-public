import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../config/app_config.dart';
import '../config/dev_mock_accounts.dart';
import '../data/product_details.dart';
import '../config/shop_catalog.dart';
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
  cms,
  supportDesk,
  experiments,
  giftCards,
  reviews,
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
  List<Map<String, dynamic>> _returnRequests = [];
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
  Map<String, dynamic>? _analyticsSummary;
  List<Map<String, dynamic>> _lowStockRows = [];
  bool _loadingAnalytics = false;
  String? _analyticsError;
  String? _orderStatusFilter;
  List<Map<String, dynamic>> _cmsPagesStaff = [];
  bool _loadingCmsStaff = false;
  List<Map<String, dynamic>> _supportTicketsStaff = [];
  bool _loadingSupportStaff = false;
  List<Map<String, dynamic>> _experimentsStaff = [];
  bool _loadingExperimentsStaff = false;
  List<Map<String, dynamic>> _giftCardsStaff = [];
  bool _loadingGiftCardsStaff = false;
  List<Map<String, dynamic>> _reviewRows = [];
  bool _loadingReviews = false;

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
    if (auth.hasPermission('manage.cms')) {
      menu.add(_MenuId.cms);
    }
    if (auth.hasPermission('manage.support')) {
      menu.add(_MenuId.supportDesk);
    }
    if (auth.hasPermission('manage.experiments')) {
      menu.add(_MenuId.experiments);
    }
    if (auth.hasPermission('manage.gift_cards')) {
      menu.add(_MenuId.giftCards);
    }
    if (auth.hasPermission('manage.reviews')) {
      menu.add(_MenuId.reviews);
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
      case _MenuId.cms:
        return 'CMS';
      case _MenuId.supportDesk:
        return 'Zgłoszenia';
      case _MenuId.experiments:
        return 'A/B';
      case _MenuId.giftCards:
        return 'Karty';
      case _MenuId.reviews:
        return 'Opinie';
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
      case _MenuId.cms:
        return selected ? Icons.article : Icons.article_outlined;
      case _MenuId.supportDesk:
        return selected ? Icons.support_agent : Icons.support_agent_outlined;
      case _MenuId.experiments:
        return selected ? Icons.science : Icons.science_outlined;
      case _MenuId.giftCards:
        return selected ? Icons.redeem : Icons.redeem_outlined;
      case _MenuId.reviews:
        return selected ? Icons.rate_review : Icons.rate_review_outlined;
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
      case _MenuId.stats:
        _loadAnalytics();
      case _MenuId.cms:
        _loadCmsStaff();
      case _MenuId.supportDesk:
        _loadSupportStaff();
      case _MenuId.experiments:
        _loadExperimentsStaff();
      case _MenuId.giftCards:
        _loadGiftCardsStaff();
      case _MenuId.reviews:
        _loadReviews();
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

  Future<void> _loadAnalytics() async {
    final auth = context.read<AuthSession>();
    if (!auth.hasToken) {
      setState(() => _analyticsError = 'Brak tokenu.');
      return;
    }
    if (!auth.hasPermission('view.analytics')) {
      setState(() => _analyticsError = 'Brak uprawnienia view.analytics.');
      return;
    }
    setState(() {
      _loadingAnalytics = true;
      _analyticsError = null;
    });
    try {
      final summary = await _api.fetchAnalyticsSummary();
      var low = <Map<String, dynamic>>[];
      if (auth.hasPermission('manage.orders')) {
        low = await _api.fetchLowStock(threshold: 3);
      }
      if (!mounted) return;
      setState(() {
        _analyticsSummary = summary;
        _lowStockRows = low;
        _loadingAnalytics = false;
      });
    } on StaffApiException catch (e) {
      if (!mounted) return;
      setState(() {
        _loadingAnalytics = false;
        _analyticsError = e.toString();
      });
    }
  }

  Future<void> _loadOrders() async {
    setState(() {
      _loadingOrders = true;
      _error = null;
    });
    try {
      final rows = await _api.fetchOrders(status: _orderStatusFilter);
      var returns = <Map<String, dynamic>>[];
      try {
        returns = await _api.fetchReturnRequests();
      } on StaffApiException {
        returns = [];
      }
      if (!mounted) return;
      setState(() {
        _orders = rows;
        _returnRequests = returns;
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

  Future<void> _loadCmsStaff() async {
    final auth = context.read<AuthSession>();
    if (!auth.hasPermission('manage.cms')) return;
    setState(() {
      _loadingCmsStaff = true;
      _error = null;
    });
    try {
      final rows = await _api.fetchCmsPagesStaff();
      if (!mounted) return;
      setState(() {
        _cmsPagesStaff = rows;
        _loadingCmsStaff = false;
      });
    } on StaffApiException catch (e) {
      if (!mounted) return;
      setState(() {
        _loadingCmsStaff = false;
        _error = e.toString();
      });
    }
  }

  Future<void> _loadSupportStaff() async {
    final auth = context.read<AuthSession>();
    if (!auth.hasPermission('manage.support')) return;
    setState(() {
      _loadingSupportStaff = true;
      _error = null;
    });
    try {
      final rows = await _api.fetchSupportTicketsStaff();
      if (!mounted) return;
      setState(() {
        _supportTicketsStaff = rows;
        _loadingSupportStaff = false;
      });
    } on StaffApiException catch (e) {
      if (!mounted) return;
      setState(() {
        _loadingSupportStaff = false;
        _error = e.toString();
      });
    }
  }

  Future<void> _loadExperimentsStaff() async {
    final auth = context.read<AuthSession>();
    if (!auth.hasPermission('manage.experiments')) return;
    setState(() {
      _loadingExperimentsStaff = true;
      _error = null;
    });
    try {
      final rows = await _api.fetchExperimentsStaff();
      if (!mounted) return;
      setState(() {
        _experimentsStaff = rows;
        _loadingExperimentsStaff = false;
      });
    } on StaffApiException catch (e) {
      if (!mounted) return;
      setState(() {
        _loadingExperimentsStaff = false;
        _error = e.toString();
      });
    }
  }

  Future<void> _loadGiftCardsStaff() async {
    final auth = context.read<AuthSession>();
    if (!auth.hasPermission('manage.gift_cards')) return;
    setState(() {
      _loadingGiftCardsStaff = true;
      _error = null;
    });
    try {
      final rows = await _api.fetchGiftCardsStaff();
      if (!mounted) return;
      setState(() {
        _giftCardsStaff = rows;
        _loadingGiftCardsStaff = false;
      });
    } on StaffApiException catch (e) {
      if (!mounted) return;
      setState(() {
        _loadingGiftCardsStaff = false;
        _error = e.toString();
      });
    }
  }

  Future<void> _loadReviews() async {
    final auth = context.read<AuthSession>();
    if (!auth.hasPermission('manage.reviews')) return;
    setState(() {
      _loadingReviews = true;
      _error = null;
    });
    try {
      final rows = await _api.fetchReviewsModeration();
      if (!mounted) return;
      setState(() {
        _reviewRows = rows;
        _loadingReviews = false;
      });
    } on StaffApiException catch (e) {
      if (!mounted) return;
      setState(() {
        _loadingReviews = false;
        _error = e.toString();
      });
    }
  }

  Future<void> _showMerchandisingDialog(StaffProduct p) async {
    final auth = context.read<AuthSession>();
    if (!auth.hasPermission('manage.catalog')) return;
    final subCtrl = TextEditingController(text: p.subtitle ?? '');
    var feat = p.isFeatured;
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setLocal) => AlertDialog(
          title: Text('Witryna: ${p.name}'),
          content: SizedBox(
            width: 420,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Pokaż w „Polecane” na stronie głównej'),
                  value: feat,
                  onChanged: (v) => setLocal(() => feat = v),
                ),
                TextField(
                  controller: subCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Podtytuł na kafelku (opcjonalnie)',
                    border: OutlineInputBorder(),
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Anuluj')),
            FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Zapisz')),
          ],
        ),
      ),
    );
    final trimmed = subCtrl.text.trim();
    subCtrl.dispose();
    if (ok != true || !mounted) return;
    try {
      await _api.patchProductMerchandising(
        p.id,
        isFeatured: feat,
        subtitle: trimmed.isEmpty ? null : trimmed,
      );
      await _loadQueue();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Zapisano ustawienia witryny.')),
      );
    } on StaffApiException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString())));
    }
  }

  Future<void> _showOrderStaffNotesDialog(StaffOrder o) async {
    final auth = context.read<AuthSession>();
    if (!auth.hasPermission('manage.orders')) return;
    Map<String, dynamic>? detail;
    try {
      detail = await _api.fetchOrderDetail(o.id);
    } on StaffApiException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString())));
      return;
    }
    if (!mounted) return;
    final noteCtrl = TextEditingController();
    await showDialog<void>(
      context: context,
      builder: (ctx) {
        final notesRaw = detail?['staffNotes'];
        final staffNotes = notesRaw is List
            ? notesRaw.whereType<Map<String, dynamic>>().toList()
            : <Map<String, dynamic>>[];
        final cn = detail?['customerNote']?.toString();
        return AlertDialog(
          title: Text('Zamówienie ${o.id.length > 8 ? '${o.id.substring(0, 8)}…' : o.id}'),
          content: SizedBox(
            width: 520,
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (cn != null && cn.trim().isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: Text(
                        'Uwagi klienta:\n$cn',
                        style: Theme.of(ctx).textTheme.bodyMedium,
                      ),
                    ),
                  Text('Notatki zespołu', style: Theme.of(ctx).textTheme.titleSmall),
                  const SizedBox(height: 8),
                  if (staffNotes.isEmpty)
                    Text(
                      'Brak notatek.',
                      style: Theme.of(ctx).textTheme.bodySmall?.copyWith(
                            color: const Color(0xFF6B6B6B),
                          ),
                    )
                  else
                    ...staffNotes.map(
                      (n) => Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: Text(
                          '${n['authorEmail'] ?? n['authorUserId'] ?? '—'}: ${n['body']}',
                          style: Theme.of(ctx).textTheme.bodySmall,
                        ),
                      ),
                    ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: noteCtrl,
                    maxLines: 3,
                    decoration: const InputDecoration(
                      labelText: 'Nowa notatka (tylko personel)',
                      border: OutlineInputBorder(),
                    ),
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Zamknij')),
            FilledButton(
              onPressed: () async {
                final t = noteCtrl.text.trim();
                if (t.isEmpty) return;
                try {
                  await _api.postStaffOrderNote(o.id, t);
                  if (!ctx.mounted) return;
                  Navigator.pop(ctx);
                  await _loadOrders();
                } on StaffApiException catch (e) {
                  if (!ctx.mounted) return;
                  ScaffoldMessenger.of(ctx).showSnackBar(SnackBar(content: Text(e.toString())));
                }
              },
              child: const Text('Dodaj notatkę'),
            ),
          ],
        );
      },
    );
    noteCtrl.dispose();
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

  bool _devIntegrationSimulation(BuildContext context) {
    final t = context.read<AuthSession>().accessToken ?? '';
    return AppConfig.useDevMockAuth || t.startsWith(kDevMockTokenPrefix);
  }

  Widget _buildStatsPanel() {
    final sim = _devIntegrationSimulation(context);
    if (_loadingAnalytics) {
      return const Center(child: CircularProgressIndicator());
    }
    final s = _analyticsSummary;
    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        Text(
          'Pulpit analityczny',
          style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 8),
        Text(
          sim
              ? 'Tryb deweloperski — dane z lokalnej bazy (API /staff/analytics/summary).'
              : 'Dane na żywo z bazy: zamówienia, płatności, produkty, klienci.',
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: const Color(0xFF6B6B6B)),
        ),
        if (s == null) ...[
          const SizedBox(height: 16),
          Text(
            'Naciśnij „Odśwież dane” powyżej (wymaga uprawnienia view.analytics).',
            style: Theme.of(context).textTheme.bodyMedium,
          ),
        ] else ...[
          const SizedBox(height: 16),
          Text(
            'Wygenerowano: ${s['generatedAt'] ?? '—'}',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(color: const Color(0xFF6B6B6B)),
          ),
          const SizedBox(height: 12),
          _statRow(context, 'Przychód (opłacone zamówienia)', '${s['paidRevenueTotal'] ?? '0'} zł'),
          _statRow(context, 'Liczba opłaconych zamówień', '${s['paidOrdersCount'] ?? 0}'),
          _statRow(context, 'Oczekujące płatności', '${s['pendingPaymentCount'] ?? 0}'),
          _statRow(context, 'Klienci (profil CUSTOMER)', '${s['customersCount'] ?? 0}'),
          if (s['products'] is Map) ...[
            _statRow(
              context,
              'Produkty (wszystkie / dostępne)',
              '${(s['products'] as Map)['total'] ?? 0} / ${(s['products'] as Map)['available'] ?? 0}',
            ),
            _statRow(
              context,
              'Niski stan (≤${(s['products'] as Map)['lowStockThreshold'] ?? 3} szt.)',
              '${(s['products'] as Map)['lowStockCount'] ?? 0}',
            ),
          ],
          const SizedBox(height: 16),
          Text(
            'Zamówienia wg statusu',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 8),
          ...(s['ordersByStatus'] is Map
              ? (s['ordersByStatus'] as Map).entries.map(
                    (e) => Padding(
                      padding: const EdgeInsets.only(bottom: 4),
                      child: Text('${e.key}: ${e.value}'),
                    ),
                  )
              : const <Widget>[]),
          const SizedBox(height: 16),
          Text(
            'Przychód wg metody płatności (opłacone)',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 8),
          ...(s['revenueByPaymentMethod'] as List<dynamic>? ?? const [])
              .map<Widget>((row) {
                if (row is! Map) return const SizedBox.shrink();
                final pm = row['paymentMethod']?.toString() ?? '';
                final tot = row['total']?.toString() ?? '0';
                return Padding(
                  padding: const EdgeInsets.only(bottom: 4),
                  child: Text('$pm: $tot zł'),
                );
              }),
          const SizedBox(height: 16),
          Text(
            'Rezerwacje wg statusu',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 8),
          ...(s['reservationsByStatus'] is Map
              ? (s['reservationsByStatus'] as Map).entries.map(
                    (e) => Padding(
                      padding: const EdgeInsets.only(bottom: 4),
                      child: Text('${e.key}: ${e.value}'),
                    ),
                  )
              : const <Widget>[]),
        ],
        if (_lowStockRows.isNotEmpty) ...[
          const SizedBox(height: 20),
          Text(
            'Produkty z niskim stanem',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 8),
          ..._lowStockRows.map(
            (r) => Card(
              child: ListTile(
                title: Text(r['name']?.toString() ?? ''),
                subtitle: Text('Stan: ${r['stockQty']} · Dotykačka: ${r['idDotykacka'] ?? '—'}'),
              ),
            ),
          ),
        ],
        const SizedBox(height: 20),
        _infoCard(
          context,
          icon: Icons.local_shipping_outlined,
          title: 'Wysyłka (API)',
          lines: const [
            'Przewoźnicy: GET /shipping/providers.',
            'Szacunek: GET /shipping/estimate.',
          ],
        ),
      ],
    );
  }

  Widget _statRow(BuildContext context, String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            flex: 2,
            child: Text(label, style: Theme.of(context).textTheme.bodyMedium),
          ),
          Expanded(
            child: Text(
              value,
              textAlign: TextAlign.end,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFinancePanel() {
    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        Text(
          'Płatności (backend)',
          style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 8),
        Text(
          'Obsługiwane metody zgodnie z enum PaymentMethod i PaymentsService:',
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: const Color(0xFF6B6B6B)),
        ),
        const SizedBox(height: 16),
        ...kSupportedPaymentMethodCodes.map((code) {
          final IconData icon;
          final String sub;
          switch (code) {
            case 'BLIK':
              icon = Icons.flash_on_outlined;
              sub =
                  'Przelewy24 — sandbox lub rejestracja trnRegister przy ustawionych P24_* w .env.';
            case 'CARD_ONLINE':
              icon = Icons.credit_card_outlined;
              sub =
                  'Przelewy24 — sandbox lub rejestracja trnRegister przy ustawionych P24_* w .env.';
            case 'BANK_TRANSFER':
              icon = Icons.account_balance_outlined;
              sub = 'Mock konta (dev) lub ręczna weryfikacja przelewu.';
            case 'CASH_ON_DELIVERY':
              icon = Icons.payments_outlined;
              sub = 'Pobranie — status COD_PENDING do momentu odbioru.';
            default:
              icon = Icons.payments_outlined;
              sub = '';
          }
          return Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: Card(
              child: ListTile(
                leading: Icon(icon),
                title: Text(paymentMethodLabelPl(code)),
                subtitle: Text(sub, style: const TextStyle(fontSize: 13)),
              ),
            ),
          );
        }),
        const SizedBox(height: 8),
        Text(
          'Symulacja: bez P24 w .env zwracany jest link sandbox-simulation; przelew = BANK_TRANSFER_MOCK.',
          style: Theme.of(context).textTheme.bodySmall?.copyWith(color: const Color(0xFF6B6B6B)),
        ),
      ],
    );
  }

  Widget _buildAiAgentsPanel() {
    final sim = _devIntegrationSimulation(context);
    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        Text(
          'Agenci AI',
          style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 12),
        _infoCard(
          context,
          icon: Icons.smart_toy_outlined,
          title: 'Status integracji',
          lines: [
            if (sim)
              'Tryb deweloperski: brak połączenia z zewnętrznym modelem — żadne dane zamówień nie są wysyłane poza API sklepu.'
            else
              'Konfiguracja agentów (np. asystent obsługi, podsumowania zamówień) nie jest jeszcze ujęta w tym repozytorium.',
            'Docelowo: bezpieczny kanał tylko po stronie serwera (sekrety w .env, nie w aplikacji mobilnej).',
          ],
        ),
      ],
    );
  }

  Widget _buildEmployeesPanel() {
    final auth = context.read<AuthSession>();
    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        Text(
          'Zespół i role',
          style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 12),
        _infoCard(
          context,
          icon: Icons.badge_outlined,
          title: 'Role w sklepie',
          lines: const [
            'OWNER — pełny dostęp: analityka, finanse, uprawnienia STAFF, promocje (API staff).',
            'STAFF — domyślnie: rezerwacje, zamówienia, klienci, Dotykačka dev, wysyłka, CMS, zgłoszenia. '
            'OWNER może nadać też A/B, karty podarunkowe i inne uprawnienia (zakładka Uprawnienia).',
            'CUSTOMER — sklep, konto, zamówienia własne (bez panelu staff).',
          ],
        ),
        const SizedBox(height: 12),
        if (auth.isOwner)
          const Card(
            color: Color(0xFFE8F0FE),
            child: ListTile(
              leading: Icon(Icons.admin_panel_settings_outlined),
              title: Text('Uprawnienia STAFF'),
              subtitle: Text(
                'Edytuj zakładkę „Uprawnienia” w tym panelu — lista permissions z /staff/permissions/users.',
              ),
            ),
          ),
      ],
    );
  }

  Widget _infoCard(
    BuildContext context, {
    required IconData icon,
    required String title,
    required List<String> lines,
  }) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, size: 28, color: Theme.of(context).colorScheme.primary),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700)),
                  const SizedBox(height: 8),
                  ...lines.map(
                    (l) => Padding(
                      padding: const EdgeInsets.only(bottom: 6),
                      child: Text(l, style: Theme.of(context).textTheme.bodyMedium),
                    ),
                  ),
                ],
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
        final auth = context.read<AuthSession>();
        final canMerch = auth.hasPermission('manage.catalog');
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
                if (p.subtitle != null && p.subtitle!.trim().isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Text(
                    p.subtitle!,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: const Color(0xFF6B6B6B),
                        ),
                  ),
                ],
                if (p.isFeatured) ...[
                  const SizedBox(height: 6),
                  Text(
                    '· Oznaczone jako „Polecane”',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          fontWeight: FontWeight.w600,
                          color: const Color(0xFF795548),
                        ),
                  ),
                ],
                const SizedBox(height: 12),
                if (canMerch) ...[
                  Align(
                    alignment: Alignment.centerLeft,
                    child: OutlinedButton.icon(
                      onPressed: () => _showMerchandisingDialog(p),
                      icon: const Icon(Icons.storefront_outlined, size: 18),
                      label: const Text('Merchandising (witryna)'),
                    ),
                  ),
                  const SizedBox(height: 12),
                ],
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

  void _showDotykackaReceiptDialog(StaffOrder o) {
    final sim = _devIntegrationSimulation(context);
    final buf = StringBuffer()
      ..writeln('SELLEKTYWNI — podgląd paragonu')
      ..writeln('Zamówienie: ${o.id}')
      ..writeln('Data: ${o.createdAt}')
      ..writeln('─────────────────────');
    for (final i in o.items) {
      buf.writeln('${i.name}  ${i.quantity}×  ${i.lineTotalRaw} zł');
    }
    buf
      ..writeln('─────────────────────')
      ..writeln('SUMA: ${o.totalAmountRaw} zł')
      ..writeln('Płatność: ${paymentMethodLabelPl(o.paymentMethod)} / ${paymentStatusLabelPl(o.paymentStatus)}')
      ..writeln()
      ..writeln(
        sim
            ? '[DEV] Symulacja wydruku z kasy powiązanej z Dotykačką — brak połączenia z drukarką fizyczną.'
            : 'Produkcja: druk z terminala / oprogramowania zgodnego z Dotykačka (API v2, CLOUD_ID w .env).',
      );
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.receipt_long_outlined),
            SizedBox(width: 8),
            Expanded(child: Text('Paragon / Dotykačka')),
          ],
        ),
        content: SingleChildScrollView(child: SelectableText(buf.toString())),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Zamknij')),
        ],
      ),
    );
  }

  void _showCourierLabelDialog(StaffOrder o) {
    final sim = _devIntegrationSimulation(context);
    final needLabel = expectsCourierOrLockerLabel(o.shippingMethod);
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.label_outline),
            SizedBox(width: 8),
            Expanded(child: Text('Etykieta kurierska')),
          ],
        ),
        content: SingleChildScrollView(
          child: Text(
            needLabel
                ? 'Wysyłka: ${shippingMethodLabelPl(o.shippingMethod)}\n'
                    'Ref / session: ${o.paymentReference ?? o.id}\n\n'
                    '${sim ? "[DEV] Symulacja etykiety — w produkcji generuj etykietę przez API przewoźnika (InPost ShipX, DPD, DHL, ORLEN SOAP itd.) według shipping_snapshot zamówienia." : "Skonfiguruj integrację przewoźnika i druk etykiety z panelu kurierskiego lub API."}'
                : 'Odbiór osobisty w salonie — etykieta kurierska nie jest wymagana. Wystarczy paragon / potwierdzenie wydania.',
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Zamknij')),
        ],
      ),
    );
  }

  Widget _buildOrdersTab() {
    final sim = _devIntegrationSimulation(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (_returnRequests.isNotEmpty)
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Wnioski o zwrot (RMA)',
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                ),
                const SizedBox(height: 8),
                ..._returnRequests.map((r) {
                  final id = r['id']?.toString() ?? '';
                  final st = r['status']?.toString() ?? '';
                  final reason = r['reason']?.toString() ?? '';
                  final order = r['order'] as Map<String, dynamic>?;
                  final oid = order?['id']?.toString() ?? '';
                  return Card(
                    margin: const EdgeInsets.only(bottom: 8),
                    child: ListTile(
                      title: Text('Zamówienie $oid · $st'),
                      subtitle: Text(reason),
                      isThreeLine: true,
                      trailing: PopupMenuButton<String>(
                        onSelected: (v) async {
                          try {
                            await _api.patchReturnRequest(id, status: v);
                            await _loadOrders();
                            if (!mounted) return;
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(content: Text('Status zwrotu: $v')),
                            );
                          } on StaffApiException catch (e) {
                            if (!mounted) return;
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(content: Text(e.toString())),
                            );
                          }
                        },
                        itemBuilder: (_) => const [
                          PopupMenuItem(value: 'APPROVED', child: Text('Zatwierdź')),
                          PopupMenuItem(value: 'REJECTED', child: Text('Odrzuć')),
                          PopupMenuItem(value: 'RECEIVED', child: Text('Przyjęto towar')),
                          PopupMenuItem(value: 'PENDING', child: Text('Oczekuje')),
                        ],
                      ),
                    ),
                  );
                }),
              ],
            ),
          ),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
          child: Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              FilterChip(
                label: const Text('Wszystkie'),
                selected: _orderStatusFilter == null,
                onSelected: (_) {
                  setState(() => _orderStatusFilter = null);
                  _loadOrders();
                },
              ),
              for (final code in const [
                'PLACED',
                'PROCESSING',
                'READY',
                'COMPLETED',
                'CANCELED',
              ])
                FilterChip(
                  label: Text(code),
                  selected: _orderStatusFilter == code,
                  onSelected: (_) {
                    setState(() => _orderStatusFilter = code);
                    _loadOrders();
                  },
                ),
            ],
          ),
        ),
        Expanded(
          child: _loadingOrders
              ? const Center(child: CircularProgressIndicator())
              : _orders.isEmpty
                  ? Center(
                      child: Text(
                        'Brak zamówień do obsługi (dla wybranego filtra).',
                        style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                              color: const Color(0xFF6B6B6B),
                            ),
                      ),
                    )
                  : ListView.separated(
      padding: const EdgeInsets.all(16),
      itemCount: _orders.length,
      separatorBuilder: (_, __) => const SizedBox(height: 10),
      itemBuilder: (context, i) {
        final o = _orders[i];
        final expanded = _expandedOrderIds.contains(o.id);
        final needCourier = expectsCourierOrLockerLabel(o.shippingMethod);
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
                    'Status zamówienia: ${orderStatusLabelPl(o.status)} (${o.status}) · '
                    '${o.itemCount} poz. · ${o.totalAmountRaw} zł',
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: const Color(0xFF6B6B6B),
                        ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Wysyłka: ${shippingMethodLabelPl(o.shippingMethod)}',
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: const Color(0xFF6B6B6B),
                        ),
                  ),
                  if (o.customerNote != null && o.customerNote!.trim().isNotEmpty) ...[
                    const SizedBox(height: 6),
                    Text(
                      'Uwagi klienta: ${o.customerNote}',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: const Color(0xFF3D4A5C),
                          ),
                    ),
                  ],
                  if (o.staffNotePreview != null && o.staffNotePreview!.trim().isNotEmpty) ...[
                    const SizedBox(height: 4),
                    Text(
                      'Ostatnia notatka: ${o.staffNotePreview}',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: const Color(0xFF6B6B6B),
                          ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                  const SizedBox(height: 4),
                  Text(
                    'Płatność: ${paymentMethodLabelPl(o.paymentMethod)} · '
                    '${paymentProviderLabelPl(o.paymentProvider)} · '
                    '${paymentStatusLabelPl(o.paymentStatus)}',
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
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF7F9FC),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: const Color(0xFFE0E6EF)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Checklist pakowania',
                          style: Theme.of(context).textTheme.titleSmall?.copyWith(
                                fontWeight: FontWeight.w700,
                              ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          '1. Paragon fiskalny — dane z systemu sprzedaży zsynchronizowanego z Dotykačką.',
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                        Text(
                          needCourier
                              ? '2. Etykieta kurierska — nadanie u wybranego przewoźnika (InPost / DPD / DHL / ORLEN / Poczta).'
                              : '2. Etykieta kurierska — nie dotyczy (odbiór w salonie).',
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                        if (sim) ...[
                          const SizedBox(height: 8),
                          Text(
                            'Tryb dev: druk i etykiety są symulowane (okna podglądu).',
                            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                  color: Theme.of(context).colorScheme.primary,
                                  fontWeight: FontWeight.w600,
                                ),
                          ),
                        ],
                        const SizedBox(height: 10),
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: [
                            OutlinedButton.icon(
                              onPressed: () => _showOrderStaffNotesDialog(o),
                              icon: const Icon(Icons.sticky_note_2_outlined, size: 18),
                              label: const Text('Notatki zespołu'),
                            ),
                            OutlinedButton.icon(
                              onPressed: () => _showDotykackaReceiptDialog(o),
                              icon: const Icon(Icons.receipt_long_outlined, size: 18),
                              label: Text(sim ? 'Symuluj paragon' : 'Podgląd paragonu'),
                            ),
                            OutlinedButton.icon(
                              onPressed: () => _showCourierLabelDialog(o),
                              icon: const Icon(Icons.local_post_office_outlined, size: 18),
                              label: Text(sim ? 'Symuluj etykietę' : 'Podgląd etykiety'),
                            ),
                          ],
                        ),
                      ],
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
    ),
        ),
      ],
    );
  }

  Future<void> _openCmsEditorDialog({Map<String, dynamic>? existing}) async {
    final slugCtrl = TextEditingController(text: existing?['slug']?.toString() ?? '');
    final titleCtrl = TextEditingController(text: existing?['title']?.toString() ?? '');
    final bodyCtrl = TextEditingController(text: existing?['bodyMarkdown']?.toString() ?? '');
    final seoTitleCtrl = TextEditingController(text: existing?['seoTitle']?.toString() ?? '');
    final seoDescCtrl = TextEditingController(text: existing?['seoDescription']?.toString() ?? '');
    var published = existing?['published'] == true;
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setLocal) => AlertDialog(
          title: Text(existing == null ? 'Nowa strona CMS' : 'Edycja strony CMS'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: slugCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Slug (URL)',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: titleCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Tytuł',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: bodyCtrl,
                  maxLines: 12,
                  decoration: const InputDecoration(
                    labelText: 'Treść (Markdown)',
                    alignLabelWithHint: true,
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 8),
                SwitchListTile(
                  title: const Text('Opublikowana'),
                  value: published,
                  onChanged: (v) => setLocal(() => published = v),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: seoTitleCtrl,
                  decoration: const InputDecoration(
                    labelText: 'SEO title (opcj.)',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: seoDescCtrl,
                  maxLines: 2,
                  decoration: const InputDecoration(
                    labelText: 'SEO description (opcj.)',
                    border: OutlineInputBorder(),
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Anuluj')),
            FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Zapisz')),
          ],
        ),
      ),
    );
    final slug = slugCtrl.text.trim();
    final title = titleCtrl.text.trim();
    final body = bodyCtrl.text.trim();
    final seoTitle = seoTitleCtrl.text.trim();
    final seoDesc = seoDescCtrl.text.trim();
    slugCtrl.dispose();
    titleCtrl.dispose();
    bodyCtrl.dispose();
    seoTitleCtrl.dispose();
    seoDescCtrl.dispose();
    if (ok != true || !mounted) return;
    if (slug.isEmpty || title.isEmpty || body.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Slug, tytuł i treść są wymagane.')),
      );
      return;
    }
    try {
      await _api.upsertCmsPage({
        'slug': slug,
        'title': title,
        'bodyMarkdown': body,
        'published': published,
        if (seoTitle.isNotEmpty) 'seoTitle': seoTitle,
        if (seoDesc.isNotEmpty) 'seoDescription': seoDesc,
      });
    } on StaffApiException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString())));
      return;
    }
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Zapisano stronę CMS.')),
    );
    await _loadCmsStaff();
  }

  Future<void> _openExperimentStaffDialog({Map<String, dynamic>? existing}) async {
    final keyCtrl = TextEditingController(text: existing?['key']?.toString() ?? '');
    final rawV = existing?['variants'];
    final initialV = rawV is List
        ? rawV.map((e) => e.toString()).join(', ')
        : 'control, variant_b';
    final varCtrl = TextEditingController(text: initialV);
    var active = existing?['active'] != false;
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setLocal) => AlertDialog(
          title: Text(existing == null ? 'Nowy eksperyment A/B' : 'Eksperyment A/B'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: keyCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Klucz (np. checkout_cta)',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 8),
                SwitchListTile(
                  title: const Text('Aktywny'),
                  value: active,
                  onChanged: (v) => setLocal(() => active = v),
                ),
                TextField(
                  controller: varCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Warianty (po przecinku)',
                    border: OutlineInputBorder(),
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Anuluj')),
            FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Zapisz')),
          ],
        ),
      ),
    );
    final key = keyCtrl.text.trim();
    final parts = varCtrl.text
        .split(',')
        .map((s) => s.trim())
        .where((s) => s.isNotEmpty)
        .toList();
    keyCtrl.dispose();
    varCtrl.dispose();
    if (ok != true || !mounted) return;
    if (key.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Podaj klucz eksperymentu.')),
      );
      return;
    }
    try {
      await _api.upsertExperimentStaff({
        'key': key,
        'active': active,
        'variants': parts,
      });
    } on StaffApiException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString())));
      return;
    }
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Zapisano eksperyment.')),
    );
    await _loadExperimentsStaff();
  }

  Future<void> _openGiftCardCreateDialog() async {
    final codeCtrl = TextEditingController();
    final amountCtrl = TextEditingController(text: '100');
    final expiryCtrl = TextEditingController();
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Nowa karta podarunkowa'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: codeCtrl,
                decoration: const InputDecoration(
                  labelText: 'Kod (puste = automatyczny)',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: amountCtrl,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                decoration: const InputDecoration(
                  labelText: 'Kwota (PLN)',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: expiryCtrl,
                decoration: const InputDecoration(
                  labelText: 'Wygasa (ISO, opcj.)',
                  border: OutlineInputBorder(),
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Anuluj')),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Utwórz')),
        ],
      ),
    );
    final amt = double.tryParse(amountCtrl.text.replaceAll(',', '.')) ?? 0;
    final code = codeCtrl.text.trim();
    final exp = expiryCtrl.text.trim();
    codeCtrl.dispose();
    amountCtrl.dispose();
    expiryCtrl.dispose();
    if (ok != true || !mounted) return;
    if (amt <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Podaj prawidłową kwotę.')),
      );
      return;
    }
    try {
      await _api.createGiftCardStaff({
        'initialAmount': amt,
        if (code.isNotEmpty) 'code': code,
        if (exp.isNotEmpty) 'expiresAtIso': exp,
      });
    } on StaffApiException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString())));
      return;
    }
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Utworzono kartę.')),
    );
    await _loadGiftCardsStaff();
  }

  Widget _buildCmsStaffTab() {
    if (_loadingCmsStaff) {
      return const Center(child: CircularProgressIndicator());
    }
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Text(
          'Treści widoczne w sklepie (regulamin, „O nas” itd.).',
          style: Theme.of(context).textTheme.bodySmall?.copyWith(color: const Color(0xFF6B6B6B)),
        ),
        const SizedBox(height: 12),
        Align(
          alignment: Alignment.centerLeft,
          child: FilledButton.tonal(
            onPressed: () => _openCmsEditorDialog(),
            child: const Text('Nowa strona'),
          ),
        ),
        const SizedBox(height: 16),
        if (_cmsPagesStaff.isEmpty)
          Text('Brak stron.', style: Theme.of(context).textTheme.bodyMedium)
        else
          ..._cmsPagesStaff.map((p) {
            final slug = p['slug']?.toString() ?? '';
            final title = p['title']?.toString() ?? slug;
            final pub = p['published'] == true;
            return Card(
              margin: const EdgeInsets.only(bottom: 8),
              child: ListTile(
                title: Text(title),
                subtitle: Text('$slug · ${pub ? "opublikowana" : "szkic"}'),
                trailing: const Icon(Icons.edit_outlined),
                onTap: () => _openCmsEditorDialog(existing: p),
              ),
            );
          }),
      ],
    );
  }

  Widget _buildSupportStaffTab() {
    if (_loadingSupportStaff) {
      return const Center(child: CircularProgressIndicator());
    }
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Text(
          'Zgłoszenia od klientów — odpowiedź ustawia status na „odpowiedziano”.',
          style: Theme.of(context).textTheme.bodySmall?.copyWith(color: const Color(0xFF6B6B6B)),
        ),
        const SizedBox(height: 12),
        if (_supportTicketsStaff.isEmpty)
          Text('Brak zgłoszeń.', style: Theme.of(context).textTheme.bodyMedium)
        else
          ..._supportTicketsStaff.map((t) {
            final id = t['id']?.toString() ?? '';
            final subj = t['subject']?.toString() ?? '';
            final st = t['status']?.toString() ?? '';
            return Card(
              margin: const EdgeInsets.only(bottom: 8),
              child: ListTile(
                title: Text(subj),
                subtitle: Text('Status: $st · $id'),
                trailing: const Icon(Icons.reply_outlined),
                onTap: () => _openSupportReplyDialog(id, subj),
              ),
            );
          }),
      ],
    );
  }

  Future<void> _openSupportReplyDialog(String ticketId, String subject) async {
    final detail = await _api.fetchSupportTicketDetail(ticketId);
    if (!mounted) return;
    final replyCtrl = TextEditingController();
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(subject),
        content: SizedBox(
          width: 480,
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              mainAxisSize: MainAxisSize.min,
              children: [
                if (detail != null && detail['messages'] is List) ...[
                  ...(detail['messages'] as List<dynamic>).map((m) {
                    if (m is! Map<String, dynamic>) return const SizedBox.shrink();
                    final body = m['body']?.toString() ?? '';
                    final staff = m['isStaff'] == true;
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: Align(
                        alignment: staff ? Alignment.centerRight : Alignment.centerLeft,
                        child: DecoratedBox(
                          decoration: BoxDecoration(
                            color: staff ? const Color(0xFFE3F2FD) : const Color(0xFFF5F5F5),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Padding(
                            padding: const EdgeInsets.all(8),
                            child: Text(body),
                          ),
                        ),
                      ),
                    );
                  }),
                ],
                const SizedBox(height: 8),
                TextField(
                  controller: replyCtrl,
                  maxLines: 4,
                  decoration: const InputDecoration(
                    labelText: 'Odpowiedź',
                    border: OutlineInputBorder(),
                  ),
                ),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Zamknij')),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Wyślij')),
        ],
      ),
    );
    final text = replyCtrl.text.trim();
    replyCtrl.dispose();
    if (ok != true || text.isEmpty || !mounted) return;
    try {
      await _api.postSupportStaffReply(ticketId, text);
    } on StaffApiException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString())));
      return;
    }
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Wysłano odpowiedź.')),
    );
    await _loadSupportStaff();
  }

  Widget _buildExperimentsStaffTab() {
    if (_loadingExperimentsStaff) {
      return const Center(child: CircularProgressIndicator());
    }
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Text(
          'Aktywne eksperymenty przydzielają wariant przy pierwszym wejściu użytkownika.',
          style: Theme.of(context).textTheme.bodySmall?.copyWith(color: const Color(0xFF6B6B6B)),
        ),
        const SizedBox(height: 12),
        Align(
          alignment: Alignment.centerLeft,
          child: FilledButton.tonal(
            onPressed: () => _openExperimentStaffDialog(),
            child: const Text('Dodaj / nadpisz eksperyment'),
          ),
        ),
        const SizedBox(height: 16),
        if (_experimentsStaff.isEmpty)
          Text('Brak rekordów.', style: Theme.of(context).textTheme.bodyMedium)
        else
          ..._experimentsStaff.map((e) {
            final key = e['key']?.toString() ?? '';
            final active = e['active'] == true;
            final rawV = e['variants'];
            final vLabel = rawV is List ? rawV.join(', ') : '$rawV';
            return Card(
              margin: const EdgeInsets.only(bottom: 8),
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            key,
                            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                  fontWeight: FontWeight.w600,
                                ),
                          ),
                        ),
                        Switch(
                          value: active,
                          onChanged: (v) async {
                            try {
                              await _api.patchExperimentActive(key, v);
                              await _loadExperimentsStaff();
                            } on StaffApiException catch (err) {
                              if (!mounted) return;
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(content: Text(err.toString())),
                              );
                            }
                          },
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text('Warianty: $vLabel', style: Theme.of(context).textTheme.bodySmall),
                    Align(
                      alignment: Alignment.centerRight,
                      child: TextButton.icon(
                        onPressed: () => _openExperimentStaffDialog(existing: e),
                        icon: const Icon(Icons.edit_outlined, size: 18),
                        label: const Text('Edytuj listę wariantów'),
                      ),
                    ),
                  ],
                ),
              ),
            );
          }),
      ],
    );
  }

  Widget _buildGiftCardsStaffTab() {
    if (_loadingGiftCardsStaff) {
      return const Center(child: CircularProgressIndicator());
    }
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Text(
          'Karty podarunkowe — saldo pomniejszane przy realizacji zamówienia.',
          style: Theme.of(context).textTheme.bodySmall?.copyWith(color: const Color(0xFF6B6B6B)),
        ),
        const SizedBox(height: 12),
        Align(
          alignment: Alignment.centerLeft,
          child: FilledButton.tonal(
            onPressed: _openGiftCardCreateDialog,
            child: const Text('Nowa karta'),
          ),
        ),
        const SizedBox(height: 16),
        if (_giftCardsStaff.isEmpty)
          Text('Brak kart.', style: Theme.of(context).textTheme.bodyMedium)
        else
          ..._giftCardsStaff.map((g) {
            final code = g['code']?.toString() ?? '';
            final bal = g['balanceAmount']?.toString() ?? '';
            final act = g['active'] == true;
            final id = g['id']?.toString() ?? '';
            return Card(
              margin: const EdgeInsets.only(bottom: 8),
              child: ListTile(
                title: Text(code),
                subtitle: Text('Saldo: $bal PLN'),
                trailing: Switch(
                  value: act,
                  onChanged: (v) async {
                    try {
                      await _api.patchGiftCardActive(id, v);
                      await _loadGiftCardsStaff();
                    } on StaffApiException catch (err) {
                      if (!mounted) return;
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text(err.toString())),
                      );
                    }
                  },
                ),
              ),
            );
          }),
      ],
    );
  }

  Widget _buildReviewsStaffTab() {
    if (_loadingReviews) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_reviewRows.isEmpty) {
      return Center(
        child: Text(
          'Brak opinii do wyświetlenia.',
          style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                color: const Color(0xFF6B6B6B),
              ),
        ),
      );
    }
    return ListView.separated(
      padding: const EdgeInsets.all(16),
      itemCount: _reviewRows.length,
      separatorBuilder: (_, __) => const SizedBox(height: 10),
      itemBuilder: (context, i) {
        final r = _reviewRows[i];
        final id = r['id']?.toString() ?? '';
        final prod = r['product'];
        final pname = prod is Map ? prod['name']?.toString() ?? '' : '';
        final comment = r['comment']?.toString() ?? '';
        final rating = (r['rating'] as num?)?.toInt() ?? 0;
        final visible = r['isVisible'] == true;
        return Card(
          child: ListTile(
            title: Text(pname.isEmpty ? 'Produkt' : pname),
            subtitle: Text(
              '${'★' * rating.clamp(0, 5).toInt()}  $comment',
              maxLines: 4,
              overflow: TextOverflow.ellipsis,
            ),
            trailing: Tooltip(
              message: 'Widoczna na stronie produktu',
              child: Switch(
                value: visible,
                onChanged: (v) async {
                  try {
                    await _api.patchReviewVisibility(id, v);
                    await _loadReviews();
                  } on StaffApiException catch (e) {
                    if (!context.mounted) return;
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text(e.toString())),
                    );
                  }
                },
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
      ['ORLEN_PACZKA', 'ORLEN Paczka'],
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
    final sim = _devIntegrationSimulation(context);
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: const Color(0xFFE8F4FD),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: const Color(0xFFB8D4EE)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Proces wysyłki (operacyjnie)',
                style: Theme.of(context).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 8),
              Text(
                '• Klient wybiera metodę w koszyku: kurier, paczkomat InPost lub odbiór w salonie.\n'
                '• Backend: GET /shipping/providers — dostępni przewoźnicy; GET /shipping/points/* — punkty; '
                'przy braku kluczy API zwracane są dane fallback / symulacja (dev).\n'
                '• Po opłaceniu zamówienia pakuj: najpierw paragon z kasy (Dotykačka), potem — jeśli wysyłka — etykieta kurierska.',
                style: Theme.of(context).textTheme.bodySmall,
              ),
              if (sim) ...[
                const SizedBox(height: 8),
                Text(
                  'Tryb deweloperski: brak rzeczywistych wywołań kurierskich przy braku konfiguracji — użyj zakładki „Dotykačka DEV” do stanów testowych.',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: Theme.of(context).colorScheme.primary,
                        fontWeight: FontWeight.w600,
                      ),
                ),
              ],
            ],
          ),
        ),
        const SizedBox(height: 16),
        Text(
          'Integracje kurierskie (API w backendzie): cennik, punkty odbioru, sugestie dla checkout.',
          style: Theme.of(context).textTheme.bodyMedium,
        ),
        const SizedBox(height: 8),
        ...kCourierIntegrationRows.map(
          (row) => Padding(
            padding: const EdgeInsets.only(bottom: 4),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('• '),
                Expanded(
                  child: Text(
                    '${row['name']} — kod ${row['code']}',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ),
              ],
            ),
          ),
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
        return _buildStatsPanel();
      case _MenuId.finance:
        return _buildFinancePanel();
      case _MenuId.aiAgents:
        return _buildAiAgentsPanel();
      case _MenuId.employees:
        return _buildEmployeesPanel();
      case _MenuId.reservations:
        return _buildQueueTab();
      case _MenuId.orders:
        return _buildOrdersTab();
      case _MenuId.shipping:
        return _buildShippingTab();
      case _MenuId.cms:
        return _buildCmsStaffTab();
      case _MenuId.supportDesk:
        return _buildSupportStaffTab();
      case _MenuId.experiments:
        return _buildExperimentsStaffTab();
      case _MenuId.giftCards:
        return _buildGiftCardsStaffTab();
      case _MenuId.reviews:
        return _buildReviewsStaffTab();
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
                      if (current == _MenuId.stats) ...[
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            FilledButton.tonal(
                              onPressed: _loadAnalytics,
                              child: const Text('Odśwież dane'),
                            ),
                            if (_analyticsError != null)
                              Expanded(
                                child: Padding(
                                  padding: const EdgeInsets.only(left: 12),
                                  child: Text(
                                    _analyticsError!,
                                    style: const TextStyle(color: Colors.red),
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              ),
                          ],
                        ),
                      ],
                      if (current == _MenuId.cms) ...[
                        const SizedBox(height: 8),
                        FilledButton.tonal(
                          onPressed: _loadCmsStaff,
                          child: const Text('Odśwież CMS'),
                        ),
                      ],
                      if (current == _MenuId.supportDesk) ...[
                        const SizedBox(height: 8),
                        FilledButton.tonal(
                          onPressed: _loadSupportStaff,
                          child: const Text('Odśwież zgłoszenia'),
                        ),
                      ],
                      if (current == _MenuId.experiments) ...[
                        const SizedBox(height: 8),
                        FilledButton.tonal(
                          onPressed: _loadExperimentsStaff,
                          child: const Text('Odśwież A/B'),
                        ),
                      ],
                      if (current == _MenuId.giftCards) ...[
                        const SizedBox(height: 8),
                        FilledButton.tonal(
                          onPressed: _loadGiftCardsStaff,
                          child: const Text('Odśwież karty'),
                        ),
                      ],
                      if (current == _MenuId.reviews) ...[
                        const SizedBox(height: 8),
                        FilledButton.tonal(
                          onPressed: _loadReviews,
                          child: const Text('Odśwież opinie'),
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
