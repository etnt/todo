import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_todo/models/todo.dart';

void main() {
  group('Todo Model', () {
    test('default values on instantiation', () {
      final todo = Todo(header: 'Test header', body: 'Test body');
      expect(todo.id, isNull);
      expect(todo.header, 'Test header');
      expect(todo.body, 'Test body');
      expect(todo.status, 'active');
      expect(todo.priority, 0);
      expect(todo.isActive, isTrue);
      expect(todo.isDone, isFalse);
      expect(todo.createdDate, isNull);
      expect(todo.finishedDate, isNull);
    });

    test('markDone sets status to done and finishedDate to now', () {
      final todo = Todo(header: 'Buy groceries', body: 'Milk, bread');
      expect(todo.isDone, isFalse);
      expect(todo.finishedDate, isNull);

      todo.markDone();

      expect(todo.status, 'done');
      expect(todo.isDone, isTrue);
      expect(todo.isActive, isFalse);
      expect(todo.finishedDate, isNotNull);
      expect(DateTime.tryParse(todo.finishedDate!), isNotNull);
    });

    test('markActive resets status to active and clears finishedDate', () {
      final todo = Todo(
        header: 'Clean desk',
        body: 'Sort papers',
        status: 'done',
        finishedDate: '2026-08-28T12:00:00Z',
      );

      todo.markActive();

      expect(todo.status, 'active');
      expect(todo.isActive, isTrue);
      expect(todo.finishedDate, isNull);
    });

    test('copyWith updates specified fields only', () {
      final original = Todo(
        id: '123',
        header: 'Original Title',
        body: 'Original Body',
        createdDate: '2026-08-28T10:00:00.000',
        status: 'active',
        priority: 1,
      );

      final updated = original.copyWith(header: 'New Title', priority: 5);

      expect(updated.id, '123');
      expect(updated.header, 'New Title');
      expect(updated.body, 'Original Body');
      expect(updated.createdDate, '2026-08-28T10:00:00.000');
      expect(updated.status, 'active');
      expect(updated.priority, 5);
    });

    test('toJson and fromJson round-trip correctly', () {
      final original = Todo(
        id: '42',
        header: 'Deploy app',
        body: 'Release to internal testers',
        createdDate: '2026-08-28T14:30:00.000',
        finishedDate: '2026-08-28T15:00:00.000',
        status: 'done',
        priority: 3,
      );

      final jsonMap = original.toJson();
      final fromJson = Todo.fromJson(jsonMap);

      expect(fromJson, equals(original));
      expect(fromJson.id, '42');
      expect(fromJson.header, 'Deploy app');
      expect(fromJson.body, 'Release to internal testers');
      expect(fromJson.createdDate, '2026-08-28T14:30:00.000');
      expect(fromJson.finishedDate, '2026-08-28T15:00:00.000');
      expect(fromJson.status, 'done');
      expect(fromJson.priority, 3);
    });

    test('value equality and hashCode behave consistently', () {
      final todoA = Todo(
        id: '1',
        header: 'Task 1',
        body: 'Description',
        priority: 0,
      );
      final todoB = Todo(
        id: '1',
        header: 'Task 1',
        body: 'Description',
        priority: 0,
      );
      final todoC = Todo(
        id: '2',
        header: 'Task 2',
        body: 'Description',
        priority: 0,
      );

      expect(todoA, equals(todoB));
      expect(todoA.hashCode, equals(todoB.hashCode));
      expect(todoA, isNot(equals(todoC)));
    });
  });
}
