import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:quincena/theme/theme.dart';

void main() {
  for (final Brightness brightness in Brightness.values) {
    testWidgets('a field in a dialog stands out from it, ${brightness.name}', (
      tester,
    ) async {
      final ThemeData theme = quincenaTheme(brightness);
      await tester.pumpWidget(
        MaterialApp(
          theme: theme,
          home: Builder(
            builder: (BuildContext context) => TextButton(
              onPressed: () => showDialog<void>(
                context: context,
                builder: (BuildContext context) =>
                    const AlertDialog(content: TextField()),
              ),
              child: const Text('Abrir'),
            ),
          ),
        ),
      );
      await tester.tap(find.text('Abrir'));
      await tester.pumpAndSettle();
      final Material dialog = tester.widget<Material>(
        find
            .descendant(
              of: find.byType(AlertDialog),
              matching: find.byType(Material),
            )
            .first,
      );
      expect(dialog.color, isNotNull);
      expect(dialog.color, isNot(theme.inputDecorationTheme.fillColor));
    });
  }
}
