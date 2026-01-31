// ignore_for_file: deprecated_member_use

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:provider/provider.dart';
import '../../../core/widgets/shimmer_loading.dart';
import '../../../core/widgets/inventory_table.dart';
import '../../../global/global_state.dart';
import '../../../core/utils/helpers.dart';
import '../../../core/widgets/app_card.dart';
import '../../../app/theme.dart';
import '../../../../data/repositories/product_repository.dart';



class InventoryScreen extends StatelessWidget {
  const InventoryScreen({super.key});



  // Firestore-safe encoding helper
  String _encode(String s) => s.trim().replaceAll('.', '_').replaceAll('/', '_');

  Future<void> _setInventoryQuantity({
    required String category,
    required String item,
    required String subItem,
    required String weight,
    required int? value,
    required int Function()? getCurrentValue,
  }) async {
    final safeCat = _encode(category);
    final safeItem = _encode(item);
    final safeSub = _encode(subItem);
    final safeWeight = _encode(weight);

    final ref = FirebaseFirestore.instance.collection('inventory').doc(safeCat);

    // If deleting
    if (value == null) {
      await ref.update({'$safeItem.$safeSub.$safeWeight': FieldValue.delete()});
      return;
    }

    // Check if this is an INCREASE
    if (getCurrentValue != null) {
      final current = getCurrentValue();
      final delta = value - current;

      if (delta > 0) {
        // Prepare keys for ProductRepository
        // category is the productId
        // weightKey needs to be constructed carefully: subItem|weight (encoded)
        
        final safeSubKey = subItem.isEmpty ? '__shared__' : safeSub;
        // NOTE: ProductRepository expects "encoded" parts joined by pipe
        // The repo then decodes parts for auditing but uses them encoded for storage.
        // Actually, let's verify Repo expectations. 
        // Repo says: parts[0] == 'shared' ? '' : _decodeKey(parts[0]);
        // So we should pass ENCODED parts.
        final weightKey = '$safeSubKey|$safeWeight';

        final repo = ProductRepository();
        
        // Allocate to pending orders first
        await repo.allocateManualReceive(category, item, weightKey, delta);
        
        // ProductRepository.allocateManualReceive ALREADY updates the product doc
        // for both allocated amounts (via receiveShipment) AND unallocated amounts (via manual txn).
        // Therefore we DO NOT need to call ref.set() here if we used the repo.
        return;
      }
    }
    
    // Fallback: Normal set/update for decrease or no-change (or if logic skipped)
    await ref.set({
      safeItem: {
        safeSub: {safeWeight: value}
      }
    }, SetOptions(merge: true));
  }

  String? _getMissingWeightsMessage({
    required List<String> subItems,
    required List<String> Function(String) weightsForSubItem,
  }) {
    if (subItems.isEmpty) return null;

    final missing = <String>[];
    for (final s in subItems) {
      final weights = weightsForSubItem(s);
      if (weights.isEmpty) {
        missing.add(s);
      }
    }

    if (missing.isEmpty) return null;

    if (missing.length == subItems.length) {
      return 'Please add weights for ${subItems.join(', ')}';
    }

    return 'Please add weights for ${missing.join(', ')}';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Inventory')),
      body: Consumer<GlobalState>(
        builder: (context, globalState, child) {
          final thresholdsMap = globalState.thresholds.asNestedMap();
          
          if (globalState.isLoading) {
             return ShimmerLoading.list(
               itemCount: 4,
               itemBuilder: (context, index) {
                 return Container(
                    margin: const EdgeInsets.symmetric(vertical: 8),
                    height: 80,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(10),
                      color: AppColors.shimmerBase(context),
                    ),
                 );
               },
             );
          }

          if (thresholdsMap.isEmpty) {
            return Center(
              child: Text(
                'No inventory yet. Add categories and items in Settings.',
                style: Theme.of(context).textTheme.bodyMedium,
                textAlign: TextAlign.center,
              ),
            );
          }

          final categories = thresholdsMap.keys.toList();

          return ListView(
            padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 12),
            children: categories.map((category) {
              final itemMap = thresholdsMap[category]!;
              final items = itemMap.keys.where((k) => !k.startsWith('__')).toList();

              return AppCard(
                child: ExpansionTile(
                  tilePadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                  childrenPadding: const EdgeInsets.only(left: 20, right: 12, bottom: 12),
                  backgroundColor: AppTheme.getHighlightBackground(context),
                  title: Text(
                    category,
                    style: TextStyle(
                      fontSize: 20, 
                      fontWeight: FontWeight.bold, 
                      color: Theme.of(context).textTheme.titleLarge?.color
                    ),
                  ),
                  children: items.isEmpty
                      ? [
                          Padding(
                            padding: const EdgeInsets.all(16.0),
                            child: Text('No items in this category', style: Theme.of(context).textTheme.bodyMedium),
                          ),
                        ]
                      : items.map((item) {
                          return ListTile(
                            title: Text(item),
                            trailing: const Icon(Icons.arrow_forward_ios, size: 16),
                            onTap: () {
                               Navigator.of(context).push(
                                MaterialPageRoute(
                                  builder: (_) {
                                    // REFACTOR: Use GlobalState as source of truth for SubItems too
                                    // This fixes "No subitems configured" when inventory is empty
                                    final subItems = Helpers.extractSubItems(itemMap[item]!);

                                    final missingMsg = _getMissingWeightsMessage(
                                      subItems: subItems,
                                      weightsForSubItem: (subItem) {
                                        return globalState.getWeightsFor(
                                          category: category, 
                                          item: item, 
                                          subItem: subItem
                                        );
                                      },
                                    );

                                    if (missingMsg != null) {
                                      return Scaffold(
                                        appBar: AppBar(title: Text('$item Inventory')),
                                        body: Center(
                                          child: Text(
                                            missingMsg,
                                            style: Theme.of(context).textTheme.bodyLarge,
                                            textAlign: TextAlign.center,
                                          ),
                                        ),
                                      );
                                    }
                                    
                                    final isSharedWeights = globalState.getWeightModeFor(
                                      category: category, 
                                      item: item
                                    ) == true;

                                    return StreamBuilder<DocumentSnapshot>(
                                      stream: FirebaseFirestore.instance.collection('inventory').doc(_encode(category)).snapshots(),
                                      builder: (context, snapshot) {
                                        if (!snapshot.hasData) {
                                          return const Scaffold(
                                            body: Center(child: CircularProgressIndicator()),
                                          );
                                        }

                                        final freshData = snapshot.data!.data() as Map<String, dynamic>? ?? {};
                                        // Lookup using Encoded Item Key
                                        final freshItemMap = (freshData[_encode(item)] as Map<String, dynamic>?) ?? {};

                                        return InventoryTable(
                                          title: '$item Inventory',
                                          category: category,
                                          item: item,
                                          mode: InventoryTableMode.inventory,
                                          subItems: subItems,
                                          isSharedWeights: isSharedWeights,
                                          weightsForSubItem: (subItem) {
                                            return globalState.getWeightsFor(
                                              category: category, 
                                              item: item, 
                                              subItem: subItem
                                            );
                                          },
                                          getValue: ({required subItem, required weight}) {
                                            // Lookup using Encoded SubItem and Weight Keys
                                            final m = freshItemMap[_encode(subItem)];
                                            final safeW = _encode(weight);
                                            if (m is Map && m[safeW] is num) {
                                              return (m[safeW] as num).toInt();
                                            }
                                            return null;
                                          },
                                          setValue: ({required subItem, required weight, required value}) async {
                                            // Capture current value before update
                                            int currentVal = 0;
                                            final m = freshItemMap[_encode(subItem)];
                                            final safeW = _encode(weight);
                                            if (m is Map && m[safeW] is num) {
                                              currentVal = (m[safeW] as num).toInt();
                                            }

                                            await _setInventoryQuantity(
                                              category: category,
                                              item: item,
                                              subItem: subItem,
                                              weight: weight,
                                              value: value,
                                              getCurrentValue: () => currentVal,
                                            );
                                          },
                                        );
                                      }
                                    );
                                  },
                                ),
                              );
                            },
                          );
                        }).toList(),
                ),
              );
            }).toList(),
          );
        },
      ),
    );
  }
}