import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../layout/web_app_frame.dart';
import '../theme/app_theme.dart';
import 'staff_api.dart';
import 'staff_models.dart';
import 'staff_session.dart';

/// Panel pracownika (Flutter Web): kolejka PENDING, skan QR klienta, profil + punkty.
class StaffDashboardScreen extends StatefulWidget {
  const StaffDashboardScreen({super.key});

  @override
  State<StaffDashboardScreen> createState() => _StaffDashboardScreenState();
}

class _StaffDashboardScreenState extends State<StaffDashboardScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabs;
  final _scanFocus = FocusNode();
  final _scanController = TextEditingController();
  final _tokenController = TextEditingController();
  final _manualIdController = TextEditingController();

  List<StaffProduct> _queue = [];
  StaffCustomerProfile? _customer;
  bool _loadingQueue = false;
  bool _loadingCustomer = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _tabs = TabController(length: 2, vsync: this);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final s = context.read<StaffSession>();
      _tokenController.text = s.accessToken ?? '';
      _requestScanFocus();
    });
  }

  @override
  void dispose() {
    _tabs.dispose();
    _scanFocus.dispose();
    _scanController.dispose();
    _tokenController.dispose();
    _manualIdController.dispose();
    super.dispose();
  }

  void _requestScanFocus() {
    Future<void>.delayed(const Duration(milliseconds: 50), () {
      if (mounted) _scanFocus.requestFocus();
    });
  }

  StaffApi get _api => StaffApi(context.read<StaffSession>());

  Future<void> _loadQueue() async {
    final session = context.read<StaffSession>();
    if (!session.hasToken) {
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
    final session = context.read<StaffSession>();
    if (!session.hasToken) {
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
      _tabs.animateTo(1);
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

  @override
  Widget build(BuildContext context) {
    final session = context.watch<StaffSession>();

    return WebAppFrame(
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Panel pracownika'),
          bottom: TabBar(
            controller: _tabs,
            tabs: const [
              Tab(text: 'Kolejka rezerwacji'),
              Tab(text: 'Profil klienta'),
            ],
          ),
        ),
        body: Stack(
          children: [
            Column(
              children: [
                Material(
                  color: const Color(0xFFF8F8F8),
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Text(
                          'API: ${session.apiBase}',
                          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                color: const Color(0xFF6B6B6B),
                              ),
                        ),
                        const SizedBox(height: 8),
                        TextField(
                          controller: _tokenController,
                          obscureText: true,
                          decoration: const InputDecoration(
                            labelText: 'Access token (JWT Supabase)',
                            border: OutlineInputBorder(),
                            isDense: true,
                          ),
                          onChanged: (v) => session.setAccessToken(v),
                        ),
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
                    ),
                  ),
                ),
                Expanded(
                  child: TabBarView(
                    controller: _tabs,
                    children: [
                      _buildQueueTab(),
                      _buildCustomerTab(),
                    ],
                  ),
                ),
              ],
            ),
            // Quick Scan: ukryte pole nasłuchujące klawiatury (skaner jako HID).
            Positioned(
              left: 0,
              top: 0,
              width: 1,
              height: 1,
              child: Opacity(
                opacity: 0.01,
                child: TextField(
                  focusNode: _scanFocus,
                  controller: _scanController,
                  autofocus: true,
                  keyboardType: TextInputType.text,
                  enableInteractiveSelection: false,
                  decoration: const InputDecoration(
                    border: InputBorder.none,
                  ),
                  onSubmitted: (value) {
                    _scanController.clear();
                    if (value.trim().isNotEmpty) {
                      _openCustomer(value);
                    }
                  },
                ),
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

  Widget _buildCustomerTab() {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: ListView(
        children: [
          Text(
            'Quick Scan: zeskanuj kod QR klienta (UUID w treści). Skaner działa jak klawiatura — pole nasłuchu jest aktywne w tle.',
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
          if (_loadingCustomer)
            const Center(child: CircularProgressIndicator())
          else if (_customer == null)
            Text(
              'Brak wybranego klienta — zeskanuj kod lub wpisz UUID.',
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
            Text(
              'Ranga',
              style: Theme.of(context).textTheme.titleSmall,
            ),
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
            Text(
              'Punkty',
              style: Theme.of(context).textTheme.titleSmall,
            ),
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
}
