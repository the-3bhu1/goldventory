import 'dart:developer' as developer;
import 'package:flutter/material.dart';
import 'package:goldventory/core/services/threshold_service.dart';

/// Global scaffold messenger for app-wide snackbars
class GlobalScaffold {
  static final messengerKey = GlobalKey<ScaffoldMessengerState>();
}

/// Small global state that delegates threshold logic to ThresholdService.
/// Keep GlobalState focused on UI/global flags and expose the services for
/// threshold-specific operations.
class GlobalState extends ChangeNotifier {
  bool isDarkMode = false;

  // Loading state
  bool _isLoading = false;

  // Bulk update mode flag
  bool _isBulkUpdating = false;
  bool get isBulkUpdating => _isBulkUpdating;

  void setBulkUpdating(bool value) {
    _isBulkUpdating = value;
    notifyListeners();
  }

  bool get isLoading => _isLoading;

  void setLoading(bool value) {
    _isLoading = value;
    notifyListeners();
  }

  void toggleTheme() {
    isDarkMode = !isDarkMode;
    notifyListeners();
    // TODO: persist theme
  }

  /// ThresholdService holds the nested thresholds and persistence logic.
  final ThresholdService thresholds = ThresholdService();

  /// Stores weight mode per (category|item).
  /// true  = shared weights
  /// false = per-subitem weights
  final Map<String, bool> _weightModes = {};

  String _weightModeKey(String category, String item) => '$category|$item';

  bool? getWeightModeFor({
    required String category,
    required String item,
  }) {
    return _weightModes[_weightModeKey(category, item)];
  }

  /// Persist weight mode selection for a category+item.
  /// This is intentionally immutable once set.
  void setWeightModeFor({
    required String category,
    required String item,
    required bool isShared,
  }) {
    final key = _weightModeKey(category, item);

    if (_weightModes.containsKey(key)) {
      // Do not allow silent mutation of mode once chosen
      developer.log(
        'WeightMode already set for $key, ignoring update',
        name: 'GlobalState',
      );
      return;
    }

    _weightModes[key] = isShared;
    notifyListeners();
  }

  // ------------------------------
  // Thin forwarding helpers (convenience)
  // ------------------------------

  int get defaultThreshold => thresholds.defaultThreshold;

  /// Simple fallback getter — returns global default when a direct lookup isn't possible.
  int getThreshold(String key) => defaultThreshold;

  /// Get threshold for a specific path (category, item, optional subItem, weight)
  int getThresholdFor({required String category, required String item, String? subItem, required String weight}) =>
      thresholds.getThresholdFor(category: category, item: item, subItem: subItem, weight: weight);

  /// Set threshold at explicit path and notify listeners
  void setThresholdFor({required String category, required String item, String? subItem, required String weight, required int threshold}) {
    thresholds.setThreshold(category: category, item: item, subItem: subItem, weight: weight, threshold: threshold);
    notifyListeners();
  }

  /// Backwards-compat shim for callers that used a single-key setter. Not implemented.
  void setThresholdByKey(String key, int threshold) {
    developer.log('setThresholdByKey is not implemented; key=$key threshold=$threshold', name: 'GlobalState');
  }

  void removeThresholdFor({required String category, required String item, String? subItem, required String weight}) {
    thresholds.removeThreshold(category: category, item: item, subItem: subItem, weight: weight);
    notifyListeners();
  }

  /// Heuristic check — consider quantity below threshold if less than global default.
  /// For precise checks prefer using getThresholdFor(...) and comparing.
  bool isBelowThreshold(String key, int? quantity) => quantity != null && quantity < defaultThreshold;

  void clearThresholds() {
    thresholds.asNestedMap().clear();
    _weightModes.clear();
    notifyListeners();
  }

  // ------------------------------
  // Persistence hooks (delegated)
  // ------------------------------

  Future<void> loadThresholds() async {
    await thresholds.load();
    notifyListeners();
  }

  Future<void> saveThresholds() async {
    await thresholds.save();
  }
}