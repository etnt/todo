import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/todo.dart';
import '../state/todo_list_model.dart';
import 'todo_edit_screen.dart';

/// Screen displaying the full details of a TODO item with actions to edit, toggle, or delete.
class TodoDetailScreen extends StatefulWidget {
  const TodoDetailScreen({
    super.key,
    required this.todo,
  });

  final Todo todo;

  @override
  State<TodoDetailScreen> createState() => _TodoDetailScreenState();
}

class _TodoDetailScreenState extends State<TodoDetailScreen> {
  late Todo _todo;

  @override
  void initState() {
    super.initState();
    _todo = widget.todo;
  }

  String _formatDate(String? isoDate) {
    if (isoDate == null) return 'N/A';
    try {
      final parsed = DateTime.parse(isoDate).toLocal();
      return '${parsed.year}-${parsed.month.toString().padLeft(2, '0')}-${parsed.day.toString().padLeft(2, '0')} ${parsed.hour.toString().padLeft(2, '0')}:${parsed.minute.toString().padLeft(2, '0')}';
    } catch (_) {
      return isoDate;
    }
  }

  Future<void> _toggleStatus() async {
    final model = context.read<TodoListModel>();
    await model.toggleStatus(_todo);
    if (mounted) {
      setState(() {
        // Updated in place by model
      });
    }
  }

  Future<void> _delete() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete TODO?'),
        content: Text('Are you sure you want to delete "${_todo.header}"? This will close the GitHub issue and mark it as deleted.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(context).colorScheme.error,
              foregroundColor: Theme.of(context).colorScheme.onError,
            ),
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed == true && mounted) {
      final model = context.read<TodoListModel>();
      await model.deleteTodo(_todo);
      if (mounted) {
        Navigator.of(context).pop();
      }
    }
  }

  Future<void> _edit() async {
    final updated = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => TodoEditScreen(todo: _todo),
      ),
    );

    if (updated == true && mounted) {
      setState(() {
        // _todo fields updated by model
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDone = _todo.isDone;

    return Scaffold(
      appBar: AppBar(
        title: Text(_todo.id != null ? 'Issue #${_todo.id}' : 'TODO Detail'),
        actions: [
          IconButton(
            icon: const Icon(Icons.edit_outlined),
            tooltip: 'Edit TODO',
            onPressed: _edit,
          ),
          IconButton(
            icon: const Icon(Icons.delete_outline),
            tooltip: 'Delete TODO',
            onPressed: _delete,
          ),
        ],
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Header / Status Badge
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Text(
                      _todo.header,
                      style: theme.textTheme.headlineSmall?.copyWith(
                        fontWeight: FontWeight.bold,
                        decoration: isDone ? TextDecoration.lineThrough : null,
                        color: isDone ? theme.colorScheme.outline : theme.colorScheme.onSurface,
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Chip(
                    avatar: Icon(
                      isDone ? Icons.check_circle : Icons.pending_outlined,
                      size: 18,
                      color: isDone ? Colors.green.shade800 : Colors.orange.shade800,
                    ),
                    label: Text(
                      isDone ? 'Done' : 'Active',
                      style: TextStyle(
                        color: isDone ? Colors.green.shade900 : Colors.orange.shade900,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    backgroundColor: isDone ? Colors.green.shade50 : Colors.orange.shade50,
                  ),
                ],
              ),
              const SizedBox(height: 16),

              // Description section
              Card(
                elevation: 0,
                color: theme.colorScheme.surfaceContainerLow,
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Description',
                        style: theme.textTheme.labelLarge?.copyWith(
                          fontWeight: FontWeight.bold,
                          color: theme.colorScheme.primary,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        _todo.body.isNotEmpty ? _todo.body : '(No description provided)',
                        style: theme.textTheme.bodyMedium?.copyWith(
                          fontStyle: _todo.body.isEmpty ? FontStyle.italic : FontStyle.normal,
                          color: _todo.body.isEmpty ? theme.colorScheme.outline : theme.colorScheme.onSurface,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),

              // Metadata card
              Card(
                elevation: 0,
                color: theme.colorScheme.surfaceContainerLow,
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Details',
                        style: theme.textTheme.labelLarge?.copyWith(
                          fontWeight: FontWeight.bold,
                          color: theme.colorScheme.primary,
                        ),
                      ),
                      const Divider(height: 16),
                      if (_todo.id != null) ...[
                        _buildMetaRow('GitHub Issue Number', '#${_todo.id}'),
                        const SizedBox(height: 8),
                      ],
                      _buildMetaRow('Priority Index', '${_todo.priority}'),
                      const SizedBox(height: 8),
                      _buildMetaRow('Created At', _formatDate(_todo.createdDate)),
                      if (isDone && _todo.finishedDate != null) ...[
                        const SizedBox(height: 8),
                        _buildMetaRow('Completed At', _formatDate(_todo.finishedDate)),
                      ],
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 24),

              // Primary Action: Toggle Status
              FilledButton.tonalIcon(
                onPressed: _toggleStatus,
                icon: Icon(isDone ? Icons.undo : Icons.check_circle_outline),
                label: Text(isDone ? 'Reopen (Mark Active)' : 'Mark as Completed'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildMetaRow(String label, String value) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: TextStyle(color: Theme.of(context).colorScheme.outline, fontSize: 13),
        ),
        Text(
          value,
          style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
        ),
      ],
    );
  }
}
