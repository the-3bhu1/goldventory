import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:goldventory/app/theme.dart';
import 'package:goldventory/core/widgets/editable_cell.dart';
import 'package:goldventory/core/widgets/responsive_layout.dart';
import 'package:goldventory/global/global_state.dart';
import 'package:goldventory/core/utils/helpers.dart';

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
  final int? Function({required String subItem, required String weight})
      getValue;
  final Future<void> Function(
      {required String subItem,
      required String weight,
      required int? value}) setValue;
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
    this.isSharedWeights = false,
  });

  final bool isSharedWeights;

  @override
  State<InventoryTable> createState() => _InventoryTableState();
}

class _InventoryTableState extends State<InventoryTable> {
  @override
  Widget build(BuildContext context) {
    const double cellWidth = 88;

    List<String> filteredSubItems =
        widget.subItems.where((s) => s.trim().isNotEmpty).toList();

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
    final availableHeight = screenHeight -
        kToolbarHeight -
        MediaQuery.of(context).padding.top -
        100;
    final rowHeight =
        (availableHeight / (filteredSubItems.length + 1)).clamp(68.0, 120.0);
    final fontSize = Responsive.textSize(context, base: 16);

    final typeColWidthRaw = (screenWidth / 3.3);
    final typeColWidth = (typeColWidthRaw.clamp(100.0, screenWidth));

    final bool isThreshold = widget.mode == InventoryTableMode.threshold;

    final tableContent = GestureDetector(
      behavior: HitTestBehavior.translucent,
      onTap: () {
        FocusManager.instance.primaryFocus?.unfocus();
      },
      child: SingleChildScrollView(
        scrollDirection: Axis.vertical,
        child: SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: IntrinsicWidth(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (widget.isSharedWeights && filteredSubItems.isNotEmpty) ...[
                  // --- SHARED WEIGHTS MODE: Single Header ---
                  (() {
                    // Use weights from the first sub-item as the shared schema
                    final firstSub = filteredSubItems.first;
                    final weights = widget
                        .weightsForSubItem(firstSub)
                        .where(
                            (w) => w.trim().isNotEmpty && !w.startsWith('__'))
                        .toList();

                    return Row(
                      children: [
                        Container(
                          width: typeColWidth,
                          height: rowHeight,
                          padding: const EdgeInsets.symmetric(horizontal: 12),
                          decoration: BoxDecoration(
                            color: AppColors.shimmerBase(context),
                            border: Border(
                              right: BorderSide(
                                  color: AppColors.borderGrey(context),
                                  width: 1.0),
                              bottom: BorderSide(
                                  color: AppColors.borderGrey(context)),
                            ),
                          ),
                          alignment: Alignment.centerLeft,
                          child: Text(
                            'Type',
                            style: TextStyle(
                              fontWeight: FontWeight.w600,
                              fontSize: fontSize,
                              color: Theme.of(context)
                                  .colorScheme
                                  .onSurfaceVariant,
                            ),
                          ),
                        ),
                        ...weights.map((w) => Container(
                              width: cellWidth,
                              height: rowHeight,
                              alignment: Alignment.center,
                              decoration: BoxDecoration(
                                color: AppColors.shimmerBase(context),
                                border: Border(
                                  right: BorderSide(
                                      color: AppColors.borderGrey(context)),
                                  bottom: BorderSide(
                                      color: AppColors.borderGrey(context)),
                                ),
                              ),
                              child: Text(
                                w,
                                style: TextStyle(
                                  fontWeight: FontWeight.w600,
                                  fontSize: fontSize,
                                  color: Theme.of(context)
                                      .colorScheme
                                      .onSurfaceVariant,
                                ),
                              ),
                            )),
                      ],
                    );
                  })(),
                ],
                ...filteredSubItems.expand((subItem) {
                  // Determine weights for this sub-item
                  final weights = widget
                      .weightsForSubItem(subItem)
                      .where((w) => w.trim().isNotEmpty && !w.startsWith('__'))
                      .toList();

                  if (weights.isEmpty) {
                    return <Widget>[
                      Row(
                        children: [
                          Container(
                            width: typeColWidth,
                            height: rowHeight,
                            padding: const EdgeInsets.symmetric(horizontal: 12),
                            decoration: BoxDecoration(
                              color: AppColors.shimmerBase(context),
                              border: Border(
                                right: BorderSide(
                                    color: AppColors.borderGrey(context),
                                    width: 1.0),
                                bottom: BorderSide(
                                    color: AppColors.borderGrey(context)),
                              ),
                            ),
                            alignment: Alignment.centerLeft,
                            child: Text(
                              'Type',
                              style: TextStyle(
                                fontWeight: FontWeight.w600,
                                fontSize: fontSize,
                                color: Theme.of(context)
                                    .colorScheme
                                    .onSurfaceVariant,
                              ),
                            ),
                          ),
                          // Message Cell
                          Expanded(
                            child: Container(
                              height: rowHeight,
                              alignment: Alignment.centerLeft,
                              padding: const EdgeInsets.only(left: 12),
                              decoration: BoxDecoration(
                                color: Theme.of(context).cardColor,
                                border: Border(
                                  bottom: BorderSide(
                                      color: AppColors.borderGrey(context)),
                                ),
                              ),
                              child: Text(
                                'Add weights for ${subItem == 'shared' ? 'Shared' : subItem}',
                                style: TextStyle(
                                  fontStyle: FontStyle.italic,
                                  color: AppColors.textGrey(context),
                                  fontSize: fontSize,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                      // Value Row (Placeholder or just skip?)
                      // The user said "I need the same message... also all similar messages should propagate"
                      // In Inventory mode, usually we might just show the message row.
                      // Let's mirror the "Header" style row above but with message.
                    ];
                  }

                  // If NOT shared weights, we repeat the header for EVERY sub-item
                  final showHeader = !widget.isSharedWeights;

                  return [
                    if (showHeader)
                      Row(
                        children: [
                          Container(
                            width: typeColWidth,
                            height: rowHeight,
                            padding: const EdgeInsets.symmetric(horizontal: 12),
                            decoration: BoxDecoration(
                              color: AppColors.shimmerBase(context),
                              border: Border(
                                right: BorderSide(
                                    color: AppColors.borderGrey(context),
                                    width: 1.0),
                                bottom: BorderSide(
                                    color: AppColors.borderGrey(context)),
                              ),
                            ),
                            alignment: Alignment.centerLeft,
                            child: Text(
                              'Type',
                              style: TextStyle(
                                fontWeight: FontWeight.w600,
                                fontSize: fontSize,
                                color: Theme.of(context)
                                    .colorScheme
                                    .onSurfaceVariant,
                              ),
                            ),
                          ),
                          ...weights.map((w) => Container(
                                width: cellWidth,
                                height: rowHeight,
                                alignment: Alignment.center,
                                decoration: BoxDecoration(
                                  color: AppColors.shimmerBase(context),
                                  border: Border(
                                    right: BorderSide(
                                        color: AppColors.borderGrey(context)),
                                    bottom: BorderSide(
                                        color: AppColors.borderGrey(context)),
                                  ),
                                ),
                                child: Text(
                                  w,
                                  style: TextStyle(
                                    fontWeight: FontWeight.w600,
                                    fontSize: fontSize,
                                    color: Theme.of(context)
                                        .colorScheme
                                        .onSurfaceVariant,
                                  ),
                                ),
                              )),
                        ],
                      ),

                    // The Value Row
                    Row(
                      children: [
                        Container(
                          width: typeColWidth,
                          height: rowHeight,
                          padding: const EdgeInsets.symmetric(horizontal: 12),
                          decoration: BoxDecoration(
                            color: AppColors.shimmerBase(context),
                            border: Border(
                              right: BorderSide(
                                  color: AppColors.borderGrey(context),
                                  width: 1.0),
                              bottom: BorderSide(
                                  color: AppColors.borderGrey(context)),
                            ),
                          ),
                          alignment: Alignment.centerLeft,
                          child: (() {
                            final label =
                                subItem == 'shared' ? 'Shared' : subItem;
                            final assetPath =
                                Helpers.getSubItemImage(widget.category, label);
                            final bool isJhumkis =
                                widget.category.toUpperCase() == 'JHUMKIS';

                            if (assetPath != null) {
                              if (isJhumkis) {
                                // For Jhumkis, show BOTH image and text in a Column
                                return Padding(
                                  padding: const EdgeInsets.all(4.0),
                                  child: Column(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Expanded(
                                        child: Image.asset(
                                          assetPath,
                                          fit: BoxFit.contain,
                                          errorBuilder: (context, error,
                                                  stackTrace) =>
                                              const Icon(Icons.image, size: 16),
                                        ),
                                      ),
                                      const SizedBox(height: 2),
                                      Text(
                                        label,
                                        textAlign: TextAlign.center,
                                        style: TextStyle(
                                          fontSize: fontSize *
                                              0.75, // Slightly smaller text
                                          fontWeight: FontWeight.w600,
                                        ),
                                        maxLines: 2,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ],
                                  ),
                                );
                              } else {
                                // For Teeka etc, just show the Image if found
                                return Padding(
                                  padding: const EdgeInsets.all(4.0),
                                  child: Image.asset(
                                    assetPath,
                                    fit: BoxFit.contain,
                                    errorBuilder:
                                        (context, error, stackTrace) => Text(
                                      label,
                                      style: TextStyle(
                                          fontSize: fontSize,
                                          fontWeight: FontWeight.w600),
                                    ),
                                  ),
                                );
                              }
                            }

                            return Text(
                              label,
                              style: TextStyle(
                                fontSize: fontSize,
                                fontWeight: FontWeight.w600,
                              ),
                            );
                          })(),
                        ),
                        ...weights.map((weight) {
                          final value =
                              widget.getValue(subItem: subItem, weight: weight);
                          return Container(
                            width: cellWidth,
                            height: rowHeight,
                            decoration: BoxDecoration(
                              border: Border(
                                right: BorderSide(
                                    color: AppColors.borderGrey(context)),
                                bottom: BorderSide(
                                    color: AppColors.borderGrey(context)),
                              ),
                            ),
                            child: EditableCell(
                              initialValue: value,
                              colorResolver: (v) {
                                // Threshold mode -> always neutral
                                if (isThreshold) {
                                  return Theme.of(context).brightness ==
                                          Brightness.light
                                      ? Colors.grey.shade100
                                      : Colors.grey.shade900;
                                }

                                // Inventory mode -> check threshold
                                if (v == null) {
                                  return Theme.of(context).brightness ==
                                          Brightness.light
                                      ? Colors.grey.shade100
                                      : Colors.grey.shade900;
                                }

                                // Access GlobalState to get the configured threshold
                                final globalState = Provider.of<GlobalState>(
                                    context,
                                    listen: false);
                                final threshold = globalState.getThresholdFor(
                                  category: widget.category,
                                  item: widget.item,
                                  subItem:
                                      subItem, // Thresholds are stored per sub-item (even shared ones are copied)
                                  weight: weight,
                                );

                                if (threshold == null) {
                                  // No threshold configured -> Grey
                                  return Theme.of(context).brightness ==
                                          Brightness.light
                                      ? Colors.grey.shade100
                                      : Colors.grey.shade900;
                                }

                                if (v < threshold) {
                                  // Below threshold -> Red
                                  return Theme.of(context).brightness ==
                                          Brightness.light
                                      ? Colors.red.shade100
                                      : Colors.red.shade900;
                                } else {
                                  // At or above threshold -> Green
                                  return Theme.of(context).brightness ==
                                          Brightness.light
                                      ? Colors.green.shade100
                                      : Colors.green.shade900;
                                }
                              },
                              onValueSaved: (parsed) async {
                                await widget.setValue(
                                  subItem: subItem,
                                  weight: weight,
                                  value: parsed,
                                );
                              },
                            ),
                          );
                        }),
                      ],
                    ),
                  ];
                }),
              ],
            ),
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
    );
  }
}
