import 'package:flutter/material.dart';
import '../../../data/models/product_model.dart';
import '../../../data/repositories/product_repository.dart';
import '../../../global/global_state.dart';
import 'package:provider/provider.dart';
import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';

class InventoryViewModel extends ChangeNotifier {
  final BuildContext context;
  InventoryViewModel(this.context);

  final ProductRepository _repo = ProductRepository();

  /// Expose repository for higher-level operations (read-only).
  ProductRepository get repo => _repo;

  Stream<List<ProductModel>> get products {
    final globalState = Provider.of<GlobalState>(context, listen: false);
    return _repo.getProducts().map((products) {
      for (final p in products) {
        globalState.setThreshold(p.name, p.threshold);
      }
      return products;
    });
  }

  Stream<List<ProductModel>> get lowStockProducts {
    final productsStream = _repo.getLowStockProducts();
    final ordersStream = FirebaseFirestore.instance
        .collection('orders')
        .where('status', whereIn: ['pending', 'partial'])
        .snapshots();

    // Controller to emit enriched product lists whenever products or orders change
    final controller = StreamController<List<ProductModel>>.broadcast();

    List<ProductModel>? latestProducts;

    Future<void> emitEnriched(List<ProductModel> products) async {
      try {
        final ids = products.map((p) => p.id).toList();
        final pendingByProduct = await _repo.computePendingForProducts(ids);
        final enriched = products.map((p) => p.copyWith(pending: pendingByProduct[p.id] ?? {})).toList();
        if (!controller.isClosed) controller.add(enriched);
      } catch (e) {
        // On failure, attempt per-product fallback to be resilient
        try {
          final List<ProductModel> enriched = [];
          for (final p in products) {
            final pending = await _repo.computePendingForProduct(p.id);
            enriched.add(p.copyWith(pending: pending));
          }
          if (!controller.isClosed) controller.add(enriched);
        } catch (e) {
          // if everything fails, emit original list without pending
          if (!controller.isClosed) controller.add(products);
        }
      }
    }

    StreamSubscription<List<ProductModel>>? productsSub;
    StreamSubscription<QuerySnapshot<Map<String, dynamic>>>? ordersSub;

    controller.onListen = () {
      productsSub = productsStream.listen((products) {
        latestProducts = products;
        // fire-and-forget enrichment
        emitEnriched(products).catchError((_) {});
      }, onError: (e) {
        if (!controller.isClosed) controller.addError(e);
      });

      ordersSub = ordersStream.listen((_) {
        // orders changed; recompute pending using latest products if available
        if (latestProducts != null) {
          emitEnriched(latestProducts!).catchError((_) {});
        }
      }, onError: (e) {
        // ignore order stream errors, they don't block product emission
      });
    };

    controller.onCancel = () async {
      await productsSub?.cancel();
      await ordersSub?.cancel();
      await controller.close();
    };

    return controller.stream;
  }

  /// Handle manual increases entered by the user in an editable cell.
  ///
  /// This will attempt to allocate the increased quantity to oldest pending
  /// orders for the given productId/weightKey (FIFO) by calling the
  /// ProductRepository.allocateManualReceive(...) helper. The repository will
  /// update orders and product weights atomically. After allocation we notify
  /// listeners so UI streams refresh.
  Future<void> handleManualIncrease(String productId, String weightKey, int delta) async {
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

  Future<void> addProduct(String name, Map<String, int> weights, {int threshold = 5}) async {
    await _repo.addProduct(ProductModel(id: '', name: name, weights: weights, threshold: threshold));
  }

  Future<void> updateQuantity(String id, Map<String, int> weights) async {
    await _repo.updateProduct(id, {'weights': weights});
    notifyListeners();
  }

  Future<void> updateThreshold(String id, int newThreshold) async {
    await _repo.updateProduct(id, {'threshold': newThreshold});
    notifyListeners();
  }

  Future<void> deleteProduct(String id) async {
    await _repo.deleteProduct(id);
  }

  Future<void> refreshThresholds(GlobalState globalState) async {
    final products = await _repo.getProducts().first;
    for (final p in products) {
      globalState.setThreshold(p.name, p.threshold);
    }
  }
}