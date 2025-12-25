import 'package:flutter/material.dart';
import 'package:goldventory/core/utils/helpers.dart';
import 'package:provider/provider.dart';
import 'package:goldventory/features/settings/settings_view_model.dart';
import 'item_list.dart';

/// A reusable CategoryList widget that displays categories and provides
/// quick actions: open, rename, delete. It relies on SettingsViewModel.
class CategoryList extends StatelessWidget {
  const CategoryList({super.key});

  @override
  Widget build(BuildContext context) {
    final vm = Provider.of<SettingsViewModel>(context);
    final categories = vm.categories;

    return ListView.separated(
      itemCount: categories.length,
      separatorBuilder: (_, __) => const Divider(height: 1),
      itemBuilder: (ctx, idx) {
        final cat = categories[idx];
        final items = vm.itemsFor(cat);

        return ListTile(
          title: Text(cat),
          subtitle: Text('${items.length} item${items.length == 1 ? '' : 's'}'),
          trailing: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              IconButton(
                icon: const Icon(Icons.edit),
                tooltip: 'Rename',
                onPressed: () async {
                  final ctrl = TextEditingController(text: cat);

                  final newName = await showDialog<String?>(
                    context: context,
                    builder: (ctx) => AlertDialog(
                      title: const Text('Rename category'),
                      content: TextField(
                        controller: ctrl,
                        decoration: const InputDecoration(hintText: 'Category name'),
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

                  if (newName != null && newName.isNotEmpty && newName != cat) {
                    vm.renameCategory(cat, newName);
                    Helpers.showSnackBar('Category renamed');
                  }
                },
              ),
              IconButton(
                icon: const Icon(Icons.delete),
                tooltip: 'Delete',
                onPressed: () async {
                  final confirmed = await showDialog<bool?>(
                    context: context,
                    builder: (dctx) => AlertDialog(
                      title: Text('Delete "$cat"?'),
                      content: const Text('This will remove the category and all its items from local changes.'),
                      actions: [
                        TextButton(onPressed: () => Navigator.of(dctx).pop(false), child: const Text('Cancel')),
                        ElevatedButton(onPressed: () => Navigator.of(dctx).pop(true), child: const Text('Delete')),
                      ],
                    ),
                  );
                  if (confirmed == true) {
                    vm.removeCategory(cat);
                    Helpers.showSnackBar('Category removed');
                  }
                },
              ),
              IconButton(
                icon: const Icon(Icons.chevron_right),
                onPressed: () {
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => ChangeNotifierProvider.value(value: vm, child: ItemList(category: cat)),
                    ),
                  );
                },
              ),
            ],
          ),
          onTap: () => Navigator.of(context).push(
            MaterialPageRoute(
              builder: (_) => ChangeNotifierProvider.value(value: vm, child: ItemList(category: cat)),
            ),
          ),
        );
      },
    );
  }
}
