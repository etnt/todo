import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/todo.dart';
import '../state/todo_list_model.dart';

/// Screen for adding a new TODO or editing an existing one.
class TodoEditScreen extends StatefulWidget {
  const TodoEditScreen({
    super.key,
    this.todo,
  });

  /// If provided, the screen operates in Edit mode; otherwise, in Add mode.
  final Todo? todo;

  @override
  State<TodoEditScreen> createState() => _TodoEditScreenState();
}

class _TodoEditScreenState extends State<TodoEditScreen> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _headerController;
  late final TextEditingController _bodyController;
  late final FocusNode _headerFocusNode;
  late final FocusNode _bodyFocusNode;

  bool _isSaving = false;
  String? _errorMessage;

  bool get _isEditing => widget.todo != null;

  @override
  void initState() {
    super.initState();
    _headerController = TextEditingController(text: widget.todo?.header ?? '');
    _bodyController = TextEditingController(text: widget.todo?.body ?? '');
    _headerFocusNode = FocusNode();
    _bodyFocusNode = FocusNode();
  }

  @override
  void dispose() {
    _headerController.dispose();
    _bodyController.dispose();
    _headerFocusNode.dispose();
    _bodyFocusNode.dispose();
    super.dispose();
  }

  String? _validateHeader(String? value) {
    if (value == null || value.trim().isEmpty) {
      return 'Please enter a title for the TODO';
    }
    return null;
  }

  bool _hasUnsavedChanges() {
    final origHeader = widget.todo?.header ?? '';
    final origBody = widget.todo?.body ?? '';
    return _headerController.text != origHeader || _bodyController.text != origBody;
  }

  Future<bool> _onWillPop() async {
    if (!_hasUnsavedChanges() || _isSaving) {
      return true;
    }

    final shouldDiscard = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Discard changes?'),
        content: const Text('You have unsaved changes. Are you sure you want to discard them?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Keep Editing'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Discard'),
          ),
        ],
      ),
    );

    return shouldDiscard ?? false;
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;

    // Dismiss soft keyboard
    FocusScope.of(context).unfocus();

    setState(() {
      _isSaving = true;
      _errorMessage = null;
    });

    final model = context.read<TodoListModel>();
    final header = _headerController.text.trim();
    final body = _bodyController.text.trim();

    try {
      if (_isEditing) {
        await model.updateTodo(widget.todo!, header, body);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('TODO updated successfully!'),
              behavior: SnackBarBehavior.floating,
            ),
          );
          Navigator.of(context).pop(true);
        }
      } else {
        await model.addTodo(header, body);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('TODO created successfully!'),
              behavior: SnackBarBehavior.floating,
            ),
          );
          Navigator.of(context).pop(true);
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isSaving = false;
          _errorMessage = e.toString();
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to save TODO: $e'),
            backgroundColor: Theme.of(context).colorScheme.error,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: !_hasUnsavedChanges() || _isSaving,
      onPopInvokedWithResult: (didPop, result) async {
        if (didPop) return;
        final shouldPop = await _onWillPop();
        if (shouldPop && context.mounted) {
          Navigator.of(context).pop();
        }
      },
      child: Scaffold(
        resizeToAvoidBottomInset: true,
        appBar: AppBar(
          title: Text(_isEditing ? 'Edit TODO' : 'New TODO'),
          actions: [
            TextButton.icon(
              onPressed: _isSaving ? null : _save,
              icon: _isSaving
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.check),
              label: Text(_isSaving ? 'Saving...' : 'Save'),
            ),
          ],
        ),
        body: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  if (_errorMessage != null) ...[
                    Container(
                      padding: const EdgeInsets.all(12),
                      margin: const EdgeInsets.only(bottom: 16),
                      decoration: BoxDecoration(
                        color: Theme.of(context).colorScheme.errorContainer,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        _errorMessage!,
                        style: TextStyle(
                          color: Theme.of(context).colorScheme.onErrorContainer,
                        ),
                      ),
                    ),
                  ],

                  // Title input
                  TextFormField(
                    controller: _headerController,
                    focusNode: _headerFocusNode,
                    autofocus: !_isEditing,
                    decoration: const InputDecoration(
                      labelText: 'Title',
                      hintText: 'What needs to be done?',
                      border: OutlineInputBorder(),
                      prefixIcon: Icon(Icons.title),
                    ),
                    textInputAction: TextInputAction.next,
                    onFieldSubmitted: (_) {
                      FocusScope.of(context).requestFocus(_bodyFocusNode);
                    },
                    validator: _validateHeader,
                  ),
                  const SizedBox(height: 16),

                  // Description input
                  TextFormField(
                    controller: _bodyController,
                    focusNode: _bodyFocusNode,
                    decoration: const InputDecoration(
                      labelText: 'Description (optional)',
                      hintText: 'Add details, notes, or bullet points...',
                      border: OutlineInputBorder(),
                      alignLabelWithHint: true,
                    ),
                    maxLines: 8,
                    minLines: 4,
                    keyboardType: TextInputType.multiline,
                  ),
                  const SizedBox(height: 24),

                  FilledButton.icon(
                    onPressed: _isSaving ? null : _save,
                    icon: _isSaving
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : const Icon(Icons.save),
                    label: Text(_isSaving ? 'Saving...' : (_isEditing ? 'Update TODO' : 'Create TODO')),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
