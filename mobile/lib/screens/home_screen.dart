import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../layout/catalog_grid_layout.dart';
import '../models/product_category.dart';
import '../models/product_condition.dart';
import '../providers/catalog_filter_notifier.dart';
import '../widgets/product_card.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final filter = context.watch<CatalogFilterNotifier>();
    final products = filter.visibleProducts;

    return Scaffold(
      appBar: AppBar(
        title: const Text('SELLEKTYWNI'),
        actions: [
          IconButton(
            tooltip: 'Powiadomienia',
            onPressed: () {
              showModalBottomSheet<void>(
                context: context,
                showDragHandle: true,
                builder: (ctx) => const _PushInfoSheet(),
              );
            },
            icon: const Icon(Icons.notifications_none_rounded),
          ),
        ],
      ),
      body: CustomScrollView(
        slivers: [
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 6, 20, 8),
              child: Text(
                'Wybierz kategorię i stan produktu',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: const Color(0xFF6B6B6B),
                    ),
              ),
            ),
          ),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  _CategoryChip(
                    label: 'Wszystkie',
                    selected: filter.category == null,
                    onSelected: (_) =>
                        context.read<CatalogFilterNotifier>().setCategory(null),
                  ),
                  ...ProductCategory.values.map(
                    (c) => _CategoryChip(
                      label: c.label,
                      selected: filter.category == c,
                      onSelected: (_) =>
                          context.read<CatalogFilterNotifier>().setCategory(c),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SliverToBoxAdapter(child: SizedBox(height: 14)),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 10),
              child: Text(
                'Stan',
                style: Theme.of(context).textTheme.titleMedium,
              ),
            ),
          ),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  _CategoryChip(
                    label: 'Wszystkie',
                    selected: filter.condition == null,
                    onSelected: (_) => context
                        .read<CatalogFilterNotifier>()
                        .setCondition(null),
                  ),
                  ...ProductCondition.values.map(
                    (c) => _CategoryChip(
                      label: c.label,
                      selected: filter.condition == c,
                      onSelected: (_) =>
                          context.read<CatalogFilterNotifier>().setCondition(c),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SliverToBoxAdapter(child: SizedBox(height: 18)),
          if (products.isEmpty)
            const SliverFillRemaining(
              hasScrollBody: false,
              child: _EmptyState(),
            )
          else
            SliverLayoutBuilder(
              builder: (context, constraints) {
                final columns =
                    catalogGridColumnCount(constraints.crossAxisExtent);
                return SliverPadding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
                  sliver: SliverGrid(
                    gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: columns,
                      mainAxisSpacing: 14,
                      crossAxisSpacing: 14,
                      childAspectRatio: 0.54,
                    ),
                    delegate: SliverChildBuilderDelegate(
                      (context, index) => ProductCard(product: products[index]),
                      childCount: products.length,
                    ),
                  ),
                );
              },
            ),
        ],
      ),
    );
  }
}

class _CategoryChip extends StatelessWidget {
  const _CategoryChip({
    required this.label,
    required this.selected,
    required this.onSelected,
  });

  final String label;
  final bool selected;
  final ValueChanged<bool> onSelected;

  @override
  Widget build(BuildContext context) {
    return FilterChip(
      label: Text(label),
      selected: selected,
      onSelected: onSelected,
      showCheckmark: false,
      selectedColor: const Color(0xFF111111),
      labelStyle: TextStyle(
        color: selected ? Colors.white : const Color(0xFF111111),
        fontWeight: FontWeight.w600,
        fontSize: 13,
      ),
      backgroundColor: const Color(0xFFF4F4F4),
      side: BorderSide(
          color: selected ? Colors.transparent : const Color(0x11000000)),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.search_off_rounded,
                size: 44, color: Colors.black.withValues(alpha: 0.35)),
            const SizedBox(height: 12),
            Text(
              'Brak produktów dla wybranych filtrów',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 8),
            Text(
              'Zmień kategorię lub stan, aby zobaczyć więcej modeli.',
              textAlign: TextAlign.center,
              style: Theme.of(context)
                  .textTheme
                  .bodyMedium
                  ?.copyWith(color: const Color(0xFF6B6B6B)),
            ),
          ],
        ),
      ),
    );
  }
}

class _PushInfoSheet extends StatelessWidget {
  const _PushInfoSheet();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Powiadomienia o zamówieniu',
              style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 10),
          Text(
            'Status zamówienia (np. akceptacja, gotowość do odbioru) otrzymasz jako wiadomość push z Firebase Cloud Messaging.',
            style: Theme.of(context)
                .textTheme
                .bodyMedium
                ?.copyWith(color: const Color(0xFF6B6B6B)),
          ),
          const SizedBox(height: 16),
          FilledButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Rozumiem'),
          ),
        ],
      ),
    );
  }
}
