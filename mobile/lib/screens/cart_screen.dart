import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../providers/cart_notifier.dart';

class CartScreen extends StatelessWidget {
  const CartScreen({super.key});

  static const _purchaseMessage = 'Czekamy na potwierdzenie dostępności ze sklepu stacjonarnego';

  Future<void> _onPurchase(BuildContext context) async {
    final cart = context.read<CartNotifier>();
    if (cart.itemCount == 0) return;

    await showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Dziękujemy'),
        content: const Text(_purchaseMessage),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('OK'),
          ),
        ],
      ),
    );
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
                    Icon(Icons.shopping_bag_outlined, size: 48, color: Colors.black.withOpacity(0.25)),
                    const SizedBox(height: 14),
                    Text(
                      'Koszyk jest pusty',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Dodaj produkty ze strony Sklep.',
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: const Color(0xFF6B6B6B)),
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
                                child: const Icon(Icons.image_not_supported_outlined, size: 22),
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
                                  style: Theme.of(context).textTheme.titleMedium,
                                ),
                                const SizedBox(height: 6),
                                Text(
                                  '${line.product.pricePln.toStringAsFixed(0)} zł × ${line.qty}',
                                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                        color: const Color(0xFF6B6B6B),
                                      ),
                                ),
                                const SizedBox(height: 10),
                                Row(
                                  children: [
                                    IconButton(
                                      onPressed: () => context.read<CartNotifier>().decrement(line.product.id),
                                      icon: const Icon(Icons.remove_circle_outline_rounded),
                                      visualDensity: VisualDensity.compact,
                                    ),
                                    Text('${line.qty}', style: Theme.of(context).textTheme.titleMedium),
                                    IconButton(
                                      onPressed: () => context.read<CartNotifier>().add(line.product),
                                      icon: const Icon(Icons.add_circle_outline_rounded),
                                      visualDensity: VisualDensity.compact,
                                    ),
                                    const Spacer(),
                                    TextButton(
                                      onPressed: () => context.read<CartNotifier>().removeLine(line.product.id),
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
                        Row(
                          children: [
                            Text('Razem', style: Theme.of(context).textTheme.titleMedium),
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
                          child: FilledButton(
                            onPressed: () => _onPurchase(context),
                            style: FilledButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 14)),
                            child: const Text('Kupuję'),
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
}
