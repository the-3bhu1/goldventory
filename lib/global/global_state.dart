import 'dart:developer' as developer;

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:goldventory/core/services/threshold_service.dart';
import 'package:goldventory/core/services/database_service.dart';
import 'package:goldventory/core/utils/helpers.dart';

/// Global scaffold messenger for app-wide snackbars
class GlobalScaffold {
  static final messengerKey = GlobalKey<ScaffoldMessengerState>();
}

/// Small global state that delegates threshold logic to ThresholdService.
/// Keep GlobalState focused on UI/global flags and expose the services for
/// threshold-specific operations.
class GlobalState extends ChangeNotifier {
  final DatabaseService databaseService;
  bool isDarkMode = false;

  GlobalState({required this.databaseService})
      : thresholds = ThresholdService(databaseService: databaseService);

  // Loading state
  bool _isLoading = true;

  bool get isLoading => _isLoading;

  void setLoading(bool value) {
    _isLoading = value;
    notifyListeners();
  }

  void toggleTheme() async {
    isDarkMode = !isDarkMode;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('isDarkMode', isDarkMode);
  }

  /// ThresholdService holds the nested thresholds and persistence logic.
  final ThresholdService thresholds;

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
  /// This is intentionally immutable once set, unless 'force' is true (migration).
  void setWeightModeFor({
    required String category,
    required String item,
    required bool isShared,
    bool force = false,
  }) {
    final key = _weightModeKey(category, item);

    if (_weightModes.containsKey(key) && !force) {
      // Do not allow silent mutation of mode once chosen unless forced
      developer.log(
        'WeightMode already set for $key, ignoring update (force=false)',
        name: 'GlobalState',
      );
      return;
    }

    _weightModes[key] = isShared;

    // Persist to thresholds metadata
    // __metadata -> shared_mode = 1 (true) or 0 (false)
    thresholds.setThreshold(
        category: category,
        item: item,
        subItem: '__metadata',
        weight: 'shared_mode',
        threshold: isShared ? 1 : 0);

    notifyListeners();
  }

  // ------------------------------
  // Thin forwarding helpers (convenience)
  // ------------------------------

  /// Get threshold for a specific path (category, item, optional subItem, weight)
  int? getThresholdFor(
      {required String category,
      required String item,
      String? subItem,
      required String weight}) {
    return thresholds.getThresholdFor(
        category: category, item: item, subItem: subItem, weight: weight);
  }

  /// Set threshold at explicit path and notify listeners
  void setThresholdFor(
      {required String category,
      required String item,
      String? subItem,
      required String weight,
      int? threshold}) {
    thresholds.setThreshold(
        category: category,
        item: item,
        subItem: subItem,
        weight: weight,
        threshold: threshold);
    notifyListeners();
  }

  /// Backwards-compat shim for callers that used a single-key setter. Not implemented.
  void setThresholdByKey(String key, int threshold) {
    developer.log(
        'setThresholdByKey is not implemented; key=$key threshold=$threshold',
        name: 'GlobalState');
  }

  void removeThresholdFor(
      {required String category,
      required String item,
      String? subItem,
      required String weight}) {
    thresholds.removeThreshold(
        category: category, item: item, subItem: subItem, weight: weight);
    notifyListeners();
  }

  /// Heuristic check — consider quantity below threshold if less than global default.
  /// For precise checks prefer using getThresholdFor(...) and comparing.
  bool isBelowThreshold(String key, int? quantity) {
    // No implicit thresholds anymore
    return false;
  }

  void clearThresholds() {
    thresholds.asNestedMap().clear();
    _weightModes.clear();
    notifyListeners();
  }

  // ------------------------------
  // Persistence hooks (delegated)
  // ------------------------------

  // -----------------
  // Schema Access
  // -----------------
  /// Get configured weights for a sub-item (Schema source of truth)
  List<String> getWeightsFor(
      {required String category,
      required String item,
      required String subItem}) {
    final catMap = thresholds.asNestedMap()[category];
    if (catMap == null) return [];
    final itemMap = catMap[item];
    if (itemMap == null) return [];

    final isShared = getWeightModeFor(category: category, item: item) == true;

    // 1. If Shared Mode, ALWAYS try the 'shared' master list first
    if (isShared) {
      final sharedMap = itemMap['shared'];
      if (sharedMap != null && sharedMap.isNotEmpty) {
        return sharedMap.keys
            .where((w) => w.isNotEmpty && !w.startsWith('__'))
            .toList()
          ..sort((a, b) => Helpers.safeNum(a).compareTo(Helpers.safeNum(b)));
      }
    }

    // 2. Otherwise (or if 'shared' was empty), get explicit weights for this sub-item
    final subMap = itemMap[subItem];
    final weights = subMap?.keys
            .where((w) => w.isNotEmpty && !w.startsWith('__'))
            .toList() ??
        [];

    // 3. Last Fallback: If Shared Mode and we still have nothing, search siblings
    if (weights.isEmpty && isShared) {
      for (final otherSub in itemMap.keys) {
        if (otherSub.startsWith('__') || otherSub == 'shared') continue;
        final otherWeights = itemMap[otherSub]
            ?.keys
            .where((w) => w.isNotEmpty && !w.startsWith('__'))
            .toList();
        if (otherWeights != null && otherWeights.isNotEmpty) {
          return otherWeights
            ..sort((a, b) => Helpers.safeNum(a).compareTo(Helpers.safeNum(b)));
        }
      }
    }

    return weights
      ..sort((a, b) => Helpers.safeNum(a).compareTo(Helpers.safeNum(b)));
  }

  // ------------------------------
  // Persistence hooks (delegated)
  // ------------------------------

  Future<void> loadThresholds() async {
    _isLoading = true;
    notifyListeners();

    // Load theme preference
    final prefs = await SharedPreferences.getInstance();
    isDarkMode = prefs.getBool('isDarkMode') ?? false;

    await thresholds.load();

    // Hydrate weight modes from metadata
    final map = thresholds.asNestedMap();
    _weightModes.clear();

    for (final cat in map.keys) {
      final items = map[cat];
      if (items == null) continue;
      for (final item in items.keys) {
        final val = thresholds.getThresholdFor(
            category: cat,
            item: item,
            subItem: '__metadata',
            weight: 'shared_mode');
        if (val != null) {
          _weightModes[_weightModeKey(cat, item)] = (val == 1);
        }
      }
    }

    _isLoading = false;
    notifyListeners();
  }

  Future<void> saveThresholds() async {
    await thresholds.save();
  }
}
