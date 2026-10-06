import 'package:decimal/decimal.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:quincena/capture/amounts.dart';
import 'package:quincena/capture/event.dart';
import 'package:quincena/capture/merchants.dart';
import 'package:quincena/capture/parser.dart';
import 'package:quincena/domain/records.dart';
import 'package:quincena/money/asset.dart';

Decimal d(String s) => Decimal.parse(s);

final DateTime arrived = DateTime(2026, 10, 1, 13, 46);

ParsedCapture parse(
  String text, {
  CaptureSource source = CaptureSource.notification,
  String? app,
  String? sender,
}) => parseCapture(
  CaptureEvent(
    source: source,
    at: arrived,
    text: text,
    app: app,
    sender: sender,
  ),
);

void main() {
  group('numbers written either way', () {
    test('money', () {
      expect(parseLooseNumber('45.900,00'), d('45900'));
      expect(parseLooseNumber('45,900.00'), d('45900'));
      expect(parseLooseNumber('45.900'), d('45900'));
      expect(parseLooseNumber('1.200.000'), d('1200000'));
      expect(parseLooseNumber('10,99'), d('10.99'));
      expect(parseLooseNumber('10.99'), d('10.99'));
      expect(parseLooseNumber('2 400 000'), d('2400000'));
    });

    test('crypto keeps its thousandths', () {
      expect(parseLooseNumber('0,001', crypto: true), d('0.001'));
      expect(parseLooseNumber('1,500', crypto: true), d('1.5'));
      expect(parseLooseNumber('0,001'), d('0.001'));
    });

    test('a number without a currency is not an amount', () {
      expect(findAmounts('01/10/2026 13:45 T.Cred *1234'), isEmpty);
      expect(findAmounts(r'Compra por $45.900,00').single.value, d('45900'));
      expect(findAmounts('Recibiste 100 USDT').single.asset, Asset.usdt);
      expect(findAmounts(r'Pagaste US$ 10,99').single.asset, Asset.usd);
    });
  });

  group('Colombian bank alerts (examples)', () {
    test('a card purchase', () {
      final ParsedCapture p = parse(
        r'Bancolombia le informa Compra por $45.900,00 en EXITO LAURELES 13:45. 01/10/2026 T.Cred *1234. Inquietudes al 6045109095.',
      );
      expect(p.amount, d('45900'));
      expect(p.kind, EntryKind.expense);
      expect(p.merchant, 'Exito Laureles');
      expect(p.card, '1234');
      expect(p.institution, 'Bancolombia');
      expect(p.when, DateTime(2026, 10, 1, 13, 45));
      expect(p.confidence, greaterThan(0.9));
    });

    test('a purchase told in the second person', () {
      final ParsedCapture p = parse(
        r'Bancolombia: Compraste $187.400,00 en CARULLA PALMAS con tu T.Deb *5678, el 30/09/2026 a las 19:02.',
      );
      expect(p.amount, d('187400'));
      expect(p.merchant, 'Carulla Palmas');
      expect(p.card, '5678');
    });

    test('a payment to someone', () {
      final ParsedCapture p = parse(
        r'Bancolombia: Pagaste $119.000,00 a FIT24 desde tu cuenta *1234 el 01/10/2026.',
      );
      expect(p.kind, EntryKind.expense);
      expect(p.merchant, 'Fit24');
      expect(knownCategory(p.merchant!), 'subscriptions');
    });

    test('a salary arriving', () {
      final ParsedCapture p = parse(
        r'Bancolombia: Recibiste una transferencia por $2.400.000,00 de ACME COLOMBIA SAS en tu cuenta *1234 el 30/09/2026 a las 08:01.',
      );
      expect(p.kind, EntryKind.income);
      expect(p.amount, d('2400000'));
      expect(p.merchant, 'Acme Colombia SAS');
    });

    test('a transfer received, said with the noun first', () {
      final ParsedCapture p = parse(
        r'Transferencia recibida por $120.000 de CAMILO RUIZ',
      );
      expect(p.kind, EntryKind.income);
      expect(p.amount, d('120000'));
      expect(p.merchant, 'Camilo Ruiz');
      // A card's payment the bank received is still money that left.
      expect(
        parse(r'Pago recibido a tu tarjeta *1234 por $480.000').kind,
        EntryKind.expense,
      );
    });

    test('Nequi, with its exclamations', () {
      final ParsedCapture paid = parse(
        r'¡Listo! Pagaste $23.500 en CREPES & WAFFLES con tu tarjeta Nequi.',
        app: 'com.nequi.MobileApp',
      );
      expect(paid.kind, EntryKind.expense);
      expect(paid.merchant, 'Crepes & Waffles');
      expect(paid.institution, 'Nequi');

      final ParsedCapture got = parse(
        r'Juan Pérez te envió $50.000',
        app: 'com.nequi.MobileApp',
      );
      expect(got.kind, EntryKind.income);
      expect(got.merchant, 'Juan Pérez');
    });

    test('Davivienda and Nu', () {
      final ParsedCapture dav = parse(
        r'Davivienda: Compra aprobada por $45.900 en EXITO con su tarjeta credito *5678 el 01/10/2026 13:45.',
      );
      expect(dav.merchant, 'Exito');
      expect(dav.card, '5678');
      expect(dav.institution, 'Davivienda');

      final ParsedCapture nu = parse(
        r'Hiciste una compra de $42.900 en FALABELLA con tu tarjeta Nu.',
      );
      expect(nu.kind, EntryKind.expense);
      expect(nu.institution, 'Nu');
      expect(nu.merchant, 'Falabella');
    });

    test('the balance after a purchase is not the purchase', () {
      final ParsedCapture p = parse(
        r'Compra por $45.900 en EXITO. Saldo disponible $1.234.567.',
      );
      expect(p.amount, d('45900'));
    });

    test('dollars and crypto', () {
      final ParsedCapture usd = parse(
        r'Pagaste US$ 10,99 a SPOTIFY con tu tarjeta *4321',
      );
      expect(usd.amount, d('10.99'));
      expect(usd.asset, Asset.usd);
      final ParsedCapture usdt = parse(
        'Binance: Depósito confirmado de 100 USDT',
        app: 'com.binance.dev',
      );
      expect(usdt.kind, EntryKind.income);
      expect(usdt.asset, Asset.usdt);
      expect(usdt.institution, 'Binance');
    });

    test('paying the card is money going out', () {
      final ParsedCapture p = parse(
        r'Recibimos tu pago de $480.000 a tu tarjeta *1234.',
      );
      expect(p.kind, EntryKind.expense);
    });
  });

  group('what is not a movement', () {
    test('a security code is set aside', () {
      expect(
        parse(
          'Bancolombia: Tu clave dinamica es 482913. No la compartas.',
        ).ignored,
        'security',
      );
      expect(
        parse('Tu código de verificación Nequi es 1234').isMovement,
        isFalse,
      );
    });

    test('an ad is set aside', () {
      expect(
        parse(
          r'Aprovecha: compra con tu tarjeta y gana hasta $50.000 de descuento',
        ).ignored,
        'advert',
      );
    });

    test('a message without an amount is not a movement', () {
      expect(
        parse('Bancolombia: Tu clave fue cambiada con éxito').isMovement,
        isFalse,
      );
    });
  });

  test('Apple Pay brings its fields apart', () {
    final ParsedCapture p = parseCapture(
      CaptureEvent(
        source: CaptureSource.wallet,
        at: arrived,
        text: '',
        merchant: 'Éxito Laureles',
        amount: r'$45.900,00',
        card: 'Bancolombia Visa',
      ),
    );
    expect(p.amount, d('45900'));
    expect(p.kind, EntryKind.expense);
    expect(p.merchant, 'Éxito Laureles');
    expect(p.institution, 'Bancolombia');
    expect(p.confidence, greaterThan(0.9));
  });

  test('the first experiment\'s file reads as events', () {
    final CaptureEvent e = CaptureEvent.fromJson(<String, Object?>{
      'ts': '2026-09-23T16:42:10-05:00',
      'fuente': 'apple_pay',
      'comercio': 'Éxito',
      'monto': r'$45.900',
      'tarjeta': 'Bancolombia Visa',
      'texto': r'Éxito · $45.900 · Bancolombia Visa',
    });
    expect(e.source, CaptureSource.wallet);
    expect(e.merchant, 'Éxito');
    expect(parseCapture(e).amount, d('45900'));
  });

  group('what the Android listener writes', () {
    test('a title and a body read as one message', () {
      final CaptureEvent e = CaptureEvent.fromJson(<String, Object?>{
        'source': 'notification',
        'at': '2026-10-01T18:45:12.345Z',
        'app': 'com.davivienda.daviviendaapp',
        'appName': 'Davivienda',
        'title': r'Compra por $45.900 en EXITO LAURELES',
        'body': 'con tu tarjeta *1234. Si no la reconoces llama al 018000',
      });
      final ParsedCapture p = parseCapture(e);
      expect(e.appName, 'Davivienda');
      expect(p.amount, d('45900'));
      expect(p.kind, EntryKind.expense);
      expect(p.merchant, 'Exito Laureles');
      expect(p.card, '1234');
    });

    test('the app\'s name in the title is not part of who sent it', () {
      final CaptureEvent e = CaptureEvent.fromJson(<String, Object?>{
        'source': 'notification',
        'at': '2026-10-01T18:45:12.345Z',
        'app': 'com.nequi.MobileApp',
        'title': 'Nequi',
        'body': r'Juan Pérez te envió $50.000',
      });
      final ParsedCapture p = parseCapture(e);
      expect(p.kind, EntryKind.income);
      expect(p.merchant, 'Juan Pérez');
    });
  });

  group('receipts and screens read from an image', () {
    ParsedCapture read(String text) =>
        parse(text, source: CaptureSource.screenshot);

    test('a transfer from a wallet, under the clock of the screenshot', () {
      final ParsedCapture p = read(r'''9:41
¡Listo! Envío exitoso
Para
Juan Pérez
¿Cuánto?
$ 50.000,00
Número Nequi
300 123 4567
Fecha
1 de octubre de 2026 a las 6:30 p. m.
Referencia
M12345678''');
      expect(p.amount, d('50000'));
      expect(p.kind, EntryKind.expense);
      expect(p.merchant, 'Juan Pérez');
      expect(p.institution, 'Nequi');
      expect(p.when, DateTime(2026, 10, 1, 18, 30));
    });

    test('a bank transfer, with the cost of it left out', () {
      final ParsedCapture p = read(r'''¡Transferencia exitosa!
Comprobante No. 0000123456
01 Oct 2026 - 06:30 p. m.
Producto origen
Ahorros *1234
Producto destino
Juan Pérez
Costo de la transferencia
$ 0,00
Valor de la transferencia
$ 50.000,00''');
      expect(p.amount, d('50000'));
      expect(p.kind, EntryKind.expense);
      expect(p.merchant, 'Juan Pérez');
      expect(p.card, '1234');
      expect(p.when, DateTime(2026, 10, 1, 18, 30));
    });

    test('a bill paid through PSE', () {
      final ParsedCapture p = read(r'''Pago exitoso
Empresa
EPM
Valor pagado
$ 187.420
Fecha de pago
2026-10-01 18:30:12
Banco Bancolombia''');
      expect(p.amount, d('187420'));
      expect(p.merchant, 'EPM');
      expect(p.when, DateTime(2026, 10, 1, 18, 30));
    });

    test('a wallet that says it in a sentence', () {
      final ParsedCapture p = read(r'''Daviplata
Pasaste plata
$20.000
a Laura Gómez
celular 310 *** 4567
1 oct. 2026 6:30 p. m.''');
      expect(p.amount, d('20000'));
      expect(p.kind, EntryKind.expense);
      expect(p.merchant, 'Laura Gómez');
      expect(p.when, DateTime(2026, 10, 1, 18, 30));
    });

    test('a movement in the bank app, where no date passes for a name', () {
      final ParsedCapture p = read(r'''Detalle del movimiento
Compra
EXITO LAURELES
-$ 45.900,00
Tarjeta débito *1234
1 de octubre de 2026''');
      expect(p.amount, d('45900'));
      expect(p.merchant, 'Exito Laureles');
      expect(p.card, '1234');
      // No hour: the day it arrived keeps the hour it arrived, another
      // day is noon.
      expect(p.when, arrived);
      expect(
        read(r'''Compra
EXITO LAURELES
-$ 45.900,00
28 de septiembre de 2026''').when,
        DateTime(2026, 9, 28, 12),
      );
    });

    test('two columns read as one line each', () {
      final ParsedCapture p = read(r'''Transferencia exitosa
Para  Juan Pérez
Valor de la transferencia  $ 50.000,00
Fecha  Oct 1, 2026, 6:30 PM''');
      expect(p.amount, d('50000'));
      expect(p.merchant, 'Juan Pérez');
      expect(p.when, DateTime(2026, 10, 1, 18, 30));
    });

    test('a notification captured from the lock screen', () {
      final ParsedCapture p = read(
        r'''BANCOLOMBIA
ahora
Bancolombia: Compraste $45.900,00 en EXITO LAURELES con tu T.Deb *1234, el 01/10/2026 a las 13:45.''',
      );
      expect(p.amount, d('45900'));
      expect(p.merchant, 'Exito Laureles');
      expect(p.when, DateTime(2026, 10, 1, 13, 45));
    });

    test('a transfer as Vision reads it on iOS and macOS', () {
      final ParsedCapture p = read(r'''¡Transferencia exitosa!
Comprobante No. 0000123456
Fecha  01 Oct 2026 - 06:30 p.m.
Producto origen  Ahorros *1234
Producto destino  Laura Gómez
Costo de la transferencia  $ 0,00
Valor de la transferencia  $ 85.000,00''');
      expect(p.amount, d('85000'));
      expect(p.merchant, 'Laura Gómez');
      expect(p.card, '1234');
      expect(p.when, DateTime(2026, 10, 1, 18, 30));
    });

    test('a transfer as ML Kit reads it on Android', () {
      final ParsedCapture p = read(r'''9:41  87%
¡Listo! Envío exitoso
Para
Juan Pérez
¿Cuánto?
$ 50.000,00
Número Nequi
300 123 4567
Fecha
1 de octubre de 2026 a las 6:30 p. m
Referencia
M12345678''');
      expect(p.amount, d('50000'));
      expect(p.merchant, 'Juan Pérez');
      expect(p.when, DateTime(2026, 10, 1, 18, 30));
    });

    test('an image always waits for the person', () {
      expect(
        read(r'Bancolombia: Compraste $45.900,00 en EXITO LAURELES').confidence,
        lessThanOrEqualTo(0.7),
      );
      expect(
        parse(
          r'Bancolombia: Compraste $45.900,00 en EXITO LAURELES',
        ).confidence,
        greaterThan(0.8),
      );
    });
  });

  group('merchant names', () {
    test('are written the way people write them', () {
      expect(prettyMerchant('EXITO LAURELES'), 'Exito Laureles');
      expect(prettyMerchant('TIENDAS D1'), 'Tiendas D1');
      expect(prettyMerchant('Crepes & Waffles'), 'Crepes & Waffles');
    });

    test('are keyed without store numbers', () {
      expect(merchantKey('EXITO LAURELES 123'), 'exito laureles');
      expect(merchantKey('POS 4512 UBER *TRIP'), 'uber trip');
    });

    test('the metro of Medellín is a train', () {
      expect(knownCategory('Metro de Medellín'), 'transport');
      expect(knownCategory('Supermercado Metro'), 'groceries');
    });
  });
}
