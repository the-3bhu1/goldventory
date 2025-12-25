import 'dart:async';
import 'package:flutter/material.dart';
import 'package:goldventory/global/global_state.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

enum WeightMode { shared, perSubItem }
const String kSharedSubItem = 'shared';

void _assertNotShared(String subItem) {
  assert(subItem != kSharedSubItem,
  'BUG: `shared` must never be treated as a real subItem');
}

String _encodeKey(String raw) {
  // Firestore map keys cannot contain '.', '/', or be empty
  // Matches ThresholdService._safeKey logic
  final k = raw.trim();
  if (k.isEmpty) return '__default';
  return k.replaceAll('.', '_').replaceAll('/', '_');
}

/// SettingsViewModel (Option B extended for subItem support)
///
/// Local editable copy now supports nested shape:
///   category -> item -> subItem -> weight -> threshold
/// and exposes convenience methods for subItem and item-level shared weights.
class SettingsViewModel extends ChangeNotifier {
  final GlobalState globalState;

  /// Local editable copy: category -> item -> subItem -> weight -> threshold
  final Map<String, Map<String, Map<String, Map<String, int>>>> _local = {};

  /// Tracks whether local changes differ from global
  bool _dirty = false;
  bool get dirty => _dirty;

  final Map<String, Map<String, WeightMode>> _weightModes = {};

  WeightMode? weightModeFor(String category, String item) {
    return _weightModes[category]?[item];
  }

  void setWeightMode(String category, String item, WeightMode mode) {
    _weightModes.putIfAbsent(category, () => {});
    // Lock-once semantics: do not allow changing mode once set
    if (_weightModes[category]!.containsKey(item)) return;
    _weightModes[category]![item] = mode;
    _dirty = true;
    notifyListeners();
  }

  SettingsViewModel({required this.globalState});

  // -----------------
  // Loading / discard
  // -----------------
  /// Load a deep copy of thresholds from global state into local buffer.
  Future<void> load() async {
    Future.microtask(() {
      globalState.setLoading(true);
    });

    try {
      await globalState.loadThresholds();

      _local.clear();
      final source = globalState.thresholds.asNestedMap();

      source.forEach((cat, items) {
        final Map<String, Map<String, Map<String, int>>> itemCopy = {};
        items.forEach((item, subMap) {
          final Map<String, Map<String, int>> subCopy = {};
          subMap.forEach((subItem, weights) {
            subCopy[subItem] = Map<String, int>.from(weights);
          });
          itemCopy[item] = subCopy;
        });
        _local[cat] = itemCopy;
      });

      _dirty = false;
    } finally {
      Future.microtask(() {
        globalState.setLoading(false);
      });
      notifyListeners();
    }
  }

  /// Discard local edits and reload from global
  Future<void> discard() async {
    await load();
  }

  // -----------------
  // Read helpers
  // -----------------
  List<String> get categories {
    final keys = _local.keys.toList();
    keys.sort();
    return keys;
  }

  List<String> itemsFor(String category) {
    final m = _local[category];
    if (m == null) return [];
    final keys = m.keys.toList()..sort();
    return keys;
  }

  List<String> subItemsFor(String category, String item) {
    final itemMap = _local[category]?[item];
    if (itemMap == null) return [];

    final keys = itemMap.keys
        .where((k) => k != kSharedSubItem && !k.startsWith('__'))
        .toList();

    keys.sort(_subItemComparator);
    return keys;
  }

  /// Explicit settings-only accessor used by weight & threshold flows.
  /// SubItems are authoritative ONLY in Settings.
  List<String> settingsSubItemsFor(String category, String item) {
    final subs = subItemsFor(category, item).where((s) => s != kSharedSubItem).toList();
    subs.sort();
    return subs;
  }

  /// Returns weights map for specific subItem. Use subItem = '' for item-level weights.
  Map<String, int> weightsFor(String category, String item, {required String subItem}) {
    final itemMap = _local[category]?[item];
    if (itemMap == null) return {};
    final wmap = itemMap[subItem];
    if (wmap == null) return {};
    return Map<String, int>.from(wmap);
  }

  /// Returns list of weights configured for a specific subItem under an item.
  /// Used by ItemWeightsEditor to restore persisted state.
  List<String> weightsForSubItem(String category, String item, String subItem) {
    final itemMap = _local[category]?[item];
    if (itemMap == null) return [];
    final weights = itemMap[subItem];
    if (weights == null) return [];

    final list = weights.keys.cast<String>().toList();
    list.sort((a, b) {
      final ia = int.tryParse(a);
      final ib = int.tryParse(b);
      if (ia != null && ib != null) return ia.compareTo(ib);
      return a.compareTo(b);
    });
    return list;
  }

  int? thresholdFor({
    required String category,
    required String item,
    required String subItem,
    required String weight,
  }) {
    return _local[category]?[item]?[subItem]?[weight];
  }

  List<String> weightsForItem(String category, String item) {
    final itemMap = _local[category]?[item];
    if (itemMap == null) return [];

    final weights = <String>{};
    for (final subMap in itemMap.values) {
      weights.addAll(subMap.keys);
    }

    final list = weights.toList()..sort();
    return list;
  }

  int defaultThreshold() => globalState.defaultThreshold;

  // -----------------
  // Write helpers (local only)
  // -----------------
  void _ensureCategoryItemSub(String category, String item, String subItem) {
    _local.putIfAbsent(category, () => {});
    _local[category]!.putIfAbsent(item, () => {});
    _local[category]![item]!.putIfAbsent(subItem, () => {});
  }

  Future<void> _ensureInventoryPath({
    required String category,
    required String item,
    required String subItem,
    String? weight,
  }) async {
    final db = FirebaseFirestore.instance;
    final safeCat = _encodeKey(category);
    final docRef = db.collection('inventory').doc(safeCat);

    // Firestore does NOT allow empty map keys
    final safeSubItem = _encodeKey(subItem);

    // Build nested merge payload
    Map<String, dynamic> payload;
    if (weight == null) {
      payload = {
        _encodeKey(item): {
          safeSubItem: {},
        },
      };
    } else {
      final safeWeight = _encodeKey(weight);
      payload = {
        _encodeKey(item): {
          safeSubItem: {
            safeWeight: 0,
          },
        },
      };
    }

    await docRef.set(payload, SetOptions(merge: true));
  }

  /// Set threshold in local buffer for category/item/subItem/weight
  /// subItem defaults to '' (item-level)
  void setThreshold({
    required String category,
    required String item,
    required String subItem,
    required String weight,
    required int threshold,
  }) {
    if (category.trim().isEmpty ||
        item.trim().isEmpty ||
        weight.trim().isEmpty ||
        threshold < 0) {
      return;
    }

    _ensureCategoryItemSub(category, item, subItem);
    _local[category]![item]![subItem]![weight] = threshold;
    unawaited(_ensureInventoryPath(
      category: category,
      item: item,
      subItem: subItem,
      weight: weight,
    ));
    _dirty = true;
    notifyListeners();

    // persist immediately so changes survive navigation
    unawaited(_commit());
  }

  /// Remove a weight threshold locally. If subItem becomes empty remove it too.
  void removeThreshold({
    required String category,
    required String item,
    required String subItem,
    required String weight,
  }) {
    final cat = _local[category];
    if (cat == null) return;
    final itemMap = cat[item];
    if (itemMap == null) return;
    final subMap = itemMap[subItem];
    if (subMap == null) return;

    subMap.remove(weight);
    if (subMap.isEmpty) {
      itemMap.remove(subItem);
    }
    if (itemMap.isEmpty) {
      cat.remove(item);
    }
    if (cat.isEmpty) {
      _local.remove(category);
    }

    _dirty = true;
    notifyListeners();

    unawaited(
      FirebaseFirestore.instance
          .collection('inventory')
          .doc(category)
          .set({}, SetOptions(merge: true)),
    );

    unawaited(_commit());
  }

  /// Create a new category locally. If it already exists this is a no-op.
  void createCategory(String category) {
    _local.putIfAbsent(category, () => {});
    _dirty = true;
    notifyListeners();

    unawaited(_commit());
  }

  /// Private helper for deleting a node from a parent map and triggering state updates
  void _deleteNode({
    required Map<String, dynamic> parent,
    required String key,
  }) {
    if (!parent.containsKey(key)) return;

    parent.remove(key);
    _dirty = true;
    notifyListeners();
    unawaited(_commit());
  }

  /// Remove a category locally
  void removeCategory(String category) {
    _deleteNode(parent: _local, key: category);
  }

  /// Rename a category while preserving all nested items, subItems and thresholds
  void renameCategory(String oldName, String newName) {
    _renameNode(
      parent: _local,
      oldName: oldName,
      newName: newName,
    );
  }

  /// Rename an item within a category while preserving all subItems and thresholds
  void renameItem(String category, String oldName, String newName) {
    final catMap = _local[category];
    if (catMap == null) return;

    _renameNode(
      parent: catMap,
      oldName: oldName,
      newName: newName,
    );
  }

  /// Rename a subItem within an item, preserving weights and thresholds
  void renameSubItem(
    String category,
    String item,
    String oldName,
    String newName,
  ) {
    _assertNotShared(oldName);

    final itemMap = _local[category]?[item];
    if (itemMap == null) return;

    _renameNode(
      parent: itemMap,
      oldName: oldName,
      newName: newName,
    );
  }

  /// Private helper for renaming a key in a nested map and triggering state updates
  void _renameNode({
    required Map<String, dynamic> parent,
    required String oldName,
    required String newName,
  }) {
    assert(oldName.trim().isNotEmpty);
    assert(newName.trim().isNotEmpty);
    if (oldName == newName) return;

    final existing = parent[oldName];
    if (existing == null) return;

    assert(!parent.containsKey(newName), 'Target already exists');

    parent[newName] = existing;
    parent.remove(oldName);

    _dirty = true;
    notifyListeners();
    unawaited(_commit());
  }

  /// Create a new item under a category. Do NOT create a default subItem.
  /// The client should explicitly create sub-items using createSubItem().
  void createItem(String category, String item, {int? threshold}) {
    _local.putIfAbsent(category, () => {});
    // create the item entry as an empty map of subItems — no default subItem created
    _local[category]!.putIfAbsent(item, () => {});
    _dirty = true;
    notifyListeners();

    unawaited(_ensureInventoryPath(
      category: category,
      item: item,
      subItem: '',
    ));

    // Persist immediately
    unawaited(_commit());
  }

  /// Create a subItem under an existing item
  void createSubItem(String category, String item, String subItem) {
    assert(category.trim().isNotEmpty);
    assert(item.trim().isNotEmpty);
    assert(subItem.trim().isNotEmpty);
    _assertNotShared(subItem);

    _ensureCategoryItemSub(category, item, subItem);
    _dirty = true;
    notifyListeners();

    unawaited(_ensureInventoryPath(
      category: category,
      item: item,
      subItem: subItem,
    ));

    unawaited(_commit());

    // Force immediate availability for threshold UI
    notifyListeners();
  }

  /// Remove an item and all its subItems
  void deleteItem(String category, String item) {
    final catMap = _local[category];
    if (catMap == null) return;

    _deleteNode(parent: catMap, key: item);

    if (catMap.isEmpty) {
      _local.remove(category);
    }
  }

  void clearWeightsForItem(String category, String item) {
    final itemMap = _local[category]?[item];
    if (itemMap == null) return;
    for (final sub in itemMap.keys) {
      itemMap[sub]?.clear();
    }
    _dirty = true;
    notifyListeners();
    unawaited(_commit());
  }

  /// Remove only a subItem under an item
  void deleteSubItem(String category, String item, String subItem) {
    _assertNotShared(subItem);

    final itemMap = _local[category]?[item];
    if (itemMap == null) return;

    _deleteNode(parent: itemMap, key: subItem);

    if (itemMap.isEmpty) {
      _local[category]?.remove(item);
    }
    if (_local[category]?.isEmpty ?? false) {
      _local.remove(category);
    }

    final safeCat = _encodeKey(category);
    final safeItem = _encodeKey(item);
    final safeSub = _encodeKey(subItem);

    FirebaseFirestore.instance
        .collection('inventory')
        .doc(safeCat)
        .set({
          safeItem: {
            safeSub: FieldValue.delete(),
          }
        }, SetOptions(merge: true));
  }

  /// Set item-level shared weights (delegates to ThresholdService via GlobalState)
  void setItemSharedWeights(String category, String item, List<String> weights) {
    // Ensure local structure exists
    _ensureCategoryItemSub(category, item, kSharedSubItem);

    // Clear existing shared weights locally
    _local[category]![item]![kSharedSubItem]!.clear();

    // Add shared weights locally with default threshold
    for (final w in weights) {
      final key = w.trim();
      if (key.isNotEmpty) {
        _local[category]![item]![kSharedSubItem]![key] = defaultThreshold();
      }
    }

    // Persist via GlobalState (single source of truth)
    globalState.thresholds.setItemSharedWeights(category, item, weights);

    _dirty = true;
    notifyListeners();

    // Persist immediately so UI navigation does not lose state
    unawaited(_commit());
  }

  /// Remove item-level shared weights
  void removeItemSharedWeights(String category, String item) {
    final itemMap = _local[category]?[item];
    if (itemMap != null) {
      itemMap.remove(kSharedSubItem);
    }

    globalState.thresholds.removeItemSharedWeights(category, item);

    _dirty = true;
    notifyListeners();

    unawaited(_commit());
  }

  /// Set weights for a specific subItem under an item.
  /// This is used when WeightMode == perSubItem.
  void setItemWeightsForSubItem(
    String category,
    String item,
    String subItem,
    List<String> weights,
  ) {
    assert(category.trim().isNotEmpty);
    assert(item.trim().isNotEmpty);
    assert(subItem.trim().isNotEmpty);
    _assertNotShared(subItem);

    // Ensure local structure exists
    _ensureCategoryItemSub(category, item, subItem);

    // Clear existing weights for this subItem
    _local[category]![item]![subItem]!.clear();

    // Add weights with default threshold
    for (final w in weights) {
      final key = w.trim();
      if (key.isNotEmpty) {
        _local[category]![item]![subItem]![key] = defaultThreshold();
      }
    }

    _dirty = true;
    notifyListeners();

    // Persist immediately so thresholds unlock without navigation
    unawaited(_commit());
  }

  List<String> sharedWeightsForItem(String category, String item) {
    final itemMap = _local[category]?[item];
    if (itemMap == null) return [];
    final shared = itemMap[kSharedSubItem];
    if (shared == null) return [];
    final list = shared.keys.toList()..sort();
    return list;
  }

  Map<String, List<String>> weightsForItemBySubItem(String category, String item) {
    final itemMap = _local[category]?[item];
    if (itemMap == null) return {};
    final result = <String, List<String>>{};
    itemMap.forEach((subItem, weights) {
      if (subItem == kSharedSubItem) return;
      final list = weights.keys.toList()..sort();
      if (list.isNotEmpty) {
        result[subItem] = list;
      }
    });
    return result;
  }

  // -----------------
  // Validation helpers
  // -----------------
  bool isValidThresholdValue(String value) => int.tryParse(value.trim()) != null;

  // -----------------
  // Commit (save)
  // -----------------
  /// Internal helper to push the local buffer into GlobalState and persist it.
  Future<void> _commit() async {
    // Validate no illegal empty subItems or weights exist
    _local.forEach((cat, items) {
      if (cat.trim().isEmpty) return;
      items.forEach((item, subMap) {
        if (item.trim().isEmpty) return;
        subMap.forEach((subItem, weights) {
          // allow '' subItem for item-level shared weights
          weights.removeWhere((w, _) => w.trim().isEmpty);
        });
      });
    });

    // Overwrite GlobalState thresholds with local copy
    globalState.clearThresholds();

    // Persist weight modes
    _weightModes.forEach((cat, items) {
      items.forEach((item, mode) {
        globalState.setWeightModeFor(
          category: cat,
          item: item,
          isShared: mode == WeightMode.shared,
        );
      });
    });

    // Write local nested map into global state
    _local.forEach((cat, items) {
      items.forEach((item, subMap) {
        subMap.forEach((subItem, weights) {
          if (subItem == kSharedSubItem) return;
          weights.forEach((w, val) {
            globalState.setThresholdFor(category: cat, item: item, subItem: subItem, weight: w, threshold: val);
          });
        });
      });
    });

    // Persist to Firestore via GlobalState
    await globalState.saveThresholds();

    _dirty = false;
    notifyListeners();
  }
}

int _subItemComparator(String a, String b) {
  final reg = RegExp(r'^(\d+)');
  final ma = reg.firstMatch(a);
  final mb = reg.firstMatch(b);

  if (ma != null && mb != null) {
    return int.parse(ma.group(1)!).compareTo(int.parse(mb.group(1)!));
  }
  if (ma != null) return -1;
  if (mb != null) return 1;
  return a.compareTo(b);
}