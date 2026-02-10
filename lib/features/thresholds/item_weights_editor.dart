import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:goldventory/features/thresholds/thresholds_view_model.dart';
import '../../app/theme.dart';
import '../../core/utils/helpers.dart';

class ItemWeightsEditor extends StatefulWidget {
  final String category;
  final String item;
  const ItemWeightsEditor(
      {super.key, required this.category, required this.item});

  @override
  State<ItemWeightsEditor> createState() => _ItemWeightsEditorState();
}

class _ItemWeightsEditorState extends State<ItemWeightsEditor> {
  // _safeNum moved to Helpers.safeNum
  List<String> _sharedWeights = [];
  final Map<String, List<String>> _perSubItemWeights = {};
  final Map<String, TextEditingController> _perSubCtrls = {};
  final TextEditingController _addCtrl = TextEditingController();
  WeightMode? _mode;
  bool _pendingMigration = false;
  bool _isSaving = false;

  // Dirty check state
  bool _hydrated = false;
  WeightMode? _initialMode;
  List<String> _initialSharedWeights = [];
  Map<String, List<String>> _initialPerSubItemWeights = {};

  @override
  void dispose() {
    for (final c in _perSubCtrls.values) {
      c.dispose();
    }
    _addCtrl.dispose();
    super.dispose();
  }

  void _addSharedWeight() {
    final text = _addCtrl.text.trim();
    if (text.isEmpty) return;
    if (_sharedWeights.contains(text)) {
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('Weight already exists')));
      return;
    }
    setState(() => _sharedWeights.add(text));
    _addCtrl.clear();
  }

  void _addPerSubItemWeight(String subItem, TextEditingController ctrl) {
    final text = ctrl.text.trim();
    if (text.isEmpty) return;
    final weights = _perSubItemWeights[subItem] ?? [];
    if (weights.contains(text)) {
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('Weight already exists')));
      return;
    }
    setState(() {
      weights.add(text);
      _perSubItemWeights[subItem] = weights;
    });
    ctrl.clear();
  }

  Future<void> _saveWeights() async {
    if (_mode == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select a weight mode first')),
      );
      return;
    }

    setState(() => _isSaving = true);
    try {
      final vm = context.read<ThresholdsViewModel>();

      // 1. Handle Migration if pending
      if (_pendingMigration) {
        await vm.confirmMigration(widget.category, widget.item, _mode!);
      }

      // 2. Persist weight mode (shared / per-subitem)
      // Use force: true if we migrated, just in case
      vm.setWeightMode(widget.category, widget.item, _mode!,
          force: _pendingMigration);

      if (_mode == WeightMode.shared) {
        // 1. Persist to the explicit 'shared' schema
        vm.setItemWeightsForSubItem(
          widget.category,
          widget.item,
          'shared',
          _sharedWeights,
        );

        // 2. Persist shared weights by applying the same list to ALL sub-items
        final subs = vm.settingsSubItemsFor(widget.category, widget.item);
        for (final sub in subs) {
          vm.setItemWeightsForSubItem(
            widget.category,
            widget.item,
            sub,
            _sharedWeights,
          );
        }
      } else if (_mode == WeightMode.perSubItem) {
        // Persist per-sub-item weights ONLY (no thresholds)
        _perSubItemWeights.forEach((subItem, weights) {
          vm.setItemWeightsForSubItem(
              widget.category, widget.item, subItem, weights);
        });
      }

      if (context.mounted) {
        Helpers.showSnackBar('Weights saved');
        Navigator.of(context).pop(true);
      }
    } catch (e) {
      if (context.mounted) {
        Helpers.showSnackBar('Error saving weights: $e');
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  Future<void> _handleModeToggle(WeightMode newMode) async {
    if (_mode == newMode) return;

    if (_initialMode != null && _initialMode != newMode) {
      // Show warning for existing items
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: Text(
            'Change Weight Mode?',
            style: TextStyle(
              color: Theme.of(context).brightness == Brightness.light
                  ? Theme.of(context).primaryColor
                  : Colors.white,
            ),
          ),
          content: const Text(
            'This will erase all existing thresholds, inventory, and pending orders for this item. \n\n'
            'Granular Erasure: Only this item will be removed from existing orders. \n\n'
            'Are you sure you want to continue?',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () => Navigator.pop(ctx, true),
              style: TextButton.styleFrom(
                  foregroundColor: Theme.of(context).colorScheme.error),
              child: const Text('Continue'),
            ),
          ],
        ),
      );

      if (confirmed != true) return;

      setState(() {
        _mode = newMode;
        _pendingMigration = true;
        // Erase local edits to force user to re-enter weights for the new mode
        _sharedWeights = [];
        _perSubItemWeights.clear();
        // and re-hydrate empty ctrls if needed?
        // Logic in build() handles empty hydrating if _mode changes.
      });
    } else {
      // First time setting mode, no warning needed
      setState(() {
        _mode = newMode;
      });
    }
  }

  Future<void> _deleteWeight(String subItem, String weight) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(
          'Delete Weight?',
          style: TextStyle(
            color: Theme.of(context).brightness == Brightness.light
                ? Theme.of(context).primaryColor
                : Colors.white,
          ),
        ),
        content: Text(
          'This will permanently delete "$weight" from this item\'s configuration, inventory, and any pending orders. \n\n'
          'Are you sure?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: TextButton.styleFrom(
                foregroundColor: Theme.of(context).colorScheme.error),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    setState(() => _isSaving = true);
    try {
      final vm = context.read<ThresholdsViewModel>();
      await vm.deleteWeight(
        category: widget.category,
        item: widget.item,
        subItem: subItem,
        weight: weight,
      );

      // Locally remove from state to reflect immediately
      if (subItem == 'shared' || _mode == WeightMode.shared) {
        _sharedWeights.remove(weight);
        _initialSharedWeights.remove(weight);
      } else {
        _perSubItemWeights[subItem]?.remove(weight);
        _initialPerSubItemWeights[subItem]?.remove(weight);
      }

      if (mounted) {
        Helpers.showSnackBar('Weight deleted');
      }
    } catch (e) {
      if (mounted) {
        Helpers.showSnackBar('Error deleting weight: $e');
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  // _areListsEqual moved to Helpers.areListsEqual

  bool get _isDirty {
    if (!_hydrated) return false;
    if (_mode != _initialMode) return true;

    if (_mode == WeightMode.shared) {
      return !Helpers.areListsEqual(_sharedWeights, _initialSharedWeights);
    }

    if (_mode == WeightMode.perSubItem) {
      if (_perSubItemWeights.length != _initialPerSubItemWeights.length) {
        return true;
      }
      for (final key in _perSubItemWeights.keys) {
        if (!_initialPerSubItemWeights.containsKey(key)) return true;
        if (!Helpers.areListsEqual(
            _perSubItemWeights[key]!, _initialPerSubItemWeights[key]!)) {
          return true;
        }
      }
      return false;
    }

    return false;
  }

  bool get _canSave {
    if (_isSaving) return false;
    if (!_isDirty) return false;

    if (_mode == WeightMode.shared) {
      return _sharedWeights.isNotEmpty;
    }
    if (_mode == WeightMode.perSubItem) {
      return _perSubItemWeights.isNotEmpty &&
          _perSubItemWeights.values.every((w) => w.isNotEmpty);
    }
    return false;
  }

  @override
  Widget build(BuildContext context) {
    final vm = context.watch<ThresholdsViewModel>();

    _mode ??= vm.weightModeFor(widget.category, widget.item);

    final subs = vm.subItemsFor(widget.category, widget.item);
    final bySub = vm.weightsForItemBySubItem(widget.category, widget.item);

    // SHARED MODE — hydrate once
    if (_mode == WeightMode.shared && _sharedWeights.isEmpty) {
      if (!_pendingMigration) {
        List<String> resolved =
            vm.sharedWeightsForItem(widget.category, widget.item);

        // Fallback to searching sub-items if explicitly shared key is empty
        if (resolved.isEmpty) {
          for (final s in subs) {
            final w = bySub[s];
            if (w != null && w.isNotEmpty) {
              resolved = w;
              break;
            }
          }
        }

        _sharedWeights = [...resolved]
          ..sort((a, b) => Helpers.safeNum(a).compareTo(Helpers.safeNum(b)));
      }
    }

    // PER-SUB-ITEM MODE — hydrate once
    if (_mode == WeightMode.perSubItem && _perSubItemWeights.isEmpty) {
      for (final s in subs) {
        final w = _pendingMigration ? <String>[] : (bySub[s] ?? <String>[]);
        _perSubItemWeights[s] = [...w]
          ..sort((a, b) => Helpers.safeNum(a).compareTo(Helpers.safeNum(b)));

        _perSubCtrls.putIfAbsent(s, () => TextEditingController());
      }
    }

    // Capture initial state ONCE
    if (!_hydrated) {
      _initialMode = _mode;

      // We must copy the lists carefully
      _initialSharedWeights = [..._sharedWeights];

      _initialPerSubItemWeights = {};
      _perSubItemWeights.forEach((k, v) {
        _initialPerSubItemWeights[k] = [...v];
      });

      // If we successfully loaded something (or even if empty start), mark hydrated
      // Wait, if _mode is null initially?
      // If _mode is null, we are just starting fresh.
      // But _mode is assigned above: _mode ??= vm.weightModeFor...

      _hydrated = true;
    }

    return Scaffold(
      appBar: AppBar(
        title: Text('${widget.item} - Add weights'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(12.0),
        child: Column(
          children: [
            Wrap(
              spacing: 8,
              runSpacing: 8,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                const Padding(
                  padding: EdgeInsets.only(right: 4.0),
                  child: Text('Mode:'),
                ),
                ChoiceChip(
                  label: Text(
                    'Shared weights',
                    style: TextStyle(
                      color: _mode == WeightMode.shared &&
                              Theme.of(context).brightness == Brightness.light
                          ? Theme.of(context).primaryColor
                          : null,
                    ),
                  ),
                  selected: _mode == WeightMode.shared,
                  selectedColor:
                      Theme.of(context).brightness == Brightness.light
                          ? Theme.of(context).cardColor
                          : Theme.of(context).primaryColor,
                  backgroundColor: AppTheme.getHighlightBackground(context),
                  checkmarkColor:
                      Theme.of(context).brightness == Brightness.light
                          ? Theme.of(context).primaryColor
                          : Colors.white,
                  onSelected: (_) => _handleModeToggle(WeightMode.shared),
                ),
                ChoiceChip(
                  label: Text(
                    'Per sub-item',
                    style: TextStyle(
                      color: _mode == WeightMode.perSubItem &&
                              Theme.of(context).brightness == Brightness.light
                          ? Theme.of(context).primaryColor
                          : null,
                    ),
                  ),
                  selected: _mode == WeightMode.perSubItem,
                  selectedColor:
                      Theme.of(context).brightness == Brightness.light
                          ? Theme.of(context).cardColor
                          : Theme.of(context).primaryColor,
                  backgroundColor: AppTheme.getHighlightBackground(context),
                  checkmarkColor:
                      Theme.of(context).brightness == Brightness.light
                          ? Theme.of(context).primaryColor
                          : Colors.white,
                  onSelected: (_) => _handleModeToggle(WeightMode.perSubItem),
                ),
              ],
            ),
            const SizedBox(height: 12),
            if (_mode == WeightMode.shared)
              Expanded(
                child: SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: TextField(
                              controller: _addCtrl,
                              decoration: const InputDecoration(
                                hintText: 'e.g. 2g, 3g, 5g',
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          ElevatedButton(
                              onPressed: _addSharedWeight,
                              style: Theme.of(context).brightness ==
                                      Brightness.light
                                  ? ElevatedButton.styleFrom(
                                      backgroundColor:
                                          Theme.of(context).cardColor,
                                      foregroundColor:
                                          Theme.of(context).primaryColor,
                                    )
                                  : null,
                              child: const Text('Add'))
                        ],
                      ),
                      const SizedBox(height: 8),
                      // Use width: double.infinity to force left alignment in Column
                      SizedBox(
                        width: double.infinity,
                        child: Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: _sharedWeights
                              .map((w) => Chip(
                                    label: Text(w),
                                    backgroundColor:
                                        AppTheme.getHighlightBackground(
                                            context),
                                    onDeleted: () => _deleteWeight('shared', w),
                                    deleteIcon:
                                        const Icon(Icons.close, size: 18),
                                  ))
                              .toList(),
                        ),
                      ),
                    ],
                  ),
                ),
              )
            else if (_mode == WeightMode.perSubItem)
              Expanded(
                child: ListView(
                  children: (_perSubItemWeights.keys.toList()
                      // ..sort(_naturalSubItemSort)) // Removed sorting
                      )
                      .map((subItem) {
                    final ctrl = _perSubCtrls[subItem]!;
                    final weights = _perSubItemWeights[subItem] ?? [];

                    final assetPath =
                        Helpers.getSubItemImage(widget.category, subItem);

                    return ExpansionTile(
                      title: assetPath != null
                          ? Row(
                              children: [
                                Image.asset(
                                  assetPath,
                                  width: 32,
                                  height: 32,
                                  fit: BoxFit.contain,
                                  errorBuilder: (_, __, ___) =>
                                      const Icon(Icons.image),
                                ),
                                const SizedBox(width: 8),
                                Text(subItem),
                              ],
                            )
                          : Text(subItem),
                      children: [
                        Padding(
                          padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                          child: Row(
                            children: [
                              Expanded(
                                child: TextField(
                                  controller: ctrl,
                                  decoration: InputDecoration(
                                    hintText: 'Add weight for $subItem',
                                  ),
                                ),
                              ),
                              const SizedBox(width: 8),
                              ElevatedButton(
                                onPressed: () {
                                  _addPerSubItemWeight(subItem, ctrl);
                                },
                                style: Theme.of(context).brightness ==
                                        Brightness.light
                                    ? ElevatedButton.styleFrom(
                                        backgroundColor:
                                            Theme.of(context).cardColor,
                                        foregroundColor:
                                            Theme.of(context).primaryColor,
                                      )
                                    : null,
                                child: const Text('Add'),
                              ),
                            ],
                          ),
                        ),
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 16.0),
                          child: Wrap(
                            spacing: 8,
                            runSpacing: 8,
                            children: (() {
                              final sorted = [
                                ...weights
                              ]; // ..sort((a, b) => _safeNum(a).compareTo(_safeNum(b)));
                              return sorted
                                  .map((w) => Chip(
                                        label: Text(w),
                                        backgroundColor:
                                            AppTheme.getHighlightBackground(
                                                context),
                                        onDeleted: () =>
                                            _deleteWeight(subItem, w),
                                        deleteIcon:
                                            const Icon(Icons.close, size: 18),
                                      ))
                                  .toList();
                            })(),
                          ),
                        ),
                      ],
                    );
                  }).toList(),
                ),
              )
            else
              Expanded(
                child: Center(
                  child: Text(
                    'Please select a weight mode to configure weights.',
                    style: Theme.of(context).textTheme.bodyMedium,
                    textAlign: TextAlign.center,
                  ),
                ),
              ),
            const SizedBox(height: 12),
            if (_mode != null &&
                ((_mode == WeightMode.shared && _sharedWeights.isNotEmpty) ||
                    (_mode == WeightMode.perSubItem &&
                        _perSubItemWeights.isNotEmpty)))
              Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Text(
                  _mode == WeightMode.shared
                      ? '${_sharedWeights.length} ${_sharedWeights.length == 1 ? 'weight' : 'weights'}'
                      : '${_perSubItemWeights.length} sub-items configured',
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
              ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: SizedBox(
                    height: 48,
                    child: ElevatedButton(
                      onPressed: _canSave ? _saveWeights : null,
                      style: Theme.of(context).brightness == Brightness.light
                          ? ElevatedButton.styleFrom(
                              backgroundColor: Theme.of(context).cardColor,
                              foregroundColor: Theme.of(context).primaryColor,
                            )
                          : null,
                      child: _isSaving
                          ? const Center(
                              child: SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Colors.blue,
                                ),
                              ),
                            )
                          : const Text('Save'),
                    ),
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
