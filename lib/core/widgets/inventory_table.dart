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
  final ScrollController _horizontalBodyController = ScrollController();
  final ScrollController _horizontalHeaderController = ScrollController();
  final ScrollController _verticalBodyController = ScrollController();
  final ScrollController _verticalHeaderController = ScrollController();

  bool _isSyncingHorizontal = false;
  bool _isSyncingVertical = false;

  @override
  void initState() {
    super.initState();
    _horizontalBodyController.addListener(_syncHorizontalBody);
    _horizontalHeaderController.addListener(_syncHorizontalHeader);
    _verticalBodyController.addListener(_syncVerticalBody);
    _verticalHeaderController.addListener(_syncVerticalHeader);
  }

  @override
  void dispose() {
    _horizontalBodyController.removeListener(_syncHorizontalBody);
    _horizontalHeaderController.removeListener(_syncHorizontalHeader);
    _verticalBodyController.removeListener(_syncVerticalBody);
    _verticalHeaderController.removeListener(_syncVerticalHeader);

    _horizontalBodyController.dispose();
    _horizontalHeaderController.dispose();
    _verticalBodyController.dispose();
    _verticalHeaderController.dispose();
    super.dispose();
  }

  void _syncHorizontalBody() {
    if (_isSyncingHorizontal) return;
    _isSyncingHorizontal = true;
    if (_horizontalHeaderController.hasClients) {
      _horizontalHeaderController.jumpTo(_horizontalBodyController.offset);
    }
    _isSyncingHorizontal = false;
  }

  void _syncHorizontalHeader() {
    if (_isSyncingHorizontal) return;
    _isSyncingHorizontal = true;
    if (_horizontalBodyController.hasClients) {
      _horizontalBodyController.jumpTo(_horizontalHeaderController.offset);
    }
    _isSyncingHorizontal = false;
  }

  void _syncVerticalBody() {
    if (_isSyncingVertical) return;
    _isSyncingVertical = true;
    if (_verticalHeaderController.hasClients) {
      _verticalHeaderController.jumpTo(_verticalBodyController.offset);
    }
    _isSyncingVertical = false;
  }

  void _syncVerticalHeader() {
    if (_isSyncingVertical) return;
    _isSyncingVertical = true;
    if (_verticalBodyController.hasClients) {
      _verticalBodyController.jumpTo(_verticalHeaderController.offset);
    }
    _isSyncingVertical = false;
  }

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

    Widget buildHeaderCell(String text, {required double width}) {
      return Container(
        width: width,
        height: rowHeight,
        padding: const EdgeInsets.symmetric(horizontal: 12),
        decoration: BoxDecoration(
          color: AppColors.shimmerBase(context),
          border: Border(
            right: BorderSide(color: AppColors.borderGrey(context), width: 1.0),
            bottom: BorderSide(color: AppColors.borderGrey(context)),
          ),
        ),
        alignment: Alignment.center,
        child: Text(
          text,
          textAlign: TextAlign.center,
          style: TextStyle(
            fontWeight: FontWeight.w600,
            fontSize: fontSize,
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
        ),
      );
    }

    Widget buildRowHeaderCell(String subItem, {required double width}) {
      final label = subItem == 'shared' ? 'Shared' : subItem;
      final assetPath = Helpers.getSubItemImage(widget.category, label);
      final bool isJhumkis = widget.category.toUpperCase() == 'JHUMKIS';

      Widget content;
      if (assetPath != null) {
        if (isJhumkis) {
          content = Padding(
            padding: const EdgeInsets.all(4.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Expanded(
                  child: Image.asset(
                    assetPath,
                    fit: BoxFit.contain,
                    errorBuilder: (context, error, stackTrace) =>
                        const Icon(Icons.image, size: 16),
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  label,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: fontSize * 0.75,
                    fontWeight: FontWeight.w600,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          );
        } else {
          content = Padding(
            padding: const EdgeInsets.all(4.0),
            child: Image.asset(
              assetPath,
              fit: BoxFit.contain,
              errorBuilder: (context, error, stackTrace) => Text(
                label,
                textAlign: TextAlign.center,
                style:
                    TextStyle(fontSize: fontSize, fontWeight: FontWeight.w600),
              ),
            ),
          );
        }
      } else {
        content = Text(
          label,
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: fontSize,
            fontWeight: FontWeight.w600,
          ),
        );
      }

      return Container(
        width: width,
        height: rowHeight,
        padding: const EdgeInsets.symmetric(horizontal: 12),
        decoration: BoxDecoration(
          color: AppColors.shimmerBase(context),
          border: Border(
            right: BorderSide(color: AppColors.borderGrey(context), width: 1.0),
            bottom: BorderSide(color: AppColors.borderGrey(context)),
          ),
        ),
        alignment: Alignment.center,
        child: content,
      );
    }

    Widget buildDataCell(String subItem, String weight) {
      final subItemWeights = widget.weightsForSubItem(subItem);
      final hasWeight = subItemWeights.contains(weight);

      if (!hasWeight) {
        return Container(
          width: cellWidth,
          height: rowHeight,
          decoration: BoxDecoration(
            color: Theme.of(context).brightness == Brightness.light
                ? Colors.grey.shade50
                : Colors.black,
            border: Border(
              right: BorderSide(color: AppColors.borderGrey(context)),
              bottom: BorderSide(color: AppColors.borderGrey(context)),
            ),
          ),
        );
      }

      final value = widget.getValue(subItem: subItem, weight: weight);
      return Container(
        width: cellWidth,
        height: rowHeight,
        decoration: BoxDecoration(
          border: Border(
            right: BorderSide(color: AppColors.borderGrey(context)),
            bottom: BorderSide(color: AppColors.borderGrey(context)),
          ),
        ),
        child: EditableCell(
          initialValue: value,
          colorResolver: (v) {
            if (isThreshold) {
              return Theme.of(context).brightness == Brightness.light
                  ? Colors.grey.shade100
                  : Colors.grey.shade900;
            }
            if (v == null) {
              return Theme.of(context).brightness == Brightness.light
                  ? Colors.grey.shade100
                  : Colors.grey.shade900;
            }
            final globalState =
                Provider.of<GlobalState>(context, listen: false);
            final threshold = globalState.getThresholdFor(
              category: widget.category,
              item: widget.item,
              subItem: subItem,
              weight: weight,
            );
            if (threshold == null) {
              return Theme.of(context).brightness == Brightness.light
                  ? Colors.grey.shade100
                  : Colors.grey.shade900;
            }
            if (v < threshold) {
              return Theme.of(context).brightness == Brightness.light
                  ? Colors.red.shade100
                  : Colors.red.shade900;
            } else {
              return Theme.of(context).brightness == Brightness.light
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
    }

    Widget tableWidget;

    if (widget.isSharedWeights) {
      // --- SHARED WEIGHTS MODE: Unified 2D Sticky Grid ---
      final Set<String> allWeightsSet = {};
      for (final sub in filteredSubItems) {
        allWeightsSet.addAll(widget
            .weightsForSubItem(sub)
            .where((w) => w.trim().isNotEmpty && !w.startsWith('__')));
      }
      final List<String> allWeights = allWeightsSet.toList()
        ..sort((a, b) => Helpers.safeNum(a).compareTo(Helpers.safeNum(b)));

      tableWidget = Column(
        children: [
          Row(
            children: [
              buildHeaderCell('Type', width: typeColWidth),
              Expanded(
                child: SingleChildScrollView(
                  controller: _horizontalHeaderController,
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: allWeights
                        .map((w) => buildHeaderCell(w, width: cellWidth))
                        .toList(),
                  ),
                ),
              ),
            ],
          ),
          Expanded(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SizedBox(
                  width: typeColWidth,
                  child: SingleChildScrollView(
                    controller: _verticalHeaderController,
                    scrollDirection: Axis.vertical,
                    physics: const NeverScrollableScrollPhysics(),
                    child: Column(
                      children: filteredSubItems
                          .map(
                              (s) => buildRowHeaderCell(s, width: typeColWidth))
                          .toList(),
                    ),
                  ),
                ),
                Expanded(
                  child: SingleChildScrollView(
                    controller: _verticalBodyController,
                    scrollDirection: Axis.vertical,
                    child: SingleChildScrollView(
                      controller: _horizontalBodyController,
                      scrollDirection: Axis.horizontal,
                      child: Column(
                        children: filteredSubItems.map((subItem) {
                          return Row(
                            children: allWeights
                                .map((weight) => buildDataCell(subItem, weight))
                                .toList(),
                          );
                        }).toList(),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      );
    } else {
      // --- PER SUB-ITEM MODE: Sectioned Layout with Horizontal stickiness ---
      tableWidget = ListView.separated(
        itemCount: filteredSubItems.length,
        padding: EdgeInsets.zero,
        separatorBuilder: (_, __) => const SizedBox(height: 0),
        itemBuilder: (context, index) {
          final subItem = filteredSubItems[index];
          final weights = widget
              .weightsForSubItem(subItem)
              .where((w) => w.trim().isNotEmpty && !w.startsWith('__'))
              .toList()
            ..sort((a, b) => Helpers.safeNum(a).compareTo(Helpers.safeNum(b)));

          if (weights.isEmpty) {
            return Row(
              children: [
                buildRowHeaderCell(subItem, width: typeColWidth),
                Expanded(
                  child: Container(
                    height: rowHeight,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      border: Border(
                        bottom:
                            BorderSide(color: AppColors.borderGrey(context)),
                      ),
                    ),
                    child: Text(
                      'No weights added',
                      style: TextStyle(
                        fontStyle: FontStyle.italic,
                        color: AppColors.textGrey(context),
                      ),
                    ),
                  ),
                ),
              ],
            );
          }

          return Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Fixed Type Column (Header + Data Label)
              Column(
                children: [
                  buildHeaderCell('Type', width: typeColWidth),
                  buildRowHeaderCell(subItem, width: typeColWidth),
                ],
              ),
              // Scrollable Weights
              Expanded(
                child: SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Column(
                    children: [
                      Row(
                        children: weights
                            .map((w) => buildHeaderCell(w, width: cellWidth))
                            .toList(),
                      ),
                      Row(
                        children: weights
                            .map((w) => buildDataCell(subItem, w))
                            .toList(),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          );
        },
      );
    }

    final tableContent = GestureDetector(
      behavior: HitTestBehavior.translucent,
      onTap: () {
        FocusManager.instance.primaryFocus?.unfocus();
      },
      child: tableWidget,
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
