import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:goldventory/features/settings/settings_view_model.dart';

import '../../core/utils/helpers.dart';

class ItemWeightsEditor extends StatefulWidget {
  final String category;
  final String item;
  const ItemWeightsEditor({super.key, required this.category, required this.item});

  @override
  State<ItemWeightsEditor> createState() => _ItemWeightsEditorState();
}

class _ItemWeightsEditorState extends State<ItemWeightsEditor> {
  SettingsViewModel? _vm;
  List<String> _sharedWeights = [];
  final Map<String, List<String>> _perSubItemWeights = {};
  final TextEditingController _addCtrl = TextEditingController();
  WeightMode? _mode;

  // This screen MUST restore state from SettingsViewModel.
  // Firestore is the source of truth. UI never clears persisted data.
  @override
  void initState() {
    super.initState();

    _vm = Provider.of<SettingsViewModel>(context, listen: false);

    // Restore persisted mode (if already chosen)
    _mode = _vm!.weightModeFor(widget.category, widget.item);

    // Restore persisted weights from Settings (SOURCE OF TRUTH)
    final shared = _vm!.sharedWeightsForItem(widget.category, widget.item);
    final perSub = _vm!.weightsForItemBySubItem(widget.category, widget.item);

    if (shared.isNotEmpty) {
      _mode ??= WeightMode.shared;
      _sharedWeights = List<String>.from(shared);
      _sharedWeights.sort((a, b) => num.parse(a).compareTo(num.parse(b)));
    } else if (perSub.isNotEmpty) {
      _mode ??= WeightMode.perSubItem;
      _perSubItemWeights
        ..clear()
        ..addAll(perSub);
      _perSubItemWeights.forEach((_, list) {
        list.sort((a, b) => num.parse(a).compareTo(num.parse(b)));
      });
    }

    // Ensure all subItems appear even if empty
    if (_mode == WeightMode.perSubItem) {
      final subs = List<String>.from(
        _vm!.settingsSubItemsFor(widget.category, widget.item),
      )..sort(_naturalSubItemSort);
      for (final s in subs) {
        _perSubItemWeights.putIfAbsent(s, () => []);
      }
    }
  }

  @override
  void dispose() {
    _addCtrl.dispose();
    super.dispose();
  }

  void _addSharedWeight() {
    final text = _addCtrl.text.trim();
    if (text.isEmpty) return;
    if (_sharedWeights.contains(text)) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Weight already exists')));
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
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Weight already exists')));
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
    if (_vm != null) {
      // Persist weight mode (shared / per-subitem)
      _vm!.setWeightMode(widget.category, widget.item, _mode ?? WeightMode.shared);

      final thresholdService = _vm!.globalState.thresholds;

      if (_mode == WeightMode.shared) {
        // Persist shared weights list
        _vm!.setItemSharedWeights(widget.category, widget.item, _sharedWeights);

        // IMPORTANT:
        // Settings is the source of truth.
        // Inventory is derived.
        // Thresholds unlock immediately after save.
        // Sub-items MUST come from Settings (source of truth)
        final subItems = _vm!.settingsSubItemsFor(widget.category, widget.item);
        if (subItems.isEmpty) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Please add sub-items before configuring weights'),
            ),
          );
          return;
        }

        for (final sub in subItems) {
          for (final w in _sharedWeights) {
            thresholdService.setThreshold(
              category: widget.category,
              item: widget.item,
              subItem: sub,
              weight: w,
              threshold: thresholdService.defaultThreshold,
            );
          }
        }
      } else if (_mode == WeightMode.perSubItem) {
        // Persist per-sub-item weights into Settings (new method assumed)
        _perSubItemWeights.forEach((subItem, weights) {
          _vm!.setItemWeightsForSubItem(widget.category, widget.item, subItem, weights);
        });

        // IMPORTANT:
        // Settings is the source of truth.
        // Inventory is derived.
        // Thresholds unlock immediately after save.
        _perSubItemWeights.forEach((subItem, weights) {
          for (final w in weights) {
            thresholdService.setThreshold(
              category: widget.category,
              item: widget.item,
              subItem: subItem,
              weight: w,
              threshold: thresholdService.defaultThreshold,
            );
          }
        });
      }

      // Persist settings to Firestore explicitly
      await thresholdService.save();

    }

    if (context.mounted) {
      Helpers.showSnackBar('Weights saved');
      Navigator.of(context).pop(true);
    }
  }

  Future<bool> _confirmModeSwitch() async {
    return await showDialog<bool>(
          context: context,
          builder: (_) => AlertDialog(
            title: const Text('Change weight mode?'),
            content: const Text('Switching mode will remove existing weights.'),
            actions: [
              TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
              ElevatedButton(onPressed: () => Navigator.pop(context, true), child: const Text('Confirm')),
            ],
          ),
        ) ?? false;
  }

  bool get _canSave {
    if (_mode == WeightMode.shared) {
      return _sharedWeights.isNotEmpty;
    }
    if (_mode == WeightMode.perSubItem) {
      return _perSubItemWeights.isNotEmpty &&
          _perSubItemWeights.values.every((w) => w.isNotEmpty);
    }
    return false;
  }

  int _naturalSubItemSort(String a, String b) {
    final aNum = int.tryParse(a.split(' ').first);
    final bNum = int.tryParse(b.split(' ').first);
    if (aNum != null && bNum != null) return aNum.compareTo(bNum);
    if (aNum != null) return -1;
    if (bNum != null) return 1;
    return a.compareTo(b);
  }

  @override
  Widget build(BuildContext context) {
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
                  label: const Text('Shared weights'),
                  selected: _mode == WeightMode.shared,
                  onSelected: (v) async {
                    if (_vm?.weightModeFor(widget.category, widget.item) != null) return;
                    if (_mode != WeightMode.shared && (_perSubItemWeights.values.any((w) => w.isNotEmpty))) {
                      final ok = await _confirmModeSwitch();
                      if (!ok) return;
                      _sharedWeights.clear();
                      _perSubItemWeights.clear();
                      _vm?.clearWeightsForItem(widget.category, widget.item);
                    }
                    setState(() {
                      _mode = WeightMode.shared;
                    });
                  },
                ),
                ChoiceChip(
                  label: const Text('Per sub-item'),
                  selected: _mode == WeightMode.perSubItem,
                  onSelected: (v) async {
                    if (_vm?.weightModeFor(widget.category, widget.item) != null) return;
                    if (_mode == WeightMode.shared && _sharedWeights.isNotEmpty) {
                      final ok = await _confirmModeSwitch();
                      if (!ok) return;
                      _sharedWeights.clear();
                      _perSubItemWeights.clear();
                      _vm?.clearWeightsForItem(widget.category, widget.item);
                    }
                    setState(() {
                      _mode = WeightMode.perSubItem;
                      if (_perSubItemWeights.isEmpty) {
                        final subItems = _vm?.settingsSubItemsFor(widget.category, widget.item) ?? [];
                        for (final sub in subItems) {
                          _perSubItemWeights[sub] = [];
                        }
                      }
                    });
                  },
                ),
              ],
            ),
            const SizedBox(height: 12),
            if (_mode == WeightMode.shared) ...[
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
                  ElevatedButton(onPressed: _addSharedWeight, child: const Text('Add'))
                ],
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: _sharedWeights.map((w) => Chip(label: Text(w))).toList(),
              ),
            ] else if (_mode == WeightMode.perSubItem) ...[
              Expanded(
                child: ListView(
                  children: (_perSubItemWeights.keys.toList()
                    ..sort(_naturalSubItemSort))
                      .map((subItem) {
                    final ctrl = TextEditingController();
                    final weights = _perSubItemWeights[subItem] ?? [];

                    return ExpansionTile(
                      title: Text(subItem),
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
                            children: weights.map((w) => Chip(label: Text(w))).toList(),
                          ),
                        ),
                      ],
                    );
                  }).toList(),
                ),
              ),
            ] else ...[
              Expanded(
                child: Center(
                  child: Text(
                    'Please select a weight mode to configure weights.',
                    style: Theme.of(context).textTheme.bodyMedium,
                    textAlign: TextAlign.center,
                  ),
                ),
              ),
            ],
            const SizedBox(height: 12),
            if (_mode != null && ((_mode == WeightMode.shared && _sharedWeights.isNotEmpty) || (_mode == WeightMode.perSubItem && _perSubItemWeights.isNotEmpty)))
              Padding(
                padding: const EdgeInsets.only(top: 12),
                child: Text(
                  _mode == WeightMode.shared
                      ? '${_sharedWeights.length} ${_sharedWeights.length == 1 ? 'weight' : 'weights'}'
                      : '${_perSubItemWeights.length} sub-items configured',
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
              ),
          ],
        ),
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
          child: SizedBox(
            height: 48,
            child: ElevatedButton(
              onPressed: _canSave ? _saveWeights : null,
              child: const Text('Save'),
            ),
          ),
        ),
      ),
    );
  }
}
