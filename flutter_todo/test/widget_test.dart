import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_todo/main.dart';
import 'package:flutter_todo/screens/settings_screen.dart';
import 'package:flutter_todo/screens/todo_list_screen.dart';
import 'package:flutter_todo/state/settings_model.dart';
import 'package:flutter_todo/state/todo_list_model.dart';
import 'package:provider/provider.dart';

import 'settings_screen_test.dart';

Widget buildApp({required bool configured}) {
  final settingsStore = FakeSettingsStore();
  if (configured) {
    settingsStore.saveRepo('etnt/todo-flutter-scratch');
    settingsStore.saveToken('test_token');
  }
  final settingsModel = SettingsModel(settingsStore: settingsStore);
  final todoListModel = TodoListModel();

  return MultiProvider(
    providers: [
      ChangeNotifierProvider.value(value: settingsModel),
      ChangeNotifierProvider.value(value: todoListModel),
    ],
    child: TodoApp(configured: configured),
  );
}

void main() {
  testWidgets('starts on Settings screen when unconfigured', (tester) async {
    await tester.pumpWidget(buildApp(configured: false));
    await tester.pumpAndSettle();

    expect(find.byType(SettingsScreen), findsOneWidget);
    expect(find.byType(TodoListScreen), findsNothing);
  });

  testWidgets('starts on Todo list screen when configured', (tester) async {
    await tester.pumpWidget(buildApp(configured: true));
    await tester.pumpAndSettle();

    expect(find.byType(TodoListScreen), findsOneWidget);
    expect(find.text('TODOs'), findsOneWidget);
  });

  testWidgets('settings icon navigates to Settings screen', (tester) async {
    await tester.pumpWidget(buildApp(configured: true));
    await tester.pumpAndSettle();

    await tester.tap(find.byIcon(Icons.settings_outlined));
    await tester.pumpAndSettle();

    expect(find.byType(SettingsScreen), findsOneWidget);
  });
}
