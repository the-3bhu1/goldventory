// ignore_for_file: deprecated_member_use

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:provider/provider.dart';
import '../../../core/widgets/inventory_table.dart';
import '../../../global/global_state.dart';

class _InventorySkeleton extends StatelessWidget {
  const _InventorySkeleton();

  @override
  Widget build(BuildContext context) {
    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 12),
      itemCount: 4,
      itemBuilder: (context, index) {
        return Card(
          margin: const EdgeInsets.symmetric(vertical: 8),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          child: Container(
            height: 72,
            padding: const EdgeInsets.symmetric(horizontal: 20),
            alignment: Alignment.centerLeft,
            child: Row(
              children: [
                Expanded(
                  child: Container(
                    height: 16,
                    decoration: BoxDecoration(
                      color: Colors.grey.shade300,
                      borderRadius: BorderRadius.circular(6),
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                Container(
                  width: 16,
                  height: 16,
                  decoration: BoxDecoration(
                    color: Colors.grey.shade300,
                    shape: BoxShape.circle,
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class InventoryScreen extends StatelessWidget {
  const InventoryScreen({super.key});

  List<String> _extractSubItems(Map<String, dynamic> itemMap) {
    return itemMap.keys
        .where((k) => k != 'shared' && !k.startsWith('__'))
        .toList()
      ..sort();
  }

  Future<void> _setInventoryQuantity({
    required String category,
    required String item,
    required String subItem,
    required String weight,
    required int? value,
  }) async {
    final ref = FirebaseFirestore.instance.collection('inventory').doc(category);
    if (value == null) {
      await ref.update({'$item.$subItem.$weight': FieldValue.delete()});
    } else {
      await ref.set({
        item: {
          subItem: {weight: value}
        }
      }, SetOptions(merge: true));
    }
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
             return const _InventorySkeleton();
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

              return Card(
                color: const Color(0xFFC6E6DA),
                elevation: 2,
                margin: const EdgeInsets.symmetric(vertical: 8),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                child: ExpansionTile(
                  tilePadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                  childrenPadding: const EdgeInsets.only(left: 20, right: 12, bottom: 12),
                  backgroundColor: const Color(0xFFF0F8F3),
                  title: Text(
                    category,
                    style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.black),
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
                                    final subItems = itemMap[item]!.keys
                                        .where((k) => k != 'shared' && !k.startsWith('__'))
                                        .toList();
                                        // ..sort(); // Insertion order maintained by Map

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
                                      stream: FirebaseFirestore.instance.collection('inventory').doc(category).snapshots(),
                                      builder: (context, snapshot) {
                                        if (!snapshot.hasData) {
                                          return const Scaffold(
                                            body: Center(child: CircularProgressIndicator()),
                                          );
                                        }

                                        final freshData = snapshot.data!.data() as Map<String, dynamic>? ?? {};
                                        final freshItemMap = (freshData[item] as Map<String, dynamic>?) ?? {};

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
                                            final m = freshItemMap[subItem];
                                            if (m is Map && m[weight] is num) {
                                              return (m[weight] as num).toInt();
                                            }
                                            return null;
                                          },
                                          setValue: ({required subItem, required weight, required value}) async {
                                            await _setInventoryQuantity(
                                              category: category,
                                              item: item,
                                              subItem: subItem,
                                              weight: weight,
                                              value: value,
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