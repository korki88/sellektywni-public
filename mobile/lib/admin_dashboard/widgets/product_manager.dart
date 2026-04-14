import 'package:flutter/material.dart';

import '../../staff/staff_models.dart';
import '../../theme/design_tokens.dart';

class ProductManager extends StatelessWidget {
  const ProductManager({
    super.key,
    required this.isOwner,
    required this.catalogQueryController,
    required this.uploadingCostingSheet,
    required this.lastCostingImport,
    required this.loadingCatalog,
    required this.catalogRows,
    required this.onImportCostingSheet,
    required this.onLoadCatalog,
    required this.onEditMerchandising,
  });

  final bool isOwner;
  final TextEditingController catalogQueryController;
  final bool uploadingCostingSheet;
  final StaffCostingImportResult? lastCostingImport;
  final bool loadingCatalog;
  final List<Map<String, dynamic>> catalogRows;
  final VoidCallback onImportCostingSheet;
  final VoidCallback onLoadCatalog;
  final ValueChanged<StaffProduct> onEditMerchandising;

  StaffProduct _staffProductFromCatalog(Map<String, dynamic> row) {
    return StaffProduct(
      id: row['id']?.toString() ?? '',
      idDotykacka: row['idDotykacka']?.toString() ?? '',
      name: row['name']?.toString() ?? 'Produkt',
      priceRaw: row['price']?.toString() ?? '0',
      status: row['status']?.toString() ?? '',
      pendingQuantity: 0,
      subtitle: row['subtitle']?.toString(),
      isFeatured: row['isFeatured'] == true,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'Katalog i merchandising. Zarządzaj widocznością produktów oraz podtytułami kart.',
            style: Theme.of(
              context,
            ).textTheme.bodyMedium?.copyWith(color: DesignTokens.mutedText),
          ),
          const SizedBox(height: 12),
          if (isOwner) ...[
            Card(
              color: DesignTokens.infoSoft,
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Migracja danych kosztowych (CSV/Excel)',
                      style: Theme.of(context).textTheme.titleSmall?.copyWith(
                            fontWeight: FontWeight.w700,
                          ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'Kolumny: productId lub idDotykacka oraz purchasePriceNet, vatRate, marginTarget, supplier, paymentTermsDays.',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                    const SizedBox(height: 10),
                    FilledButton.tonalIcon(
                      onPressed:
                          uploadingCostingSheet ? null : onImportCostingSheet,
                      icon: uploadingCostingSheet
                          ? const SizedBox(
                              width: 14,
                              height: 14,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.upload_file_outlined),
                      label: Text(
                        uploadingCostingSheet
                            ? 'Importowanie...'
                            : 'Importuj CSV / Excel',
                      ),
                    ),
                    if (lastCostingImport != null) ...[
                      const SizedBox(height: 10),
                      Text(
                        'Ostatni import: ${lastCostingImport!.fileName}\n'
                        'Wiersze: ${lastCostingImport!.rowsTotal} · '
                        'Produkty: ${lastCostingImport!.updatedProducts} · '
                        'Dostawcy: ${lastCostingImport!.upsertedSuppliers}',
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                      if (lastCostingImport!.warnings.isNotEmpty) ...[
                        const SizedBox(height: 8),
                        SizedBox(
                          height: 110,
                          child: ListView.builder(
                            itemCount: lastCostingImport!.warnings.length,
                            itemBuilder: (context, i) => Text(
                              '• ${lastCostingImport!.warnings[i]}',
                              style: Theme.of(context)
                                  .textTheme
                                  .bodySmall
                                  ?.copyWith(color: DesignTokens.mutedText),
                            ),
                          ),
                        ),
                      ],
                    ],
                  ],
                ),
              ),
            ),
            const SizedBox(height: 12),
          ],
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: catalogQueryController,
                  onSubmitted: (_) => onLoadCatalog(),
                  decoration: const InputDecoration(
                    labelText: 'Szukaj produktu (nazwa, fraza)',
                    border: OutlineInputBorder(),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              FilledButton.tonal(
                onPressed: onLoadCatalog,
                child: const Text('Szukaj'),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Expanded(
            child: loadingCatalog
                ? const Center(child: CircularProgressIndicator())
                : catalogRows.isEmpty
                    ? Center(
                        child: Text(
                          'Brak produktów dla bieżącego filtra.',
                          style:
                              Theme.of(context).textTheme.bodyLarge?.copyWith(
                                    color: DesignTokens.mutedText,
                                  ),
                        ),
                      )
                    : ListView.separated(
                        itemCount: catalogRows.length,
                        separatorBuilder: (_, __) => const SizedBox(height: 8),
                        itemBuilder: (context, i) {
                          final row = catalogRows[i];
                          final p = _staffProductFromCatalog(row);
                          return Card(
                            child: ListTile(
                              title: Text(p.name),
                              subtitle: Text(
                                'ID: ${p.id} · Cena: ${p.priceRaw} zł'
                                '${p.subtitle != null && p.subtitle!.trim().isNotEmpty ? '\nPodtytuł: ${p.subtitle}' : ''}',
                              ),
                              isThreeLine: p.subtitle != null &&
                                  p.subtitle!.trim().isNotEmpty,
                              trailing: Wrap(
                                spacing: 8,
                                crossAxisAlignment: WrapCrossAlignment.center,
                                children: [
                                  if (p.isFeatured)
                                    const Chip(label: Text('Polecane')),
                                  OutlinedButton.icon(
                                    onPressed: () => onEditMerchandising(p),
                                    icon: const Icon(Icons.edit_outlined,
                                        size: 18),
                                    label: const Text('Edytuj'),
                                  ),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
          ),
        ],
      ),
    );
  }
}
