import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_todo/main.dart';
import 'package:flutter_todo/screens/settings_screen.dart';
import 'package:flutter_todo/screens/todo_list_screen.dart';
import 'package:flutter_todo/services/settings_store.dart';
import 'package:shared_preferences/shared_preferences.dart';

Future<Widget> buildApp({required bool configured}) async {
  SharedPreferences.setMockInitialValues({
    if (configured) SettingsStore.repoKey: 'etnt/todo-flutter-scratch',
  });
  final isConfigured = await SettingsStore().isConfigured();
  return TodoApp(configured: isConfigured);
}

void main() {
  testWidgets('starts on Settings screen when unconfigured', (tester) async {
    await tester.pumpWidget(await buildApp(configured: false));

    expect(find.byType(SettingsScreen), findsOneWidget);
    expect(find.byType(TodoListScreen), findsNothing);
  });

  testWidgets('starts on Todo list screen when configured', (tester) async {
    await tester.pumpWidget(await buildApp(configured: true));

    expect(find.byType(TodoListScreen), findsOneWidget);
    expect(find.text('TODO List'), findsOneWidget);
    expect(find.text('No todos yet'), findsOneWidget);
  });

  testWidgets('settings icon navigates to Settings screen', (tester) async {
    await tester.pumpWidget(await buildApp(configured: true));

    await tester.tap(find.byIcon(Icons.settings_outlined));
    await tester.pumpAndSettle();

    expect(find.byType(SettingsScreen), findsOneWidget);
  });
}
