import 'dart:io';
import 'package:goldventory/core/utils/helpers.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:path_provider/path_provider.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:goldventory/core/services/inventory_snapshot_service.dart';
import 'package:goldventory/core/widgets/responsive_layout.dart';
import 'package:goldventory/core/widgets/shimmer_loading.dart';
import 'package:open_filex/open_filex.dart';
import 'package:goldventory/app/routes.dart';
import '../../../../app/theme.dart';

import '../../../../global/global_state.dart';

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

  String _encodeKey(String raw) =>
      raw.trim().replaceAll('.', '_').replaceAll('/', '_');

  String _encodeWeightKey(String subItem, String weight) {
    final safeSub = subItem.isEmpty ? '__shared__' : _encodeKey(subItem);
    final safeWeight = _encodeKey(weight);
    return '$safeSub|$safeWeight';
  }

  late Stream<List<ReorderRow>> _reorderStream;

  @override
  void initState() {
    super.initState();
    final globalState = Provider.of<GlobalState>(context, listen: false);
    _reorderStream =
        InventorySnapshotService(thresholdService: globalState.thresholds)
            .streamReorderRows();
  }

  @override
  Widget build(BuildContext context) {
    // Listen to GlobalState for loading changes
    final globalState = Provider.of<GlobalState>(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Reorder Needed'),
        centerTitle: true,
        actions: [
          IconButton(
            tooltip: 'Pending Orders',
            color: Theme.of(context).brightness == Brightness.light
                ? Colors.black
                : Colors.white,
            icon: const Icon(Icons.receipt_long),
            onPressed: () {
              Navigator.of(context).pushNamed(AppRoutes.orders);
            },
          ),
        ],
      ),
      body: Padding(
        padding: Responsive.screenPadding(context),
        child: globalState.isLoading
            ? ShimmerLoading.list(
                itemCount: 5,
                itemBuilder: (context, index) => Container(
                  margin: const EdgeInsets.symmetric(vertical: 8),
                  height: 60,
                  decoration: BoxDecoration(
                    color: AppColors.shimmerBase(context),
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              )
            : StreamBuilder<List<ReorderRow>>(
                stream: _reorderStream,
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return ShimmerLoading.list(
                      itemCount: 5,
                      itemBuilder: (context, index) => Container(
                        margin: const EdgeInsets.symmetric(vertical: 8),
                        height: 60,
                        decoration: BoxDecoration(
                          color: AppColors.shimmerBase(context),
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                    );
                  }

                  final rows = snapshot.data ?? [];
                  if (rows.isEmpty) {
                    return const Center(
                        child: Text('All stock levels are healthy!'));
                  }

                  final Map<String, List<ReorderRow>> grouped = {};
                  for (final r in rows) {
                    final key = '${r.category}|${r.item}';
                    grouped.putIfAbsent(key, () => []).add(r);
                  }

                  return ListView(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    children: grouped.entries.map((entry) {
                      final rowsForItem = entry.value;
                      final title = rowsForItem.first.item;

                      return Card(
                        color: AppColors.inventoryCardBackground(context),
                        child: ExpansionTile(
                          key: ValueKey(entry.key),
                          maintainState: true,
                          title: Text(title),
                          backgroundColor:
                              AppTheme.getHighlightBackground(context),
                          children: [
                            SingleChildScrollView(
                              scrollDirection: Axis.horizontal,
                              child: DataTable(
                                columns: const [
                                  DataColumn(label: Text('Select')),
                                  DataColumn(label: Text('Sub Item')),
                                  DataColumn(label: Text('Weight')),
                                  DataColumn(label: Text('To Order')),
                                  DataColumn(label: Text('Pending')),
                                ],
                                rows: rowsForItem.map((r) {
                                  final rowKey =
                                      '${r.category}|${r.item}|${r.subItem}|${r.weight}';
                                  _selected.putIfAbsent(rowKey, () => false);

                                  final isOrderable = r.toOrder > 0;

                                  return DataRow(cells: [
                                    DataCell(Checkbox(
                                      value: _selected[rowKey],
                                      onChanged: isOrderable
                                          ? (v) => setState(() =>
                                              _selected[rowKey] = v ?? false)
                                          : null,
                                    )),
                                    DataCell(
                                        Text(r.subItem.replaceAll('_', ' '))),
                                    DataCell(Text('${r.weight} g')),
                                    DataCell(Text(r.toOrder > 0
                                        ? r.toOrder.toString()
                                        : '')),
                                    DataCell(Text(r.pending > 0
                                        ? r.pending.toString()
                                        : '')),
                                  ]);
                                }).toList(),
                              ),
                            ),
                          ],
                        ),
                      );
                    }).toList(),
                  );
                },
              ),
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.endFloat,
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: Theme.of(context).brightness == Brightness.light
            ? Theme.of(context).cardColor
            : Theme.of(context).primaryColor,
        foregroundColor: Theme.of(context).brightness == Brightness.light
            ? Theme.of(context).primaryColor
            : Theme.of(context).colorScheme.onPrimary,
        onPressed: () async {
          // Build PDF only from rows the user has checked
          // Use snapshot rows and _selected to build selectedRows
          final List<Map<String, dynamic>> selectedRows = [];

          // Need to get the latest rows from the snapshot service
          final globalState = Provider.of<GlobalState>(context, listen: false);
          final thresholdService = globalState.thresholds;
          final snapshotService =
              InventorySnapshotService(thresholdService: thresholdService);
          final rows = await snapshotService.streamReorderRows().first;

          for (final entry in _selected.entries) {
            if (!entry.value) continue;

            final parts = entry.key.split('|');
            if (parts.length != 4) continue;

            final category = parts[0];
            final item = parts[1];
            final subItem = parts[2];
            final weight = parts[3];

            final row = rows.firstWhere(
              (r) =>
                  r.category == category &&
                  r.item == item &&
                  r.subItem == subItem &&
                  r.weight == weight,
              orElse: () => throw StateError('Selected row not found'),
            );

            selectedRows.add({
              'category': category,
              'item': item,
              'subItem': subItem,
              'weight': weight,
              'weightKey': _encodeWeightKey(subItem, weight),
              'toOrder': row.toOrder,
              'rowKey': entry.key,
            });
          }

          if (selectedRows.isEmpty) {
            Helpers.showSnackBar('Please select at least one row to export');
            return;
          }

          // Create order in Firestore using snapshot-based payload
          final orderItems = selectedRows
              .map((r) => {
                    'productId': r[
                        'category'], // IMPORTANT: productId IS the category name in this app structure
                    'category': r['category'],
                    'item': r['item'],
                    'subItem': r['subItem'],
                    'weight': r['weight'],
                    'weightKey': r['weightKey'],
                    'qtyOrdered': r['toOrder'],
                  })
              .toList();

          final orderDoc =
              await FirebaseFirestore.instance.collection('orders').add({
            'status': 'pending',
            'createdAt': FieldValue.serverTimestamp(),
            'items': orderItems,
          });

          final orderId = orderDoc.id;

          // Uncheck selected rows now that order placed
          setState(() {
            for (final r in selectedRows) {
              final rk = r['rowKey'] as String;
              _selected[rk] = false;
            }
          });

          // Create a human-friendly order name (DD-MM-YYYY) for display
          final nowPlaced = DateTime.now().toLocal();
          final orderDisplayName = _formatDateDdMmYyyy(nowPlaced);

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

                  // group rows by category|item
                  for (var groupKey in selectedRows
                      .map((e) => '${e['category']}|${e['item']}')
                      .toSet())
                    pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.start,
                      children: [
                        pw.Text(
                          groupKey
                              .split('|')[1]
                              .replaceAll('_', ' ')
                              .toUpperCase(),
                          style: pw.TextStyle(
                              fontSize: 18, fontWeight: pw.FontWeight.bold),
                        ),
                        pw.SizedBox(height: 6),
                        pw.TableHelper.fromTextArray(
                          headers: ['Sub Item', 'Weight', 'To Order'],
                          data: selectedRows
                              .where((r) =>
                                  '${r['category']}|${r['item']}' == groupKey)
                              .map((r) => [
                                    r['subItem']
                                        .toString()
                                        .replaceAll('_', ' '),
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
        icon: const Icon(Icons.share),
        label: const Text('Export'),
      ),
    );
  }
}
