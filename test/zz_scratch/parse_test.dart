import 'package:flutter_test/flutter_test.dart';
import 'package:quincena/capture/event.dart';
import 'package:quincena/capture/parser.dart';
import 'package:quincena/capture/merchants.dart';

void main() {
  test('parse', () {
    final at = DateTime(2026, 10, 3, 9);
    for (final (String? app, String text) in <(String?, String)>[
      ('com.nequi.MobileApp', r'Nequi · Pagaste $32.000 en Rappi'),
      ('com.nequi.MobileApp', r'Nequi · Pagaste $9.800 en Tienda La Esquina'),
      ('com.todo1.mobile', r'Bancolombia · Pago por $89.900 a Claro'),
      ('com.davivienda.daviviendaapp', r'Davivienda · Compra por $120.000 en Falabella'),
      ('com.todo1.mobile', r'Bancolombia · Compra por $45.000 en D1 T.Deb *1234'),
      ('com.todo1.mobile', r'Bancolombia · Compra por $18.500 en Juan Valdez T.Deb *1234'),
      (null, r'Nequi: Recibiste $200.000 de Diego Lopez'),
      (null, r'Bancolombia le informa Compra por $25.000 en Carulla con T.Deb *1234'),
      (null, r'Bancolombia: movimiento por $50.000 en tu cuenta *5678'),
      (null, r'Hola, ¿cómo vas? Nos vemos a las 5'),
      (null, r'Compraste $27.500 en Farmatodo'),
      (null, r'Movimiento de $50.000 en tu cuenta'),
      (null, r'Nequi: Pagaste $32.000 en Rappi'),
    ]) {
      final p = parseCapture(CaptureEvent(source: app == null ? CaptureSource.paste : CaptureSource.notification, at: at, text: text, app: app));
      print('$text => ${p.toJson()} cat=${p.merchant == null ? null : knownCategory(p.merchant!)}');
    }
  });
}
