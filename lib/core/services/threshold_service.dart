import 'dart:developer' as developer;
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';
import 'database_service.dart';

/// ThresholdService
///
/// Owns all threshold configuration and persists it to Firestore
/// in the `thresholds` collection.
///
/// In-memory model (human-readable, NOT Firestore-safe):
///
/// ```
/// _thresholds:
///   Map<category,
///     Map<item,
///       Map<subItem,
///         Map<weightKey, dynamic>>>>
/// ```
///
/// Firestore persistence rules (CRITICAL):
/// - Firestore does NOT allow '.', '/', or empty strings in map keys or path segments.
/// - ALL keys are encoded at the Firestore boundary using `_safeKey(...)`.
/// - Decoding back to human‑readable form happens only in memory / UI logic.
/// - Empty keys ('') are stored as '__default' in Firestore.
///
/// Legacy support:
/// - Old documents shaped as item -> weightMap (no subItems) are transparently
///   loaded as subItem == '' in memory and re‑saved in the modern structure.
class ThresholdService {
  final DatabaseService databaseService;
  ThresholdService({required this.databaseService});

  /// category -> item -> subItem -> weightKey -> value
  final Map<String, Map<String, Map<String, Map<String, dynamic>>>>
      _thresholds = {};

  // -----------------
  // Read / access
  // -----------------
  Map<String, Map<String, Map<String, Map<String, dynamic>>>> asNestedMap() =>
      _thresholds;

  /// Get a deep copy view for external use if needed
  Map<String, dynamic> asMap() {
    final out = <String, dynamic>{};
    _thresholds.forEach((cat, items) {
      final itemOut = <String, dynamic>{};
      items.forEach((item, subMap) {
        final subOut = <String, dynamic>{};
        subMap.forEach((subItem, weightMap) {
          final weightOut = <String, dynamic>{};
          weightMap.forEach((w, v) {
            final outKey = (w == '') ? '__default' : w;
            weightOut[outKey] = v;
          });
          subOut[subItem] = weightOut;
        });
        itemOut[item] = subOut;
      });

      out[cat] = itemOut;
    });
    return out;
  }

  // -----------------
  // Write helpers
  // -----------------
  void _ensureCategoryItemSub(String category, String item, String subItem) {
    _thresholds.putIfAbsent(category, () => {});
    _thresholds[category]!.putIfAbsent(item, () => {});
    _thresholds[category]![item]!.putIfAbsent(subItem, () => {});
  }

  /// Ensure a structural path exists for a weight key (creates empty map if missing).
  void ensureThresholdPath({
    required String category,
    required String item,
    required String subItem,
    required String weight,
  }) {
    final s = subItem.trim();
    _thresholds
        .putIfAbsent(category, () => {})
        .putIfAbsent(item, () => {})
        .putIfAbsent(s, () => {})
        .putIfAbsent(weight, () => null);
  }

  /// Set or update a threshold value.
  ///
  /// Notes:
  /// - `subItem == ''` represents item‑level thresholds
  /// - This updates in‑memory state ONLY
  void setThreshold(
      {required String category,
      required String item,
      String? subItem,
      required String weight,
      int? threshold}) {
    final s = (subItem ?? '').trim();
    _ensureCategoryItemSub(category, item, s);
    _thresholds[category]![item]![s]![weight] = threshold;
  }

  /// Remove a threshold key; cleans empty maps on the way up
  void removeThreshold(
      {required String category,
      required String item,
      String? subItem,
      required String weight}) {
    final s = (subItem ?? '').trim();
    final cat = _thresholds[category];
    if (cat == null) return;
    final itemMap = cat[item];
    if (itemMap == null) return;
    final sub = itemMap[s];
    if (sub == null) return;
    sub.remove(weight);
    if (sub.isEmpty) itemMap.remove(s);
    if (itemMap.isEmpty) _thresholds.remove(category);
  }

  /// Helper to rename a key in a map while preserving its index/order.
  void _renameKeyInOrderedMap<V>(
      Map<String, V> map, String oldKey, String newKey) {
    if (!map.containsKey(oldKey)) return;
    if (map.containsKey(newKey)) return;

    final entries = map.entries.toList();
    final index = entries.indexWhere((e) => e.key == oldKey);
    if (index == -1) return;

    final value = entries[index].value;

    // Rebuild map
    map.clear();
    for (int i = 0; i < entries.length; i++) {
      if (i == index) {
        map[newKey] = value;
      } else {
        map[entries[i].key] = entries[i].value;
      }
    }
  }

  void renameCategory(String oldName, String newName) {
    _renameKeyInOrderedMap(_thresholds, oldName, newName);
  }

  void renameItem(String category, String oldName, String newName) {
    final catMap = _thresholds[category];
    if (catMap == null) return;
    _renameKeyInOrderedMap(catMap, oldName, newName);
  }

  void renameSubItem(
      String category, String item, String oldName, String newName) {
    final catMap = _thresholds[category];
    if (catMap == null) return;
    final itemMap = catMap[item];
    if (itemMap == null) return;
    _renameKeyInOrderedMap(itemMap, oldName, newName);
  }

  // -----------------
  // Resolution
  // -----------------
  /// Resolve threshold preferring most-specific value:
  /// Returns null if no threshold is set.
  int? getThresholdFor({
    required String category,
    required String item,
    String? subItem,
    required String weight,
  }) {
    int? tryLookup(String cat, String it, String? sub, String w) {
      try {
        final catMap = _thresholds[cat];
        if (catMap == null) return null;
        final itMap = catMap[it];
        if (itMap == null) return null;
        if (sub != null && itMap.containsKey(sub)) {
          final wm = itMap[sub]!;
          return wm[w];
        }
      } catch (e) {
        developer.log(
            'ThresholdService.tryLookup failed: $cat|$it|$sub|$w -> $e',
            name: 'ThresholdService');
      }
      return null;
    }

    final s = (subItem ?? '').trim();

    // 1) exact subItem match
    if (s.isNotEmpty) {
      final v = tryLookup(category, item, s, weight);
      if (v != null) return v;

      // try canonical variants
      final underscored = weight.replaceAll(' ', '_');
      final spaced = weight.replaceAll('_', ' ');
      return tryLookup(category, item, s, underscored) ??
          tryLookup(category, item, s, spaced);
    }

    // NO FALLBACK — missing means null
    return null;
  }

  /// Encode a human‑readable key into a Firestore‑safe identifier.
  ///
  /// Firestore rules:
  /// - Map keys and document IDs must NOT contain '.', '/', or be empty.
  /// - Violating this causes native iOS crashes (no Dart exception).
  ///
  /// Encoding rules:
  /// - Empty string ('') → '__default'
  /// - '.' and '/' → '_'
  ///
  /// NOTE:
  /// - This MUST be applied to *every* value used as:
  ///   - a document ID
  ///   - a map key
  ///   - a field‑path segment
  String _safeKey(String key) {
    final k = key.trim();
    if (k.isEmpty) return '__default';
    return k.replaceAll('.', '_').replaceAll('/', '_');
  }

  // _ensureInventoryPath removed to prevent destructive overwrites.
  // Inventory structure is no longer mirrored from Thresholds.

  // backfillInventoryFromThresholds removed.
  // -----------------
  // Persistence
  // -----------------
  /// Load thresholds from Firestore (`thresholds` collection) (server first then cache fallback)
  Future<void> load() async {
    try {
      final col = FirebaseFirestore.instance
          .collection(databaseService.thresholdsCollection);
      final snaps = await col.get();

      // 1. Identify Layout Document
      List<String> categoryOrder = [];
      try {
        final layoutDoc = snaps.docs.firstWhere((d) => d.id == '_layout');
        final data = layoutDoc.data();
        if (data['categories'] is List) {
          categoryOrder = List<String>.from(data['categories']);
        }
      } catch (_) {
        // No layout doc found, or invalid format
      }

      // 2. Separate Data Docs
      final docsMap = {for (var d in snaps.docs) d.id: d.data()};
      docsMap.remove(
          '_layout'); // Ensure layout doc is not processed as a category

      _thresholds.clear();

      // 3. Process Categories in Order
      final orderedCategories = <String>{
        ...categoryOrder,
        ...docsMap.keys, // Append any new/unknown categories at the end
      };

      String decode(String s) =>
          s.startsWith('__') ? s : s.replaceAll('_', '.');

      for (final catKeyRaw in orderedCategories) {
        final catKey = decode(catKeyRaw);
        final data = docsMap[catKeyRaw]; // Lookup using raw ID
        if (data == null) continue;

        // Extract Item Order
        List<String> itemOrder = [];
        if (data['__item_order'] is List) {
          itemOrder = List<String>.from(data['__item_order']);
        }

        // Filter out metadata from data map
        final itemsMap = Map<String, dynamic>.from(data);
        itemsMap.remove('__item_order');

        final orderedItems = <String>{
          ...itemOrder,
          ...itemsMap.keys,
        };

        for (final itemKeyRaw in orderedItems) {
          // Skip internal keys at item level if any
          if (itemKeyRaw.toString().startsWith('__')) continue;

          final itemKey = decode(itemKeyRaw.toString());
          final itemValue = itemsMap[itemKeyRaw]; // Lookup using raw ID
          if (itemValue is! Map) continue;

          // Extract SubItem Order
          List<String> subItemOrder = [];
          if (itemValue['__sub_item_order'] is List) {
            subItemOrder = List<String>.from(itemValue['__sub_item_order']);
          }

          final subItemsMap = Map<String, dynamic>.from(itemValue);
          subItemsMap.remove('__sub_item_order');

          final orderedSubItems = <String>{
            ...subItemOrder,
            ...subItemsMap.keys,
          };

          for (final subKeyRaw in orderedSubItems) {
            // Skip internal keys at sub-item level if any, EXCEPT __metadata (used for WeightMode)
            if (subKeyRaw.toString().startsWith('__') &&
                subKeyRaw != '__metadata') {
              continue;
            }

            final subKey = decode(subKeyRaw.toString());
            final subVal = subItemsMap[subKeyRaw]; // Lookup using raw subKey

            if (subVal is! Map) continue;

            _ensureCategoryItemSub(catKey, itemKey, subKey);

            // Extract Weight Order
            List<String> weightOrder = [];
            if (subVal['__weight_order'] is List) {
              weightOrder = List<String>.from(subVal['__weight_order']);
            }

            final weightsMap = Map<String, dynamic>.from(subVal);
            weightsMap.remove('__weight_order');

            final orderedWeights = <String>{
              ...weightOrder,
              ...weightsMap.keys,
            };

            for (final wKeyRaw in orderedWeights) {
              if (wKeyRaw.toString().startsWith('__')) continue;

              // Don't decode content inside metadata
              final wKey = (subKey == '__metadata')
                  ? wKeyRaw.toString()
                  : decode(wKeyRaw.toString());

              final val = weightsMap[wKeyRaw];

              // Hardening: Block corrupted data (Maps/Lists) but try to recover wrapped values
              if (subKey != '__metadata' && (val is Map || val is List)) {
                // RECOVERY: Check if it's a wrapped value from the bug
                if (val is Map && val.containsKey('_value')) {
                  _thresholds[catKey]![itemKey]![subKey]![wKey] = val['_value'];
                  continue;
                }

                // RECOVERY: If it's an empty map (common corruption pattern), treat as valid null (unset threshold)
                // This restores the "button" even if the threshold number is lost.
                if (val is Map && val.isEmpty) {
                  _thresholds[catKey]![itemKey]![subKey]![wKey] = null;
                  continue;
                }

                developer.log(
                    'ThresholdService: Ignoring corrupted weight value for $wKey: $val',
                    name: 'ThresholdService');
                continue;
              }

              _thresholds[catKey]![itemKey]![subKey]![wKey] = val;
            }
          }
        }
      }
      // Backfill disabled to prevent overwriting existing inventory values with empty maps
      // await backfillInventoryFromThresholds();
    } catch (e, st) {
      developer.log('ThresholdService.load failed: $e',
          error: e, stackTrace: st, name: 'ThresholdService');
    }
  }

  /// Persist all thresholds to Firestore (`thresholds` collection).
  ///
  /// IMPORTANT SAFETY NOTES:
  /// - All keys are encoded before writing (see `_safeKey`)
  /// - Empty payloads are intentionally NOT written
  ///   (prevents iOS Firestore native crashes)
  /// - Uses `merge: false` to keep the document schema deterministic
  ///
  /// This method is the ONLY place where thresholds touch Firestore.
  Future<void> save() async {
    try {
      // If firebase isn't initialized, avoid calling Firestore (prevents native crashes)
      try {
        if (Firebase.apps.isEmpty) {
          developer.log(
              'ThresholdService.save(): Firebase not initialized; skipping save.',
              name: 'ThresholdService');
          return;
        }
      } catch (e) {
        // Firebase not available in this runtime; log and skip
        developer.log('ThresholdService.save(): Firebase.check failed: $e',
            name: 'ThresholdService');
        return;
      }

      // Build the raw payload as before
      final Map<String, dynamic> payload = {};

      // Capture Order Metadata from current in-memory insertion order
      final List<String> categoryOrder =
          _thresholds.keys.map(_safeKey).toList();

      _thresholds.forEach((cat, itemMap) {
        final Map<String, dynamic> itemPayload = {};

        // Item Order
        final List<String> itemOrder = itemMap.keys
            .where((k) => !k.startsWith('__'))
            .map(_safeKey)
            .toList();
        itemPayload['__item_order'] = itemOrder;

        itemMap.forEach((item, subMap) {
          final Map<String, dynamic> subPayload = {};

          // Sub-item Order
          final List<String> subItemOrder = subMap.keys
              .where((k) => k != 'shared' && !k.startsWith('__'))
              .map(_safeKey)
              .toList();
          subPayload['__sub_item_order'] = subItemOrder;

          subMap.forEach((subItem, weightMap) {
            final Map<String, dynamic> weightPayload = {};

            // Weight Order: Skip for metadata
            final List<String> weightOrder = subItem == '__metadata'
                ? []
                : weightMap.keys
                    .where((w) => w.trim().isNotEmpty && !w.startsWith('__'))
                    .map(_safeKey)
                    .toList();
            if (weightOrder.isNotEmpty) {
              weightPayload['__weight_order'] = weightOrder;
            }

            for (final weightKey in weightMap.keys) {
              if (weightKey.startsWith('__')) continue;

              final dynamic val = weightMap[weightKey];

              // We only skip nulls for the master 'shared' map.
              // For all other sub-items (S1, S13, etc.), we EXPLICITLY write the null
              // to Firestore so the user can see the placeholder in the console.
              final bool isSharedMap = (subItem == 'shared');
              if (val == null && isSharedMap) {
                continue;
              }

              final String outKey = _safeKey(weightKey);
              weightPayload[outKey] = val;
            }
            final String safeSubItem = _safeKey(subItem);
            subPayload[safeSubItem] = weightPayload;
          });
          final safeItem = _safeKey(item.toString());
          itemPayload[safeItem] = subPayload;
        });
        payload[_safeKey(cat)] = itemPayload;
      });

      // DIRECT SAVE: Removed faulty sanitization/wrapping logic that was corrupting data
      final sanitized = payload;

      try {
        developer.log(
            'ThresholdService.save(): payload size = ${sanitized.length} categories',
            name: 'ThresholdService');
      } catch (_) {}

      // Write one document per category (exact mirror of inventory)
      final col = FirebaseFirestore.instance
          .collection(databaseService.thresholdsCollection);

      // 1. Save Category Order Layout
      await col.doc('_layout').set({
        'categories': categoryOrder,
      }, SetOptions(merge: false));

      // 2. Save Data Docs
      for (final entry in sanitized.entries) {
        final cat = entry.key;
        final data = entry.value;
        if (data is! Map) continue;

        final Map<String, dynamic> typed = Map<String, dynamic>.from(data);

        await col.doc(cat).set(typed, SetOptions(merge: false));
      }
      developer.log('ThresholdService.save(): write completed',
          name: 'ThresholdService');
    } catch (e, st) {
      developer.log('ThresholdService.save failed: $e',
          error: e, stackTrace: st, name: 'ThresholdService');
      // swallow errors to avoid crashing the UI; caller can re-attempt
    }
  }
}
