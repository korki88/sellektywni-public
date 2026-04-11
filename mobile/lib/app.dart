import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'layout/web_app_frame.dart';
import 'providers/cart_notifier.dart';
import 'screens/cart_screen.dart';
import 'screens/home_screen.dart';
import 'theme/app_theme.dart';

class SellektywniApp extends StatelessWidget {
  const SellektywniApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'SELLEKTYWNI',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light,
      home: const _RootShell(),
    );
  }
}

class _RootShell extends StatefulWidget {
  const _RootShell();

  @override
  State<_RootShell> createState() => _RootShellState();
}

class _RootShellState extends State<_RootShell> {
  int _index = 0;

  @override
  Widget build(BuildContext context) {
    final cartCount = context.watch<CartNotifier>().itemCount;

    return WebAppFrame(
      child: Scaffold(
        body: IndexedStack(
          index: _index,
          children: const [
            HomeScreen(),
            CartScreen(),
          ],
        ),
        bottomNavigationBar: NavigationBar(
          selectedIndex: _index,
          onDestinationSelected: (i) => setState(() => _index = i),
          destinations: [
            const NavigationDestination(
              icon: Icon(Icons.grid_view_outlined),
              selectedIcon: Icon(Icons.grid_view_rounded),
              label: 'Sklep',
            ),
            NavigationDestination(
              icon: _CartNavIcon(count: cartCount, selected: false),
              selectedIcon: _CartNavIcon(count: cartCount, selected: true),
              label: 'Koszyk',
            ),
          ],
        ),
      ),
    );
  }
}

class _CartNavIcon extends StatelessWidget {
  const _CartNavIcon({required this.count, required this.selected});

  final int count;
  final bool selected;

  @override
  Widget build(BuildContext context) {
    final icon = selected ? Icons.shopping_bag_rounded : Icons.shopping_bag_outlined;
    if (count <= 0) {
      return Icon(icon);
    }
    return Badge(
      label: Text('$count'),
      child: Icon(icon),
    );
  }
}
