import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:provider/provider.dart';

import '../data/product_details.dart';
import '../models/product.dart';
import '../providers/auth_session.dart';

class ProductDetailsScreen extends StatefulWidget {
  const ProductDetailsScreen({super.key, required this.product});

  final Product product;

  @override
  State<ProductDetailsScreen> createState() => _ProductDetailsScreenState();
}

class _ProductDetailsScreenState extends State<ProductDetailsScreen> {
  Map<String, dynamic>? _reviewsPayload;
  bool _reviewsLoading = true;
  final _commentCtrl = TextEditingController();
  int _rating = 5;

  @override
  void dispose() {
    _commentCtrl.dispose();
    super.dispose();
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _fetchReviews());
  }

  Future<void> _fetchReviews() async {
    final auth = context.read<AuthSession>();
    setState(() => _reviewsLoading = true);
    try {
      final uri = Uri.parse('${auth.apiBase}/products/${widget.product.id}/reviews');
      final r = await http.get(uri).timeout(const Duration(seconds: 12));
      if (r.statusCode == 200) {
        final j = jsonDecode(r.body);
        if (j is Map<String, dynamic>) {
          setState(() {
            _reviewsPayload = j;
            _reviewsLoading = false;
          });
          return;
        }
      }
    } catch (_) {}
    if (mounted) {
      setState(() => _reviewsLoading = false);
    }
  }

  Future<void> _submitReview() async {
    final auth = context.read<AuthSession>();
    final token = auth.accessToken;
    if (!auth.isAuthenticated || token == null || token.isEmpty) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Zaloguj się, aby dodać opinię.')),
      );
      return;
    }
    try {
      final uri = Uri.parse('${auth.apiBase}/order/reviews');
      final r = await http
          .post(
            uri,
            headers: {
              'Content-Type': 'application/json',
              'Authorization': 'Bearer $token',
            },
            body: jsonEncode({
              'productId': widget.product.id,
              'rating': _rating,
              'comment': _commentCtrl.text.trim(),
            }),
          )
          .timeout(const Duration(seconds: 12));
      if (!mounted) return;
      if (r.statusCode != 200 && r.statusCode != 201) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Nie udało się zapisać opinii (${r.statusCode}).')),
        );
        return;
      }
      _commentCtrl.clear();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Dziękujemy za opinię.')),
      );
      await _fetchReviews();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.toString())),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final d = detailsForProduct(widget.product);
    final reviews = (_reviewsPayload?['reviews'] as List<dynamic>? ?? const [])
        .whereType<Map<String, dynamic>>()
        .toList();
    final avg = _reviewsPayload?['averageRating'];
    final count = _reviewsPayload?['reviewCount'];

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
                widget.product.imageUrl,
                fit: BoxFit.cover,
              ),
            ),
          ),
          const SizedBox(height: 14),
          Text(
            widget.product.name,
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
          ),
          const SizedBox(height: 6),
          Text(
            '${widget.product.pricePln.toStringAsFixed(0)} zł',
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
          if (widget.product.stockQty > 0 || widget.product.reservedQty > 0)
            _kv(
              'Dostępność',
              'Magazyn: ${widget.product.stockQty}, rezerwacje: ${widget.product.reservedQty}',
            ),
          const SizedBox(height: 12),
          Text('Opinie klientów', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 6),
          if (_reviewsLoading)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 12),
              child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
            )
          else ...[
            if (avg != null && count != null && (count as num) > 0)
              Text(
                'Średnia: ${(avg as num).toStringAsFixed(1)} / 5 · $count opinii',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
              )
            else
              Text(
                'Brak opinii — bądź pierwszy.',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: const Color(0xFF6B6B6B),
                    ),
              ),
            const SizedBox(height: 8),
            ...reviews.map(
              (r) => Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: Text('• ${r['rating']}/5 ${(r['comment'] ?? '').toString().trim()}'),
              ),
            ),
          ],
          const SizedBox(height: 12),
          Text('Twoja opinia', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 6),
          Row(
            children: [
              const Text('Ocena:'),
              Expanded(
                child: Slider(
                  value: _rating.toDouble(),
                  min: 1,
                  max: 5,
                  divisions: 4,
                  label: '$_rating',
                  onChanged: (v) => setState(() => _rating = v.round()),
                ),
              ),
            ],
          ),
          TextField(
            controller: _commentCtrl,
            decoration: const InputDecoration(
              labelText: 'Komentarz (opcjonalnie)',
              border: OutlineInputBorder(),
            ),
            maxLines: 3,
          ),
          const SizedBox(height: 8),
          FilledButton(
            onPressed: _submitReview,
            child: const Text('Zapisz opinię'),
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
