import 'package:flutter/material.dart';
import '../models/todo.dart';

/// List tile widget representing a single TODO item with swipe actions and reorder handle.
class TodoListTile extends StatelessWidget {
  const TodoListTile({
    super.key,
    required this.todo,
    required this.index,
    required this.onToggle,
    required this.onDelete,
    this.onTap,
  });

  final Todo todo;
  final int index;
  final VoidCallback onToggle;
  final VoidCallback onDelete;
  final VoidCallback? onTap;

  String _formatDate(String? isoDate) {
    if (isoDate == null) return '';
    try {
      final parsed = DateTime.parse(isoDate).toLocal();
      return '${parsed.year}-${parsed.month.toString().padLeft(2, '0')}-${parsed.day.toString().padLeft(2, '0')}';
    } catch (_) {
      return isoDate;
    }
  }

  Future<bool?> _confirmDismiss(BuildContext context, DismissDirection direction) async {
    if (direction == DismissDirection.startToEnd) {
      onToggle();
      return false; // don't remove from widget tree; let state notify
    } else if (direction == DismissDirection.endToStart) {
      return showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('Delete TODO?'),
          content: Text('Are you sure you want to delete "${todo.header}"? This will close the GitHub issue and mark it as deleted.'),
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
    }
    return false;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDone = todo.isDone;

    final createdStr = _formatDate(todo.createdDate);
    final finishedStr = _formatDate(todo.finishedDate);
    final subtitleText = isDone && finishedStr.isNotEmpty
        ? 'Created: $createdStr • Done: $finishedStr'
        : 'Created: $createdStr';

    return Dismissible(
      key: ValueKey('todo_${todo.id ?? todo.header}_$index'),
      confirmDismiss: (direction) => _confirmDismiss(context, direction),
      onDismissed: (direction) {
        if (direction == DismissDirection.endToStart) {
          onDelete();
        }
      },
      background: Container(
        color: Colors.green.shade600,
        alignment: Alignment.centerLeft,
        padding: const EdgeInsets.symmetric(horizontal: 20),
        child: Row(
          children: [
            Icon(isDone ? Icons.undo : Icons.check, color: Colors.white),
            const SizedBox(width: 8),
            Text(
              isDone ? 'Mark Active' : 'Mark Done',
              style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
            ),
          ],
        ),
      ),
      secondaryBackground: Container(
        color: theme.colorScheme.error,
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.symmetric(horizontal: 20),
        child: const Row(
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            Text(
              'Delete',
              style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
            ),
            SizedBox(width: 8),
            Icon(Icons.delete_outline, color: Colors.white),
          ],
        ),
      ),
      child: Card(
        margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
        elevation: isDone ? 0 : 1,
        color: isDone ? theme.colorScheme.surfaceContainerHighest.withAlpha(120) : null,
        child: ListTile(
          contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
          leading: Checkbox(
            value: isDone,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
            onChanged: (_) => onToggle(),
          ),
          title: Text(
            todo.header,
            style: TextStyle(
              fontSize: 16,
              fontWeight: isDone ? FontWeight.normal : FontWeight.w600,
              decoration: isDone ? TextDecoration.lineThrough : null,
              color: isDone ? theme.colorScheme.outline : theme.colorScheme.onSurface,
            ),
          ),
          subtitle: todo.createdDate != null
              ? Text(
                  subtitleText,
                  style: TextStyle(
                    fontSize: 12,
                    color: theme.colorScheme.outline,
                  ),
                )
              : null,
          trailing: ReorderableDragStartListener(
            index: index,
            child: const Padding(
              padding: EdgeInsets.all(8),
              child: Icon(Icons.drag_handle),
            ),
          ),
          onTap: onTap,
        ),
      ),
    );
  }
}
