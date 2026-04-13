import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../providers/catalog_filter_notifier.dart';
import '../providers/cart_notifier.dart';

class CartScreen extends StatefulWidget {
  const CartScreen({
    super.key,
    this.activationTick = 0,
  });

  final int activationTick;

  @override
  State<CartScreen> createState() => _CartScreenState();
}

class _CartScreenState extends State<CartScreen> {
  Map<String, _ReservationSummary> _summaryByProduct = {};
  final Set<String> _selectedForFinalize = {};
  final Set<String> _availabilityNotified = {};
  bool _loadingSummary = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _refreshSummary();
    });
  }

  @override
  void didUpdateWidget(covariant CartScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.activationTick != oldWidget.activationTick) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        _refreshSummary();
      });
    }
  }

  Future<void> _refreshSummary() async {
    if (!mounted) return;
    setState(() => _loadingSummary = true);
    final cart = context.read<CartNotifier>();
    final rows = await cart.fetchMyReservationsSummary();
    cart.reconcileWithServerReservations(rows);
    if (!mounted) return;
    setState(() {
      _summaryByProduct = {
        for (final row in rows)
          (row['productId'] as String? ?? ''): _ReservationSummary.fromJson(row),
      };
      _loadingSummary = false;
    });
    final watches = await cart.fetchAvailabilityWatches();
    if (!mounted) return;
    for (final w in watches) {
      final productId = w['productId'] as String?;
      final availableNow = w['availableNow'] as bool? ?? false;
      if (productId == null || !availableNow || _availabilityNotified.contains(productId)) {
        continue;
      }
      _availabilityNotified.add(productId);
      final productName = (w['productName'] as String?) ?? 'produkt';
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Dobra wiadomość! Produkt "$productName" jest ponownie dostępny.',
          ),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  Future<void> _finalizeSelected(BuildContext context) async {
    final cart = context.read<CartNotifier>();
    final selected = <Map<String, dynamic>>[];
    for (final productId in _selectedForFinalize) {
      final summary = _summaryByProduct[productId];
      final matching = cart.lines.where((e) => e.product.id == productId);
      final line = matching.isEmpty ? null : matching.first;
      if (summary == null || line == null) continue;
      final qty = summary.acceptedQty < line.qty ? summary.acceptedQty : line.qty;
      if (qty <= 0) continue;
      selected.add({'productId': productId, 'quantity': qty});
    }
    if (selected.isEmpty) return;
    final checkout = await _openCheckoutDialog(context, cart);
    if (checkout == null) return;
    final order = await cart.finalizeAcceptedOrder(
      items: selected,
      paymentMethod: checkout.paymentMethod,
      shippingMethod: checkout.shippingMethod,
      shippingTarget: checkout.shippingTarget,
      saveToAddressBook: checkout.saveToAddressBook,
      promoCode: checkout.promoCode,
    );
    final apiError = order?['_error']?.toString();
    if (order == null || (apiError != null && apiError.isNotEmpty)) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            (apiError != null && apiError.isNotEmpty)
                ? apiError
                : 'Nie udało się sfinalizować zamówienia.',
          ),
        ),
      );
      return;
    }
    for (final item in selected) {
      cart.removeQuantity(item['productId'] as String, item['quantity'] as int);
    }
    if (!context.mounted) return;
    setState(() => _selectedForFinalize.clear());
    await context.read<CatalogFilterNotifier>().refreshFromApi();
    await _refreshSummary();
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Zamówienie dodane do listy zamówień klienta.')),
    );
  }

  Future<
      ({
        String paymentMethod,
        String shippingMethod,
        Map<String, dynamic> shippingTarget,
        bool saveToAddressBook,
        String? promoCode,
      })?> _openCheckoutDialog(BuildContext context, CartNotifier cart) async {
    final options = await cart.fetchCheckoutOptions();
    if (options == null) {
      if (!context.mounted) return null;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Nie udało się pobrać opcji dostawy i płatności.')),
      );
      return null;
    }
    final paymentMethods = (options['paymentMethods'] as List<dynamic>? ?? const [])
        .map((e) => e.toString())
        .toList();
    final shippingMethods = (options['shippingMethods'] as List<dynamic>? ?? const [])
        .map((e) => e.toString())
        .toList();
    final addressBook = (options['addressBook'] as List<dynamic>? ?? const [])
        .whereType<Map<String, dynamic>>()
        .toList();
    final suggestedInpostPoints =
        (options['suggestedInpostPoints'] as List<dynamic>? ?? const [])
            .whereType<Map<String, dynamic>>()
            .toList();
    final defaults = options['defaults'] as Map<String, dynamic>? ?? const {};

    if (!context.mounted) return null;
    return showDialog<
        ({
          String paymentMethod,
          String shippingMethod,
          Map<String, dynamic> shippingTarget,
          bool saveToAddressBook,
          String? promoCode,
        })>(
      context: context,
      builder: (ctx) {
        var selectedPayment =
            (defaults['paymentMethod']?.toString().isNotEmpty == true
                ? defaults['paymentMethod'].toString()
                : (paymentMethods.isNotEmpty ? paymentMethods.first : 'BLIK'));
        var selectedShipping =
            (defaults['shippingMethod']?.toString().isNotEmpty == true
                ? defaults['shippingMethod'].toString()
                : (shippingMethods.isNotEmpty ? shippingMethods.first : 'COURIER'));
        var selectedAddressId = defaults['preferredAddressId']?.toString();
        var saveToAddressBook = true;
        var useCustomAddress = selectedAddressId == null || selectedAddressId.isEmpty;

        final labelCtrl = TextEditingController();
        final recipientCtrl = TextEditingController();
        final phoneCtrl = TextEditingController();
        final emailCtrl = TextEditingController();
        final postalCtrl = TextEditingController();
        final cityCtrl = TextEditingController();
        final streetCtrl = TextEditingController();
        final buildingCtrl = TextEditingController();
        final apartmentCtrl = TextEditingController();
        final lockerIdCtrl = TextEditingController();
        final lockerLabelCtrl = TextEditingController();
        final promoCtrl = TextEditingController();
        String? selectedSuggestedLockerId;
        final formKey = GlobalKey<FormState>();
        var triedSubmit = false;

        return StatefulBuilder(
          builder: (context, setModalState) => AlertDialog(
            title: const Text('Finalizacja zamówienia'),
            content: SizedBox(
              width: 520,
              child: SingleChildScrollView(
                child: Form(
                  key: formKey,
                  autovalidateMode: triedSubmit
                      ? AutovalidateMode.always
                      : AutovalidateMode.onUserInteraction,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      DropdownButtonFormField<String>(
                        initialValue: selectedPayment,
                        decoration: const InputDecoration(labelText: 'Metoda płatności'),
                        items: paymentMethods
                            .map((m) => DropdownMenuItem(value: m, child: Text(_paymentLabel(m))))
                            .toList(),
                        onChanged: (v) {
                          if (v == null) return;
                          setModalState(() => selectedPayment = v);
                        },
                      ),
                      const SizedBox(height: 12),
                      DropdownButtonFormField<String>(
                        initialValue: selectedShipping,
                        decoration: const InputDecoration(labelText: 'Metoda dostawy'),
                        items: shippingMethods
                            .map((m) => DropdownMenuItem(value: m, child: Text(_shippingLabel(m))))
                            .toList(),
                        onChanged: (v) {
                          if (v == null) return;
                          setModalState(() => selectedShipping = v);
                        },
                      ),
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: promoCtrl,
                        decoration: const InputDecoration(
                          labelText: 'Kod promocyjny (opcjonalnie)',
                          hintText: 'np. WELCOME10',
                        ),
                        textCapitalization: TextCapitalization.characters,
                      ),
                      const SizedBox(height: 12),
                      if (addressBook.isNotEmpty) ...[
                        DropdownButtonFormField<String>(
                          initialValue: useCustomAddress ? null : selectedAddressId,
                          decoration:
                              const InputDecoration(labelText: 'Zapisane adresy / paczkomaty'),
                          items: addressBook
                              .map(
                                (a) => DropdownMenuItem(
                                  value: a['id']?.toString(),
                                  child: Text(_addressLabel(a)),
                                ),
                              )
                              .toList(),
                          onChanged: (v) {
                            setModalState(() {
                              selectedAddressId = v;
                              useCustomAddress = v == null || v.isEmpty;
                            });
                          },
                        ),
                        TextButton(
                          onPressed: () => setModalState(() {
                            useCustomAddress = true;
                            selectedAddressId = null;
                          }),
                          child: const Text('Użyj nowego adresu / paczkomatu'),
                        ),
                      ] else
                        const Text('Brak zapisanych adresów. Dodaj nowy poniżej.'),
                      if (useCustomAddress) ...[
                        const Divider(height: 20),
                        TextFormField(
                          controller: labelCtrl,
                          decoration:
                              const InputDecoration(labelText: 'Etykieta (np. Dom, Biuro)'),
                        ),
                        TextFormField(
                          controller: recipientCtrl,
                          decoration: const InputDecoration(labelText: 'Imię i nazwisko odbiorcy'),
                          validator: (v) {
                            final value = (v ?? '').trim();
                            if (value.isEmpty) return 'Podaj imię i nazwisko odbiorcy.';
                            return null;
                          },
                        ),
                        TextFormField(
                          controller: phoneCtrl,
                          decoration: const InputDecoration(labelText: 'Telefon kontaktowy'),
                          keyboardType: TextInputType.phone,
                          inputFormatters: [
                            FilteringTextInputFormatter.allow(RegExp(r'[0-9+\-\s]')),
                          ],
                          validator: (v) {
                            final value = (v ?? '').trim();
                            if (value.isEmpty) return 'Podaj numer do kontaktu.';
                            if (!RegExp(r'^\+?[0-9\s-]{7,20}$').hasMatch(value)) {
                              return 'Podaj poprawny numer telefonu.';
                            }
                            return null;
                          },
                        ),
                        TextFormField(
                          controller: emailCtrl,
                          decoration: const InputDecoration(labelText: 'E-mail (opcjonalnie)'),
                          keyboardType: TextInputType.emailAddress,
                          validator: (v) {
                            final value = (v ?? '').trim();
                            if (value.isEmpty) return null;
                            if (!RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$').hasMatch(value)) {
                              return 'Podaj poprawny adres e-mail.';
                            }
                            return null;
                          },
                        ),
                        if (selectedShipping == 'PARCEL_LOCKER_INPOST') ...[
                          if (suggestedInpostPoints.isNotEmpty)
                            DropdownButtonFormField<String>(
                              initialValue: selectedSuggestedLockerId,
                              decoration: const InputDecoration(
                                labelText: 'Sugerowane paczkomaty (na podstawie danych)',
                              ),
                              items: suggestedInpostPoints
                                  .map(
                                    (p) => DropdownMenuItem(
                                      value: p['id']?.toString(),
                                      child: Text(
                                        '${p['id']} · ${p['address'] ?? p['name'] ?? ''}',
                                      ),
                                    ),
                                  )
                                  .toList(),
                              onChanged: (v) {
                                if (v == null) return;
                                final match = suggestedInpostPoints.firstWhere(
                                  (p) => p['id']?.toString() == v,
                                  orElse: () => const {},
                                );
                                setModalState(() {
                                  selectedSuggestedLockerId = v;
                                  lockerIdCtrl.text = v;
                                  lockerLabelCtrl.text = (match['name']?.toString() ??
                                          match['address']?.toString() ??
                                          '')
                                      .trim();
                                });
                              },
                            ),
                          TextFormField(
                            controller: lockerIdCtrl,
                            decoration:
                                const InputDecoration(labelText: 'ID paczkomatu (np. WAW123M)'),
                            validator: (v) {
                              final value = (v ?? '').trim();
                              if (value.isEmpty) return 'Podaj identyfikator paczkomatu.';
                              return null;
                            },
                          ),
                          TextFormField(
                            controller: lockerLabelCtrl,
                            decoration:
                                const InputDecoration(labelText: 'Opis lokalizacji paczkomatu'),
                          ),
                        ] else if (selectedShipping == 'COURIER') ...[
                          TextFormField(
                            controller: postalCtrl,
                            decoration: const InputDecoration(labelText: 'Kod pocztowy (00-000)'),
                            keyboardType: TextInputType.number,
                            inputFormatters: [
                              FilteringTextInputFormatter.allow(RegExp(r'[0-9-]')),
                              LengthLimitingTextInputFormatter(6),
                            ],
                            validator: (v) {
                              final value = (v ?? '').trim();
                              if (!RegExp(r'^\d{2}-\d{3}$').hasMatch(value)) {
                                return 'Podaj kod pocztowy w formacie 00-000.';
                              }
                              return null;
                            },
                          ),
                          TextFormField(
                            controller: cityCtrl,
                            decoration: const InputDecoration(labelText: 'Miasto'),
                            validator: (v) {
                              final value = (v ?? '').trim();
                              if (value.isEmpty) return 'Podaj miasto.';
                              return null;
                            },
                          ),
                          TextFormField(
                            controller: streetCtrl,
                            decoration: const InputDecoration(labelText: 'Ulica'),
                            validator: (v) {
                              final value = (v ?? '').trim();
                              if (value.isEmpty) return 'Podaj ulicę.';
                              return null;
                            },
                          ),
                          TextFormField(
                            controller: buildingCtrl,
                            decoration: const InputDecoration(labelText: 'Numer budynku'),
                            validator: (v) {
                              final value = (v ?? '').trim();
                              if (value.isEmpty) return 'Podaj numer budynku.';
                              return null;
                            },
                          ),
                          TextFormField(
                            controller: apartmentCtrl,
                            decoration:
                                const InputDecoration(labelText: 'Numer lokalu (opcjonalnie)'),
                          ),
                        ],
                        CheckboxListTile(
                          value: saveToAddressBook,
                          contentPadding: EdgeInsets.zero,
                          onChanged: (v) => setModalState(() => saveToAddressBook = v ?? true),
                          title: const Text('Dodaj do listy adresów i zapamiętaj na przyszłość'),
                        ),
                      ],
                    ],
                  ),
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
                  final valid = formKey.currentState?.validate() ?? false;
                  if (!valid) {
                    setModalState(() => triedSubmit = true);
                    return;
                  }
                  final shippingTarget = <String, dynamic>{};
                  final selectedId = selectedAddressId;
                  if (!useCustomAddress && selectedId != null && selectedId.isNotEmpty) {
                    shippingTarget['addressBookEntryId'] = selectedAddressId;
                  } else {
                    void addIfNotEmpty(String key, String value) {
                      final v = value.trim();
                      if (v.isNotEmpty) {
                        shippingTarget[key] = v;
                      }
                    }

                    addIfNotEmpty('label', labelCtrl.text);
                    addIfNotEmpty('recipientName', recipientCtrl.text);
                    addIfNotEmpty('phone', phoneCtrl.text);
                    addIfNotEmpty('email', emailCtrl.text);
                    addIfNotEmpty('postalCode', postalCtrl.text);
                    addIfNotEmpty('city', cityCtrl.text);
                    addIfNotEmpty('street', streetCtrl.text);
                    addIfNotEmpty('buildingNumber', buildingCtrl.text);
                    addIfNotEmpty('apartmentNumber', apartmentCtrl.text);
                    addIfNotEmpty('parcelLockerId', lockerIdCtrl.text);
                    addIfNotEmpty('parcelLockerLabel', lockerLabelCtrl.text);
                    shippingTarget['country'] = 'PL';
                  }
                  Navigator.of(ctx).pop((
                    paymentMethod: selectedPayment,
                    shippingMethod: selectedShipping,
                    shippingTarget: shippingTarget,
                    saveToAddressBook: useCustomAddress ? saveToAddressBook : true,
                    promoCode: promoCtrl.text.trim().isEmpty
                        ? null
                        : promoCtrl.text.trim(),
                  ));
                },
                child: const Text('Finalizuj'),
              ),
            ],
          ),
        );
      },
    );
  }

  String _paymentLabel(String method) {
    switch (method) {
      case 'BLIK':
        return 'BLIK';
      case 'CARD_ONLINE':
        return 'Karta online';
      case 'BANK_TRANSFER':
        return 'Przelew tradycyjny';
      case 'CASH_ON_DELIVERY':
        return 'Płatność przy odbiorze';
      default:
        return method;
    }
  }

  String _shippingLabel(String method) {
    switch (method) {
      case 'COURIER':
        return 'Kurier';
      case 'PARCEL_LOCKER_INPOST':
        return 'Paczkomat InPost';
      case 'STORE_PICKUP':
        return 'Odbiór osobisty';
      default:
        return method;
    }
  }

  String _addressLabel(Map<String, dynamic> a) {
    final label = (a['label']?.toString() ?? '').trim();
    final recipient = (a['recipientName']?.toString() ?? '').trim();
    final locker = (a['parcelLockerId']?.toString() ?? '').trim();
    final city = (a['city']?.toString() ?? '').trim();
    final street = (a['street']?.toString() ?? '').trim();
    if (locker.isNotEmpty) {
      return '${label.isNotEmpty ? '$label · ' : ''}Paczkomat $locker';
    }
    final address = [city, street].where((e) => e.isNotEmpty).join(', ');
    return [label, recipient, address].where((e) => e.isNotEmpty).join(' · ');
  }

  @override
  Widget build(BuildContext context) {
    final cart = context.watch<CartNotifier>();
    final lines = cart.lines;

    return Scaffold(
      appBar: AppBar(title: const Text('Koszyk')),
      body: lines.isEmpty
          ? Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.shopping_bag_outlined,
                        size: 48, color: Colors.black.withValues(alpha: 0.25)),
                    const SizedBox(height: 14),
                    Text(
                      'Koszyk jest pusty',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Dodaj produkty ze strony Sklep.',
                      textAlign: TextAlign.center,
                      style: Theme.of(context)
                          .textTheme
                          .bodyMedium
                          ?.copyWith(color: const Color(0xFF6B6B6B)),
                    ),
                  ],
                ),
              ),
            )
          : Column(
              children: [
                Expanded(
                  child: ListView.separated(
                    padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
                    itemCount: lines.length,
                    separatorBuilder: (_, __) => const Divider(height: 22),
                    itemBuilder: (context, index) {
                      final line = lines[index];
                      return Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          ClipRRect(
                            borderRadius: BorderRadius.circular(14),
                            child: Image.network(
                              line.product.imageUrl,
                              width: 78,
                              height: 98,
                              fit: BoxFit.cover,
                              errorBuilder: (_, __, ___) => Container(
                                width: 78,
                                height: 98,
                                color: const Color(0xFFF4F4F4),
                                alignment: Alignment.center,
                                child: const Icon(
                                    Icons.image_not_supported_outlined,
                                    size: 22),
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  line.product.name,
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                  style:
                                      Theme.of(context).textTheme.titleMedium,
                                ),
                                const SizedBox(height: 6),
                                Text(
                                  '${line.product.pricePln.toStringAsFixed(0)} zł × ${line.qty}',
                                  style: Theme.of(context)
                                      .textTheme
                                      .bodyMedium
                                      ?.copyWith(
                                        color: const Color(0xFF6B6B6B),
                                      ),
                                ),
                                const SizedBox(height: 10),
                                if (_loadingSummary)
                                  const Padding(
                                    padding: EdgeInsets.only(bottom: 8),
                                    child: LinearProgressIndicator(minHeight: 2),
                                  )
                                else
                                  _buildStatusBadges(line.product.id),
                                const SizedBox(height: 8),
                                Row(
                                  children: [
                                    IconButton(
                                      onPressed: () async {
                                        final cart = context.read<CartNotifier>();
                                        cart.decrement(line.product.id);
                                        await cart.releaseOnServer(line.product);
                                        if (!context.mounted) return;
                                        await context
                                            .read<CatalogFilterNotifier>()
                                            .refreshFromApi();
                                      },
                                      icon: const Icon(
                                          Icons.remove_circle_outline_rounded),
                                      visualDensity: VisualDensity.compact,
                                    ),
                                    Text('${line.qty}',
                                        style: Theme.of(context)
                                            .textTheme
                                            .titleMedium),
                                    IconButton(
                                      onPressed: () async {
                                        final cart = context.read<CartNotifier>();
                                        final err =
                                            await cart.reserveOnServer(line.product);
                                        if (err != null) {
                                          if (!context.mounted) return;
                                          ScaffoldMessenger.of(context).showSnackBar(
                                            SnackBar(
                                              content: Text('Brak rezerwacji: $err'),
                                            ),
                                          );
                                          await context
                                              .read<CatalogFilterNotifier>()
                                              .refreshFromApi();
                                          return;
                                        }
                                        cart.add(line.product);
                                        if (!context.mounted) return;
                                        await context
                                            .read<CatalogFilterNotifier>()
                                            .refreshFromApi();
                                      },
                                      icon: const Icon(
                                          Icons.add_circle_outline_rounded),
                                      visualDensity: VisualDensity.compact,
                                    ),
                                    const Spacer(),
                                    Checkbox(
                                      value: _selectedForFinalize.contains(line.product.id),
                                      onChanged: ((_summaryByProduct[line.product.id]
                                                      ?.acceptedQty ??
                                                  0) >
                                              0)
                                          ? (v) {
                                              setState(() {
                                                if (v == true) {
                                                  _selectedForFinalize.add(line.product.id);
                                                } else {
                                                  _selectedForFinalize.remove(line.product.id);
                                                }
                                              });
                                            }
                                          : null,
                                    ),
                                    TextButton(
                                      onPressed: () async {
                                        final cart = context.read<CartNotifier>();
                                        cart.removeLine(line.product.id);
                                        await cart.releaseOnServer(
                                          line.product,
                                          qty: line.qty,
                                        );
                                        if (!context.mounted) return;
                                        await context
                                            .read<CatalogFilterNotifier>()
                                            .refreshFromApi();
                                      },
                                      child: const Text('Usuń'),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ],
                      );
                    },
                  ),
                ),
                Container(
                  decoration: const BoxDecoration(
                    color: Colors.white,
                    border: Border(top: BorderSide(color: Color(0xFFEEEEEE))),
                  ),
                  padding: const EdgeInsets.fromLTRB(20, 14, 20, 18),
                  child: SafeArea(
                    top: false,
                    child: Column(
                      children: [
                        SizedBox(
                          width: double.infinity,
                          child: FilledButton(
                            onPressed: _selectedForFinalize.isEmpty
                                ? null
                                : () => _finalizeSelected(context),
                            child: const Text('Finalizuj zaakceptowane'),
                          ),
                        ),
                        const SizedBox(height: 10),
                        Row(
                          children: [
                            Text('Razem',
                                style: Theme.of(context).textTheme.titleMedium),
                            const Spacer(),
                            Text(
                              '${cart.subtotalPln.toStringAsFixed(0)} zł',
                              style: Theme.of(context).textTheme.titleMedium,
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        SizedBox(
                          width: double.infinity,
                          child: FilledButton.tonal(
                            onPressed: _refreshSummary,
                            style: FilledButton.styleFrom(
                              padding: const EdgeInsets.symmetric(vertical: 14),
                            ),
                            child: const Text('Odśwież statusy rezerwacji'),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
    );
  }

  Widget _buildStatusBadges(String productId) {
    final s = _summaryByProduct[productId];
    if (s == null) {
      return const SizedBox.shrink();
    }
    final chips = <Widget>[];
    if (s.inCartQty > 0) {
      chips.add(_chip('W koszyku: ${s.inCartQty}', const Color(0xFFE8F0FE)));
    }
    if (s.pendingQty > 0) {
      chips.add(_chip('Oczekuje: ${s.pendingQty}', const Color(0xFFFFF3E0)));
    }
    if (s.acceptedQty > 0) {
      chips.add(_chip('Zaakceptowane: ${s.acceptedQty}', const Color(0xFFE8F5E9)));
    }
    if (s.rejectedQty > 0) {
      chips.add(_chip('Odrzucone: ${s.rejectedQty}', const Color(0xFFFFEBEE)));
    }
    return Wrap(spacing: 6, runSpacing: 6, children: chips);
  }

  Widget _chip(String text, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(text, style: const TextStyle(fontSize: 12)),
    );
  }
}

class _ReservationSummary {
  const _ReservationSummary({
    required this.inCartQty,
    required this.pendingQty,
    required this.acceptedQty,
    required this.rejectedQty,
  });

  final int inCartQty;
  final int pendingQty;
  final int acceptedQty;
  final int rejectedQty;

  factory _ReservationSummary.fromJson(Map<String, dynamic> j) {
    return _ReservationSummary(
      inCartQty: (j['inCartQty'] as num?)?.toInt() ?? 0,
      pendingQty: (j['pendingQty'] as num?)?.toInt() ?? 0,
      acceptedQty: (j['acceptedQty'] as num?)?.toInt() ?? 0,
      rejectedQty: (j['rejectedQty'] as num?)?.toInt() ?? 0,
    );
  }
}
