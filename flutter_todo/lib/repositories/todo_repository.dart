import '../models/todo.dart';
import '../services/github_api_client.dart';
import '../services/issue_meta_codec.dart';

/// Repository managing TODO items backed by GitHub Issues.
///
/// Ports the business logic of Python `TodoManager`, maintaining priority ordering,
/// metadata encoding, and CRUD operations.
class TodoRepository {
  TodoRepository({
    required this.apiClient,
    required this.repo,
  });

  final GitHubApiClient apiClient;
  final String repo;

  final List<Todo> _todos = [];

  /// Returns an unmodifiable list of currently loaded todos.
  List<Todo> get todos => List.unmodifiable(_todos);

  /// Loads all todos from GitHub issues, decodes metadata, filters deleted items,
  /// and sorts by priority.
  Future<List<Todo>> load() async {
    final issues = await apiClient.listIssues(repo);
    _todos.clear();

    for (var idx = 0; idx < issues.length; idx++) {
      final issue = issues[idx];
      final todo = IssueMetaCodec.fromGitHubIssue(issue, defaultPriority: idx);
      if (todo != null) {
        _todos.add(todo);
      }
    }

    _sortTodos();
    return todos;
  }

  /// Returns active (open) todos sorted by priority.
  List<Todo> getActiveTodos() {
    return _todos.where((t) => t.isActive).toList()
      ..sort((a, b) => a.priority.compareTo(b.priority));
  }

  /// Returns completed (closed) todos sorted by priority.
  List<Todo> getDoneTodos() {
    return _todos.where((t) => t.isDone).toList()
      ..sort((a, b) => a.priority.compareTo(b.priority));
  }

  /// Returns all non-deleted todos sorted by priority.
  List<Todo> getAllTodos() {
    return List.of(_todos)..sort((a, b) => a.priority.compareTo(b.priority));
  }

  /// Creates a new TODO item, uploads it as a GitHub issue, and adds it to the repository.
  Future<Todo> addTodo(String header, String body) async {
    final maxPriority = _todos.fold<int>(
      -1,
      (max, t) => t.priority > max ? t.priority : max,
    );
    final nextPriority = maxPriority + 1;

    final encodedBody = IssueMetaCodec.encode(
      body,
      IssueMetadata(priority: nextPriority, deleted: false),
    );

    final createdIssue = await apiClient.createIssue(
      repo,
      title: header,
      body: encodedBody,
    );

    final todo = IssueMetaCodec.fromGitHubIssue(
      createdIssue,
      defaultPriority: nextPriority,
    );

    if (todo == null) {
      throw GitHubApiException('Failed to instantiate Todo from created issue response.');
    }

    _todos.add(todo);
    _sortTodos();
    return todo;
  }

  /// Updates header and body of an existing [todo].
  Future<void> updateTodo(Todo todo, String header, String body) async {
    final issueNumber = _parseIssueNumber(todo);
    final encodedBody = IssueMetaCodec.encode(
      body,
      IssueMetadata(priority: todo.priority, deleted: false),
    );

    await apiClient.patchIssue(
      repo,
      issueNumber,
      {
        'title': header,
        'body': encodedBody,
      },
    );

    todo.header = header;
    todo.body = body;
  }

  /// Toggles the active/done status of [todo] (flips GitHub issue state between open and closed).
  Future<void> toggleStatus(Todo todo) async {
    final issueNumber = _parseIssueNumber(todo);
    final newState = todo.isActive ? 'closed' : 'open';

    await apiClient.patchIssue(
      repo,
      issueNumber,
      {'state': newState},
    );

    if (newState == 'closed') {
      todo.markDone();
    } else {
      todo.markActive();
    }
  }

  /// Moves [todo] up in priority by swapping priority with the previous item in [list].
  Future<void> moveUp(Todo todo, [List<Todo>? list]) async {
    final targetList = list ?? getAllTodos();
    final currentIndex = targetList.indexOf(todo);

    if (currentIndex > 0) {
      final prevTodo = targetList[currentIndex - 1];
      final tempPriority = todo.priority;
      todo.priority = prevTodo.priority;
      prevTodo.priority = tempPriority;

      await Future.wait([
        _patchPriority(todo),
        _patchPriority(prevTodo),
      ]);

      _sortTodos();
    }
  }

  /// Moves [todo] down in priority by swapping priority with the next item in [list].
  Future<void> moveDown(Todo todo, [List<Todo>? list]) async {
    final targetList = list ?? getAllTodos();
    final currentIndex = targetList.indexOf(todo);

    if (currentIndex >= 0 && currentIndex < targetList.length - 1) {
      final nextTodo = targetList[currentIndex + 1];
      final tempPriority = todo.priority;
      todo.priority = nextTodo.priority;
      nextTodo.priority = tempPriority;

      await Future.wait([
        _patchPriority(todo),
        _patchPriority(nextTodo),
      ]);

      _sortTodos();
    }
  }

  /// Permanently removes [todo] by closing the GitHub issue, adding `deleted: true` metadata,
  /// and removing it from local memory.
  Future<void> deleteTodo(Todo todo) async {
    final issueNumber = _parseIssueNumber(todo);
    final encodedBody = IssueMetaCodec.encode(
      todo.body,
      IssueMetadata(priority: todo.priority, deleted: true),
    );

    await apiClient.patchIssue(
      repo,
      issueNumber,
      {
        'state': 'closed',
        'body': encodedBody,
      },
    );

    _todos.remove(todo);
  }

  int _parseIssueNumber(Todo todo) {
    if (todo.id == null) {
      throw ArgumentError('Todo must have an ID to perform GitHub operations.');
    }
    final number = int.tryParse(todo.id!);
    if (number == null) {
      throw ArgumentError('Invalid issue number id: ${todo.id}');
    }
    return number;
  }

  Future<void> _patchPriority(Todo todo) async {
    final issueNumber = _parseIssueNumber(todo);
    final encodedBody = IssueMetaCodec.encode(
      todo.body,
      IssueMetadata(priority: todo.priority, deleted: false),
    );
    await apiClient.patchIssue(
      repo,
      issueNumber,
      {'body': encodedBody},
    );
  }

  void _sortTodos() {
    _todos.sort((a, b) => a.priority.compareTo(b.priority));
  }
}
