// ignore_for_file: deprecated_member_use

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../../core/widgets/inventory_table.dart';

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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Inventory')),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('inventory')
            .snapshots(includeMetadataChanges: true),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const _InventorySkeleton();
          }

          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
            return Center(
              child: Text(
                'No inventory yet. Add categories and items in Settings.',
                style: Theme.of(context).textTheme.bodyMedium,
                textAlign: TextAlign.center,
              ),
            );
          }

          if (snapshot.data!.metadata.isFromCache) {
            return const _InventorySkeleton();
          }

          final categoryDocs = snapshot.data!.docs;

          return ListView(
            padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 12),
            children: categoryDocs.map((catDoc) {
              final category = catDoc.id;
              final data = Map<String, dynamic>.from(catDoc.data() as Map);

              // Items are top-level keys under category
              final items = data.keys.where((k) => !k.startsWith('__')).toList()..sort();

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
                                    final itemMap = data[item] as Map<String, dynamic>;
                                    final subItems = _extractSubItems(itemMap);

                                    return InventoryTable(
                                      title: '$item Inventory',
                                      category: category,
                                      item: item,
                                      mode: InventoryTableMode.inventory,
                                      subItems: subItems,
                                      weightsForSubItem: (subItem) {
                                        final m = itemMap[subItem];
                                        if (m is Map<String, dynamic>) {
                                          return m.keys
                                              .where((w) => w != 'shared' && !w.startsWith('__'))
                                              .cast<String>()
                                              .toList()
                                            ..sort();
                                        }
                                        return <String>[];
                                      },
                                      getValue: ({required subItem, required weight}) {
                                        final m = itemMap[subItem];
                                        assert(weight != 'shared', 'InventoryTable tried to read forbidden weight key: shared');
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