import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/product.dart';
import '../config/shop_market_holder.dart';
import '../providers/catalog_filter_notifier.dart';
import '../providers/cart_notifier.dart';
import '../providers/compare_notifier.dart';
import '../providers/wishlist_notifier.dart';
import '../screens/product_details_screen.dart';

class ProductCard extends StatelessWidget {
  const ProductCard({super.key, required this.product});

  final Product product;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final inCart = context.watch<CartNotifier>().contains(product);
    final reserved = !product.canAddToCart;
    final inWishlist = context.watch<WishlistNotifier>().contains(product.id);
    final inCompare = context.watch<CompareNotifier>().contains(product);

    return Card(
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          AspectRatio(
            aspectRatio: 3 / 4,
            child: Stack(
              fit: StackFit.expand,
              children: [
                ColorFiltered(
                  colorFilter: reserved
                      ? const ColorFilter.mode(Colors.grey, BlendMode.saturation)
                      : const ColorFilter.mode(Colors.transparent, BlendMode.srcOver),
                  child: InkWell(
                    onTap: () => Navigator.of(context).push(
                      MaterialPageRoute<void>(
                        builder: (_) => ProductDetailsScreen(product: product),
                      ),
                    ),
                    child: Image.network(
                      product.imageUrl,
                      fit: BoxFit.cover,
                      loadingBuilder: (context, child, progress) {
                        if (progress == null) return child;
                        return Container(
                          color: const Color(0xFFF4F4F4),
                          alignment: Alignment.center,
                          child: const SizedBox(
                            width: 28,
                            height: 28,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          ),
                        );
                      },
                      errorBuilder: (_, __, ___) => Container(
                        color: const Color(0xFFF4F4F4),
                        alignment: Alignment.center,
                        child: const Icon(Icons.image_not_supported_outlined),
                      ),
                    ),
                  ),
                ),
                Positioned(
                  left: 12,
                  top: 12,
                  child: _Pill(text: product.condition.label),
                ),
                if (product.isFeatured)
                  Positioned(
                    left: 12,
                    bottom: 12,
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        color: const Color(0xFFFFF8E1),
                        borderRadius: BorderRadius.circular(999),
                        border: Border.all(color: const Color(0xFFFFB300)),
                      ),
                      child: const Padding(
                        padding: EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                        child: Text(
                          'Polecane',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            color: Color(0xFF795548),
                          ),
                        ),
                      ),
                    ),
                  ),
                Positioned(
                  right: 8,
                  top: 8,
                  child: Material(
                    color: Colors.white.withValues(alpha: 0.92),
                    shape: const CircleBorder(),
                    clipBehavior: Clip.antiAlias,
                    child: IconButton(
                      tooltip: inWishlist ? 'Usuń z ulubionych' : 'Dodaj do ulubionych',
                      onPressed: () async {
                        final err = await context.read<WishlistNotifier>().toggle(product.id);
                        if (!context.mounted) return;
                        if (err != null) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text(err), behavior: SnackBarBehavior.floating),
                          );
                        }
                      },
                      icon: Icon(
                        inWishlist ? Icons.favorite_rounded : Icons.favorite_border_rounded,
                        color: inWishlist ? const Color(0xFFB71C1C) : const Color(0xFF111111),
                      ),
                    ),
                  ),
                ),
                Positioned(
                  right: 8,
                  top: 52,
                  child: Material(
                    color: Colors.white.withValues(alpha: 0.92),
                    shape: const CircleBorder(),
                    clipBehavior: Clip.antiAlias,
                    child: IconButton(
                      tooltip: inCompare ? 'Usuń z porównania' : 'Dodaj do porównania',
                      onPressed: () {
                        context.read<CompareNotifier>().toggle(product);
                        if (!context.mounted) return;
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('Lista porównania zaktualizowana.'),
                            behavior: SnackBarBehavior.floating,
                          ),
                        );
                      },
                      icon: Icon(
                        inCompare ? Icons.compare_arrows_rounded : Icons.compare_arrows_outlined,
                        color: const Color(0xFF111111),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 14, 14, 14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                InkWell(
                  onTap: () => Navigator.of(context).push(
                    MaterialPageRoute<void>(
                      builder: (_) => ProductDetailsScreen(product: product),
                    ),
                  ),
                  child: Text(
                    product.name,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.titleMedium,
                  ),
                ),
                if (product.subtitle != null && product.subtitle!.trim().isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Text(
                    product.subtitle!,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: const Color(0xFF6B6B6B),
                    ),
                  ),
                ],
                const SizedBox(height: 6),
                Text(
                  '${product.pricePln.toStringAsFixed(0)} zł',
                  style: theme.textTheme.bodyLarge?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
                if (ShopMarketHolder.displayCurrencies.isNotEmpty) ...[
                  Builder(
                    builder: (ctx) {
                      final dc = ShopMarketHolder.displayCurrencies.first;
                      final code = dc['code']?.toString() ?? '';
                      final rate = (dc['rateToPrimary'] as num?)?.toDouble() ?? 0;
                      final sec = ShopMarketHolder.formatSecondary(
                        product.pricePln,
                        code,
                        rate,
                      );
                      if (sec == null) return const SizedBox.shrink();
                      return Padding(
                        padding: const EdgeInsets.only(top: 4),
                        child: Text(
                          '~ $sec',
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: const Color(0xFF6B6B6B),
                          ),
                        ),
                      );
                    },
                  ),
                ],
                const SizedBox(height: 12),
                Text(
                  'Magazyn: ${product.stockQty} · Rezerwacje: ${product.reservedQty}',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: const Color(0xFF6B6B6B),
                  ),
                ),
                const SizedBox(height: 10),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton.tonal(
                    onPressed: reserved
                        ? () async {
                            final cart = context.read<CartNotifier>();
                            final message =
                                await cart.watchAvailabilityOnServer(product.id);
                            if (!context.mounted) return;
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text(message ?? 'Powiadomienie zostało zapisane.'),
                                behavior: SnackBarBehavior.floating,
                              ),
                            );
                          }
                        : () async {
                      final cart = context.read<CartNotifier>();
                      final syncError = await cart.reserveOnServer(product);
                      if (syncError != null) {
                        if (!context.mounted) return;
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(syncError),
                            behavior: SnackBarBehavior.floating,
                          ),
                        );
                        if (!context.mounted) return;
                        await context.read<CatalogFilterNotifier>().refreshFromApi();
                        return;
                      }
                      cart.add(product);
                      if (!context.mounted) return;
                      await context.read<CatalogFilterNotifier>().refreshFromApi();
                      if (!context.mounted) return;
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text('Dodano: ${product.name}'),
                          behavior: SnackBarBehavior.floating,
                        ),
                      );
                    },
                    style: FilledButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      backgroundColor: reserved
                          ? const Color(0xFFEFF3F8)
                          : inCart
                          ? const Color(0xFF111111)
                          : const Color(0xFFF4F4F4),
                      foregroundColor:
                          reserved
                              ? const Color(0xFF1A3B5D)
                              : (inCart ? Colors.white : const Color(0xFF111111)),
                    ),
                    child: Text(
                      reserved
                          ? 'Powiadom o dostępności'
                          : (inCart ? 'Dodaj kolejny' : 'Do koszyka'),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _Pill extends StatelessWidget {
  const _Pill({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.92),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: const Color(0x11000000)),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        child: Text(
          text,
          style: const TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: Color(0xFF111111),
          ),
        ),
      ),
    );
  }
}
