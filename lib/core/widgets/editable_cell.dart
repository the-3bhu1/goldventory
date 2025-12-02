import 'package:flutter/material.dart';
import 'package:goldventory/core/utils/helpers.dart';
import 'package:goldventory/core/widgets/responsive_layout.dart';
import 'package:provider/provider.dart';
import 'package:goldventory/global/global_state.dart';

class EditableCell extends StatefulWidget {
  final String initialValue;
  final ValueChanged<String> onValueChanged;
  final Future<void> Function(int)? onManualIncrease;
  final TextAlign textAlign;
  final TextInputType keyboardType;
  final double width;
  final double height;
  final int? threshold;

  const EditableCell({
    super.key,
    required this.initialValue,
    required this.onValueChanged,
    this.onManualIncrease,
    this.textAlign = TextAlign.center,
    this.keyboardType = TextInputType.number,
    this.width = 100,
    this.height = 48,
    this.threshold,
  });

  @override
  State<EditableCell> createState() => _EditableCellState();
}

class _EditableCellState extends State<EditableCell> {
  bool _hasShownThresholdSnack = false;
  int _lastSaved = 0;

  late TextEditingController _controller;
  bool _isEditing = false;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.initialValue);
    _lastSaved = int.tryParse(widget.initialValue) ?? 0;
  }

  @override
  void didUpdateWidget(covariant EditableCell oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.initialValue != oldWidget.initialValue &&
        widget.initialValue != _controller.text) {
      _controller.text = widget.initialValue;
      _lastSaved = int.tryParse(widget.initialValue) ?? 0;
    }
  }

  Future<void> _save() async {
    // prevent duplicate saves triggering duplicate snackbars
    setState(() => _isEditing = false);

    final globalState = Provider.of<GlobalState>(context, listen: false);

    // Parse the quantity safely
    final parsed = int.tryParse(_controller.text.trim());
    final int newVal = parsed ?? 0;

    // Compute delta relative to last saved value
    final delta = newVal - _lastSaved;

    if (delta > 0) {
      // Positive delta = manual receive. Prefer to route this through the
      // manual-increase callback so the view model / repository can allocate
      // FIFO to pending orders and update product quantities atomically.
      try {
        if (widget.onManualIncrease != null) {
          // allow parent to be async
          await widget.onManualIncrease!(delta);
        } else {
          // fallback: if no manual-increase handler, write absolute value
          widget.onValueChanged(newVal.toString());
        }
      } catch (e) {
        // swallow errors to avoid breaking UI
        print('EditableCell onManualIncrease failed: $e');
      }
    } else {
      // delta <= 0: treat as absolute set (covers decreases and explicit sets)
      try {
        widget.onValueChanged(newVal.toString());
      } catch (e) {
        print('EditableCell onValueChanged failed: $e');
      }
    }

    // update last saved to the new value
    _lastSaved = newVal;

    final stableKey = widget.key?.toString() ?? '';

    // Determine the applicable threshold (widget > global > default 5)
    final threshold = widget.threshold ?? globalState.getThreshold(stableKey);

    // Check if below threshold
    final belowThreshold = newVal < threshold;

    // Show warning snackbar only once per edit/save if valid number and below threshold
    if (_controller.text.trim().isNotEmpty && belowThreshold && !_hasShownThresholdSnack) {
      _hasShownThresholdSnack = true;
      Helpers.showSnackBar('Quantity below threshold!');
    }
  }

  void _startEditing() {
    setState(() => _isEditing = true);
    _hasShownThresholdSnack = false;
    _controller.selection = TextSelection.fromPosition(
      TextPosition(offset: _controller.text.length),
    );
  }

  @override
  Widget build(BuildContext context) {
    final cellWidth = Responsive.cellWidth(context, base: widget.width);
    final cellHeight = Responsive.rowHeight(context, base: widget.height);
    final fontSize = Responsive.textSize(context, base: 16);
    final horizontalPadding = Responsive.isTablet(context) ? 8.0 : 4.0;
    final globalState = Provider.of<GlobalState>(context);
    final stableKey = widget.key?.toString() ?? '';
    final quantity = int.tryParse(_controller.text) ?? 0;
    final threshold = widget.threshold ?? globalState.getThreshold(stableKey);
    final isEmpty = _controller.text.trim().isEmpty;
    final belowThreshold = !isEmpty && quantity < threshold;
    final backgroundColor = isEmpty
        ? Colors.grey.shade100
        : belowThreshold
            ? Colors.red.shade100
            : Colors.green.shade100;
    return GestureDetector(
      onTap: _startEditing,
      child: Container(
        width: cellWidth,
        height: cellHeight,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          border: Border.all(color: Colors.grey.shade400),
          color: backgroundColor,
        ),
        child: _isEditing
            ? Focus(
                onFocusChange: (hasFocus) {
                  if (!hasFocus) _save();
                },
                child: TextField(
                  controller: _controller,
                  autofocus: true,
                  keyboardType: widget.keyboardType,
                  textAlign: widget.textAlign,
                  onSubmitted: (_) => _save(),
                  decoration: InputDecoration(
                    isDense: true,
                    border: InputBorder.none,
                    contentPadding: EdgeInsets.symmetric(horizontal: horizontalPadding),
                  ),
                ),
              )
            : Text(
                _controller.text,
                textAlign: widget.textAlign,
                style: TextStyle(fontSize: fontSize),
              ),
      ),
    );
  }
}