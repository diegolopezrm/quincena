import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:quincena/ui/exit_list.dart';

Widget list(List<String> items, {bool still = false}) => MaterialApp(
  home: MediaQuery(
    data: MediaQueryData(disableAnimations: still),
    child: Scaffold(
      body: ExitList<String>(
        items: items,
        keyOf: (String s) => s,
        builder: (BuildContext context, String s) => Text(s),
      ),
    ),
  ),
);

void main() {
  testWidgets('an item that leaves folds away where it was', (tester) async {
    await tester.pumpWidget(list(<String>['Éxito', 'Laura', 'Uber']));
    await tester.pumpWidget(list(<String>['Éxito', 'Uber']));
    // Still there for a moment, between the two it sat between.
    expect(find.text('Laura'), findsOneWidget);
    final double laura = tester.getTopLeft(find.text('Laura')).dy;
    expect(laura, greaterThan(tester.getTopLeft(find.text('Éxito')).dy));
    expect(laura, lessThan(tester.getTopLeft(find.text('Uber')).dy));
    await tester.pumpAndSettle();
    expect(find.text('Laura'), findsNothing);
    expect(find.text('Uber'), findsOneWidget);
  });

  testWidgets('with animations turned down it simply goes', (tester) async {
    await tester.pumpWidget(list(<String>['Éxito', 'Laura'], still: true));
    await tester.pumpWidget(list(<String>['Éxito'], still: true));
    expect(find.text('Laura'), findsNothing);
  });

  testWidgets('an item that comes back is not leaving any more', (
    tester,
  ) async {
    await tester.pumpWidget(list(<String>['Éxito', 'Laura']));
    await tester.pumpWidget(list(<String>['Éxito']));
    await tester.pumpWidget(list(<String>['Éxito', 'Laura']));
    await tester.pumpAndSettle();
    expect(find.text('Laura'), findsOneWidget);
  });
}
