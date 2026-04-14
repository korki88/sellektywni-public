import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/product.dart';
import '../models/product_category.dart';
import '../providers/compare_notifier.dart';

class ComparisonScreen extends StatelessWidget {
  const ComparisonScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final items = context.watch<CompareNotifier>().items;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Porównanie produktów'),
        actions: [
          TextButton(
            onPressed: () => context.read<CompareNotifier>().clear(),
            child: const Text('Wyczyść'),
          ),
        ],
      ),
      body: items.isEmpty
          ? const Center(child: Text('Dodaj produkty z karty (ikona porównania).'))
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: DataTable(
                    columns: const [
                      DataColumn(label: Text('')),
                      DataColumn(label: Text('Nazwa')),
                      DataColumn(label: Text('Cena')),
                      DataColumn(label: Text('Stan')),
                      DataColumn(label: Text('Kategoria')),
                    ],
                    rows: items.map((Product p) {
                      return DataRow(
                        cells: [
                          DataCell(
                            IconButton(
                              icon: const Icon(Icons.close_rounded),
                              onPressed: () =>
                                  context.read<CompareNotifier>().remove(p.id),
                            ),
                          ),
                          DataCell(SizedBox(width: 160, child: Text(p.name))),
                          DataCell(Text('${p.pricePln.toStringAsFixed(0)} zł')),
                          DataCell(Text('${p.stockQty}')),
                          DataCell(Text(p.category.label)),
                        ],
                      );
                    }).toList(),
                  ),
                ),
              ],
            ),
    );
  }
}
