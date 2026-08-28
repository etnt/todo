import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../app_routes.dart';
import '../models/todo.dart';
import '../state/settings_model.dart';
import '../state/todo_list_model.dart';
import '../widgets/empty_state.dart';
import '../widgets/error_banner.dart';
import '../widgets/todo_list_tile.dart';
import 'todo_detail_screen.dart';
import 'todo_edit_screen.dart';

/// Main TODO list screen with tabs, pull-to-refresh, reordering, and swipe actions.
class TodoListScreen extends StatefulWidget {
  const TodoListScreen({super.key});

  @override
  State<TodoListScreen> createState() => _TodoListScreenState();
}

class _TodoListScreenState extends State<TodoListScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final todoListModel = context.read<TodoListModel>();
      if (todoListModel.hasRepository && todoListModel.currentTodos.isEmpty) {
        todoListModel.loadTodos();
      }
    });
  }

  void _onReorder(int oldIndex, int newIndex) {
    final model = context.read<TodoListModel>();
    final currentList = model.currentTodos;
    if (oldIndex < newIndex) {
      newIndex -= 1;
    }
    if (oldIndex == newIndex || oldIndex >= currentList.length) return;

    final target = currentList[oldIndex];
    if (oldIndex < newIndex) {
      model.moveDown(target);
    } else {
      model.moveUp(target);
    }
  }

  Widget _buildEmptyState(TodoFilterView view) {
    switch (view) {
      case TodoFilterView.active:
        return const EmptyState(
          title: 'No active tasks',
          subtitle: 'Tap the + button below to add your first TODO.',
          icon: Icons.checklist_rtl_outlined,
        );
      case TodoFilterView.done:
        return const EmptyState(
          title: 'No completed tasks yet',
          subtitle: 'Swipe right or tap checkbox on any active task to mark it done.',
          icon: Icons.task_alt,
        );
      case TodoFilterView.all:
        return const EmptyState(
          title: 'No TODOs found',
          subtitle: 'Create a new task to get started.',
          icon: Icons.inbox_outlined,
        );
    }
  }

  void _openDetail(Todo todo) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => TodoDetailScreen(todo: todo),
      ),
    );
  }

  void _openAdd() {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => const TodoEditScreen(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final settings = context.watch<SettingsModel>();
    final todoList = context.watch<TodoListModel>();
    final todos = todoList.currentTodos;

    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('TODOs', style: TextStyle(fontWeight: FontWeight.bold)),
            if (settings.repo.isNotEmpty)
              Text(
                settings.repo,
                style: theme.textTheme.labelSmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.settings_outlined),
            tooltip: 'GitHub Settings',
            onPressed: () => Navigator.pushNamed(context, AppRoutes.settings),
          ),
        ],
      ),
      body: Column(
        children: [
          if (todoList.errorMessage != null)
            ErrorBanner(
              message: todoList.errorMessage!,
              onRetry: () => todoList.loadTodos(),
            ),

          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: SegmentedButton<TodoFilterView>(
              segments: const [
                ButtonSegment(
                  value: TodoFilterView.active,
                  label: Text('Active'),
                  icon: Icon(Icons.radio_button_unchecked, size: 16),
                ),
                ButtonSegment(
                  value: TodoFilterView.done,
                  label: Text('Done'),
                  icon: Icon(Icons.check_circle_outline, size: 16),
                ),
                ButtonSegment(
                  value: TodoFilterView.all,
                  label: Text('All'),
                  icon: Icon(Icons.list_alt, size: 16),
                ),
              ],
              selected: {todoList.currentView},
              onSelectionChanged: (newSelection) {
                todoList.setView(newSelection.first);
              },
            ),
          ),

          if (todoList.isLoading && todos.isEmpty)
            const Expanded(
              child: Center(child: CircularProgressIndicator()),
            )
          else if (todos.isEmpty)
            Expanded(
              child: RefreshIndicator(
                onRefresh: () => todoList.loadTodos(),
                child: ListView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  children: [
                    SizedBox(
                      height: MediaQuery.of(context).size.height * 0.5,
                      child: _buildEmptyState(todoList.currentView),
                    ),
                  ],
                ),
              ),
            )
          else
            Expanded(
              child: RefreshIndicator(
                onRefresh: () => todoList.loadTodos(),
                child: ReorderableListView.builder(
                  physics: const AlwaysScrollableScrollPhysics(),
                  itemCount: todos.length,
                  buildDefaultDragHandles: false,
                  onReorderItem: (oldIdx, newIdx) => _onReorder(oldIdx, newIdx),
                  itemBuilder: (context, index) {
                    final todo = todos[index];
                    return TodoListTile(
                      key: ValueKey('tile_${todo.id ?? todo.header}_$index'),
                      todo: todo,
                      index: index,
                      onToggle: () => todoList.toggleStatus(todo),
                      onDelete: () => todoList.deleteTodo(todo),
                      onTap: () => _openDetail(todo),
                    );
                  },
                ),
              ),
            ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _openAdd,
        child: const Icon(Icons.add),
      ),
    );
  }
}
