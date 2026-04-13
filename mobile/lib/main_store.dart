import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'layout/web_app_frame.dart';
import 'providers/app_navigation.dart';
import 'providers/auth_session.dart';
import 'providers/cart_notifier.dart';
import 'providers/wishlist_notifier.dart';
import 'screens/cart_screen.dart';
import 'screens/home_screen.dart';
import 'screens/user_account_screen.dart';

/// Sklep dla klienta i gościa (brak logowania). OWNER/STAFF po zalogowaniu widzą [AdminDashboard].
class MainStore extends StatefulWidget {
  const MainStore({super.key});

  @override
  State<MainStore> createState() => _MainStoreState();
}

class _MainStoreState extends State<MainStore> {
  int _index = 0;
  int _cartActivationTick = 0;
  int _accountActivationTick = 0;

  void _onDestinationSelected(int i) {
    setState(() {
      _index = i;
      if (i == 1) {
        _cartActivationTick++;
      } else if (i == 2) {
        _accountActivationTick++;
      }
    });
    if (i == 2) {
      context.read<AuthSession>().refreshProfile();
      context.read<WishlistNotifier>().load();
    }
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthSession>();
    final nav = context.watch<AppNavigation>();
    final showBackToPanel =
        auth.isAuthenticated && auth.isAdminDashboardRole && nav.staffViewingShop;

    return WebAppFrame(
      child: Scaffold(
        floatingActionButton: showBackToPanel
            ? FloatingActionButton.extended(
                onPressed: () =>
                    context.read<AppNavigation>().openAdminPanel(),
                icon: const Icon(Icons.admin_panel_settings_outlined),
                label: const Text('Panel'),
              )
            : null,
        body: IndexedStack(
          index: _index,
          children: [
            const HomeScreen(),
            CartScreen(activationTick: _cartActivationTick),
            UserAccountScreen(activationTick: _accountActivationTick),
          ],
        ),
        bottomNavigationBar: NavigationBar(
          selectedIndex: _index,
          onDestinationSelected: _onDestinationSelected,
          destinations: const [
            NavigationDestination(
              icon: Icon(Icons.grid_view_outlined),
              selectedIcon: Icon(Icons.grid_view_rounded),
              label: 'Sklep',
            ),
            NavigationDestination(
              icon: _CartNavIcon(selected: false),
              selectedIcon: _CartNavIcon(selected: true),
              label: 'Koszyk',
            ),
            NavigationDestination(
              icon: Icon(Icons.person_outline),
              selectedIcon: Icon(Icons.person),
              label: 'Konto',
            ),
          ],
        ),
      ),
    );
  }
}

class _CartNavIcon extends StatelessWidget {
  const _CartNavIcon({required this.selected});

  final bool selected;

  @override
  Widget build(BuildContext context) {
    final realCount = context.watch<CartNotifier>().itemCount;
    final icon =
        selected ? Icons.shopping_bag_rounded : Icons.shopping_bag_outlined;
    if (realCount <= 0) {
      return Icon(icon);
    }
    return Badge(
      label: Text('$realCount'),
      child: Icon(icon),
    );
  }
}
