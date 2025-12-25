import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:goldventory/global/global_state.dart';
import 'package:goldventory/features/settings/settings_view_model.dart';
import 'package:goldventory/features/settings/category_list.dart';
import 'item_list.dart';

/// Settings landing page: provides a SettingsViewModel and shows categories.
class SettingsPage extends StatelessWidget {
  const SettingsPage({super.key});

  Future<void> _showCreateCategoryDialog(BuildContext context) async {
    final controller = TextEditingController();
    final vm = Provider.of<SettingsViewModel>(context, listen: false);

    final result = await showDialog<String?>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFFF0F8F3),
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

    return ChangeNotifierProvider<SettingsViewModel>(
      create: (_) => SettingsViewModel(globalState: gs)..load(),
      child: Consumer<SettingsViewModel>(builder: (context, vm, _) {
        final gs = context.watch<GlobalState>();
        return Scaffold(
          appBar: AppBar(title: const Text('Settings')),
          body: Padding(
            padding: const EdgeInsets.all(12.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Categories', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600)),
                const SizedBox(height: 8),
                Expanded(
                  child: gs.isLoading
                      ? _SettingsSkeleton()
                      : vm.categories.isEmpty
                          ? Center(
                              child: Text(
                                'No categories yet. Tap + to create one.',
                                style: Theme.of(context).textTheme.bodyMedium,
                              ),
                            )
                          : const CategoryList(),
                ),
              ],
            ),
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

class _SettingsSkeleton extends StatefulWidget {
  @override
  State<_SettingsSkeleton> createState() => _SettingsSkeletonState();
}

class _SettingsSkeletonState extends State<_SettingsSkeleton>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final base = Colors.grey.shade300;
    final highlight = Colors.grey.shade200;

    Widget row() => Container(
          margin: const EdgeInsets.symmetric(vertical: 8),
          height: 16,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(6),
            gradient: LinearGradient(
              begin: Alignment.centerLeft,
              end: Alignment.centerRight,
              colors: [base, highlight, base],
              stops: const [0.25, 0.5, 0.75],
              transform: _SlidingGradientTransform(_controller.value),
            ),
          ),
        );

    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            row(),
            row(),
            row(),
            row(),
          ],
        );
      },
    );
  }
}

class _SlidingGradientTransform extends GradientTransform {
  final double slidePercent;

  const _SlidingGradientTransform(this.slidePercent);

  @override
  Matrix4 transform(Rect bounds, {TextDirection? textDirection}) {
    return Matrix4.translationValues(bounds.width * slidePercent, 0, 0);
  }
}