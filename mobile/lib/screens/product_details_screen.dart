import 'package:flutter/material.dart';

import '../data/product_details.dart';
import '../models/product.dart';

class ProductDetailsScreen extends StatelessWidget {
  const ProductDetailsScreen({super.key, required this.product});

  final Product product;

  @override
  Widget build(BuildContext context) {
    final d = detailsForProduct(product);
    return Scaffold(
      appBar: AppBar(title: const Text('Karta produktu')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(16),
            child: AspectRatio(
              aspectRatio: 3 / 4,
              child: Image.network(
                product.imageUrl,
                fit: BoxFit.cover,
              ),
            ),
          ),
          const SizedBox(height: 14),
          Text(
            product.name,
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
          ),
          const SizedBox(height: 6),
          Text(
            '${product.pricePln.toStringAsFixed(0)} zł',
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: 14),
          _kv('Marka', d.brand),
          _kv('Kolekcja', d.collection),
          _kv('SKU', d.sku),
          _kv('Kolor', d.color),
          _kv('Materiał', d.material),
          _kv('Krój', d.fit),
          _kv('Sezon', d.season),
          _kv('Kraj pochodzenia', d.originCountry),
          _kv('Rozmiarówka', d.sizeRange),
          if (product.stockQty > 0 || product.reservedQty > 0)
            _kv(
              'Dostępność',
              'Magazyn: ${product.stockQty}, rezerwacje: ${product.reservedQty}',
            ),
          const SizedBox(height: 12),
          Text('Cechy produktu', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 6),
          ...d.features.map((f) => Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: Text('• $f'),
              )),
          const SizedBox(height: 12),
          Text('Pielęgnacja', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 6),
          ...d.careInstructions.map((c) => Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: Text('• $c'),
              )),
          const SizedBox(height: 12),
          Text('Wymiary referencyjne', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 6),
          ...d.measurements.entries.map((e) => _kv(e.key, e.value)),
        ],
      ),
    );
  }

  Widget _kv(String key, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(width: 140, child: Text(key)),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );
  }
}
