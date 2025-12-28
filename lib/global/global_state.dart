import 'dart:developer' as developer;
import 'package:cloud_firestore/cloud_firestore.dart';
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
    
    // Persist to thresholds metadata
    // __metadata -> shared_mode = 1 (true) or 0 (false)
    thresholds.setThreshold(
      category: category, 
      item: item, 
      subItem: '__metadata', 
      weight: 'shared_mode', 
      threshold: isShared ? 1 : 0
    );

    // Sync to inventory collection (mirrored structure)
    // MUST use safe keys to avoid crashes on iOS if keys have '.' or '/'
    String safeKey(String k) => k.replaceAll('.', '_').replaceAll('/', '_');
    
    FirebaseFirestore.instance.collection('inventory').doc(safeKey(category)).set({
      safeKey(item): {
        '__metadata': {
          'shared_mode': isShared ? 1 : 0
        }
      }
    }, SetOptions(merge: true));
    
    notifyListeners();
  }

  // ------------------------------
  // Thin forwarding helpers (convenience)
  // ------------------------------

  /// Get threshold for a specific path (category, item, optional subItem, weight)
  int? getThresholdFor({required String category, required String item, String? subItem, required String weight}) {
    return thresholds.getThresholdFor(category: category, item: item, subItem: subItem, weight: weight);
  }

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
  List<String> getWeightsFor({
    required String category, 
    required String item, 
    required String subItem
  }) {
    final catMap = thresholds.asNestedMap()[category];
    if (catMap == null) return [];
    final itemMap = catMap[item];
    if (itemMap == null) return [];
    
    final subMap = itemMap[subItem];
    
    // 1. Get explicit weights (if any)
    final explicitKeys = subMap?.keys
        .where((w) => w.isNotEmpty && !w.startsWith('__'))
        .toList() ?? [];
        
    // 2. If explicit weights found, return them
    if (explicitKeys.isNotEmpty) return explicitKeys;

    // 3. Fallback: If Shared Mode, look for schema from siblings
    final isShared = getWeightModeFor(category: category, item: item) == true;
    if (isShared) {
      // Find a "donor" subitem that has weights
      for (final otherSub in itemMap.keys) {
        if (otherSub.startsWith('__')) continue; 
        final otherWeights = itemMap[otherSub];
        
        final donorKeys = otherWeights?.keys
            .where((w) => w.isNotEmpty && !w.startsWith('__'))
            .toList();
            
        if (donorKeys != null && donorKeys.isNotEmpty) {
           return donorKeys;
        }
      }
    }
    
    return [];
  }

  // ------------------------------
  // Persistence hooks (delegated)
  // ------------------------------
  
  Future<void> loadThresholds() async {
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
          weight: 'shared_mode'
        );
        if (val != null) {
          _weightModes[_weightModeKey(cat, item)] = (val == 1);
        }
      }
    }
    
    notifyListeners();
  }

  Future<void> saveThresholds() async {
    await thresholds.save();
  }
}