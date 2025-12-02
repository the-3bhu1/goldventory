// ignore_for_file: deprecated_member_use

import 'dart:io';
import 'dart:math';
import 'package:goldventory/core/utils/helpers.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:path_provider/path_provider.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:goldventory/features/inventory/view_model/inventory_view_model.dart';
import 'package:goldventory/core/widgets/responsive_layout.dart';
import 'package:goldventory/data/models/product_model.dart';
import 'package:open_filex/open_filex.dart';
import 'package:goldventory/app/routes.dart';

class ReorderScreen extends StatefulWidget {
  const ReorderScreen({super.key});

  @override
  State<ReorderScreen> createState() => _ReorderScreenState();
}

class _ReorderScreenState extends State<ReorderScreen> {
  final Map<String, bool> _selected = {};

  String _formatDateDdMmYyyy(DateTime d) {
    final dd = d.day.toString().padLeft(2, '0');
    final mm = d.month.toString().padLeft(2, '0');
    final yyyy = d.year.toString();
    return '$dd-$mm-$yyyy';
  }

  @override
  Widget build(BuildContext context) {
    final viewModel = Provider.of<InventoryViewModel>(context, listen: false);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Reorder Needed'),
        centerTitle: true,
        actions: [
          IconButton(
            tooltip: 'Pending Orders',
            icon: const Icon(Icons.receipt_long),
            onPressed: () {
              Navigator.of(context).pushNamed(AppRoutes.orders);
            },
          ),
        ],
      ),
      body: Padding(
        padding: Responsive.screenPadding(context),
        child: StreamBuilder<List<ProductModel>>(
          stream: viewModel.lowStockProducts,
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }

            final products = snapshot.data ?? [];
            if (products.isEmpty) {
              return const Center(
                child: Text(
                  'All stock levels are healthy!',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.w500),
                ),
              );
            }

            return ListView.builder(
              itemCount: products.length,
              itemBuilder: (context, index) {
                final product = products[index];
                final uiName = product.name
                    .replaceAll('_', ' ')
                    .split(' ')
                    .map((word) => word.isNotEmpty
                        ? word[0].toUpperCase() + word.substring(1)
                        : word)
                    .join(' ');
                final lowStockWeights = product.weights.entries
                    .where((e) => e.value < product.threshold)
                    .toList();
                // helper to title-case a string
                String titleCase(String s) => s.split(' ').map((w) => w.isNotEmpty ? (w[0].toUpperCase() + w.substring(1)) : w).join(' ');

                return Center(
                  child: ConstrainedBox(
                    constraints: BoxConstraints(
                      // On tablet/large screens limit the max width so content is readable
                      maxWidth: Responsive.isTablet(context) ? 1100 : double.infinity,
                    ),
                    child: Card(
                      color: Color(0xFFC6E6DA),
                      shadowColor: Theme.of(context).colorScheme.primary.withOpacity(0.4),
                      elevation: 3,
                      margin: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
                      child: ExpansionTile(
                        key: PageStorageKey(product.id),
                        title: Text(
                          uiName,
                          style: TextStyle(
                            fontSize: Responsive.textSize(context, base: 18),
                            color: Colors.black,
                          ),
                        ),
                        tilePadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                        childrenPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        backgroundColor: Color(0xFFF0F8F3),
                        children: [
                          Padding(
                            padding: const EdgeInsets.all(8.0),
                            child: SingleChildScrollView(
                              key: PageStorageKey('${product.id}_hscroll'),
                              scrollDirection: Axis.horizontal,
                              child: ConstrainedBox(
                                // ensure table takes reasonable width on wide screens
                                constraints: BoxConstraints(
                                  minWidth: Responsive.isTablet(context)
                                      ? MediaQuery.of(context).size.width * 0.7
                                      : MediaQuery.of(context).size.width * 0.95,
                                ),
                                child: DataTable(
                                  columnSpacing: 28,
                                  dataRowHeight: Responsive.rowHeight(context, base: 48),
                                  headingRowHeight: 56,
                                  columns: const [
                                    DataColumn(label: Text('Select')),
                                    DataColumn(label: Text('Type')),
                                    DataColumn(label: Text('Weight')),
                                    DataColumn(label: Text('Pending')),
                                    DataColumn(label: Text('To Order')),
                                  ],
                                  rows: lowStockWeights.map((entry) {
                                    final parts = entry.key.split('|');
                                    final rawType = parts.length > 1 ? parts[0] : '';
                                    final rawWeight = parts.length > 1 ? parts[1] : parts[0];
                                    final type = titleCase(rawType.replaceAll('_', ' '));
                                    final weight = rawWeight.replaceAll('_', ' ');
                                    final currentQty = entry.value;
                                    final threshold = product.threshold;
                                    // support both stored key formats when resolving pending: prefer exact key, then underscored variant
                                    final pendingQty = product.pending[entry.key] ?? product.pending[entry.key.replaceAll(' ', '_')] ?? 0;
                                    final toOrder = max(threshold - (currentQty + pendingQty), 0);

                                    final rowKey = '${product.id}::${entry.key}';

                                    _selected.putIfAbsent(rowKey, () => false);

                                    return DataRow(cells: [
                                      DataCell(
                                        Checkbox(
                                          value: _selected[rowKey],
                                          onChanged: (v) {
                                            setState(() {
                                              _selected[rowKey] = v ?? false;
                                            });
                                          },
                                        ),
                                      ),
                                      DataCell(Text(type, style: TextStyle(fontSize: Responsive.textSize(context, base: 14)))),
                                      DataCell(Text('$weight g', style: TextStyle(fontSize: Responsive.textSize(context, base: 14)))),
                                      DataCell(Text(pendingQty.toString(), style: TextStyle(fontSize: Responsive.textSize(context, base: 14)))),
                                      DataCell(Text(toOrder.toString(), style: TextStyle(fontSize: Responsive.textSize(context, base: 14)))),
                                    ]);
                                  }).toList(),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              },
            );
          },
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: Theme.of(context).primaryColor,
        onPressed: () async {
          // Build PDF only from rows the user has checked
          final snapshot = await viewModel.lowStockProducts.first;
          final products = snapshot;

          // collect selected rows
          final List<Map<String, dynamic>> selectedRows = [];

          for (var product in products) {
            // compute UI display name inside this loop so it's available here
            final uiName = product.name
                .replaceAll('_', ' ')
                .split(' ')
                .map((word) => word.isNotEmpty ? word[0].toUpperCase() + word.substring(1) : word)
                .join(' ');
            for (var e in product.weights.entries) {
              final key = '${product.id}::${e.key}';
              final selected = _selected[key] ?? false;
              if (!selected) continue;

              final parts = e.key.split('|');
              final type = parts.length > 1 ? parts[0] : '';
              final weight = parts.length > 1 ? parts[1] : parts[0];
              final currentQty = e.value;
              final threshold = product.threshold;
              final pendingQty = product.pending[e.key] ?? 0;
              final toOrder = max(threshold - (currentQty + pendingQty), 0);

              selectedRows.add({
                'productId': product.id,
                'productName': uiName,
                'type': type,
                'weight': weight,
                'weightKey': e.key,
                'currentQty': currentQty,
                'threshold': threshold,
                'pending': pendingQty,
                'toOrder': toOrder,
                'rowKey': key,
              });
            }
          }

          if (selectedRows.isEmpty) {
            Helpers.showSnackBar('Please select at least one row to export');
            return;
          }

          // Create order in Firestore using repository before generating PDF
          final repo = Provider.of<InventoryViewModel>(context, listen: false).repo;
          final orderItems = selectedRows.map((r) => {
            'productId': r['productId'],
            'weightKey': r['weightKey'],
            'qtyOrdered': r['toOrder'],
          }).toList();

          String orderId;
          try {
            orderId = await repo.createOrder(orderItems);
          } catch (e) {
            Helpers.showSnackBar('Order creation failed: $e');
            return;
          }

          // Uncheck selected rows now that order placed
          setState(() {
            for (final r in selectedRows) {
              final rk = r['rowKey'] as String;
              _selected[rk] = false;
            }
          });

          // Create a human-friendly order name (DD-MM-YYYY HH:MM) for display
          final nowPlaced = DateTime.now().toLocal();
          final hh = nowPlaced.hour.toString().padLeft(2, '0');
          final mm = nowPlaced.minute.toString().padLeft(2, '0');
          final orderDisplayName = '${_formatDateDdMmYyyy(nowPlaced)} $hh:$mm';

          // Persist the display name onto the order document so other screens can show it
          try {
            await FirebaseFirestore.instance
                .collection('orders')
                .doc(orderId)
                .update({'orderName': orderDisplayName});
          } catch (e) {
            // ignore failures to update orderName — order already exists and display fallback will work
          }

          Helpers.showSnackBar('Order placed: $orderDisplayName');

          // proceed with PDF generation using the selectedRows captured above
          final pdf = pw.Document();
          final now = DateTime.now().toLocal();
          final dateStr = _formatDateDdMmYyyy(now);

          pdf.addPage(
            pw.MultiPage(
              build: (pw.Context context) {
                return [
                  // date top-right
                  pw.Row(
                    mainAxisAlignment: pw.MainAxisAlignment.end,
                    children: [
                      pw.Text(dateStr, style: pw.TextStyle(fontSize: 12)),
                    ],
                  ),
                  pw.SizedBox(height: 8),
                  pw.Text(
                    'Reorder Summary',
                    style: pw.TextStyle(
                      fontSize: 24,
                      fontWeight: pw.FontWeight.bold,
                    ),
                  ),
                  pw.SizedBox(height: 16),

                  // group rows by product
                  for (var productName in selectedRows.map((e) => e['productName'] as String).toSet())
                    pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.start,
                      children: [
                        pw.Text(
                          productName.replaceAll('_', ' ').toUpperCase(),
                          style: pw.TextStyle(fontSize: 18, fontWeight: pw.FontWeight.bold),
                        ),
                        pw.SizedBox(height: 6),
                        pw.TableHelper.fromTextArray(
                          headers: ['Type', 'Weight', 'To Order'],
                          data: selectedRows
                              .where((r) => r['productName'] == productName)
                              .map((r) => [
                            r['type'].toString(),
                            r['weight'].toString(),
                            r['toOrder'].toString(),
                          ])
                              .toList(),
                        ),
                        pw.SizedBox(height: 20),
                      ],
                    ),
                ];
              },
            ),
          );

          // Use an appropriate writeable directory on iOS and other platforms.
          Directory dir;
          if (Platform.isIOS) {
            dir = await getApplicationDocumentsDirectory();
          } else {
            final downloadsDir = await getDownloadsDirectory();
            dir = downloadsDir ?? await getApplicationDocumentsDirectory();
          }

          await dir.create(recursive: true);
          final file = File('${dir.path}/reorder_summary_$dateStr.pdf');
          await file.writeAsBytes(await pdf.save());

          Helpers.showSnackBar('PDF saved to Downloads folder');

          await OpenFilex.open(file.path);
        },
        icon: const Icon(Icons.share, color: Colors.black),
        label: const Text('Export', style: TextStyle(color: Colors.black)),
      ),
    );
  }
}