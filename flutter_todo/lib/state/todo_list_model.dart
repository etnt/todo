import 'package:flutter/foundation.dart';
import '../models/todo.dart';
import '../repositories/todo_repository.dart';

enum TodoFilterView { active, done, all }

/// State model managing the TODO list, filtering, loading, and error states.
class TodoListModel extends ChangeNotifier {
  TodoListModel({TodoRepository? repository}) : _repo = repository;

  TodoRepository? _repo;

  TodoFilterView _currentView = TodoFilterView.active;
  bool _isLoading = false;
  String? _errorMessage;

  TodoFilterView get currentView => _currentView;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;
  bool get hasRepository => _repo != null;

  /// Returns the current list of todos filtered by [currentView].
  List<Todo> get currentTodos {
    if (_repo == null) return [];
    switch (_currentView) {
      case TodoFilterView.active:
        return _repo!.getActiveTodos();
      case TodoFilterView.done:
        return _repo!.getDoneTodos();
      case TodoFilterView.all:
        return _repo!.getAllTodos();
    }
  }

  /// Updates or initializes the underlying [TodoRepository].
  void setRepository(TodoRepository repository) {
    _repo = repository;
    notifyListeners();
  }

  /// Switches current view filter (active / done / all).
  void setView(TodoFilterView view) {
    if (_currentView != view) {
      _currentView = view;
      notifyListeners();
    }
  }

  /// Refreshes/loads the list of todos from GitHub.
  Future<void> loadTodos() async {
    if (_repo == null) return;

    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      await _repo!.load();
    } catch (e) {
      _errorMessage = e.toString();
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Adds a new TODO and refreshes.
  Future<Todo?> addTodo(String header, String body) async {
    if (_repo == null) return null;

    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final created = await _repo!.addTodo(header, body);
      return created;
    } catch (e) {
      _errorMessage = e.toString();
      rethrow;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Updates header and body of an existing [todo].
  Future<void> updateTodo(Todo todo, String header, String body) async {
    if (_repo == null) return;

    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      await _repo!.updateTodo(todo, header, body);
    } catch (e) {
      _errorMessage = e.toString();
      rethrow;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Toggles status between active and done.
  Future<void> toggleStatus(Todo todo) async {
    if (_repo == null) return;

    final wasDone = todo.isDone;
    if (wasDone) {
      todo.markActive();
    } else {
      todo.markDone();
    }
    notifyListeners();

    try {
      if (wasDone) {
        todo.markDone();
      } else {
        todo.markActive();
      }
      await _repo!.toggleStatus(todo);
    } catch (e) {
      if (wasDone) {
        todo.markDone();
      } else {
        todo.markActive();
      }
      _errorMessage = 'Failed to toggle status: $e';
    } finally {
      notifyListeners();
    }
  }

  /// Moves [todo] up in priority.
  Future<void> moveUp(Todo todo) async {
    if (_repo == null) return;
    try {
      await _repo!.moveUp(todo, currentTodos);
      notifyListeners();
    } catch (e) {
      _errorMessage = 'Failed to reorder: $e';
      notifyListeners();
    }
  }

  /// Moves [todo] down in priority.
  Future<void> moveDown(Todo todo) async {
    if (_repo == null) return;
    try {
      await _repo!.moveDown(todo, currentTodos);
      notifyListeners();
    } catch (e) {
      _errorMessage = 'Failed to reorder: $e';
      notifyListeners();
    }
  }

  /// Deletes [todo] permanently from GitHub issues and local state.
  Future<void> deleteTodo(Todo todo) async {
    if (_repo == null) return;

    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      await _repo!.deleteTodo(todo);
    } catch (e) {
      _errorMessage = 'Failed to delete: $e';
      rethrow;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }
}
