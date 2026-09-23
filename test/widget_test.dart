import 'package:cw1_counter_app/main.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  Future<void> pumpApp(WidgetTester tester) async {
    await tester.pumpWidget(const CounterImageToggleApp());
    await tester.pumpAndSettle();
  }

  Future<void> tapText(WidgetTester tester, String text) async {
    final finder = find.text(text);
    await tester.ensureVisible(finder);
    await tester.pumpAndSettle();
    await tester.tap(finder);
  }

  ButtonStyleButton buttonWithText(WidgetTester tester, String text) {
    return tester.widget<ButtonStyleButton>(
      find.ancestor(
        of: find.text(text),
        matching: find.byWidgetPredicate((w) => w is ButtonStyleButton),
      ),
    );
  }

  testWidgets('starts at 0 and Increment adds one', (tester) async {
    await pumpApp(tester);
    expect(find.text('0'), findsOneWidget);

    await tapText(tester, 'Increment');
    await tester.pump();

    expect(find.text('1'), findsOneWidget);
  });

  testWidgets('step selector changes the increment amount', (tester) async {
    await pumpApp(tester);

    await tapText(tester, '+5');
    await tester.pumpAndSettle();
    await tapText(tester, 'Increment');
    await tester.pump();

    expect(find.text('5'), findsOneWidget);
    expect(find.text('Step size: 5'), findsOneWidget);
  });

  testWidgets('Decrement and Reset are disabled at 0', (tester) async {
    await pumpApp(tester);

    expect(buttonWithText(tester, 'Decrement').onPressed, isNull);
    expect(buttonWithText(tester, 'Reset').onPressed, isNull);

    await tapText(tester, 'Increment');
    await tester.pump();

    expect(buttonWithText(tester, 'Decrement').onPressed, isNotNull);
    expect(buttonWithText(tester, 'Reset').onPressed, isNotNull);
  });

  testWidgets('Undo restores the previous value', (tester) async {
    await pumpApp(tester);

    await tapText(tester, 'Increment');
    await tester.pump();
    await tapText(tester, 'Increment');
    await tester.pump();
    expect(find.text('2'), findsOneWidget);

    await tapText(tester, 'Undo');
    await tester.pump();
    expect(find.text('1'), findsOneWidget);
  });

  testWidgets('counter value is restored from storage', (tester) async {
    SharedPreferences.setMockInitialValues({'counter': 7});
    await pumpApp(tester);

    expect(find.text('7'), findsOneWidget);
  });

  testWidgets('Toggle Image cross-fades to the moon', (tester) async {
    await pumpApp(tester);

    FadeTransition moon() =>
        tester.widget<FadeTransition>(find.byKey(const ValueKey('moonFade')));
    expect(moon().opacity.value, 0);

    await tapText(tester, 'Toggle Image');
    await tester.pumpAndSettle();

    expect(moon().opacity.value, 1);
    expect(find.text('Night 🌙'), findsOneWidget);
  });

  testWidgets('theme button switches to dark mode', (tester) async {
    await pumpApp(tester);

    MaterialApp app() => tester.widget<MaterialApp>(find.byType(MaterialApp));
    expect(app().themeMode, ThemeMode.light);

    await tester.tap(find.byTooltip('Switch to dark mode'));
    await tester.pumpAndSettle();

    expect(app().themeMode, ThemeMode.dark);
  });
}
