import 'dart:async';

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:goldventory/core/widgets/editable_cell.dart';
import 'package:goldventory/core/widgets/responsive_layout.dart';
import 'package:goldventory/core/utils/helpers.dart';

import 'package:provider/provider.dart';
import 'package:goldventory/features/inventory/view_model/inventory_view_model.dart';

import '../../data/repositories/product_repository.dart';

class InventoryTable extends StatefulWidget {
  final String title;
  final String firestoreDocId;
  final List<String> types;
  final List<String> weights;

  const InventoryTable({
    super.key,
    required this.title,
    required this.firestoreDocId,
    required this.types,
    required this.weights,
  });

  @override
  State<InventoryTable> createState() => _InventoryTableState();
}

class _InventoryTableState extends State<InventoryTable> {
  // Map[type][weight] = quantity
  Map<String, Map<String, int?>> data = {};
  StreamSubscription<DocumentSnapshot>? _subscription;

  @override
  void initState() {
    super.initState();
    // Initialize data with null (empty) values immediately
    for (var type in widget.types) {
      data[type] = {for (var w in widget.weights) w: null};
    }
    _listenToData();
  }

  void _listenToData() {
    _subscription = FirebaseFirestore.instance
        .collection('inventory')
        .doc(widget.firestoreDocId)
        .snapshots()
        .listen((doc) {
      if (!mounted) return;
      if (doc.exists && doc.data() != null) {
        final fetchedData = doc.data()!;
        setState(() {
          for (var type in widget.types) {
            final typeData = Map<String, dynamic>.from(fetchedData[type] ?? {});
            data[type] ??= {};
            for (var w in widget.weights) {
              final safeWeight = w.replaceAll('.', '_');
              final val = typeData[safeWeight];
              if (val is int) {
                data[type]![w] = val;
              } else if (val is String) {
                data[type]![w] = int.tryParse(val);
              }
            }
          }
        });
      }
    });
  }

  Future<void> _updateFirestoreField(String type, String weight, int? val) async {
    try {
      final docRef = FirebaseFirestore.instance
          .collection('inventory')
          .doc(widget.firestoreDocId);

      // Replace '.' with '_' for Firestore-safe key
      final safeWeight = weight.replaceAll('.', '_');
      // Use field-path update into the nested type map only (no flat 'weights' writes)
      final fieldPath = '$type.$safeWeight';

      if (val == null) {
        await docRef.update({fieldPath: FieldValue.delete()});
      } else {
        await docRef.update({fieldPath: val});
      }
    } catch (e) {
      // If update fails because the document does not exist yet, fall back to set with merge
      try {
        final safeWeight = weight.replaceAll('.', '_');
        final mapToSet = {type: {safeWeight: val}};
        await FirebaseFirestore.instance
            .collection('inventory')
            .doc(widget.firestoreDocId)
            .set(mapToSet, SetOptions(merge: true));
      } catch (e2) {
        print('Error updating Firestore field (fallback): $e2');
      }
    }
  }

  void _showAddQuantityDialog() {
    String selectedType = widget.types.first;
    final Map<String, TextEditingController> controllers = {
      for (var w in widget.weights) w: TextEditingController()
    };

    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Bulk Add Quantities'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                DropdownButtonFormField<String>(
                  value: selectedType,
                  decoration: const InputDecoration(labelText: 'Type'),
                  items: widget.types
                      .map((type) =>
                          DropdownMenuItem(value: type, child: Text(type)))
                      .toList(),
                  onChanged: (val) {
                    if (val != null) selectedType = val;
                  },
                ),
                const SizedBox(height: 16),
                const Text('Enter quantities for each weight:',
                    style: TextStyle(fontWeight: FontWeight.bold)),
                const SizedBox(height: 8),
                ...widget.weights.map((w) => Padding(
                      padding: const EdgeInsets.symmetric(vertical: 4),
                      child: TextFormField(
                        controller: controllers[w],
                        keyboardType: TextInputType.number,
                        decoration: InputDecoration(
                          labelText: 'Weight $w',
                          border: const OutlineInputBorder(),
                        ),
                      ),
                    )),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () async {
                // Capture objects that may be needed after awaits so we don't look up
                // ancestor widgets from a deactivated context later.
                final viewModel = Provider.of<InventoryViewModel>(context, listen: false);
                final repo = ProductRepository();

                // 1) Track immediate updates for UI
                final Map<String, Map<String, int>> immediateUpdates = {};

                try {
                  for (var w in widget.weights) {
                    final txt = controllers[w]!.text.trim();
                    final parsed = int.tryParse(txt);
                    if (parsed == null) continue;

                    final currentVal = data[selectedType]?[w] ?? 0;
                    final newVal = parsed; // REPLACE behavior (not add)
                    // 2) Record intended immediate update
                    // record immediate update so UI can reflect change instantly
                    immediateUpdates.putIfAbsent(selectedType, () => {})[w] = newVal;
                    if (newVal == currentVal) continue;

                    final safeWeight = w.replaceAll('.', '_');

                    if (newVal > currentVal) {
                      // allocate increase FIFO to pending orders and update stock via view model
                      final delta = newVal - currentVal;
                      // Construct weightKey used in orders: "type|weightKey"
                      final weightKeyForOrders = '$selectedType|$safeWeight';
                      await viewModel.handleManualIncrease(widget.firestoreDocId, weightKeyForOrders, delta);
                    } else {
                      // Decrease: directly set the backend quantity
                      await repo.updateWeightQuantity(widget.firestoreDocId, safeWeight, newVal);
                    }
                  }

                  // 3) Apply immediate local updates so the table reflects the new values instantly.
                  if (mounted && immediateUpdates.isNotEmpty) {
                    setState(() {
                      immediateUpdates.forEach((typeKey, map) {
                        data[typeKey] ??= {};
                        map.forEach((wKey, val) {
                          data[typeKey]![wKey] = val;
                        });
                      });
                    });
                  }

                  // Refresh local snapshot from backend so UI reflects true values after allocations
                  final docSnap = await FirebaseFirestore.instance
                      .collection('inventory')
                      .doc(widget.firestoreDocId)
                      .get();
                  if (docSnap.exists && docSnap.data() != null) {
                    final fetchedData = docSnap.data()!;
                    if (!mounted) {
                      // widget no longer in tree, just return
                      Helpers.showSnackBar('Quantities updated');
                      return;
                    }

                    setState(() {
                      for (var type in widget.types) {
                        final typeData = Map<String, dynamic>.from(fetchedData[type] ?? {});
                        for (var w in widget.weights) {
                          final safeWeight = w.replaceAll('.', '_');

                          // ONLY update entries that are present in the fetched document.
                          // Do not overwrite or set missing fields to 0 — leave existing local value intact.
                          if (!typeData.containsKey(safeWeight)) continue;

                          final val = typeData[safeWeight];
                          if (val is int) {
                            data[type]![w] = val;
                          } else if (val is String) {
                            data[type]![w] = int.tryParse(val);
                          } else {
                            // if value present but cannot parse, leave existing value unchanged
                            continue;
                          }
                        }
                      }
                    });
                  }

                  Helpers.showSnackBar('Quantities updated');

                  // Close the dialog safely
                  if (Navigator.of(context).canPop()) Navigator.of(context).pop();
                } catch (e) {
                  print('Bulk update failed: $e');
                  Helpers.showSnackBar('Bulk update failed: $e');
                }
              },
              child: const Text('Add'),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final totalCols = widget.weights.length + 1; // 1 for Type column
    final typeColWidthRaw = (screenWidth / totalCols) * 1.2;
    // Ensure the Type column is wide enough to show at least one full word comfortably on most devices
    final typeColWidth = (typeColWidthRaw.clamp(70.0, screenWidth));
    final weightColWidth = ((screenWidth - typeColWidth) / widget.weights.length).clamp(80.0, double.infinity);
    final screenHeight = MediaQuery.of(context).size.height;
    final availableHeight = screenHeight - kToolbarHeight - MediaQuery.of(context).padding.top - 100; // 100px buffer for FAB etc.
    final rowHeight = (availableHeight / (widget.types.length + 1)).clamp(48.0, 120.0);
    // final rowHeight = Responsive.rowHeight(context, base: 48);
    final fontSize = Responsive.textSize(context, base: 16);
    return Scaffold(
      appBar: AppBar(title: Text(widget.title)),
      body: GestureDetector(
        onTap: () => Helpers.unfocus(context),
        child: SingleChildScrollView(
          padding: const EdgeInsets.only(bottom: 96),
          scrollDirection: Axis.vertical,
          child: IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Fixed left type column
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      width: typeColWidth,
                      height: rowHeight,
                      padding: const EdgeInsets.all(8),
                      color: Colors.grey.shade100,
                      child: Align(
                        alignment: Alignment.centerLeft,
                        child: Text(
                          'Type',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: fontSize,
                          ),
                        ),
                      ),
                    ),
                    ...widget.types.map((t) => Container(
                      width: typeColWidth,
                      height: rowHeight,
                      padding: const EdgeInsets.all(8),
                      color: Colors.grey.shade100,
                      alignment: Alignment.centerLeft,
                      child: Text(
                        t,
                        style: TextStyle(fontSize: fontSize),
                      ),
                    )),
                  ],
                ),
                // Scrollable right section horizontally
                Expanded(
                  child: SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: IntrinsicHeight(
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: widget.weights.map((w) {
                          return Column(
                            mainAxisSize: MainAxisSize.min,
                            crossAxisAlignment: CrossAxisAlignment.center,
                            children: [
                              Container(
                                width: weightColWidth,
                                height: rowHeight,
                                padding: const EdgeInsets.all(8),
                                color: Colors.grey.shade100,
                                alignment: Alignment.center,
                                child: Text(
                                  w,
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: fontSize,
                                  ),
                                  textAlign: TextAlign.center,
                                ),
                              ),
                              ...widget.types.map((t) {
                                return Container(
                                  width: weightColWidth,
                                  height: rowHeight,
                                  padding: const EdgeInsets.all(4),
                                  child:
                                      EditableCell(
                                        initialValue: data[t]?[w]?.toString() ?? '',
                                        onValueChanged: (val) {
                                          final parsed = val.trim().isEmpty ? null : int.tryParse(val);
                                          setState(() {
                                            data[t]![w] = parsed;
                                          });
                                          _updateFirestoreField(t, w, parsed);
                                        },
                                        onManualIncrease: (delta) async {
                                          // allocate manual increase to pending orders (FIFO)
                                          try {
                                            final viewModel = Provider.of<InventoryViewModel>(context, listen: false);
                                            // Construct weightKey as stored in orders: "type|weightKey"
                                            final displayWeight = w.replaceAll('.', '_');
                                            final weightKey = '$t|$displayWeight';
                                            await viewModel.handleManualIncrease(widget.firestoreDocId, weightKey, delta);
                                          } catch (e) {
                                            // swallow errors to avoid breaking UI
                                            print('allocateManualReceive failed: $e');
                                          }
                                        },
                                      ),
                                );
                              }),
                            ],
                          );
                        }).toList(),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        heroTag: '${widget.firestoreDocId}_addQuantityFAB',
        onPressed: _showAddQuantityDialog,
        backgroundColor: Theme.of(context).primaryColor,
        foregroundColor: Colors.black,
        label: const Text('Add Quantity'),
        icon: const Icon(Icons.add),
      ),
    );
  }
  @override
  void dispose() {
    _subscription?.cancel();
    super.dispose();
  }
}
