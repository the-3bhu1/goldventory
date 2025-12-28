import 'package:flutter/material.dart';
import 'package:goldventory/core/widgets/responsive_layout.dart';

class EditableCell extends StatefulWidget {
  final int? initialValue;
  final Future<void> Function(int? value) onValueSaved;
  final Color Function(int? value) colorResolver;

  final TextAlign textAlign;
  final TextInputType keyboardType;
  final double width;
  final double height;

  const EditableCell({
    super.key,
    required this.initialValue,
    required this.onValueSaved,
    required this.colorResolver,
    this.textAlign = TextAlign.center,
    this.keyboardType = TextInputType.number,
    this.width = 100,
    this.height = 48,
  });

  @override
  State<EditableCell> createState() => _EditableCellState();
}

class _EditableCellState extends State<EditableCell> {
  late TextEditingController _controller;
  late FocusNode _focusNode;

  int? _currentValue;
  late Color _backgroundColor;

  @override
  void initState() {
    super.initState();
    _currentValue = widget.initialValue;
    _backgroundColor = widget.colorResolver(_currentValue);

    _controller = TextEditingController(
      text: _currentValue?.toString() ?? '',
    );

    _focusNode = FocusNode();
    _focusNode.addListener(_onFocusChange);
  }

  void _onFocusChange() {
    if (!_focusNode.hasFocus) {
      _commit();
    }
  }

  void _commit() {
    final parsed =
        _controller.text.trim().isEmpty ? null : int.tryParse(_controller.text);

    if (parsed == _currentValue) return;

    setState(() {
      _currentValue = parsed;
      _backgroundColor = widget.colorResolver(parsed);
    });

    widget.onValueSaved(parsed);
  }

  @override
  void didUpdateWidget(covariant EditableCell oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.initialValue != widget.initialValue &&
        widget.initialValue != _currentValue) {
      _currentValue = widget.initialValue;
      _controller.text = widget.initialValue?.toString() ?? '';
      _backgroundColor = widget.colorResolver(_currentValue);
    }
  }

  @override
  void dispose() {
    _focusNode.removeListener(_onFocusChange);
    _focusNode.dispose();
    _controller.dispose();
    super.dispose();
  }

  void _startEditing() {
    FocusManager.instance.primaryFocus?.unfocus();
    setState(() {
      _backgroundColor = Colors.white;
    });
    _focusNode.requestFocus();
    _controller.selection = TextSelection.fromPosition(
      TextPosition(offset: _controller.text.length),
    );
  }

  @override
  Widget build(BuildContext context) {
    final cellWidth = Responsive.cellWidth(context, base: widget.width);
    final cellHeight = Responsive.rowHeight(context, base: widget.height);
    final fontSize = Responsive.textSize(context, base: 16);

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: _startEditing,
      child: Container(
        width: cellWidth,
        height: cellHeight,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          border: Border.all(color: Colors.grey.shade400),
          color: _backgroundColor,
        ),
        child: TextField(
          controller: _controller,
          focusNode: _focusNode,
          textAlign: widget.textAlign,
          keyboardType: widget.keyboardType,
          decoration: const InputDecoration(
            border: InputBorder.none,
            isDense: true,
          ),
          style: TextStyle(fontSize: fontSize),
        ),
      ),
    );
  }
}