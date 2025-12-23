import 'package:flutter/material.dart';

/// Simple dialog for creating or renaming a category.
/// If `category` is provided it's a rename dialog; otherwise creation.
class CategoryEditor extends StatefulWidget {
  final String? category;
  const CategoryEditor({super.key, this.category});

  @override
  State<CategoryEditor> createState() => _CategoryEditorState();
}

class _CategoryEditorState extends State<CategoryEditor> {
  late TextEditingController _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl = TextEditingController(text: widget.category ?? '');
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isRename = widget.category != null && widget.category!.isNotEmpty;
    return AlertDialog(
      title: Text(isRename ? 'Rename category' : 'Create category'),
      content: TextField(
        controller: _ctrl,
        decoration: const InputDecoration(hintText: 'Category name'),
        autofocus: true,
      ),
      actions: [
        TextButton(onPressed: () => Navigator.of(context).pop(null), child: const Text('Cancel')),
        ElevatedButton(onPressed: () => Navigator.of(context).pop(_ctrl.text.trim()), child: Text(isRename ? 'Rename' : 'Create')),
      ],
    );
  }
}