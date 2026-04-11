import 'package:flutter/foundation.dart';

/// OWNER/STAFF: przełączenie między [AdminDashboard] a [MainStore] (sklep).
class AppNavigation extends ChangeNotifier {
  bool _staffViewingShop = false;

  bool get staffViewingShop => _staffViewingShop;

  void openShop() {
    if (_staffViewingShop) return;
    _staffViewingShop = true;
    notifyListeners();
  }

  void openAdminPanel() {
    if (!_staffViewingShop) return;
    _staffViewingShop = false;
    notifyListeners();
  }

  void resetAfterLogout() {
    _staffViewingShop = false;
    notifyListeners();
  }
}
