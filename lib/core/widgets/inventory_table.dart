import 'package:flutter/material.dart';
import 'package:goldventory/core/widgets/editable_cell.dart';
import 'package:goldventory/core/widgets/responsive_layout.dart';

import '../services/threshold_service.dart';

enum InventoryTableMode {
  inventory,
  threshold,
}


class InventoryTable extends StatefulWidget {
  final String title;
  final String category;
  final String item;
  /// When true, renders only the table content (no Scaffold/AppBar/FAB)
  final bool embed;

  final InventoryTableMode mode;
  final int? Function({required String subItem, required String weight}) getValue;
  final Future<void> Function({required String subItem, required String weight, required int? value}) setValue;
  final List<String> subItems;
  final List<String> Function(String subItem) weightsForSubItem;

const InventoryTable({
    super.key,
    required this.title,
    required this.category,
    required this.item,
    required this.mode,
    required this.getValue,
    required this.setValue,
    required this.subItems,
    required this.weightsForSubItem,
    this.embed = false,
  });

  @override
  State<InventoryTable> createState() => _InventoryTableState();
}

class _InventoryTableState extends State<InventoryTable> {
  // Bulk update dialog state
  int _bulkDelta = 0;
  String? _selectedSubItem;

  @override
  Widget build(BuildContext context) {
    final filteredSubItems = widget.subItems.where((s) => s.trim().isNotEmpty).toList();
    if (filteredSubItems.isEmpty) {
      return Scaffold(
        appBar: widget.embed ? null : AppBar(title: Text(widget.title)),
        body: const Center(
          child: Text('No sub-items configured.'),
        ),
      );
    }

    final screenWidth = MediaQuery.of(context).size.width;
    final screenHeight = MediaQuery.of(context).size.height;
    final availableHeight = screenHeight - kToolbarHeight - MediaQuery.of(context).padding.top - 100;
    final rowHeight = (availableHeight / (filteredSubItems.length + 1)).clamp(48.0, 120.0);
    final fontSize = Responsive.textSize(context, base: 16);

    final typeColWidthRaw = (screenWidth / 4) * 1.2;
    final typeColWidth = (typeColWidthRaw.clamp(70.0, screenWidth));

    final tableContent = GestureDetector(
      onTap: () => FocusScope.of(context).unfocus(),
      child: SingleChildScrollView(
        padding: const EdgeInsets.only(bottom: 96),
        scrollDirection: Axis.vertical,
        child: IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
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
                      child: Text('Type', style: TextStyle(fontWeight: FontWeight.bold, fontSize: fontSize)),
                    ),
                  ),
                  ...filteredSubItems.map((subItem) => Container(
                        width: typeColWidth,
                        height: rowHeight,
                        padding: const EdgeInsets.all(8),
                        color: Colors.grey.shade100,
                        alignment: Alignment.centerLeft,
                        child: Text(subItem, style: TextStyle(fontSize: fontSize)),
                      )),
                ],
              ),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Header row for weights per subItem
                    Container(
                      height: rowHeight,
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: filteredSubItems.map((subItem) {
                          final weights = widget.weightsForSubItem(subItem).where((w) => w.trim().isNotEmpty).toList();
                          final weightColWidth = ((screenWidth - typeColWidth) / weights.length).clamp(80.0, double.infinity);
                          return Container(
                            width: weightColWidth * weights.length,
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: weights.map((weight) {
                                return Container(
                                  width: weightColWidth,
                                  height: rowHeight,
                                  padding: const EdgeInsets.all(8),
                                  color: Colors.grey.shade100,
                                  alignment: Alignment.center,
                                  child: Text(weight, style: TextStyle(fontWeight: FontWeight.bold, fontSize: fontSize), textAlign: TextAlign.center),
                                );
                              }).toList(),
                            ),
                          );
                        }).toList(),
                      ),
                    ),
                    // Rows per subItem with their weights
                    ...filteredSubItems.map((subItem) {
                      final weights = widget.weightsForSubItem(subItem).where((w) => w.trim().isNotEmpty).toList();
                      final weightColWidth = ((screenWidth - typeColWidth) / weights.length).clamp(80.0, double.infinity);
                      return Container(
                        height: rowHeight,
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: weights.map((weight) {
                            final value = widget.getValue(subItem: subItem, weight: weight);
                            Color bgColor = Colors.grey.shade100;
                            if (widget.mode == InventoryTableMode.inventory && value != null) {
                              final threshold = ThresholdService().getThresholdFor(
                                category: widget.category,
                                item: widget.item,
                                subItem: subItem,
                                weight: weight,
                              );
                              bgColor = value < threshold ? Colors.red.shade100 : Colors.green.shade100;
                            }
                            return Container(
                              width: weightColWidth,
                              height: rowHeight,
                              padding: const EdgeInsets.all(4),
                              child: EditableCell(
                                initialValue: value?.toString() ?? '',
                                backgroundColor: bgColor,
                                onValueChanged: (val) async {
                                  final parsed = val.trim().isEmpty ? null : int.tryParse(val);
                                  try {
                                    await widget.setValue(subItem: subItem, weight: weight, value: parsed);
                                    setState(() {});
                                  } catch (_) {}
                                },
                              ),
                            );
                          }).toList(),
                        ),
                      );
                    }),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );

    if (widget.embed) {
      return Card(
        margin: EdgeInsets.zero,
        child: Padding(
          padding: const EdgeInsets.all(8.0),
          child: tableContent,
        ),
      );
    }
    return Scaffold(
      appBar: AppBar(title: Text(widget.title)),
      body: tableContent,
      floatingActionButton: widget.mode == InventoryTableMode.inventory
          ? FloatingActionButton.extended(
              onPressed: _showBulkUpdateDialog,
              label: const Text('Bulk Update'),
              icon: const Icon(Icons.add),
            )
          : null,
    );
  }

  void _showBulkUpdateDialog() {
    if (widget.subItems.isEmpty) return;

    _selectedSubItem ??= widget.subItems.first;

    showDialog(
      context: context,
      builder: (_) {
        return AlertDialog(
          title: const Text('Bulk Update Quantity'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              DropdownButtonFormField<String>(
                value: _selectedSubItem,
                decoration: const InputDecoration(labelText: 'Sub Item'),
                items: widget.subItems
                    .map((s) => DropdownMenuItem(value: s, child: Text(s)))
                    .toList(),
                onChanged: (v) {
                  setState(() {
                    _selectedSubItem = v;
                  });
                },
              ),
              const SizedBox(height: 12),
              TextField(
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(labelText: 'Set Quantity'),
                onChanged: (v) {
                  setState(() {
                    _bulkDelta = int.tryParse(v) ?? 0;
                  });
                },
              ),
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
            ElevatedButton(
              child: const Text('Apply'),
              onPressed: () async {
                final subItem = _selectedSubItem;
                if (subItem == null || _bulkDelta == 0) return;
                // Bulk update callback: For each weight, call setValue
                for (final weight in widget.weightsForSubItem(subItem)) {
                  await widget.setValue(subItem: subItem, weight: weight, value: _bulkDelta);
                }
                _bulkDelta = 0;
                Navigator.pop(context);
              },
            ),
          ],
        );
      },
    );
  }
}
