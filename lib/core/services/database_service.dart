import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

enum DatabaseFlavor {
  prod,
  dev,
}

class DatabaseService extends ChangeNotifier {
  static const String _flavorKey = 'db_flavor';
  static const String _devModeKey = 'dev_mode_active';

  DatabaseFlavor _flavor = DatabaseFlavor.prod;
  bool _isDevModeActive = false;
  int _versionTapCount = 0;
  DateTime? _lastTapTime;

  DatabaseFlavor get flavor => _flavor;
  bool get isDevModeActive => _isDevModeActive;

  DatabaseService();

  Future<void> init() async {
    final prefs = await SharedPreferences.getInstance();
    final savedFlavor = prefs.getString(_flavorKey);
    if (savedFlavor != null) {
      _flavor = DatabaseFlavor.values.firstWhere(
        (e) => e.toString() == savedFlavor,
        orElse: () => DatabaseFlavor.prod,
      );
    }
    _isDevModeActive = prefs.getBool(_devModeKey) ?? false;
  }

  Future<void> setFlavor(DatabaseFlavor flavor) async {
    if (_flavor == flavor) return;
    _flavor = flavor;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_flavorKey, flavor.toString());
    notifyListeners();
  }

  Future<void> setDevModeActive(bool active) async {
    if (_isDevModeActive == active) return;
    _isDevModeActive = active;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_devModeKey, active);
    notifyListeners();
  }

  void recordVersionTap() {
    final now = DateTime.now();
    if (_lastTapTime == null ||
        now.difference(_lastTapTime!) > const Duration(seconds: 2)) {
      _versionTapCount = 1;
    } else {
      _versionTapCount++;
    }
    _lastTapTime = now;

    if (_versionTapCount >= 3) {
      setDevModeActive(true);
      _versionTapCount = 0;
    }
  }

  String get inventoryCollection =>
      _flavor == DatabaseFlavor.dev ? 'dev_inventory' : 'inventory';
  String get ordersCollection =>
      _flavor == DatabaseFlavor.dev ? 'dev_orders' : 'orders';
  String get thresholdsCollection =>
      _flavor == DatabaseFlavor.dev ? 'dev_thresholds' : 'thresholds';
}
