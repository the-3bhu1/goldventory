import 'package:flutter/material.dart';
import 'package:goldventory/core/widgets/responsive_layout.dart';

class EditableCell extends StatefulWidget {
  final String initialValue;
  final ValueChanged<String> onValueChanged;
  final TextAlign textAlign;
  final TextInputType keyboardType;
  final double width;
  final double height;
  final Color? backgroundColor;

  const EditableCell({
    super.key,
    required this.initialValue,
    required this.onValueChanged,
    this.textAlign = TextAlign.center,
    this.keyboardType = TextInputType.number,
    this.width = 100,
    this.height = 48,
    this.backgroundColor,
  });

  @override
  State<EditableCell> createState() => _EditableCellState();
}

class _EditableCellState extends State<EditableCell> {

  late TextEditingController _controller;
  bool _isEditing = false;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.initialValue);
  }

  @override
  void didUpdateWidget(covariant EditableCell oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.initialValue != oldWidget.initialValue &&
        widget.initialValue != _controller.text) {
      _controller.text = widget.initialValue;
    }
  }

  Future<void> _save() async {
    setState(() => _isEditing = false);
    try {
      widget.onValueChanged(_controller.text.trim());
    } catch (_) {}
  }

  void _startEditing() {
    setState(() => _isEditing = true);
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

    return GestureDetector(
      onTap: _startEditing,
      child: Container(
        width: cellWidth,
        height: cellHeight,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          border: Border.all(color: Colors.grey.shade400),
          color: widget.backgroundColor ?? Colors.grey.shade100,
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
                  onChanged: (v) {
                    try {
                      widget.onValueChanged(v.trim());
                    } catch (_) {}
                  },
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