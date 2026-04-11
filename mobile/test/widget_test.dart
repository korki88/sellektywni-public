import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:sellektywni_shop/app.dart';
import 'package:sellektywni_shop/providers/auth_session.dart';
import 'package:sellektywni_shop/providers/cart_notifier.dart';
import 'package:sellektywni_shop/providers/catalog_filter_notifier.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('SELLEKTYWNI app smoke test', (WidgetTester tester) async {
    SharedPreferences.setMockInitialValues({});
    final auth = AuthSession();
    await auth.init();

    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider(create: (_) => CatalogFilterNotifier()),
          ChangeNotifierProvider(create: (_) => CartNotifier()),
          ChangeNotifierProvider<AuthSession>.value(value: auth),
        ],
        child: const SellektywniApp(),
      ),
    );

    await tester.pump();

    expect(find.text('SELLEKTYWNI'), findsOneWidget);
  });
}
