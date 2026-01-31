import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:goldventory/global/global_state.dart';
import 'package:goldventory/features/thresholds/thresholds_view_model.dart';
import 'package:goldventory/features/thresholds/category_list.dart';
import '../../core/widgets/shimmer_loading.dart';
import 'item_list.dart';
import '../../app/theme.dart';

/// Thresholds landing page: provides a ThresholdsViewModel and shows categories.
class ThresholdsPage extends StatelessWidget {
  const ThresholdsPage({super.key});

  Future<void> _showCreateCategoryDialog(BuildContext context) async {
    final controller = TextEditingController();
    final vm = Provider.of<ThresholdsViewModel>(context, listen: false);

    final result = await showDialog<String?>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppTheme.highlightBackground,
        title: const Text('Create category'),
        content: TextField(
          controller: controller,
          decoration: const InputDecoration(hintText: 'Category name'),
          autofocus: true,
        ),
        actions: [
          TextButton(onPressed: () => Navigator.of(ctx).pop(null), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () => Navigator.of(ctx).pop(controller.text.trim()),
            child: const Text('Create'),
          ),
        ],
      ),
    );

    if (result != null && result.isNotEmpty) {
      final category = result;
      vm.createCategory(category);

      if (context.mounted) {
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => ChangeNotifierProvider.value(
              value: vm,
              child: ItemList(category: category),
            ),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final gs = Provider.of<GlobalState>(context, listen: false);

    return ChangeNotifierProvider<ThresholdsViewModel>(
      create: (_) {
        final vm = ThresholdsViewModel(globalState: gs);
        Future.microtask(() => vm.load());
        return vm;
      },
      child: Consumer<ThresholdsViewModel>(builder: (context, vm, _) {
        final gs = context.watch<GlobalState>();
        return Scaffold(
          appBar: AppBar(title: const Text('Categories')),
          body: Padding(
            padding: const EdgeInsets.all(12.0),
            child: gs.isLoading
                ? ShimmerLoading.list(
                    itemCount: 4,
                    itemBuilder: (context, index) => Container(
                          margin: const EdgeInsets.symmetric(vertical: 8),
                          height: 56, // Match ListTile height + padding
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(6),
                            color: AppColors.shimmerBase,
                          ),
                        ),
                  )
                : vm.categories.isEmpty
                    ? Center(
                        child: Text(
                          'No categories yet. Tap + to create one.',
                          style: Theme.of(context).textTheme.bodyMedium,
                        ),
                      )
                    : const CategoryList(),
          ),
          floatingActionButton: FloatingActionButton(
            onPressed: () => _showCreateCategoryDialog(context),
            backgroundColor: Theme.of(context).primaryColor,
            foregroundColor: Colors.black,
            child: const Icon(Icons.add),
          ),
        );
      }),
    );
  }
}
