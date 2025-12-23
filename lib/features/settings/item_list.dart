import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:goldventory/features/settings/settings_view_model.dart';
import '../../core/utils/helpers.dart';
import '../../core/widgets/inventory_table.dart';
import 'sub_item_list.dart';
import 'item_weights_editor.dart';

/// Shows items for a selected category and allows creating / editing / deleting items
/// Uses SettingsViewModel (local buffer) instead of writing directly to GlobalState.
class ItemList extends StatefulWidget {
  final String category;
  const ItemList({super.key, required this.category});

  @override
  State<ItemList> createState() => _ItemListState();
}

class _ItemListState extends State<ItemList> {
  late SettingsViewModel _vm;

  @override
  void initState() {
    super.initState();
    // Obtain VM (caller should have provided it). If not loaded, trigger load.
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      _vm = Provider.of<SettingsViewModel>(context, listen: false);
      if (_vm.categories.isEmpty) {
        await _vm.load();
      }
    });
  }

  Future<void> _showCreateItemDialog(BuildContext context) async {
    final controller = TextEditingController();
    final vm = Provider.of<SettingsViewModel>(context, listen: false);

    final result = await showDialog<String?>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Create item'),
        content: TextField(
          controller: controller,
          decoration: const InputDecoration(hintText: 'Item name'),
          autofocus: true,
        ),
        actions: [
          TextButton(onPressed: () => Navigator.of(ctx).pop(null), child: const Text('Cancel')),
          ElevatedButton(onPressed: () => Navigator.of(ctx).pop(controller.text.trim()), child: const Text('Create')),
        ],
      ),
    );

    if (result != null && result.isNotEmpty) {
      final item = result;
      // create item locally in VM buffer
      vm.createItem(widget.category, item, threshold: vm.defaultThreshold());
      Helpers.showSnackBar('Item created');
    }
  }

  @override
  Widget build(BuildContext context) {
    final vm = Provider.of<SettingsViewModel>(context);
    final itemKeys = vm.itemsFor(widget.category);

    return Scaffold(
      appBar: AppBar(title: Text(widget.category)),
      body: Padding(
        padding: const EdgeInsets.all(12.0),
        child: Column(
          children: [
            Expanded(
              child: itemKeys.isEmpty
                  ? Center(child: Text('No items in this category. Tap + to add one.'))
                  : ListView.separated(
                      itemCount: itemKeys.length,
                      separatorBuilder: (_, __) => const Divider(height: 1),
                      itemBuilder: (ctx, idx) {
                        final item = itemKeys[idx];
                        final subItems = vm.subItemsFor(widget.category, item);
                        final subCount = subItems.length;
                        final displaySubtitle = subCount == 1
                            ? '1 sub-item'
                            : '$subCount sub-items';

                        return ListTile(
                          title: Text(item),
                          subtitle: Text(displaySubtitle),
                          trailing: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              IconButton(
                                icon: const Icon(Icons.edit),
                                tooltip: 'Edit thresholds',
                                onPressed: () {
                                  final subItems = vm.subItemsFor(widget.category, item);

                                  Navigator.of(context).push(
                                    MaterialPageRoute(
                                      builder: (_) => InventoryTable(
                                        title: '$item – Thresholds',
                                        category: widget.category,
                                        item: item,
                                        mode: InventoryTableMode.threshold,
                                        subItems: subItems,
                                        weightsForSubItem: (subItem) {
                                          return vm.weightsForSubItem(
                                            widget.category,
                                            item,
                                            subItem,
                                          );
                                        },
                                        getValue: ({required subItem, required weight}) {
                                          return vm.thresholdFor(
                                            category: widget.category,
                                            item: item,
                                            subItem: subItem,
                                            weight: weight,
                                          );
                                        },
                                        setValue: ({required subItem, required weight, required int? value}) {
                                          if (value == null) return Future.value();
                                          vm.setThreshold(
                                            category: widget.category,
                                            item: item,
                                            subItem: subItem,
                                            weight: weight,
                                            threshold: value,
                                          );
                                          return Future.value();
                                        },
                                      ),
                                    ),
                                  );
                                },
                              ),
                              IconButton(
                                icon: const Icon(Icons.view_column),
                                tooltip: 'Edit columns',
                                onPressed: () {
                                  Navigator.of(context).push(MaterialPageRoute(
                                    builder: (_) => ChangeNotifierProvider.value(
                                      value: vm,
                                      child: ItemWeightsEditor(category: widget.category, item: item),
                                    ),
                                  ));
                                },
                              ),
                              IconButton(
                                icon: const Icon(Icons.view_list),
                                tooltip: 'Sub-items',
                                onPressed: () {
                                  Navigator.of(context).push(MaterialPageRoute(
                                    builder: (_) => ChangeNotifierProvider.value(
                                      value: vm,
                                      child: SubItemList(category: widget.category, item: item),
                                    ),
                                  ));
                                },
                              ),
                              IconButton(
                                icon: const Icon(Icons.delete),
                                tooltip: 'Delete item',
                                onPressed: () async {
                                  final confirmed = await showDialog<bool?>(
                                    context: context,
                                    builder: (dctx) => AlertDialog(
                                      title: Text('Delete "$item"?'),
                                      content: const Text('This will remove the item from the local changes.'),
                                      actions: [
                                        TextButton(onPressed: () => Navigator.of(dctx).pop(false), child: const Text('Cancel')),
                                        ElevatedButton(onPressed: () => Navigator.of(dctx).pop(true), child: const Text('Delete')),
                                      ],
                                    ),
                                  );
                                  if (confirmed == true) {
                                    vm.deleteItem(widget.category, item);
                                    Helpers.showSnackBar('Item removed');
                                  }
                                },
                              ),
                            ],
                          ),
                        );
                      },
                    ),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: () => _showCreateItemDialog(context),
                    icon: const Icon(Icons.add),
                    label: const Text('Add item'),
                  ),
                ),
              ],
            )
          ],
        ),
      ),
    );
  }
}