// A section's title with something beside it, as a day in Movimientos with
// what its movements add up to. A long one used to take the whole width and
// leave the day a letter to a line, as a day of crumbs in five coins did.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:quincena/theme/theme.dart';
import 'package:quincena/ui/own/look.dart';

import 'fonts.dart';

void main() {
  setUpAll(loadAppFonts);

  testWidgets('a long total beside a day leaves the day on one line', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1170, 2532);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      MaterialApp(
        theme: quincenaTheme(Brightness.light),
        home: const Scaffold(
          body: Padding(
            padding: EdgeInsets.all(16),
            child: Column(
              children: <Widget>[
                SectionLabel(
                  'Sábado 3 de octubre',
                  trailing: Text(
                    '+0,00000014 ADA · +0,00000007 BTC · +0,00000193 FDUSD · '
                    '+0,00000005 VET · +0,001 USDT',
                  ),
                ),
                SectionLabel('Viernes 2 de octubre', trailing: Text('−45.000')),
              ],
            ),
          ),
        ),
      ),
    );
    final Size long = tester.getSize(find.text('SÁBADO 3 DE OCTUBRE'));
    final Size short = tester.getSize(find.text('VIERNES 2 DE OCTUBRE'));
    expect(long.height, short.height);
    expect(long.width, greaterThanOrEqualTo(358 / 2));
    // The total wraps on its own side, inside the screen.
    final Rect total = tester.getRect(find.textContaining('FDUSD'));
    expect(total.left, greaterThanOrEqualTo(16 + 358 / 2));
    expect(total.right, lessThanOrEqualTo(390 - 16));
    expect(tester.takeException(), isNull);
  });
}
