import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:goldventory/features/settings/settings_view_model.dart';

import '../../core/utils/helpers.dart';

class SubItemList extends StatelessWidget {
  final String category;
  final String item;

  const SubItemList({
    super.key,
    required this.category,
    required this.item,
  });

  Future<void> _showCreateSubItemDialog(
      BuildContext context, SettingsViewModel vm) async {
    final ctrl = TextEditingController();

    final result = await showDialog<String?>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Create sub-item'),
        content: TextField(
          controller: ctrl,
          decoration: const InputDecoration(hintText: 'Sub-item name'),
          autofocus: true,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(null),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(ctx).pop(ctrl.text.trim()),
            child: const Text('Create'),
          ),
        ],
      ),
    );

    if (result != null && result.isNotEmpty) {
      vm.createSubItem(category, item, result);
      if (context.mounted) {
        Helpers.showSnackBar('Sub-item created');
      }
    }
  }

  Future<void> _renameSubItem(
      BuildContext context, SettingsViewModel vm, String oldName) async {
    final ctrl = TextEditingController(text: oldName);

    final result = await showDialog<String?>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Rename sub-item'),
        content: TextField(
          controller: ctrl,
          decoration: const InputDecoration(hintText: 'New name'),
          autofocus: true,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(null),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(ctx).pop(ctrl.text.trim()),
            child: const Text('Rename'),
          ),
        ],
      ),
    );

    if (result != null && result.isNotEmpty && result != oldName) {
      // Move thresholds from old → new
      final weights = vm.weightsFor(category, item, subItem: oldName);

      vm.createSubItem(category, item, result);

      weights.forEach((w, val) {
        vm.setThreshold(
          category: category,
          item: item,
          subItem: result,
          weight: w,
          threshold: val,
        );
      });

      vm.deleteSubItem(category, item, oldName);

      if (context.mounted) {
        Helpers.showSnackBar('Sub-item renamed');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final vm = Provider.of<SettingsViewModel>(context);
    final subs = vm.subItemsFor(category, item);

    return Scaffold(
      appBar: AppBar(
        title: Text('$item — sub-items'),
      ),
      body: ListView.separated(
        itemCount: subs.length,
        separatorBuilder: (_, __) => const Divider(height: 1),
        itemBuilder: (ctx, idx) {
          final s = subs[idx];

          return ListTile(
            title: Text(s),
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                IconButton(
                  icon: const Icon(Icons.edit),
                  tooltip: 'Rename',
                  onPressed: () => _renameSubItem(context, vm, s),
                ),
                IconButton(
                  icon: const Icon(Icons.delete),
                  tooltip: 'Delete',
                  onPressed: () async {
                    final confirmed = await showDialog<bool?>(
                      context: context,
                      builder: (dctx) => AlertDialog(
                        title: Text('Delete "$s"?'),
                        content: const Text(
                            'This will remove the sub-item and its thresholds.'),
                        actions: [
                          TextButton(
                            onPressed: () => Navigator.of(dctx).pop(false),
                            child: const Text('Cancel'),
                          ),
                          ElevatedButton(
                            onPressed: () => Navigator.of(dctx).pop(true),
                            child: const Text('Delete'),
                          ),
                        ],
                      ),
                    );

                    if (confirmed == true) {
                      vm.deleteSubItem(category, item, s);
                      if (context.mounted) {
                        Helpers.showSnackBar('Sub-item deleted');
                      }
                    }
                  },
                ),
              ],
            ),
            onTap: null,
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showCreateSubItemDialog(context, vm),
        backgroundColor: Theme.of(context).primaryColor,
        foregroundColor: Colors.black,
        child: const Icon(Icons.add),
      ),
    );
  }
}