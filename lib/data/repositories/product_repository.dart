import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/product_model.dart';

class ProductRepository {
  Map<String, dynamic> _sanitizeNestedMap(Map<String, dynamic> input) {
    final result = <String, dynamic>{};

    for (final entry in input.entries) {
      final key = entry.key;

      // Block forbidden structural keys
      if (key == 'shared' || key.startsWith('__')) continue;

      final value = entry.value;

      if (value is Map<String, dynamic>) {
        final cleaned = _sanitizeNestedMap(value);
        if (cleaned.isNotEmpty) {
          result[key] = cleaned;
        }
      } else {
        result[key] = value;
      }
    }

    return result;
  }

  final CollectionReference _db =
      FirebaseFirestore.instance.collection('inventory');

  String _decodeKey(String encoded) =>
      encoded.replaceAll('_', '.');

  String _encodeKey(String raw) =>
      raw.trim().replaceAll('.', '_').replaceAll('/', '_');

  Future<void> addProduct(ProductModel product) async {
    try {
      final safeId = _encodeKey(product.id.isNotEmpty
          ? product.id
          : product.name);

      if (safeId.isEmpty) {
        throw Exception('Invalid product id/name');
      }

      final raw = product.toMap();
      final sanitizedRaw = _sanitizeNestedMap(raw);
      if (sanitizedRaw.isEmpty) {
        throw Exception('Sanitized product map is empty for product ${product.name}');
      }

      await _db.doc(safeId).set(sanitizedRaw, SetOptions(merge: true));
      print('Product created safely: $safeId');
    } catch (e, stack) {
      print('Error adding product: $e');
      print(stack);
      rethrow;
    }
  }

  Stream<List<ProductModel>> getProducts() {
    return _db.snapshots().map((snapshot) {
      return snapshot.docs.map((doc) {
        final data = doc.data() as Map<String, dynamic>;
        // LEGACY FLATTENING: kept temporarily for inventory UI compatibility.
        // Do NOT use for reorder or threshold logic.
        final flatWeights = <String, int>{};
        data.forEach((type, nested) {
          if (nested is Map<String, dynamic>) {
            nested.forEach((weight, qty) {
              final displayWeight = weight.replaceAll('_', '.');
              if (qty is int) flatWeights['$type|$displayWeight'] = qty;
            });
          }
        });
        final mergedData = {
          'id': doc.id,
          'name': data['name'] ?? doc.id,
          'weights': flatWeights,
          'threshold': (data['threshold'] ?? 5),
        };
        return ProductModel.fromMap(doc.id, mergedData);
      }).toList();
    });
  }

  /// Returns a stream of products where any weight is below threshold.
  @Deprecated('Legacy API. Do not use. Reorder uses InventorySnapshotService.')
  Stream<List<ProductModel>> getLowStockProducts() {
    // LEGACY: uses defaultThreshold and flat weights. Not schema-safe.
    return getProducts().map((products) {
      const int defaultThreshold = 5;
      final lowStock = products.where((product) {
        return product.weights.entries.any((entry) => entry.value < defaultThreshold);
      }).toList();
      return lowStock;
    });
  }

  /// Compute pending outstanding quantities per weightKey for a product
  /// by aggregating orders with status 'pending' or 'partial'.
  Future<Map<String, int>> computePendingForProduct(String productId) async {
    final ordersCol = FirebaseFirestore.instance.collection('orders');
    // Query pending / partial orders
    final q = await ordersCol
        .where('status', whereIn: ['pending', 'partial'])
        .get();

    final Map<String, int> pending = {};

    for (final doc in q.docs) {
      final orderData = doc.data();
      final items = List<Map<String, dynamic>>.from(orderData['items'] ?? []);
      for (final item in items) {
        if (item['productId'] != productId) continue;
        final encoded = item['weightKey'] as String;
        final parts = encoded.split('|');
        final subItem =
        parts[0] == 'shared' ? '' : _decodeKey(parts[0]);
        final weight = _decodeKey(parts[1]);
        final weightKey = '$subItem|$weight';
        final qtyOrdered = (item['qtyOrdered'] ?? 0) as int;
        final qtyReceived = (item['qtyReceived'] ?? 0) as int;
        final int outstanding = qtyOrdered - qtyReceived;
        if (outstanding <= 0) continue;
        pending[weightKey] = (pending[weightKey] ?? 0) + outstanding;
      }
    }

    return pending;
  }

  /// Compute pending outstanding quantities for multiple products in one pass.
  /// Returns a map: { productId: { weightKey: pendingQty, ... }, ... }
  Future<Map<String, Map<String, int>>> computePendingForProducts(
      List<String> productIds) async {
    if (productIds.isEmpty) return {};
    final ordersCol = FirebaseFirestore.instance.collection('orders');
    // Fetch all pending/partial orders
    final q = await ordersCol
        .where('status', whereIn: ['pending', 'partial'])
        .get();

    final Map<String, Map<String, int>> result = {};

    // Pre-seed maps for requested productIds
    for (final id in productIds) {
      result[id] = {};
    }

    for (final doc in q.docs) {
      final orderData = doc.data();
      final items = List<Map<String, dynamic>>.from(orderData['items'] ?? []);
      for (final item in items) {
        final pid = item['productId'] as String? ?? '';
        if (!result.containsKey(pid)) continue; // skip products we don't care about
        final encoded = item['weightKey'] as String;
        final parts = encoded.split('|');
        final subItem =
        parts[0] == 'shared' ? '' : _decodeKey(parts[0]);
        final weight = _decodeKey(parts[1]);
        final weightKey = '$subItem|$weight';
        final qtyOrdered = (item['qtyOrdered'] ?? 0) as int;
        final qtyReceived = (item['qtyReceived'] ?? 0) as int;
        final outstanding = qtyOrdered - qtyReceived;
        if (outstanding <= 0) continue;
        final mapForPid = result[pid]!;
        mapForPid[weightKey] = (mapForPid[weightKey] ?? 0) + outstanding;
      }
    }

    return result;
  }

  /// Receive shipment items grouped by order. Each item map should contain:
  /// { 'orderId': String, 'productId': String, 'weightKey': String, 'qtyReceivedNow': int }
  /// This runs a transaction per order and updates products, order items and audit events.
  Future<void> receiveShipment(
      List<Map<String, dynamic>> receivedItems) async {
    final db = FirebaseFirestore.instance;

    // Group items by orderId to combine updates into one transaction per order
    final Map<String, List<Map<String, dynamic>>> byOrder = {};
    for (final r in receivedItems) {
      final oid = r['orderId'] as String;
      byOrder.putIfAbsent(oid, () => []).add(r);
    }

    for (final entry in byOrder.entries) {
      final orderId = entry.key;
      final itemsForOrder = entry.value;

      final orderRef = db.collection('orders').doc(orderId);

      await db.runTransaction((tx) async {
        // Read order first
        final orderSnap = await tx.get(orderRef);
        if (!orderSnap.exists) throw Exception('Order $orderId not found');

        final orderData = orderSnap.data() as Map<String, dynamic>;
        final List<Map<String, dynamic>> orderItems =
        List<Map<String, dynamic>>.from(orderData['items'] ?? []);

        // Read all product docs we will need
        final Map<String, DocumentReference> productRefs = {};
        for (final recv in itemsForOrder) {
          final prodId = recv['productId'] as String;
          final safeProdId = _encodeKey(prodId);
          productRefs.putIfAbsent(safeProdId, () => _db.doc(safeProdId));
        }

        final Map<String, DocumentSnapshot> productSnaps = {};
        for (final pid in productRefs.keys) {
          final snap = await tx.get(productRefs[pid]!);
          if (!snap.exists) throw Exception('Product $pid not found');
          productSnaps[pid] = snap;
        }

        // Apply writes
        for (final recv in itemsForOrder) {
          final prodIdRaw = recv['productId'] as String;
          final prodId = _encodeKey(prodIdRaw);
          final weightKey = recv['weightKey'] as String;
          final qtyNow = (recv['qtyReceivedNow'] as int);

          final idx = orderItems.indexWhere((it) =>
              it['productId'] == prodIdRaw && it['weightKey'] == weightKey);
          if (idx == -1) {
            throw Exception('Order $orderId does not contain item $prodIdRaw/$weightKey');
          }

          final item = Map<String, dynamic>.from(orderItems[idx]);
          final prevReceived = (item['qtyReceived'] ?? 0) as int;
          final qtyOrdered = (item['qtyOrdered'] ?? 0) as int;

          final acceptedReceive = (prevReceived + qtyNow) <= qtyOrdered
              ? qtyNow
              : (qtyOrdered - prevReceived);

          if (acceptedReceive <= 0) continue;

          // update order item locally
          item['qtyReceived'] = prevReceived + acceptedReceive;
          orderItems[idx] = item;

          // Update product nested map (type.nestedKey) only
          final prodSnap = productSnaps[prodId]!;
          final prodData = Map<String, dynamic>.from(prodSnap.data() as Map<String, dynamic>);

          String type;
          String nestedKey;
          if (weightKey.contains('|')) {
            final parts = weightKey.split('|');
            type = _encodeKey(parts[0]);
            nestedKey = _encodeKey(parts.sublist(1).join('|'));
          } else {
            type = _encodeKey(weightKey);
            nestedKey = _encodeKey(weightKey);
          }

          final typeMap = Map<String, dynamic>.from(prodData[type] ?? {});
          final prevQty = (typeMap[nestedKey] ?? 0) as int;
          final newQty = prevQty + acceptedReceive;

          final productRef = _db.doc(prodId);
          tx.update(productRef, {'$type.$nestedKey': newQty});

          // audit event
          final auditRef = productRef.collection('events').doc();
          tx.set(auditRef, {
            'type': 'receive',
            'orderId': orderId,
            'qty': acceptedReceive,
            'weightKey': weightKey,
            'createdAt': FieldValue.serverTimestamp(),
          });
        }

        final allReceived = orderItems.every((it) =>
        (it['qtyReceived'] ?? 0) >= (it['qtyOrdered'] ?? 0));
        final newStatus = allReceived ? 'received' : 'partial';

        tx.update(orderRef, {
          'items': orderItems,
          'status': newStatus,
          'lastUpdatedAt': FieldValue.serverTimestamp(),
        });
      });
    }
  }

  /// Allocate manual receive delta to oldest pending orders (FIFO). Any remainder
  /// will be added to product weights and an audit event created.
  Future<Map<String, int>> allocateManualReceive(
      String productId, String weightKey, int delta) async {
    if (delta <= 0) return {'allocated': 0, 'unallocated': 0};
    final db = FirebaseFirestore.instance;

    // Fetch pending/partial orders oldest-first that contain this product/weight
    final q = await db
        .collection('orders')
        .where('status', whereIn: ['pending', 'partial'])
        .orderBy('createdAt', descending: false)
        .get();

    int remaining = delta;
    final List<Map<String, dynamic>> allocations = [];

    for (final doc in q.docs) {
      if (remaining <= 0) break;
      final orderData = doc.data();
      final items = List<Map<String, dynamic>>.from(orderData['items'] ?? []);

      for (final it in items) {
        if (remaining <= 0) break;
        final pid = it['productId'] as String? ?? '';
        final wk = it['weightKey'] as String? ?? '';
        if (pid != productId || wk != weightKey) continue;

        final qtyOrdered = (it['qtyOrdered'] ?? 0) as int;
        final qtyReceived = (it['qtyReceived'] ?? 0) as int;
        final outstanding = qtyOrdered - qtyReceived;
        if (outstanding <= 0) continue;

        final alloc = remaining <= outstanding ? remaining : outstanding;
        allocations.add({
          'orderId': doc.id,
          'productId': productId,
          'weightKey': weightKey,
          'qtyReceivedNow': alloc,
        });
        remaining -= alloc;
      }
    }

    // Apply allocations against orders (this will also update product weights via the existing transaction)
    if (allocations.isNotEmpty) {
      await receiveShipment(allocations);
    }

    // If some quantity remains unallocated, add it to product weights as stock and create an audit event
    if (remaining > 0) {
      final productRef = _db.doc(_encodeKey(productId));
      await FirebaseFirestore.instance.runTransaction((tx) async {
        final snap = await tx.get(productRef);
        if (!snap.exists) throw Exception('Product $productId not found');
        final prodData = Map<String, dynamic>.from(snap.data() as Map<String, dynamic>);

        // determine nested type/key from weightKey
        String type; String nestedKey;
        if (weightKey.contains('|')) {
          final parts = weightKey.split('|');
          type = _encodeKey(parts[0]);
          nestedKey = _encodeKey(parts.sublist(1).join('|'));
        } else {
          type = _encodeKey(weightKey);
          nestedKey = _encodeKey(weightKey);
        }

        final typeMap = Map<String, dynamic>.from(prodData[type] ?? {});
        final prevQty = (typeMap[nestedKey] ?? 0) as int;
        final newQty = prevQty + remaining;

        tx.update(productRef, {'$type.$nestedKey': newQty});

        // audit event
        final auditRef = productRef.collection('events').doc();
        tx.set(auditRef, {
          'type': 'manual_receive',
          'qty': remaining,
          'weightKey': weightKey,
          'note': 'auto_allocated_excess',
          'createdAt': FieldValue.serverTimestamp(),
        });
      });
    }

    final allocated = delta - remaining;
    return {'allocated': allocated, 'unallocated': remaining};
  }

  /// Create a new purchase order document. `items` should be a list of maps:
  /// { productId: string, productName: string, weightKey: string, qtyOrdered: int }
  /// Returns the created orderId.
  Future<String> createOrder(List<Map<String, dynamic>> items,
      {String? supplierId, DateTime? expectedDelivery, String? createdBy}) async {
    try {
      final orders = FirebaseFirestore.instance.collection('orders');
      final now = DateTime.now().toLocal();
      final orderName =
          '${now.day.toString().padLeft(2, '0')}-${now.month.toString().padLeft(2, '0')}-${now.year} ${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}';

      final docRef = await orders.add({
        'status': 'pending',
        'createdAt': FieldValue.serverTimestamp(),
        'orderName': orderName,
        'expectedDelivery':
            expectedDelivery == null ? null : Timestamp.fromDate(expectedDelivery),
        'supplierId': supplierId,
        'createdBy': createdBy,
        'items': items
            .map((i) => {
                  'productId': i['productId'],
                  'productName': i['productName'] ?? i['productId'],
                  'weightKey': i['weightKey'],
                  'qtyOrdered': i['qtyOrdered'],
                  'qtyReceived': 0,
                })
            .toList(),
      });
      return docRef.id;
    } catch (e) {
      print('Error creating order: $e');
      rethrow;
    }
  }

  Future<void> updateProduct(String id, Map<String, dynamic> data) async {
    try {
      final docRef = _db.doc(id);

      // Prepare a processed map that contains nested maps only
      final Map<String, dynamic> processed = {};

      // copy id/name/threshold if present
      for (final key in ['id', 'name', 'threshold']) {
        if (data.containsKey(key)) processed[key] = data[key];
      }

      // If caller provided a flat 'weights' map, expand into nested maps
      if (data.containsKey('weights') && data['weights'] is Map<String, dynamic>) {
        final weightsMap = Map<String, dynamic>.from(data['weights'] as Map<String, dynamic>);
        for (final entry in weightsMap.entries) {
          final flatKey = entry.key; // expected format: 'type|weightKey'
          final val = entry.value;
          if (flatKey.contains('|')) {
            final parts = flatKey.split('|');
            final type = parts[0];
            final nestedKey = parts.sublist(1).join('|');
            processed.putIfAbsent(type, () => <String, dynamic>{});
            final nested = Map<String, dynamic>.from(processed[type] as Map<String, dynamic>);
            nested[nestedKey] = val;
            processed[type] = nested;
          }
        }
      }

      // Also copy any nested maps provided directly by the caller
      for (final key in data.keys) {
        if (key == 'weights' || key == 'id' || key == 'name' || key == 'threshold') continue;
        final candidate = data[key];
        if (candidate is Map<String, dynamic>) {
          processed.putIfAbsent(key, () => <String, dynamic>{});
          final nested = Map<String, dynamic>.from(processed[key] as Map<String, dynamic>);
          for (final wk in candidate.entries) {
            nested[wk.key] = wk.value;
          }
          processed[key] = nested;
        }
      }

      final cleaned = _sanitizeNestedMap(processed);
      await docRef.set(cleaned, SetOptions(merge: true));
      print('Product $id successfully updated with data: $processed');
    } catch (e, stack) {
      print('Error updating product $id: $e');
      print(stack);
    }
  }

  Future<void> updateWeightQuantity(
      String id, String weightKey, int newQuantity) async {
    try {
      await updateWeightQuantityTransaction(id, weightKey, newQuantity);
    } catch (e) {
      print('Error updating weight quantity: $e');
    }
  }

  /// Safely set a weight's quantity via a read-modify-write transaction.
  /// This avoids field-path ambiguity and race conditions.
  Future<void> updateWeightQuantityTransaction(
      String id, String weightKey, int newQuantity) async {

    final safeId = _encodeKey(id);
    final docRef = _db.doc(safeId);

    await FirebaseFirestore.instance.runTransaction((tx) async {
      final snap = await tx.get(docRef);
      if (!snap.exists) {
        throw Exception('Product $id not found');
      }

      String type;
      String nestedKey;

      if (weightKey.contains('|')) {
        final parts = weightKey.split('|');
        type = _encodeKey(parts[0].isEmpty ? 'shared' : parts[0]);
        nestedKey = _encodeKey(parts.sublist(1).join('|'));
      } else {
        type = _encodeKey(weightKey);
        nestedKey = _encodeKey(weightKey);
      }

      tx.update(docRef, {
        '$type.$nestedKey': newQuantity,
      });
    });
  }

  Future<void> deleteProduct(String id) async {
    try {
      await _db.doc(id).delete();
    } catch (e) {
      print('Error deleting product: $e');
    }
  }
}