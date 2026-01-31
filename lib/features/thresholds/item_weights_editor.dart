import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:goldventory/features/thresholds/thresholds_view_model.dart';
import '../../app/theme.dart';
import '../../core/utils/helpers.dart';

class ItemWeightsEditor extends StatefulWidget {
  final String category;
  final String item;
  const ItemWeightsEditor({super.key, required this.category, required this.item});

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
    // vm is defined in build, so we get it from context here
    final vm = context.read<ThresholdsViewModel>();
    // Persist weight mode (shared / per-subitem)
    vm.setWeightMode(widget.category, widget.item, _mode!);

    if (_mode == WeightMode.shared) {
      // Persist shared weights by applying the same list to ALL sub-items
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
        vm.setItemWeightsForSubItem(widget.category, widget.item, subItem, weights);
      });
    }

    if (context.mounted) {
      Helpers.showSnackBar('Weights saved');
      Navigator.of(context).pop(true);
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
      if (_perSubItemWeights.length != _initialPerSubItemWeights.length) return true;
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
      List<String> resolved = vm.sharedWeightsForItem(widget.category, widget.item);
      
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

    // PER-SUB-ITEM MODE — hydrate once
    if (_mode == WeightMode.perSubItem && _perSubItemWeights.isEmpty) {
      for (final s in subs) {
        final w = bySub[s] ?? <String>[];
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
                  label: const Text('Shared weights'),
                  selected: _mode == WeightMode.shared,
                  selectedColor: AppTheme.highlightBackground,
                  backgroundColor: Colors.white,
                  onSelected: _mode == null
                      ? (_) {
                          final vm = context.read<ThresholdsViewModel>();
                          vm.setWeightMode(widget.category, widget.item, WeightMode.shared);
                          setState(() {
                            _mode = WeightMode.shared;
                          });
                        }
                      : null,
                  disabledColor: _mode == WeightMode.shared ? AppTheme.highlightBackground : Colors.grey.shade300,
                ),
                ChoiceChip(
                  label: const Text('Per sub-item'),
                  selected: _mode == WeightMode.perSubItem,
                  selectedColor: AppTheme.highlightBackground,
                  backgroundColor: Colors.white,
                  onSelected: _mode == null
                      ? (_) {
                          final vm = context.read<ThresholdsViewModel>();
                          vm.setWeightMode(widget.category, widget.item, WeightMode.perSubItem);
                          setState(() {
                            _mode = WeightMode.perSubItem;
                          });
                        }
                      : null,
                  disabledColor: _mode == WeightMode.perSubItem ? AppTheme.highlightBackground : Colors.grey.shade300,
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
                          ElevatedButton(onPressed: _addSharedWeight, child: const Text('Add'))
                        ],
                      ),
                      const SizedBox(height: 8),
                      // Use width: double.infinity to force left alignment in Column
                      SizedBox(
                        width: double.infinity,
                        child: Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: _sharedWeights.map((w) => Chip(
                            label: Text(w),
                            backgroundColor: AppTheme.highlightBackground,
                          )).toList(),
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

                    final assetPath = Helpers.getSubItemImage(widget.category, subItem);

                    return ExpansionTile(
                      title: assetPath != null
                          ? Row(
                              children: [
                                Image.asset(
                                  assetPath,
                                  width: 32,
                                  height: 32,
                                  fit: BoxFit.contain,
                                  errorBuilder: (_, __, ___) => const Icon(Icons.image),
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
                              final sorted = [...weights]; // ..sort((a, b) => _safeNum(a).compareTo(_safeNum(b)));
                              return sorted.map((w) => Chip(
                                label: Text(w),
                                backgroundColor: AppTheme.highlightBackground,
                              )).toList();
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
            if (_mode != null && ((_mode == WeightMode.shared && _sharedWeights.isNotEmpty) || (_mode == WeightMode.perSubItem && _perSubItemWeights.isNotEmpty)))
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
                    child: const Text('Save'),
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
