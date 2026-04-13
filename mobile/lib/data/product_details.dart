import '../models/product.dart';
import '../models/product_category.dart';
import 'mock_catalog.dart';

class ProductDetailsSpec {
  const ProductDetailsSpec({
    required this.brand,
    required this.collection,
    required this.sku,
    required this.color,
    required this.material,
    required this.fit,
    required this.season,
    required this.originCountry,
    required this.sizeRange,
    required this.features,
    required this.careInstructions,
    required this.measurements,
  });

  final String brand;
  final String collection;
  final String sku;
  final String color;
  final String material;
  final String fit;
  final String season;
  final String originCountry;
  final String sizeRange;
  final List<String> features;
  final List<String> careInstructions;
  final Map<String, String> measurements;
}

Product? lookupProductById(String productId) {
  for (final p in mockProducts) {
    if (p.id == productId) return p;
  }
  return null;
}

Product fallbackProductForOrderItem({
  required String productId,
  required String name,
  required double pricePln,
}) {
  return Product(
    id: productId,
    name: name,
    pricePln: pricePln,
    imageUrl: 'https://picsum.photos/seed/fallback-$productId/900/1200',
    category: ProductCategory.clothing,
    condition: ProductCondition.newItem,
  );
}

const Map<String, ProductDetailsSpec> productDetailsById = {
  '1': ProductDetailsSpec(
    brand: 'SELLEKTYWNI Atelier',
    collection: 'FW Essentials',
    sku: 'SEL-SWT-001',
    color: 'Grafitowy',
    material: '100% kaszmir',
    fit: 'Regular fit',
    season: 'Jesień/Zima',
    originCountry: 'Włochy',
    sizeRange: 'XS-XL',
    features: ['Ręczne wykończenie ściągaczy', 'Miękka przędza premium'],
    careInstructions: ['Pranie ręczne 30C', 'Suszyć na płasko'],
    measurements: {'Długość': '66 cm', 'Szerokość klatki': '54 cm (M)'},
  ),
  '2': ProductDetailsSpec(
    brand: 'SELLEKTYWNI Studio',
    collection: 'Linen Edit',
    sku: 'SEL-SHR-002',
    color: 'Biały',
    material: '100% len',
    fit: 'Relaxed fit',
    season: 'Wiosna/Lato',
    originCountry: 'Portugalia',
    sizeRange: 'S-XXL',
    features: ['Oddychająca tkanina', 'Guziki z masy perłowej'],
    careInstructions: ['Pranie delikatne 30C', 'Prasować parą'],
    measurements: {'Długość': '72 cm', 'Rękaw': '64 cm (M)'},
  ),
};

ProductDetailsSpec detailsForProduct(Product p) {
  return productDetailsById[p.id] ??
      ProductDetailsSpec(
        brand: 'SELLEKTYWNI Selected',
        collection: 'Core',
        sku: 'SEL-${p.id}',
        color: 'Mix',
        material: 'Materiały premium',
        fit: 'Standard',
        season: 'Całoroczny',
        originCountry: 'UE',
        sizeRange: 'Uniwersalny',
        features: const ['Limitowana selekcja', 'Weryfikacja jakości'],
        careInstructions: const ['Postępuj wg metki', 'Czyścić zgodnie z zaleceniami producenta'],
        measurements: const {'Informacja': 'Szczegóły wymiarów na życzenie'},
      );
}
