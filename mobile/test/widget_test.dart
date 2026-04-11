import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:sellektywni_shop/app.dart';
import 'package:sellektywni_shop/providers/cart_notifier.dart';
import 'package:sellektywni_shop/providers/catalog_filter_notifier.dart';

void main() {
  testWidgets('SELLEKTYWNI app smoke test', (WidgetTester tester) async {
    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider(create: (_) => CatalogFilterNotifier()),
          ChangeNotifierProvider(create: (_) => CartNotifier()),
        ],
        child: const SellektywniApp(),
      ),
    );

    expect(find.text('SELLEKTYWNI'), findsOneWidget);
  });
}
