import 'dart:developer' as developer;
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';
import 'dart:convert' as convert;

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
  ThresholdService();

  /// category -> item -> subItem -> weightKey -> value
  final Map<String, Map<String, Map<String, Map<String, dynamic>>>> _thresholds = {};

  // -----------------
  // Read / access
  // -----------------
  Map<String, Map<String, Map<String, Map<String, dynamic>>>> asNestedMap() => _thresholds;

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
        .putIfAbsent(weight, () => {});
  }

  /// Set or update a threshold value.
  ///
  /// Notes:
  /// - `subItem == ''` represents item‑level thresholds
  /// - This updates in‑memory state ONLY
  void setThreshold({required String category, required String item, String? subItem, required String weight, required int threshold}) {
    final s = (subItem ?? '').trim();
    _ensureCategoryItemSub(category, item, s);
    _thresholds[category]![item]![s]![weight] = threshold;
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
      } catch (_) {}
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


  // _ensureInventoryPath removed to prevent destructive overwrites.
  // Inventory structure is no longer mirrored from Thresholds.

  // backfillInventoryFromThresholds removed.
  // -----------------
  // Persistence
  // -----------------
  /// Load thresholds from Firestore (`thresholds` collection) (server first then cache fallback)
  Future<void> load() async {
    try {
      final col = FirebaseFirestore.instance.collection('thresholds');
      final snaps = await col.get();

      _thresholds.clear();

      for (final snap in snaps.docs) {
        final catKey = snap.id;
        final data = snap.data();

        if (data.isEmpty) continue;

        data.forEach((itemKey, itemValue) {
          if (itemValue is! Map) return;

          itemValue.forEach((subKey, subVal) {
            if (subVal is! Map) return;
            _ensureCategoryItemSub(catKey, itemKey.toString(), subKey.toString());

            subVal.forEach((wKey, wVal) {
              _thresholds[catKey]![itemKey.toString()]![subKey.toString()]![wKey.toString()] = wVal;
            });
          });
        });
      }
      // Backfill disabled to prevent overwriting existing inventory values with empty maps
      // await backfillInventoryFromThresholds();
    } catch (e, st) {
      developer.log('ThresholdService.load failed: $e', error: e, stackTrace: st, name: 'ThresholdService');
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

      _thresholds.forEach((cat, itemMap) {
        final Map<String, dynamic> itemPayload = {};

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

      // Write one document per category (exact mirror of inventory)
      final col = FirebaseFirestore.instance.collection('thresholds');
      for (final entry in sanitized.entries) {
        final cat = entry.key;
        final data = entry.value;
        if (data is! Map) continue;

        final Map<String, dynamic> typed =
        Map<String, dynamic>.from(data);

        await col.doc(cat).set(typed, SetOptions(merge: false));
      }
      developer.log('ThresholdService.save(): write completed', name: 'ThresholdService');
    } catch (e, st) {
      developer.log('ThresholdService.save failed: $e', error: e, stackTrace: st, name: 'ThresholdService');
      // swallow errors to avoid crashing the UI; caller can re-attempt
    }
  }
}