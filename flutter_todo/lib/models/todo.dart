/// Represents a single TODO item.
///
/// Can be stored locally or backed by a GitHub Issue.
class Todo {
  Todo({
    required this.header,
    required this.body,
    this.id,
    this.createdDate,
    this.finishedDate,
    this.status = 'active',
    this.priority = 0,
  });

  /// Unique identifier (GitHub issue number string when backed by GitHub).
  String? id;

  /// Short summary or title of the TODO (GitHub issue title).
  String header;

  /// Detailed description of the TODO without internal metadata comments.
  String body;

  /// Timestamp when the TODO was created (ISO-8601 string).
  String? createdDate;

  /// Timestamp when the TODO was finished/closed (ISO-8601 string), or null if active.
  String? finishedDate;

  /// 'active' or 'done'.
  String status;

  /// Priority order for sorting (lower numbers appear first).
  int priority;

  /// Convenience getter for status.
  bool get isDone => status == 'done';

  /// Convenience getter for active status.
  bool get isActive => status == 'active';

  /// Marks the todo as done and sets finishedDate to current ISO timestamp.
  void markDone() {
    status = 'done';
    finishedDate = DateTime.now().toIso8601String();
  }

  /// Marks the todo as active and clears finishedDate.
  void markActive() {
    status = 'active';
    finishedDate = null;
  }

  /// Creates a copy with optionally updated fields.
  Todo copyWith({
    String? id,
    String? header,
    String? body,
    String? createdDate,
    String? finishedDate,
    String? status,
    int? priority,
  }) {
    return Todo(
      id: id ?? this.id,
      header: header ?? this.header,
      body: body ?? this.body,
      createdDate: createdDate ?? this.createdDate,
      finishedDate: finishedDate ?? this.finishedDate,
      status: status ?? this.status,
      priority: priority ?? this.priority,
    );
  }

  /// Converts this [Todo] to a JSON Map.
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'header': header,
      'body': body,
      'created_date': createdDate,
      'finished_date': finishedDate,
      'status': status,
      'priority': priority,
    };
  }

  /// Creates a [Todo] from a standard JSON map.
  factory Todo.fromJson(Map<String, dynamic> json) {
    return Todo(
      id: json['id']?.toString(),
      header: json['header'] as String? ?? '',
      body: json['body'] as String? ?? '',
      createdDate: json['created_date'] as String?,
      finishedDate: json['finished_date'] as String?,
      status: json['status'] as String? ?? 'active',
      priority: (json['priority'] as num?)?.toInt() ?? 0,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is Todo &&
          runtimeType == other.runtimeType &&
          id == other.id &&
          header == other.header &&
          body == other.body &&
          createdDate == other.createdDate &&
          finishedDate == other.finishedDate &&
          status == other.status &&
          priority == other.priority;

  @override
  int get hashCode =>
      id.hashCode ^
      header.hashCode ^
      body.hashCode ^
      createdDate.hashCode ^
      finishedDate.hashCode ^
      status.hashCode ^
      priority.hashCode;

  @override
  String toString() =>
      'Todo(id: $id, header: $header, status: $status, priority: $priority)';
}
