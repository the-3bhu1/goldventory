import 'dart:async';
import 'dart:developer' as developer;
import 'package:flutter/material.dart';
import 'package:goldventory/global/global_state.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

enum WeightMode { shared, perSubItem }

String _encodeKey(String raw) {
  // Firestore map keys cannot contain '.' or '/'
  // Empty keys are NOT allowed by design
  final k = raw.trim();
  assert(k.isNotEmpty, 'BUG: empty Firestore key is not allowed');
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
  final Map<String, Map<String, Map<String, Map<String, int?>>>> _local = {};

  /// Tracks whether local changes differ from global
  bool _dirty = false;
  bool get dirty => _dirty;

  bool _disposed = false;

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

  SettingsViewModel({required this.globalState}) {
    globalState.addListener(_onGlobalStateChanged);
  }

  @override
  void dispose() {
    globalState.removeListener(_onGlobalStateChanged);
    _disposed = true;
    super.dispose();
  }

  void _onGlobalStateChanged() {
    if (_disposed) return;
    // If GlobalState finished loading and we are empty, hydrate.
    if (!globalState.isLoading && _local.isEmpty && globalState.thresholds.asNestedMap().isNotEmpty) {
      _hydrateFromGlobal();
      notifyListeners();
    }
  }

  // -----------------
  // Loading / discard
  // -----------------
  /// Load a deep copy of thresholds from global state into local buffer.
  Future<void> load() async {
    developer.log('SettingsViewModel.load() STARTED', name: 'SettingsVM');
    
    // 1. If _local is already populated, DO NOT RELOAD.
    //    This assumes SettingsViewModel is long-lived or we want to preserve edits.
    //    Since we want to fix "Temporary Blankness", we trust the existing _local state.
    if (_local.isNotEmpty) {
      developer.log('SettingsViewModel.load() SKIPPED: _local already populated with ${_local.length} categories.', name: 'SettingsVM');
      return;
    }

    // 2. Always hydrate from in-memory GlobalState first (Fast, Synchronous, Fresh)
    if (globalState.thresholds.asNestedMap().isNotEmpty) {
      _hydrateFromGlobal();
      developer.log('SettingsViewModel.load() hydrated from existing GlobalState', name: 'SettingsVM');
    }

    // 3. Only fetch from Firestore if GlobalState is empty and not already loading.
    if (globalState.thresholds.asNestedMap().isEmpty && !globalState.isLoading) {
       developer.log('SettingsViewModel.load() fetching from Firestore...', name: 'SettingsVM');
       Future.microtask(() {
         globalState.setLoading(true);
       });

       try {
         await globalState.loadThresholds();
         _hydrateFromGlobal();
       } finally {
         Future.microtask(() {
           globalState.setLoading(false);
         });
         notifyListeners();
       }
    } else {
      notifyListeners();
    }
  }

  void _hydrateFromGlobal() {
      _local.clear();
      developer.log('SettingsViewModel.load() CLEARED _local', name: 'SettingsVM');
      final source = globalState.thresholds.asNestedMap();

      source.forEach((cat, items) {
        final Map<String, Map<String, Map<String, int?>>> itemCopy = {};
        items.forEach((item, subMap) {
          final Map<String, Map<String, int?>> subCopy = {};
          subMap.forEach((subItem, weights) {
            final out = <String, int?>{};
            weights.forEach((w, v) {
              out[w.toString()] = v is int ? v : null;
            });
                      subCopy[subItem] = out;
          });
          itemCopy[item] = subCopy;
        });
        _local[cat] = itemCopy;
      });
      developer.log('SettingsViewModel.load() POPULATED _local with ${_local.length} categories', name: 'SettingsVM');

      // Restore persisted weight modes from GlobalState
      _weightModes.clear();
      for (final cat in _local.keys) {
        final items = _local[cat]!;
        for (final item in items.keys) {
          final isShared = globalState.getWeightModeFor(
            category: cat,
            item: item,
          );
          if (isShared != null) {
            _weightModes.putIfAbsent(cat, () => {});
            _weightModes[cat]![item] =
                isShared ? WeightMode.shared : WeightMode.perSubItem;
          }
        }
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
    // keys.sort(); // Removed to preserve insertion order
    return keys;
  }

  List<String> itemsFor(String category) {
    final m = _local[category];
    if (m == null) return [];
    
    // keys.sort(); // Removed
    // Filter out metadata fields (e.g. __item_order)
    return m.keys.where((k) => !k.startsWith('__')).toList();
  }

  List<String> subItemsFor(String category, String item) {
    final itemMap = _local[category]?[item];
    if (itemMap == null) return [];

    // Preserve insertion order exactly as stored
    // Filter out metadata fields (e.g. __metadata, __item_order etc)
    return itemMap.keys.where((k) => !k.startsWith('__')).toList();
  }

  /// Explicit settings-only accessor used by weight & threshold flows.
  /// SubItems are authoritative ONLY in Settings.
  List<String> settingsSubItemsFor(String category, String item) {
    return subItemsFor(category, item);
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

    // 0. If Shared Mode, perform Smart Inheritance check
    final mode = weightModeFor(category, item);
    final isShared = mode == WeightMode.shared;

    // 1. Get explicit weights (if any)
    final explicitList = weights.keys.cast<String>().toList();

    // 2. If Shared Mode AND explicit list is empty (or we just want to be robust), lookup schema from siblings
    if (isShared && explicitList.isEmpty) {
      // Find a "donor" subitem that has weights
      for (final otherSub in itemMap.keys) {
        if (otherSub.startsWith('__')) continue; // skip metadata
        final otherWeights = itemMap[otherSub];
        if (otherWeights != null && otherWeights.isNotEmpty) {
           return otherWeights.keys.cast<String>().toList();
        }
      }
    }

    return explicitList;
  }

  int? thresholdFor({
    required String category,
    required String item,
    required String subItem,
    required String weight,
  }) {
    // 1. Try local
    final val = _local[category]?[item]?[subItem]?[weight];
    if (val != null) return val;

    // 2. Fallback / Self-Repair: Check GlobalState
    // If _local is missing data that GlobalState has, we define GlobalState as truth (for display).
    // This catches cases where _local might have been accidentally cleared or failed to hydrate.
    final globalVal = globalState.getThresholdFor(
      category: category,
      item: item,
      subItem: subItem,
      weight: weight,
    );

    if (globalVal != null) {
      developer.log('SettingsViewModel.thresholdFor REPAIRED local miss for $subItem/$weight -> $globalVal', name: 'SettingsVM');
      // Repair local silently
      _ensureCategoryItemSub(category, item, subItem);
      _local[category]![item]![subItem]![weight] = globalVal;
      return globalVal;
    }

    return null;
  }

  List<String> weightsForItem(String category, String item) {
    final itemMap = _local[category]?[item];
    if (itemMap == null) return [];

    final weights = <String>{};
    for (final subMap in itemMap.values) {
      weights.addAll(subMap.keys);
    }

    final list = weights.toList(); // ..sort(); // Removed
    return list;
  }


  // -----------------
  // Write helpers (local only)
  // -----------------
  void _ensureCategoryItemSub(String category, String item, String subItem) {
    _local.putIfAbsent(category, () => {});
    _local[category]!.putIfAbsent(item, () => {});
    _local[category]![item]!.putIfAbsent(subItem, () => {});
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
    // unawaited(_ensureInventoryPath(...)); // REMOVED: No more writes to inventory from Settings
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
     
    // Update GlobalState (Preserving Order)
    globalState.thresholds.renameCategory(oldName, newName);
    
    // Explicitly rename the Persistence Document via delete-then-create transaction or similar?
    // Firestore doesn't support "rename collection/doc".
    // Since we are changing the ID, we must read-copy-delete.
    // However, `save()` handles writing the new data.
    // We just need to delete the old data.
    // BUT we must also migrate the INVENTORY data.
    
    // For Category rename, it's expensive (move all docs). 
    // Implementing Inventory Migration for Category is complex.
    // Given the user report was about SubItems, let's focus on that first, 
    // but at least clean up the old Threshold doc.
    
    final safeOld = _encodeKey(oldName);
    FirebaseFirestore.instance.collection('thresholds').doc(safeOld).delete();
    
    
    // TODO: Migrate Inventory Collection for this category?
    // This is a heavy operation. Leaving as-is for now unless requested.
    
    unawaited(_commit());
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
    
    // Update GlobalState (Preserving Order)
    globalState.thresholds.renameItem(category, oldName, newName);

    // Remove old key from Firestore (thresholds)
    // We rely on save() to write the new key.
    final safeCat = _encodeKey(category);
    final safeOld = _encodeKey(oldName);
    
    FirebaseFirestore.instance.collection('thresholds').doc(safeCat).update({
        safeOld: FieldValue.delete(),
    });
    
    // Migrate Inventory Data?
    // Inventory structure: doc(cat) -> field(item) -> map(subItem)
    // We should move field(item) -> field(newitem)
    final safeNew = _encodeKey(newName);
    
    final docRef = FirebaseFirestore.instance.collection('inventory').doc(safeCat);
    FirebaseFirestore.instance.runTransaction((tx) async {
        final snap = await tx.get(docRef);
        if (!snap.exists) return;
        final data = snap.data();
        if (data == null) return;
        
        final oldData = data[safeOld];
        if (oldData != null) {
            // Write to new key
            tx.update(docRef, {
                safeNew: oldData,
                safeOld: FieldValue.delete(),
            });
        }
    }).catchError((e) {
        developer.log('Inventory item rename failed: $e', name: 'SettingsVM');
    });
    
    unawaited(_commit());
  }

  /// Rename a subItem within an item, preserving weights and thresholds
  void renameSubItem(
    String category,
    String item,
    String oldName,
    String newName,
  ) {

    final itemMap = _local[category]?[item];
    if (itemMap == null) return;

    _renameNode(
      parent: itemMap,
      oldName: oldName,
      newName: newName,
    );

    // Update GlobalState (Preserving Order)
    globalState.thresholds.renameSubItem(category, item, oldName, newName);
    
    // Firestore Persistence:
    final safeCat = _encodeKey(category);
    final safeItem = _encodeKey(item);
    final safeOld = _encodeKey(oldName);
    final safeNew = _encodeKey(newName);
    
    // 1. Migrate Inventory Data (Crucial to prevent data loss)
    // path: inventory/doc(cat)/item/oldSub -> inventory/doc(cat)/item/newSub
    
    final docRef = FirebaseFirestore.instance.collection('inventory').doc(safeCat);
    FirebaseFirestore.instance.runTransaction((tx) async {
        final snap = await tx.get(docRef);
        if (!snap.exists) return; // No inventory to migrate
        
        // We need to read the nested map safely
        // Snapshot data is Map<String, dynamic>
        // We look for [safeItem][safeOld]
        final data = snap.data();
        if (data == null) return;
        
        final itemData = data[safeItem];
        // Must perform safe casting and null checks
        if (itemData is Map) {
             final subData = itemData[safeOld];
             // If we have data for the old sub-item, move it
             if (subData != null) {
                 // Construct update map
                 // We can use dot notation for nested fields in 'update'
                 // "item.newSub": value
                 // "item.oldSub": delete
                 
                 final fieldPathNew = '$safeItem.$safeNew';
                 final fieldPathOld = '$safeItem.$safeOld';
                 
                 tx.update(docRef, {
                     fieldPathNew: subData,
                     fieldPathOld: FieldValue.delete(),
                 });
             }
        }
    }).catchError((e) {
        developer.log('Inventory sub-item rename failed: $e', name: 'SettingsVM');
    });
    
    // 2. Remove old key from Thresholds Firestore
    // (New key is written by _commit() -> save(), but old key remains unless deleted)
    final fieldPathOld = '$safeItem.$safeOld';
    FirebaseFirestore.instance.collection('thresholds').doc(safeCat).update({
        fieldPathOld: FieldValue.delete(),
    });
    
    unawaited(_commit());
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

    // PRESERVE ORDER: Reconstruct map with new key in valid position
    final keys = parent.keys.toList();
    
    // Create temp map to rebuild
    final newMap = <String, dynamic>{};
    for (int i = 0; i < keys.length; i++) {
        final key = keys[i];
        if (key == oldName) {
            newMap[newName] = existing;
        } else {
            newMap[key] = parent[key];
        }
    }
    
    // Replace content of parent map in-place
    parent.clear();
    // Use manual iteration to avoid "not a subtype" error with addAll
    for (final entry in newMap.entries) {
      parent[entry.key] = entry.value;
    }

    // CRITICAL FIX: Do NOT call _commit here.
    // _commit pushes _local to GlobalState; it does not remove old keys.
    // If we commit before the caller removes the old key from GlobalState, we persist duplicates.
    // The caller MUST handles GlobalState updates and then call unawaited(_commit()).
    
    _dirty = true;
    notifyListeners();
  }

  /// Create a new item under a category. Do NOT create a default subItem.
  /// The client should explicitly create sub-items using createSubItem().
  void createItem(String category, String item, {int? threshold}) {
    _local.putIfAbsent(category, () => {});
    // create the item entry as an empty map of subItems — no default subItem created
    _local[category]!.putIfAbsent(item, () => {});
    _dirty = true;
    notifyListeners();

    // Persist immediately
    unawaited(_commit());
  }

  /// Create a subItem under an existing item
  void createSubItem(String category, String item, String subItem) {
    assert(category.trim().isNotEmpty);
    assert(item.trim().isNotEmpty);
    assert(subItem.trim().isNotEmpty);

    _ensureCategoryItemSub(category, item, subItem);
    _dirty = true;
    notifyListeners();

    // unawaited(_ensureInventoryPath(...)); // REMOVED: No more writes to inventory from Settings
    unawaited(_commit());

    // Auto-Copy Shared Weights Logic
    // If in Shared Mode, the new sub-item should immediately inherit the schema of its siblings.
    final mode = weightModeFor(category, item);
    if (mode == WeightMode.shared) {
       final itemMap = _local[category]?[item];
       if (itemMap != null) {
          // Find a donor
          Map<String, int?>? donorWeights;
          for (final otherSub in itemMap.keys) {
             if (otherSub == subItem) continue; // skip self
             if (otherSub.startsWith('__')) continue;
             if (itemMap[otherSub]?.isNotEmpty ?? false) {
                donorWeights = itemMap[otherSub];
                break;
             }
          }

          if (donorWeights != null) {
             // Copy structure (values initialized to null)
             _local[category]![item]![subItem] = {}; // ensure clean start
             for (final w in donorWeights.keys) {
                _local[category]![item]![subItem]![w] = null;
             }
             developer.log('createSubItem: Auto-copied ${donorWeights.length} shared weights to $subItem', name: 'SettingsVM');
          }
       }
    }

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

    final itemMap = _local[category]?[item];
    if (itemMap == null) return;

    // 1. Remove from local state (Manual removal to avoid premature _commit() from _deleteNode)
    itemMap.remove(subItem);
    
    // 2. Remove from GlobalState (CRITICAL: Must happen BEFORE _commit/save)
    final globalItemMap = globalState.thresholds.asNestedMap()[category]?[item];
    if (globalItemMap != null) {
      globalItemMap.remove(subItem);
      // Clean up parent if empty
      if (globalItemMap.isEmpty) {
        globalState.thresholds.asNestedMap()[category]?.remove(item);
      }
    }

    // 3. Check for empty parents in local state from the bottom up
    if (itemMap.isEmpty) {
      _local[category]?.remove(item);
    }
    if (_local[category]?.isEmpty ?? false) {
      _local.remove(category);
    }

    _dirty = true;
    notifyListeners();
    
    // 4. Persist to Thresholds (Overwrite)
    // Now that GlobalState is clean, this will write the document WITHOUT the deleted sub-item
    unawaited(_commit());

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

    // Ensure local structure exists
    _ensureCategoryItemSub(category, item, subItem);

    // Clear existing weights for this subItem
    _local[category]![item]![subItem]!.clear();

    for (final w in weights) {
      final weight = w.trim();
      if (weight.isEmpty) continue;

      // Update local state
      _local[category]![item]![subItem]![weight] = null;

      // Thresholds: ensure empty structural node
      globalState.thresholds.ensureThresholdPath(
        category: category,
        item: item,
        subItem: subItem,
        weight: weight,
      );

      // Inventory: ensure empty structural node
      // unawaited(_ensureInventoryPath(...)); // REMOVED: No more writes to inventory from Settings
    }

    _dirty = true;
    notifyListeners();

    unawaited(_commit());
  }

  List<String> sharedWeightsForItem(String category, String item) {
    // No longer supported
    return const [];
  }

  Map<String, List<String>> weightsForItemBySubItem(String category, String item) {
    final itemMap = _local[category]?[item];
    if (itemMap == null) return {};

    final result = <String, List<String>>{};

    itemMap.forEach((subItem, weights) {
      final list = weights.keys
          .map((e) => e.toString())
          .toList();
        /*
        ..sort((a, b) {
          final ia = int.tryParse(a);
          final ib = int.tryParse(b);
          if (ia != null && ib != null) return ia.compareTo(ib);
          return a.compareTo(b);
        });
        */

      // IMPORTANT: even empty maps are VALID
      result[subItem] = list;
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
          weights.removeWhere((w, _) => w.trim().isEmpty);
        });
      });
    });

    // Overwrite GlobalState thresholds with local copy
    // (Structural persistence patch: do NOT clear structure on every commit)

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

    // Write local nested map into global state (structure-first: ensure empty nodes are committed)
    _local.forEach((cat, items) {
      items.forEach((item, subMap) {
        subMap.forEach((subItem, weights) {
          // Ensure subItem exists even if no weights yet
          globalState.thresholds
              .asNestedMap()
              .putIfAbsent(cat, () => {})
              .putIfAbsent(item, () => {})
              .putIfAbsent(subItem, () => {});

          // Ensure each weight key exists structurally
          for (final w in weights.keys) {
            globalState.thresholds.ensureThresholdPath(
              category: cat,
              item: item,
              subItem: subItem,
              weight: w,
            );

            final val = weights[w];
            if (val != null) {
              // Direct write to service to avoid 100s of notifyListeners()
              globalState.thresholds.setThreshold(
                category: cat, // ignore: invalid_use_of_protected_member
                item: item,
                subItem: subItem,
                weight: w,
                threshold: val,
              );
            }
          }
        });
      });
    });

    // Notify GlobalState listeners ONCE after bulk update
    // ignore: invalid_use_of_protected_member, invalid_use_of_visible_for_testing_member
    globalState.notifyListeners();

    // Persist to Firestore via GlobalState
    await globalState.saveThresholds();

    _dirty = false;
    if (_disposed) return;
    notifyListeners();
  }


}
