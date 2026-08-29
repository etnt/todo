import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../config/app_version.dart';

import '../app_routes.dart';
import '../models/todo.dart';
import '../repositories/todo_repository.dart';
import '../state/settings_model.dart';
import '../state/todo_list_model.dart';
import '../widgets/empty_state.dart';
import '../widgets/error_banner.dart';
import '../widgets/todo_list_tile.dart';
import 'todo_detail_screen.dart';
import 'todo_edit_screen.dart';

/// Main TODO list screen with tabs, pull-to-refresh, reordering, swipe actions,
/// and quick active repository switching menu.
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

  Future<void> _switchActiveRepo(String newRepo) async {
    final settings = context.read<SettingsModel>();
    final todoList = context.read<TodoListModel>();

    if (newRepo == settings.activeRepo) return;

    try {
      await settings.selectActiveRepo(newRepo);

      final apiClient = settings.createApiClient();
      final repository = TodoRepository(apiClient: apiClient, repo: newRepo);
      todoList.setRepository(repository);
      await todoList.loadTodos();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Switched to repository "$newRepo"'),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to switch repository: $e'),
            backgroundColor: Theme.of(context).colorScheme.error,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
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

    final repos = settings.repos;
    final activeRepo = settings.activeRepo;

    return Scaffold(
      appBar: AppBar(
        title: repos.length > 1
            ? PopupMenuButton<String>(
                tooltip: 'Select Active Repository',
                onSelected: _switchActiveRepo,
                itemBuilder: (context) {
                  return repos.map((r) {
                    final isCurrent = r == activeRepo;
                    return PopupMenuItem<String>(
                      value: r,
                      child: Row(
                        children: [
                          Icon(
                            isCurrent ? Icons.check_circle : Icons.circle_outlined,
                            size: 18,
                            color: isCurrent ? theme.colorScheme.primary : theme.colorScheme.outline,
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              r,
                              style: TextStyle(
                                fontWeight: isCurrent ? FontWeight.bold : FontWeight.normal,
                                color: isCurrent ? theme.colorScheme.primary : theme.colorScheme.onSurface,
                              ),
                            ),
                          ),
                        ],
                      ),
                    );
                  }).toList();
                },
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Flexible(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisSize: MainAxisSize.min,
                            crossAxisAlignment: CrossAxisAlignment.baseline,
                            textBaseline: TextBaseline.alphabetic,
                            children: [
                              const Text('TODOs', style: TextStyle(fontWeight: FontWeight.bold)),
                              const SizedBox(width: 6),
                              Text(
                                appVersion,
                                style: const TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w300,
                                ),
                              ),
                            ],
                          ),
                          Text(
                            activeRepo.isNotEmpty ? activeRepo : 'Select repo',
                            style: theme.textTheme.labelSmall?.copyWith(
                              color: theme.colorScheme.primary,
                              fontWeight: FontWeight.w600,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 4),
                    const Icon(Icons.arrow_drop_down, size: 20),
                  ],
                ),
              )
            : Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.baseline,
                    textBaseline: TextBaseline.alphabetic,
                    children: [
                      const Text('TODOs', style: TextStyle(fontWeight: FontWeight.bold)),
                      const SizedBox(width: 6),
                      Text(
                        appVersion,
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w300,
                        ),
                      ),
                    ],
                  ),
                  if (activeRepo.isNotEmpty)
                    Text(
                      activeRepo,
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
        tooltip: 'Add new TODO',
        child: const Icon(Icons.add),
      ),
    );
  }
}
