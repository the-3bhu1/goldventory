import 'package:flutter/material.dart';
import '../../../data/models/product_model.dart';
import '../../../data/repositories/product_repository.dart';
import 'dart:async';

/// NOTE:
/// This ViewModel manages inventory quantities ONLY.
/// Reorder logic is handled by InventorySnapshotService.
/// Thresholds are managed by SettingsViewModel / ThresholdService.
/// InventoryViewModel
/// ------------------
/// - Reads and writes ONLY inventory quantities
/// - Never creates or mutates threshold configuration
/// - Thresholds are consumed read-only by UI / reorder logic
class InventoryViewModel extends ChangeNotifier {
  void _assertNotShared(String key) {
    assert(
      key != 'shared' && !key.startsWith('__'),
      'BUG: inventory must never contain shared or internal keys: $key',
    );
  }

  /// Check if a given quantity is below the specified threshold.
  /// Threshold lookup must be done by the caller.
  bool isBelowThreshold({
    required int qty,
    required int threshold,
  }) {
    return qty < threshold;
  }

  final BuildContext context;
  InventoryViewModel(this.context);

  final ProductRepository _repo = ProductRepository();

  /// Expose repository for higher-level operations (read-only).
  ProductRepository get repo => _repo;

  Stream<List<ProductModel>> get products {
    return _repo.getProducts();
  }

  /// Handle manual increases entered by the user in an editable cell.
  ///
  /// This will attempt to allocate the increased quantity to oldest pending
  /// orders for the given productId/weightKey (FIFO) by calling the
  /// ProductRepository.allocateManualReceive(...) helper. The repository will
  /// update orders and product weights atomically. After allocation we notify
  /// listeners so UI streams refresh.
  Future<void> handleManualIncrease(String productId, String weightKey, int delta) async {
    _assertNotShared(weightKey);
    if (delta <= 0) return;

    try {
      final result = await _repo.allocateManualReceive(productId, weightKey, delta);

      // show summary to user if possible
      try {
        // use context to show a SnackBar if available
        if (context.mounted) {
          final allocated = result['allocated'] ?? 0;
          final unallocated = result['unallocated'] ?? 0;
          final msg = 'Allocated $allocated to pending orders; $unallocated added to stock.';
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg), duration: const Duration(seconds: 3)));
        }
      } catch (_) {}

      // notify UI to refresh; lowStockProducts listens to orders+products so it will recompute
      notifyListeners();
    } catch (e) {
      // surface an error snackbar but don't crash
      try {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed to allocate received qty: $e')));
        }
      } catch (_) {}
    }
  }

  Future<void> addProduct({
    required String category,
    required String item,
    required String name,
    required Map<String, int> weights,
  }) async {
    for (final key in weights.keys) {
      _assertNotShared(key);
    }
    await _repo.addProduct(
      ProductModel(
        id: '',
        category: category,
        item: item,
        name: name,
        weights: weights,
      ),
    );
  }

  Future<void> updateQuantity(String id, Map<String, int> weights) async {
    for (final key in weights.keys) {
      _assertNotShared(key);
    }
    await _repo.updateProduct(id, {'weights': weights});
    notifyListeners();
  }

  Future<void> deleteProduct(String id) async {
    await _repo.deleteProduct(id);
  }
}