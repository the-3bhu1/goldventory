import 'dart:async';
import 'package:async/async.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:goldventory/core/services/threshold_service.dart';

String _decodeKey(String encoded) {
  return encoded.replaceAll('_', '.');
}

class ReorderRow {
  final String category;
  final String item;
  final String subItem;
  final String weight;
  final int quantity;
  final int pending;
  final int threshold;
  final int toOrder;

  ReorderRow({
    required this.category,
    required this.item,
    required this.subItem,
    required this.weight,
    required this.quantity,
    required this.pending,
    required this.threshold,
    required this.toOrder,
  });
}

/// Read-only snapshot service for reorder logic
class InventorySnapshotService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;
  final ThresholdService thresholdService;

  InventorySnapshotService({required this.thresholdService});

  Stream<List<ReorderRow>> streamReorderRows() {
    final inventoryStream = _db.collection('inventory').snapshots();
    final ordersStream = _db
        .collection('orders')
        .where('status', whereIn: ['pending', 'partial'])
        .snapshots();

    return StreamZip([inventoryStream, ordersStream]).map((events) {
      final invSnap = events[0];
      final ordersSnap = events[1];

      // pending: category|item|subItem|weight -> qty
      final Map<String, int> pending = {};

      for (final doc in ordersSnap.docs) {
        final data = doc.data();
        final items = List<Map<String, dynamic>>.from(data['items'] ?? []);
        for (final it in items) {
          final wk = it['weightKey'] as String?;
          if (wk == null) continue;
          final ordered = (it['qtyOrdered'] ?? 0) as int;
          final received = (it['qtyReceived'] ?? 0) as int;
          final out = ordered - received;
          if (out <= 0) continue;
          pending[wk] = (pending[wk] ?? 0) + out;
        }
      }

      final List<ReorderRow> rows = [];

      for (final catDoc in invSnap.docs) {
        final category = _decodeKey(catDoc.id);
        final catData = catDoc.data();

        catData.forEach((itemKey, itemVal) {
          if (itemVal is! Map) return;
          final item = _decodeKey(itemKey);

          final Map<String, dynamic> subItems = Map<String, dynamic>.from(itemVal);
          subItems.forEach((subItemKey, subVal) {
            if (subVal is! Map) return;
            final subItem = subItemKey == '__shared__' ? '' : _decodeKey(subItemKey);

            final Map<String, dynamic> weights = Map<String, dynamic>.from(subVal);
            weights.forEach((weightKey, qtyVal) {
              if (qtyVal is! int) return;

              final weight = _decodeKey(weightKey);
              final quantity = qtyVal;
              final fullKey = '$subItem|$weight';

              final threshold = thresholdService.getThresholdFor(
                category: category,
                item: item,
                subItem: subItem,
                weight: weight,
              );

              final pendingQty = pending[fullKey] ?? 0;
              final toOrder = threshold - (quantity + pendingQty);

              if (toOrder > 0) {
                rows.add(ReorderRow(
                  category: category,
                  item: item,
                  subItem: subItem,
                  weight: weight,
                  quantity: quantity,
                  pending: pendingQty,
                  threshold: threshold,
                  toOrder: toOrder,
                ));
              }
            });
          });
        });
      }

      return rows;
    });
  }
}