import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

/// Treść strony CMS z API `GET /cms/pages/:slug` (markdown jako zwykły tekst).
class CmsPageScreen extends StatefulWidget {
  const CmsPageScreen({
    super.key,
    required this.apiBase,
    required this.slug,
    this.titleFallback,
  });

  final String apiBase;
  final String slug;
  final String? titleFallback;

  @override
  State<CmsPageScreen> createState() => _CmsPageScreenState();
}

class _CmsPageScreenState extends State<CmsPageScreen> {
  late Future<Map<String, dynamic>?> _future;

  @override
  void initState() {
    super.initState();
    _future = _load();
  }

  Future<Map<String, dynamic>?> _load() async {
    final uri = Uri.parse(
      '${widget.apiBase}/cms/pages/${Uri.encodeComponent(widget.slug)}',
    );
    try {
      final r = await http.get(uri).timeout(const Duration(seconds: 15));
      if (r.statusCode != 200) return null;
      final j = jsonDecode(r.body);
      if (j is Map<String, dynamic>) return j;
      return null;
    } catch (_) {
      return null;
    }
  }

  @override
  Widget build(BuildContext context) {
    final title = widget.titleFallback ?? widget.slug;
    return Scaffold(
      appBar: AppBar(title: Text(title)),
      body: FutureBuilder<Map<String, dynamic>?>(
        future: _future,
        builder: (context, snap) {
          if (snap.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          final data = snap.data;
          if (data == null) {
            return const Center(
              child: Padding(
                padding: EdgeInsets.all(24),
                child: Text('Nie udało się wczytać strony.'),
              ),
            );
          }
          final t = data['title']?.toString() ?? title;
          final body = data['bodyMarkdown']?.toString() ?? '';
          return ListView(
            padding: const EdgeInsets.all(20),
            children: [
              Text(
                t,
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
              ),
              const SizedBox(height: 16),
              SelectableText(
                body,
                style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                      height: 1.45,
                    ),
              ),
            ],
          );
        },
      ),
    );
  }
}
