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
      expect(p.card, isNull);
      expect(p.account, '1234');
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

    test('money someone sent, however the bank says it', () {
      const Map<String, String?> said = <String, String?>{
        r'Te enviaron $50.000 desde Nequi': null,
        r'Daviplata: Te enviaron $40.000': null,
        r'Te enviaron plata: $45.000 de MARIA LOPEZ': 'Maria Lopez',
        r'Te llegaron $45.000 de MARIA LOPEZ': 'Maria Lopez',
        r'Llegaron $40.000 a tu Nequi': null,
        r'Te mandaron $40.000': null,
        r'MARIA LOPEZ te mandó $40.000': 'Maria Lopez',
        r'Te pagaron $40.000': null,
        r'Te giraron $40.000 de CAMILO RUIZ': 'Camilo Ruiz',
        r'Transferencia entrante por $100.000 de CAMILO RUIZ': 'Camilo Ruiz',
        r'Ingreso por $200.000 a tu cuenta': null,
        r'Pago recibido de CAMILO RUIZ por $40.000': 'Camilo Ruiz',
        r'Recibiste $80.000 de JUAN PEREZ': 'Juan Perez',
        r'Recibiste un abono de $300.000': null,
        r'Abono a tu cuenta de ahorros por $300.000': null,
        r'Bancolombia le informa abono por $1.200.000 en su cuenta *1234': null,
      };
      for (final MapEntry<String, String?> e in said.entries) {
        final ParsedCapture p = parse(e.key);
        expect(p.kind, EntryKind.income, reason: e.key);
        expect(p.merchant, e.value, reason: e.key);
      }
      // A card's payment the bank received is still money that left, and
      // money sent is still sent.
      expect(
        parse(r'Pago recibido a tu tarjeta *1234 por $480.000').kind,
        EntryKind.expense,
      );
      expect(parse(r'Enviaste $40.000 a CAMILO RUIZ').kind, EntryKind.expense);
      expect(
        parse(r'Bancolombia: movimiento por $50.000 en tu cuenta *5678').kind,
        isNull,
      );
    });

    test('before the amount, only who sent it is named', () {
      expect(parse(r'Abono de nómina por $2.500.000').merchant, isNull);
      expect(parse(r'Ingreso de dinero por $50.000').merchant, isNull);
      expect(parse(r'Abono de intereses por $1.234').merchant, isNull);
      expect(
        parse(r'Recibiste un pago de nómina por $2.500.000').merchant,
        isNull,
      );
      expect(
        parse(r'Transferencia recibida de CAMILO RUIZ por $120.000').merchant,
        'Camilo Ruiz',
      );
      // A shop called Depósito is still a shop.
      expect(
        parse(r'Compraste $50.000 en DEPOSITO LA 80').merchant,
        'Deposito la 80',
      );
      expect(
        parse(
          r'Compra por $80.000 en DEPOSITO DE MATERIALES EL CONSTRUCTOR',
        ).merchant,
        'Deposito de Materiales',
      );
    });

    test('an account\'s number is not a card\'s', () {
      final ParsedCapture moved = parse(
        r'Bancolombia: movimiento por $50.000 en tu cuenta *5678',
      );
      expect(moved.card, isNull);
      expect(moved.account, '5678');
      expect(
        parse(
          r'Consignación recibida por $100.000 en tu cta. ahorros *5678',
        ).account,
        '5678',
      );
      expect(
        parse(
          r'Abono en tu cuenta de ahorros terminada en 5678 por $90.000',
        ).account,
        '5678',
      );
      // Both, each for what it is.
      final ParsedCapture both = parse(
        r'Compraste $45.900 con tu T.Deb *1234 asociada a tu cuenta *5678',
      );
      expect(both.card, '1234');
      expect(both.account, '5678');
      // Someone else's account: where money went, or where it came from.
      expect(
        parse(
          r'Nequi: Enviaste $100.000 a la cuenta Bancolombia *9999',
        ).account,
        isNull,
      );
      expect(
        parse(r'Recibiste $50.000 de la cuenta *1111 de CAMILO RUIZ').account,
        isNull,
      );
      // The person's own, wherever the alert puts it.
      expect(
        parse(
          r'Transferiste $50.000 a la cuenta *9999 desde tu cuenta *5678',
        ).account,
        '5678',
      );
      expect(parse(r'Abono a la cuenta *5678 por $90.000').account, '5678');
      expect(
        parse(
          r'Retiro por $200.000 con tu tarjeta débito asociada a la cuenta *5678',
        ).account,
        '5678',
      );
      expect(
        parse(r'Débito de la cuenta de ahorros *5678 por $40.000').account,
        '5678',
      );
      // Kept with the capture, for a better reading later.
      expect(ParsedCapture.fromJson(moved.toJson()).account, '5678');
      expect(ParsedCapture.fromJson(moved.toJson()).card, isNull);
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

  // Shaped like texts a person's phone got in October 2026, with the
  // numbers, cards, shops and links changed. The shortcut hands Quincena
  // every text with a `$`, so ads with a price arrive with the alerts.
  group('texts as they reach Quincena', () {
    ParsedCapture text(String body) =>
        parse(body, source: CaptureSource.sms, sender: '85000');

    test('a card alert that writes pesos with no sign', () {
      final ParsedCapture p = text(
        'DAVIbank: Realizaste  transaccion en PANADERIA LA ESPIGA por 12,400 '
        'con tu tarjeta Visa Platinum 2026/10/04 11:18:00',
      );
      expect(p.kind, EntryKind.expense);
      expect(p.amount, d('12400'));
      expect(p.asset, isNull);
      expect(p.merchant, 'Panaderia la Espiga');
      expect(p.institution, 'Davivienda');
      final ParsedCapture again = text(
        'DAVIbank : Compra recurrente en STREAMPLUS por 21,900 con tu tarjeta '
        'Visa Platinum 2026/09/01 16:36:09',
      );
      expect(again.isMovement, isTrue);
      expect(again.amount, d('21900'));
    });

    test('a transfer by key that went out, and one that came in', () {
      final ParsedCapture out = text(
        r'BoldCF: Realizaste una transferencia a traves de llaves por un valor '
        r'de $120.000,00 desde tu cuenta terminada en *1111. 08/10/2026 09:29AM',
      );
      expect(out.kind, EntryKind.expense);
      expect(out.amount, d('120000'));
      expect(out.account, '1111');
      expect(out.institution, 'Bold');
      final ParsedCapture came = text(
        r'Bold CF: Has recibido una transferencia por un valor de $250.000,00 '
        r'en tu cuenta Bold terminada en *1111. 06/10/2026 08:50 AM',
      );
      expect(came.kind, EntryKind.income);
      expect(came.amount, d('250000'));
    });

    test('signing in is not a movement', () {
      expect(
        text(
          'Bold CF: Has ingresado exitosamente a tu cuenta Bold. 01/10/2026 '
          '11:34 AM.',
        ).isMovement,
        isFalse,
      );
    });

    test('ads with a price are set aside', () {
      for (final String ad in <String>[
        r'Activa CineMax con TuOperador por $9.900/mes y empieza a '
            'disfrutarlo. bit.ly/4abcdEF Aplican TyC.',
        r'Suscribete a StreamPlus con TuOperador por $18.900/mes. ¡Activalo!',
        r'MARCA: Polos desde $89.990! Elige tus favoritas y sumalas a tus '
            'looks. Encuentralas en tiendas, https://bit.ly/4xYz. SALIRMARCA',
        r'FARMACIA: HOY puedes ahorrar $20.000 con el CUPON OCT20 en compras '
            r'desde $120.000, solo digital. Pide ahora https://farmacia.link/a',
        r'Del cine a tu casa: la pelicula llega para alquiler por $19.900. '
            'Ingresa: bit.ly/4zZz Aplican TyC',
        r'Shoes: VIP, 25% OFF EVERYTHING disappears TONIGHT! Stack your $5 '
            "REWARD for extra savings. Don't miss out",
        'Que tu tarjeta te devuelva plata! Recibe 150mil cashback por '
            'comprar con ella. Pidela: https://tarjeta.co/a',
        '¡Empezo Megadescuentos! Compra desde HOY con hasta 45% Dcto',
      ]) {
        expect(text(ad).ignored, 'advert', reason: ad);
      }
    });

    test('money that did arrive is no ad, whatever words it uses', () {
      final ParsedCapture p = text(
        r'Recibiste $5.000 de cashback en tu cuenta por tu compra. Aplican TyC',
      );
      expect(p.ignored, isNull);
      expect(p.kind, EntryKind.income);
    });

    test('a scare with a link is a fraud, not a movement', () {
      expect(
        text(
          'Banco de Bogota: le informa activacion de PLAN X por valor de '
          '99,900 mensuales. No reconoces este movimiento? Cancela aqui '
          'https://rebrand.ly/abc12',
        ).ignored,
        'suspicious',
      );
      expect(
        text(
          r'Placa ABC123 Pague el Impuesto Vehicular 2026 sin sanciones. '
          r'Multa de $262.000 Pague en pagos-impuesto.example.co/abc',
        ).ignored,
        'suspicious',
      );
    });

    test('a real alert with a link stays one', () {
      final ParsedCapture p = text(
        r'Bancolombia: Compraste $45.900 en EXITO con tu T.Deb *1234. Si no '
        'reconoces esta compra ingresa a https://www.bancolombia.com/personas',
      );
      expect(p.ignored, isNull);
      expect(p.amount, d('45900'));
      // A bank's own link with nothing to fear is no scam either.
      expect(
        text(
          'Nequi: Recibiste una remesa del exterior en Nequi. Mas info '
          'https://redirect.nequi.co/dashboard.movements',
        ).ignored,
        isNull,
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
      // A savings account's digits, not a card's.
      expect(p.card, isNull);
      expect(p.account, '1234');
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
      expect(p.account, '1234');
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

  group('money moved between the person\'s own accounts', () {
    MoveHint move(String text, {String? app}) {
      final ParsedCapture p = parse(text, app: app);
      return readMove(text, institution: p.institution, kind: p.kind);
    }

    test('names the other account the alert calls the person\'s', () {
      expect(
        move(r'Transferiste $150.000 a tu Nequi', app: 'com.todo1.mobile').own,
        'Nequi',
      );
      expect(
        move(
          r'Recibiste $50.000 desde tu cuenta Bancolombia',
          app: 'com.nequi.MobileApp',
        ).own,
        'Bancolombia',
      );
      // The account the alert is about is not another one.
      expect(
        move(
          r'Pagaste $35.000 a CLARO desde tu cuenta *5678',
          app: 'com.todo1.mobile',
        ).own,
        isNull,
      );
      expect(
        move(
          r'Compraste $45.000 en RAPPI con tu tarjeta *1234',
          app: 'com.todo1.mobile',
        ).own,
        isNull,
      );
    });

    test('reads cash taken out at an ATM', () {
      expect(move(r'Retiraste $200.000 en cajero ATM').withdrawal, isTrue);
      expect(move(r'Retiro en corresponsal por $50.000').withdrawal, isTrue);
      expect(move(r'Compraste $20.000 en CAJERO EXPRESS').withdrawal, isFalse);
    });

    test('reads the payment of a credit card', () {
      expect(
        move(r'Pagaste $480.000 a tu tarjeta de crédito Visa').cardPayment,
        isTrue,
      );
      expect(
        move(r'Pago de tarjeta de crédito por $480.000').cardPayment,
        isTrue,
      );
      expect(
        move(r'Pagaste $45.000 en Rappi con tu tarjeta *1234').cardPayment,
        isFalse,
      );
      expect(move(r'Pago por $89.900 a Claro').cardPayment, isFalse);
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
