import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../config/app_config.dart';
import '../layout/web_app_frame.dart';
import '../providers/app_navigation.dart';
import '../providers/auth_session.dart';
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
  scanner,
  loyalty,
}

class _AdminDashboardState extends State<AdminDashboard> {
  int _railIndex = 0;
  final _scanFocus = FocusNode();
  final _scanController = TextEditingController();
  final _manualIdController = TextEditingController();

  List<StaffProduct> _queue = [];
  StaffCustomerProfile? _customer;
  bool _loadingQueue = false;
  bool _loadingCustomer = false;
  String? _error;

  List<_MenuId> _menuForRole(String? role) {
    if (role == 'OWNER') {
      return const [
        _MenuId.stats,
        _MenuId.finance,
        _MenuId.aiAgents,
        _MenuId.employees,
        _MenuId.reservations,
        _MenuId.scanner,
      ];
    }
    return const [_MenuId.reservations, _MenuId.scanner, _MenuId.loyalty];
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
      case _MenuId.scanner:
        return selected ? Icons.qr_code_scanner : Icons.qr_code_scanner_outlined;
      case _MenuId.loyalty:
        return selected ? Icons.card_giftcard : Icons.card_giftcard_outlined;
    }
  }

  @override
  void initState() {
    super.initState();
    if (kIsWeb) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _requestScanFocus();
    });
  }

  @override
  void dispose() {
    _scanFocus.dispose();
    _scanController.dispose();
    _manualIdController.dispose();
    super.dispose();
  }

  void _requestScanFocus() {
    if (kIsWeb) return;
    Future<void>.delayed(const Duration(milliseconds: 50), () {
      if (mounted) _scanFocus.requestFocus();
    });
  }

  StaffApi get _api => StaffApi(context.read<AuthSession>());

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

  void _focusTabAfterScan() {
    final menu = _menuForRole(context.read<AuthSession>().role);
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
                Text(
                  p.name,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                ),
                const SizedBox(height: 6),
                Text(
                  '${p.priceRaw} zł · ${p.status}',
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
    final menu = _menuForRole(auth.role);
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
      onDestinationSelected: (i) => setState(() => _railIndex = i),
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
