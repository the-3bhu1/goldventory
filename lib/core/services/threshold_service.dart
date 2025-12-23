import 'dart:developer' as developer;
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';
import 'dart:convert' as convert;

/// ThresholdService
///
/// Owns all threshold configuration and persists it to Firestore at
/// `settings/thresholds`.
///
/// In-memory model (human-readable, NOT Firestore-safe):
///
/// ```
/// _thresholds:
///   Map<category,
///     Map<item,
///       Map<subItem,
///         Map<weightKey, int>>>>
///
/// _itemSharedWeights:
///   Map<category, Map<item, List<weightKey>>>
/// ```
///
/// Firestore persistence rules (CRITICAL):
/// - Firestore does NOT allow '.', '/', or empty strings in map keys or path segments.
/// - ALL keys are encoded at the Firestore boundary using `_safeKey(...)`.
/// - Decoding back to human‑readable form happens only in memory / UI logic.
/// - Empty keys ('') are stored as '__default' in Firestore.
///
/// Reserved Firestore keys:
/// - '__item_shared_weights': metadata map storing item‑level shared weight columns.
///
/// Legacy support:
/// - Old documents shaped as item -> weightMap (no subItems) are transparently
///   loaded as subItem == '' in memory and re‑saved in the modern structure.
class ThresholdService {
  ThresholdService();

  /// category -> item -> subItem -> weightKey -> value
  final Map<String, Map<String, Map<String, Map<String, int>>>> _thresholds = {};

  /// category -> (item -> ordered list of shared weight keys)
  final Map<String, Map<String, List<String>>> _itemSharedWeights = {};

  int defaultThreshold = 5;

  // -----------------
  // Read / access
  // -----------------
  Map<String, Map<String, Map<String, Map<String, int>>>> asNestedMap() => _thresholds;

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

  /// Get item shared weights for a category/item (copy)
  List<String> getItemSharedWeights(String category, String item) {
    final m = _itemSharedWeights[category];
    if (m == null) return const [];
    final l = m[item];
    if (l == null) return const [];
    return List<String>.from(l);
  }

  // -----------------
  // Write helpers
  // -----------------
  void _ensureCategoryItemSub(String category, String item, String subItem) {
    _thresholds.putIfAbsent(category, () => {});
    _thresholds[category]!.putIfAbsent(item, () => {});
    _thresholds[category]![item]!.putIfAbsent(subItem, () => {});
  }

  /// Set or update a threshold value.
  ///
  /// Notes:
  /// - `subItem == ''` represents item‑level thresholds
  /// - This updates in‑memory state ONLY
  /// - Inventory mirroring is triggered separately via `_ensureInventoryPath`
  void setThreshold({required String category, required String item, String? subItem, required String weight, required int threshold}) {
    final s = (subItem ?? '').trim();
    _ensureCategoryItemSub(category, item, s);
    _thresholds[category]![item]![s]![weight] = threshold;

    // mirror structure into inventory with quantity = 0
    _ensureInventoryPath(
      category: category,
      item: item,
      subItem: s,
      weight: weight,
    );
  }

  /// Remove a threshold key; cleans empty maps on the way up
  void removeThreshold({required String category, required String item, String? subItem, required String weight}) {
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

  /// Define item‑level shared weight columns.
  ///
  /// These weights:
  /// - Appear across all subItems of an item
  /// - Are persisted under the reserved Firestore key '__item_shared_weights'
  /// - Must always use Firestore‑safe encoded keys
  void setItemSharedWeights(String category, String item, List<String> weights) {
    _itemSharedWeights.putIfAbsent(category, () => {});
    _itemSharedWeights[category]![item] = List<String>.from(weights);

    final subs = _thresholds[category]?[item]?.keys ?? const Iterable<String>.empty();
    for (final sub in subs) {
      for (final w in weights) {
        _ensureInventoryPath(
          category: category,
          item: item,
          subItem: sub,
          weight: w,
        );
      }
    }
  }

  void removeItemSharedWeights(String category, String item) {
    _itemSharedWeights[category]?.remove(item);
  }

  // -----------------
  // Resolution
  // -----------------
  /// Resolve threshold preferring most-specific value:
  /// 1) subItem-specific weight
  /// 2) subItem-specific canonical variants (space/underscore)
  /// 3) item-shared-weights: try to find weight column and then subItem value for that column
  /// 4) global default
  int getThresholdFor({required String category, required String item, String? subItem, required String weight}) {
    // helpers
    int? tryLookup(String? sCategory, String cat, String it, String? sub, String w) {
      try {
        final catMap = _thresholds[cat];
        if (catMap == null) return null;
        final itMap = catMap[it];
        if (itMap == null) return null;
        if (sub != null && itMap.containsKey(sub)) {
          final wm = itMap[sub]!;
          if (wm.containsKey(w)) return wm[w];
        }
      } catch (_) {
        // ignore
      }
      return null;
    }

    final s = (subItem ?? '').trim();

    // 1) exact subItem weight
    if (s.isNotEmpty) {
      final v = tryLookup(null, category, item, s, weight);
      if (v != null) return v;

      // 2) try variants
      final underscored = weight.replaceAll(' ', '_');
      final spaced = weight.replaceAll('_', ' ');
      final v2 = tryLookup(null, category, item, s, underscored) ?? tryLookup(null, category, item, s, spaced);
      if (v2 != null) return v2;
    }

    // fallback: global default
    return defaultThreshold;
  }

  /// Recursively sanitize a dynamic structure so all Map keys are Strings and
  /// nested Maps/Lists are converted to Firestore-friendly types.
  Map<String, dynamic> _sanitizeToMap(dynamic input) {
    if (input is Map) {
      final out = <String, dynamic>{};
      input.forEach((k, v) {
        final keyStr = k.toString();
        out[keyStr] = _sanitizeToMap(v);
      });
      return out;
    }
    if (input is List) {
      return {'_list': input.map((e) => _sanitizeToMap(e)).toList()};
    }
    // primitive
    return {'_value': input};
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


  /// Ensure the corresponding inventory path exists for a threshold entry.
  ///
  /// This method:
  /// - Encodes all identifiers using `_safeKey(...)`
  /// - Creates missing Firestore paths with quantity = 0
  /// - Uses merge writes so existing quantities are NEVER overwritten
  ///
  /// Safe to call multiple times (idempotent).
  Future<void> _ensureInventoryPath({
    required String category,
    required String item,
    required String subItem,
    required String weight,
  }) async {
    if (subItem == 'shared') return;
    final cat = category.trim();
    final it = item.trim();
    final w = weight.trim();

    // CRITICAL SAFETY:
    // iOS Firestore crashes if any path segment is empty or whitespace
    if (cat.isEmpty || it.isEmpty || w.isEmpty) {
      developer.log(
        '_ensureInventoryPath skipped due to empty segment '
        '(cat="$cat", item="$it", weight="$w")',
        name: 'ThresholdService',
      );
      return;
    }

    final safeSub = subItem.trim().isEmpty ? '__default' : _safeKey(subItem);
    final safeWeight = _safeKey(w);

    final ref = FirebaseFirestore.instance
        .collection('inventory')
        .doc(_safeKey(cat));

    await ref.set({
      _safeKey(it): {
        safeSub: {
          safeWeight: 0,
        }
      }
    }, SetOptions(merge: true));
  }

  /// One‑time (or repeated) migration to ensure Inventory mirrors Thresholds.
  ///
  /// Used to:
  /// - Backfill inventory for existing threshold data
  /// - Recover from partial data loss
  ///
  /// Safe to call multiple times:
  /// - Uses encoded keys
  /// - Uses merge writes
  /// - Never overwrites existing inventory quantities
  Future<void> backfillInventoryFromThresholds() async {
    for (final catEntry in _thresholds.entries) {
      final category = catEntry.key;
      for (final itemEntry in catEntry.value.entries) {
        final item = itemEntry.key;
        for (final subEntry in itemEntry.value.entries) {
          if (subEntry.key == 'shared') continue;
          final subItem = subEntry.key;
          for (final weight in subEntry.value.keys) {
            await _ensureInventoryPath(
              category: category,
              item: item,
              subItem: subItem,
              weight: weight,
            );
          }
        }
      }
    }
  }
  // -----------------
  // Persistence
  // -----------------
  /// Load thresholds from Firestore doc `settings/thresholds` (server first then cache fallback)
  Future<void> load() async {
    try {
      final doc = FirebaseFirestore.instance.doc('settings/thresholds');
      final snap = await doc.get(GetOptions(source: Source.server)).catchError((_) async {
        // fallback to cache
        return await doc.get(GetOptions(source: Source.cache));
      });

      if (!snap.exists) return;

      final data = snap.data()!;
      _thresholds.clear();
      _itemSharedWeights.clear();

      // 1. Extract shared weights from root if present
      if (data['__item_shared_weights'] is Map) {
        try {
          final mapRaw = data['__item_shared_weights'] as Map;
          final outMap = <String, List<String>>{};
          mapRaw.forEach((ik, iv) {
            try {
              final list = (iv as List).map((e) => e.toString()).toList();
              outMap[ik.toString()] = list;
            } catch (_) {}
          });
          // mapRaw keys are categories encoded (or raw? save() uses safeKey(cat))
          // _itemSharedWeights expects category -> item -> list
          // The structure in save() is: payload['__item_shared_weights'] = { safeKey(cat): { safeKey(item): [...] } }
          // The loop above iterates keys of mapRaw which are safeKey(cat).
          // Wait, the logic above (copied from original) treated 'ik' as category?
          // Re-reading save(): sharedWeightsPayload[_safeKey(cat)] = catWeights.map...
          // So mapRaw is { cat: { item: [list] } }.
          // The parsing logic needs to go one level deeper.

          mapRaw.forEach((catKey, itemMapRaw) {
             if (itemMapRaw is Map) {
               final perCategory = <String, List<String>>{};
               itemMapRaw.forEach((itemKey, cols) {
                 if (cols is List) {
                   perCategory[itemKey.toString()] = cols.map((e) => e.toString()).toList();
                 }
               });
               if (perCategory.isNotEmpty) {
                 _itemSharedWeights[catKey.toString()] = perCategory;
               }
             }
          });

        } catch (_) {
          // ignore malformed
        }
      }

      // 2. Process categories and items
      data.forEach((catKey, catValue) {
        if (catKey == '__item_shared_weights') return;
        if (catValue is Map) {
          catValue.forEach((itemKey, itemValue) {
            if (itemValue is Map) {
              // Ensure item exists even if empty
              _ensureCategoryItemSub(catKey.toString(), itemKey.toString(), '');

              // Detect legacy shape: item -> weightMap (value types are int/num)
              bool looksLikeLegacy = false;
              for (final v in itemValue.values) {
                if (v is int || v is num) {
                  looksLikeLegacy = true;
                } else {
                  looksLikeLegacy = false;
                  break;
                }
              }

              if (looksLikeLegacy) {
                 // create subItem '' as item-level weights
                final weightMap = <String, int>{};
                itemValue.forEach((wKey, wVal) {
                  final keyStr = wKey.toString();
                  final storeKey = keyStr == '__default' ? '' : keyStr;
                  if (wVal is int) {
                    weightMap[storeKey] = wVal;
                  } else if (wVal is num) {
                    weightMap[storeKey] = wVal.toInt();
                  }
                });
                _thresholds[catKey.toString()]![itemKey.toString()]![''] = weightMap;
              } else {
                // New shape: item -> subItem -> weightMap
                final subMap = <String, Map<String, int>>{};
                itemValue.forEach((subKey, subVal) {
                  if (subVal is Map) {
                    final Map<String, int> weightMap = {};
                    subVal.forEach((wKey, wVal) {
                      final keyStr = wKey.toString();
                      final storeKey = keyStr == '__default' ? '' : keyStr;
                      if (wVal is int) {
                        weightMap[storeKey] = wVal;
                      } else if (wVal is num) {
                        weightMap[storeKey] = wVal.toInt();
                      }
                    });
                    subMap[subKey.toString()] = weightMap;
                  }
                });

                // Merge subMap into _thresholds structure
                if (subMap.isNotEmpty) {
                  _thresholds[catKey.toString()]![itemKey.toString()] = subMap;
                }
              }
            }
          });
        }
      });
      // Backfill inventory to mirror existing thresholds (safe migration)
      await backfillInventoryFromThresholds();
    } catch (e, st) {
      developer.log('ThresholdService.load failed: $e', error: e, stackTrace: st, name: 'ThresholdService');
    }
  }

  /// Persist all thresholds to Firestore (`settings/thresholds`).
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
          developer.log('ThresholdService.save(): Firebase not initialized; skipping save.', name: 'ThresholdService');
          return;
        }
      } catch (e) {
        // Firebase not available in this runtime; log and skip
        developer.log('ThresholdService.save(): Firebase.check failed: $e', name: 'ThresholdService');
        return;
      }

      // Build the raw payload as before
      final Map<String, dynamic> payload = {};
      // Prepare top-level shared weights payload
      final Map<String, dynamic> sharedWeightsPayload = {};

      _thresholds.forEach((cat, itemMap) {
        final Map<String, dynamic> itemPayload = {};

        // Collect shared weights per category (SAFE)
        final catWeights = _itemSharedWeights[cat];
        if (catWeights != null && catWeights.isNotEmpty) {
          sharedWeightsPayload[_safeKey(cat)] =
              catWeights.map((k, v) => MapEntry(_safeKey(k), List<String>.from(v)));
        }

        itemMap.forEach((item, subMap) {
          final Map<String, dynamic> subPayload = {};
          subMap.forEach((subItem, weightMap) {
            if (subItem == 'shared') return;
            final Map<String, dynamic> weightPayload = {};
            weightMap.forEach((w, val) {
              final outKey = _safeKey(w == '' ? '' : w.toString());
              weightPayload[outKey] = val;
            });
            final safeSubItem = _safeKey(subItem.toString());
            subPayload[safeSubItem] = weightPayload;
          });
          final safeItem = _safeKey(item.toString());
          itemPayload[safeItem] = subPayload;
        });
        payload[_safeKey(cat)] = itemPayload;
      });

      // Attach metadata AFTER category loop
      if (sharedWeightsPayload.isNotEmpty) {
        payload['__item_shared_weights'] = sharedWeightsPayload;
      }

      // Sanitize payload into a Firestore-friendly map
      Map<String, dynamic> sanitized = {};

      // helper to unwrap the wrapper structure produced by _sanitizeToMap
      dynamic unwrap(dynamic node) {
        if (node is Map<String, dynamic>) {
          if (node.containsKey('_value')) return node['_value'];
          if (node.containsKey('_list')) {
            return (node['_list'] as List).map((e) => unwrap(e)).toList();
          }
          final out = <String, dynamic>{};
          node.forEach((kk, vv) {
            out[kk] = unwrap(vv);
          });
          return out;
        }
        return node;
      }

      payload.forEach((k, v) {
        final s = _sanitizeToMap(v);
        sanitized[k.toString()] = unwrap(s);
      });

      // Debug: log the sanitized payload as JSON so we can inspect exactly what is sent to Firestore
      try {
        developer.log('ThresholdService.save(): sanitized payload = ${convert.jsonEncode(sanitized)}', name: 'ThresholdService');
      } catch (_) {
        developer.log('ThresholdService.save(): sanitized payload could not be JSON-encoded', name: 'ThresholdService');
      }

      // IMPORTANT: Avoid writing an empty map.
      // On iOS Firestore, setData({}, merge:false) can trigger native validation crashes.
      if (sanitized.isEmpty) {
        developer.log(
          'ThresholdService.save(): sanitized payload empty; skipping Firestore write.',
          name: 'ThresholdService',
        );
        return;
      }

      // Attempt the write and log any native Firestore errors
      try {
        await FirebaseFirestore.instance.doc('settings/thresholds').set(sanitized, SetOptions(merge: false));
        developer.log('ThresholdService.save(): write completed', name: 'ThresholdService');
      } catch (e, st) {
        developer.log('ThresholdService.save(): Firestore.set failed: $e', error: e, stackTrace: st, name: 'ThresholdService');
        rethrow;
      }
    } catch (e, st) {
      developer.log('ThresholdService.save failed: $e', error: e, stackTrace: st, name: 'ThresholdService');
      // swallow errors to avoid crashing the UI; caller can re-attempt
    }
  }
}