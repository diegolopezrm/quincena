// Flows of Cuentas (04) y Cripto (05).
import 'dart:convert';

import 'package:decimal/decimal.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:quincena/domain/commitments.dart' show Instalments;
import 'package:quincena/domain/net_worth.dart';
import 'package:quincena/domain/pay_schedule.dart';
import 'package:quincena/domain/records.dart';
import 'package:quincena/domain/shared.dart';
import 'package:quincena/exchanges/binance_link.dart' show SecureKeyVault;
import 'package:quincena/exchanges/wallets.dart' show Chain;
import 'package:quincena/format/money.dart';
import 'package:quincena/money/asset.dart';
import 'package:quincena/money/money.dart';
import 'package:quincena/money/rates.dart';
import 'package:quincena/own/own_controller.dart';
import 'package:quincena/portfolio/cost_basis.dart';
import 'package:quincena/portfolio/market.dart';
import 'package:quincena/portfolio/portfolio.dart';
import 'package:quincena/store/store.dart';
import 'package:quincena/ui/kit.dart' show Block, Figures;
import 'package:quincena/ui/own/balance_explained.dart' show AccountExplained;
import 'package:quincena/ui/own/binance_page.dart'
    show BinanceCard, BinancePage;
import 'package:quincena/ui/own/look.dart' show Headline, moneyText;
import 'package:quincena/ui/own/movement_list.dart' show MovementRow;
import 'package:quincena/ui/own/portfolio_chart.dart';
import 'package:quincena/ui/own/portfolio_page.dart' show percentText;
import 'package:quincena/ui/own/statement_page.dart' show StatementPage;

import '../../test/own_flow_test.dart' show settle;
import '../../test_screens/accounts.dart' show screensNow, seeded;
import '../tour.dart';
import 'flow.dart';

final List<AppFlow> cuentasFlows = <AppFlow>[
  AppFlow(
    '04-01-ver-mi-patrimonio',
    'Ver mi patrimonio y de dónde sale',
    area: 'Cuentas',
    goal:
        'Quiero saber cuánto tengo en total, descontando lo que debo, y '
        'entender cómo se llega a esa cifra.',
    data: fullAccount,
    (FlowRun f) async {
      final OwnController own = f.own;
      await f.tap('Cuentas');
      await f.page(
        'Cuentas: arriba el «Patrimonio», lo que tienes menos lo que debes, '
        'y bajo él cada parte con su monto: uso diario, tarjetas, ahorros, '
        'cripto, lo que te deben, lo que les debes y las cuotas, que juntas '
        'dan la cifra. Después, las cuentas agrupadas por para qué son.',
      );
      final NetWorth worth = own.netWorth();
      await f.check(
        'Las partes que se ven bajo el patrimonio suman ${_cop(worth.total)}',
        () {
          const List<String> parts = <String>[
            'En tus cuentas de uso diario',
            'Lo que debes en tarjetas',
            'En ahorros e inversiones',
            'En cripto',
            'Te deben',
            'Les debes a otras personas',
            'Compras a cuotas',
          ];
          var sum = Decimal.zero;
          for (final String part in parts) {
            if (_rowOf(f, part) case final String value) {
              sum += _parsePesos(value);
            }
          }
          // Each part is shown rounded to the peso: a peso each at most.
          expect(
            (sum - worth.total.amount.round()).abs().toDouble(),
            lessThanOrEqualTo(parts.length),
          );
        },
      );
      await f.check(
        'El patrimonio en pantalla, ${_cop(worth.total)}, es la suma de las '
        'cuentas más lo que te deben menos lo que debes',
        () {
          expect(f.shows(_cop(worth.total)), isTrue);
          // Each account at its rate, rounded to the peso, added here.
          var accounts = Decimal.zero;
          for (final Account a in own.accounts) {
            final Decimal rate = own.rates.rate(a.asset, Asset.cop)!;
            accounts += (_balance(own, a).amount * rate).round();
          }
          expect(
            worth.total.amount,
            accounts +
                worth.owed.amount -
                worth.owing.amount -
                worth.instalments.amount,
          );
        },
      );
      await f.check(
        'El saldo de cada cuenta en pesos es lo que tenía al empezar más sus '
        'movimientos hasta hoy',
        () {
          for (final Account a in own.accounts) {
            if (a.asset != Asset.cop) continue;
            expect(
              _balance(own, a).amount,
              _fromMovements(own, a),
              reason: a.name,
            );
          }
        },
      );
      final Money everyday = _everyday(own);
      await f.check(
        '«En tus cuentas de uso diario» muestra ${_cop(everyday)}, la suma '
        'de Bancolombia, Nequi y Efectivo',
        () {
          expect(
            everyday.amount,
            <String>['Bancolombia', 'Nequi', 'Efectivo']
                .map((String n) => _balance(own, _named(own, n)).amount)
                .fold(Decimal.zero, (Decimal s, Decimal v) => s + v),
          );
          expect(_rowOf(f, 'En tus cuentas de uso diario'), _cop(everyday));
        },
      );
      final Money visa = -_balance(own, _named(own, 'Visa'));
      await f.check(
        '«Lo que debes en tarjetas» es lo que debes en la Visa, '
        '${_cop(visa)}',
        () => expect(_rowOf(f, 'Lo que debes en tarjetas'), _cop(-visa)),
      );
      await f.tapFound(find.text('¿De dónde sale?').first);
      await f.page(
        'Toca «¿De dónde sale?»: lo que tienes y lo que debes, cuenta por '
        'cuenta en pesos, con la tasa de las que están en otra moneda.',
      );
      await f.check(
        'El detalle cierra en el mismo patrimonio, ${_cop(worth.total)}',
        () {
          expect(find.text('Así se calcula tu patrimonio'), findsOneWidget);
          expect(f.screenText, contains(_cop(worth.total)));
          expect(f.screenText, contains('Les debes a otras personas'));
          expect(f.screenText, contains('Compras a cuotas'));
        },
      );
      await f.back();
      await f.step('Al cerrar el detalle vuelves a Cuentas, donde estabas.');
      await f.check('El detalle se cerró y el patrimonio sigue igual', () {
        expect(find.text('Así se calcula tu patrimonio'), findsNothing);
        expect(_headline(f), _cop(worth.total));
      });
    },
  ),
  AppFlow(
    '04-02-revisar-mi-cuenta-de-banco',
    'Revisar la cuenta del banco',
    area: 'Cuentas',
    goal:
        'Quiero ver cuánto tengo en Bancolombia, por qué tengo eso y anotar '
        'un gasto directamente ahí.',
    data: fullAccount,
    (FlowRun f) async {
      final OwnController own = f.own;
      final Account bank = _named(own, 'Bancolombia');
      await f.tap('Cuentas');
      await f.tap('Banco · Bancolombia');
      await f.page(
        'Toca Bancolombia: el «Saldo hoy» arriba y debajo sus movimientos, '
        'del más reciente al más viejo.',
      );
      final Money before = _balance(own, bank);
      await f.check('El saldo hoy en pantalla es ${_cop(before)}', () {
        expect(f.shows(_cop(before)), isTrue);
      });
      await f.tapFound(find.text('¿De dónde sale?').first);
      await f.step(
        '«¿De dónde sale?» arma el saldo: con lo que empezó, más ingresos, '
        'menos gastos y la compra de USDT en Binance, hasta el «Saldo hoy».',
      );
      await f.check(
        'Con lo que empezó, ${_cop(bank.openingMoney)}, más los movimientos '
        'da el saldo de hoy',
        () {
          expect(f.screenText, contains(_cop(bank.openingMoney)));
          expect(before.amount, _fromMovements(own, bank));
        },
      );
      await f.back();
      await f.tapTip('Agregar movimiento');
      await f.step(
        'El «+» de la cuenta abre un movimiento nuevo con Bancolombia ya '
        'elegida como la cuenta de donde sale.',
      );
      await f.type('Monto', '45000');
      await f.tap('Mercado');
      await f.type('¿Dónde o a quién?', 'D1 Laureles');
      await f.tap('Guardar');
      await f.top();
      await f.step(
        'Al guardar, el gasto de 45.000 queda bajo «Hoy», arriba de la '
        'lista, y el «Saldo hoy» baja en esa cantidad.',
      );
      await f.check('El gasto quedó en Bancolombia', () {
        final Entry e = own.snapshot!.entries.firstWhere(
          (Entry e) => e.payee == 'D1 Laureles',
        );
        expect(e.accountId, bank.id);
        expect(e.amount, Decimal.parse('-45000'));
      });
      final Money after = before - Money(Decimal.parse('45000'), Asset.cop);
      await f.check('El saldo pasó de ${_cop(before)} a ${_cop(after)}', () {
        expect(_balance(own, bank), after);
        expect(f.shows(_cop(after)), isTrue);
      });
      await f.tap('D1 Laureles');
      await f.step(
        'Tocar un movimiento lo abre para corregirlo: monto, categoría, '
        'cuenta y fecha.',
      );
      await f.check('Se abre ese gasto, con sus 45.000 y su lugar', () {
        expect(_fieldText(f, 'Monto'), '45.000');
        expect(_fieldText(f, '¿Dónde o a quién?'), 'D1 Laureles');
      });
      await f.back();
      await f.check('Cerrarlo sin cambiar nada deja el saldo igual', () {
        expect(_balance(own, bank), after);
      });
      await f.tapTip('Importar extracto');
      await f.step(
        'El ícono de documento arriba abre «Importar extracto», para traer '
        'los movimientos del banco desde un archivo.',
      );
      await f.check('La importación se abre para Bancolombia', () {
        final StatementPage page = f.tester.widget<StatementPage>(
          find.byType(StatementPage),
        );
        expect(page.accountId, bank.id);
      });
      await f.back();
    },
    manual: <String>[
      'Elegir el archivo del extracto en el selector de archivos del sistema.',
    ],
  ),
  AppFlow(
    '04-03-ver-billetera-y-efectivo',
    'Ver Nequi y el efectivo',
    area: 'Cuentas',
    goal:
        'Quiero ver cuánto me queda en Nequi y en el efectivo, aunque el '
        'efectivo no tenga movimientos.',
    data: fullAccount,
    (FlowRun f) async {
      final OwnController own = f.own;
      final Account nequi = _named(own, 'Nequi');
      final Account cash = _named(own, 'Efectivo');
      await f.tap('Cuentas');
      await f.tap('Billetera digital · Nequi');
      await f.page(
        'Nequi, la billetera digital: su «Saldo hoy» y lo que se ha pagado '
        'desde ella.',
      );
      await f.tapFound(find.text('¿De dónde sale?').first);
      await f.step(
        'Su «¿De dónde sale?»: con lo que empezó y los gastos de estos días.',
      );
      await f.check(
        'El saldo de Nequi, ${_cop(_balance(own, nequi))}, es lo que tenía al '
        'empezar más sus movimientos',
        () => expect(_balance(own, nequi).amount, _fromMovements(own, nequi)),
      );
      await f.back();
      await f.back();
      await f.tapFound(find.text('Efectivo').first);
      await f.step(
        'El efectivo no tiene movimientos: muestra su saldo y un texto que '
        'dice que ahí aparecerá la plata que entra y sale.',
      );
      await f.check('El efectivo no tiene movimientos y muestra \$60.000', () {
        expect(
          own.snapshot!.entries.where((Entry e) => e.accountId == cash.id),
          isEmpty,
        );
        expect(f.shows('Aquí aparecerá tu plata entrando y saliendo.'), isTrue);
        expect(_balance(own, cash), _cop60k);
      });
      await f.tapFound(find.text('¿De dónde sale?').first);
      await f.step(
        'Sin movimientos, «¿De dónde sale?» solo muestra con lo que empezó, '
        'que es el mismo saldo de hoy.',
      );
      await f.check(
        'El detalle va de «Con lo que empezó» \$60.000 a «Saldo hoy» '
        '\$60.000, sin nada en medio',
        () {
          final Finder sheet = find.byType(AccountExplained);
          expect(_rowOf(f, 'Con lo que empezó', within: sheet), _cop(_cop60k));
          expect(_rowOf(f, 'Saldo hoy', within: sheet), _cop(_cop60k));
          expect(f.screenText, isNot(contains('gasto')));
        },
      );
      await f.back();
    },
  ),
  AppFlow(
    '04-04-revisar-la-tarjeta',
    'Revisar lo que debo en la tarjeta',
    area: 'Cuentas',
    goal:
        'Quiero ver cuánto debo en la Visa y cuánto cupo me queda para '
        'usarla.',
    data: fullAccount,
    (FlowRun f) async {
      final OwnController own = f.own;
      final Account visa = _named(own, 'Visa');
      final Money owed = -_balance(own, visa);
      final Money left = visa.creditLeft(_balance(own, visa))!;
      await f.tap('Cuentas');
      await f.reveal(find.text('Visa'));
      await f.step(
        'En «Tarjetas de crédito» la Visa dice «Debes» y, debajo, el «Cupo '
        'libre» que le queda.',
      );
      await f.check(
        'La fila dice que debes ${_cop(owed)} y te queda ${_cop(left)} de '
        'cupo',
        () {
          expect(f.shows(_cop(owed)), isTrue);
          expect(f.shows('Cupo libre ${_cop(left)}'), isTrue);
        },
      );
      await f.check('El cupo libre es el cupo menos lo que debes', () {
        expect(left.amount, visa.creditLimit! - owed.amount);
      });
      await f.tap('Visa');
      await f.page(
        'Toca la Visa: arriba «Debes» en vez de saldo, y «Cupo libre» de '
        'cuánto; debajo, las compras hechas con ella.',
      );
      await f.check('La página dice «Cupo libre ${_cop(left)} de '
          '${_cop(Money(visa.creditLimit!, Asset.cop))}»', () {
        expect(
          f.screenText,
          contains(
            'Cupo libre ${_cop(left)} de '
            '${_cop(Money(visa.creditLimit!, Asset.cop))}',
          ),
        );
      });
      await f.tapFound(find.text('¿De dónde sale?').first);
      await f.step(
        '«¿De dónde sale?» de la tarjeta termina en «Debes»: con lo que '
        'empezó debiendo más cada compra.',
      );
      await f.check('El detalle termina en «Debes ${_cop(owed)}»', () {
        expect(f.screenText, contains('Debes'));
        expect(f.screenText, contains(_cop(owed)));
        expect(-_balance(own, visa).amount, -_fromMovements(own, visa));
      });
      await f.back();
    },
  ),
  AppFlow(
    '04-05-ver-cuenta-en-dolares',
    'Ver la cuenta en dólares',
    area: 'Cuentas',
    goal:
        'Tengo dólares en Global66 y quiero ver cuánto son en pesos y con '
        'qué tasa se calculó.',
    data: fullAccount,
    (FlowRun f) async {
      final OwnController own = f.own;
      final Account usd = _named(own, 'Cuenta en dólares');
      await f.tap('Cuentas');
      await f.reveal(find.text('Cuenta en dólares'));
      await f.step(
        'La cuenta en dólares está en «Ahorros e inversiones»: el saldo en '
        'dólares y debajo, con «≈», cuánto es en pesos.',
      );
      final Money balance = _balance(own, usd);
      final Money inPesos = own.partOfTotal(usd)!;
      await f.check(
        '${moneyText(balance, base: Asset.cop)} a la tasa de hoy son '
        '${_cop(inPesos)}',
        () {
          final Decimal rate = own.rates.rate(Asset.usd, Asset.cop)!;
          expect(inPesos.amount, (balance.amount * rate).round());
          expect(f.shows('≈ ${_cop(inPesos)}'), isTrue);
        },
      );
      await f.tap('Cuenta en dólares');
      await f.page(
        'Toca la cuenta: «Saldo hoy» en dólares, cuánto es en pesos y el '
        'gasto de Spotify pagado en dólares.',
      );
      await f.tapFound(find.text('¿De dónde sale?').first);
      await f.step(
        'Su «¿De dónde sale?» explica el saldo en dólares y debajo la tasa '
        'con la que se pasa a pesos.',
      );
      final Decimal trm = own.rates.rate(Asset.usd, Asset.cop)!;
      final String rateText = formatAmount(
        trm,
        Asset.cop,
        base: Asset.cop,
        decimals: 2,
      );
      await f.check(
        'El detalle pasa ${moneyText(balance, base: Asset.cop)} a pesos con '
        'la TRM de $rateText',
        () {
          final String said = _said(f);
          expect(
            said,
            contains(
              '${_plainText(moneyText(balance, base: Asset.cop))} a '
              '${_plainText(rateText)}',
            ),
          );
          expect(said, contains('TRM oficial del 3 oct'));
          expect(balance.amount, _fromMovements(own, usd));
        },
      );
      await f.back();
    },
  ),
  AppFlow(
    '04-06-agregar-cuenta-de-ahorros',
    'Agregar una cuenta de ahorros',
    area: 'Cuentas',
    goal:
        'Abrí una cuenta de ahorros en Davivienda y quiero que cuente en mi '
        'patrimonio, pero no en lo que puedo gastar.',
    data: fullAccount,
    (FlowRun f) async {
      final OwnController own = f.own;
      final Money worth = own.netWorth().total;
      final Money everyday = own.total(spendableOnly: true);
      final int count = own.accounts.length;
      await f.tap('Cuentas');
      await f.tap('Agregar cuenta');
      await f.step(
        'Toca «Agregar cuenta»: el formulario empieza en «Banco» y en pesos, '
        'con «Cuenta de uso diario» encendida.',
      );
      await f.type('Nombre', 'Davivienda');
      await f.back();
      await f.check('Cerrar el formulario sin guardar no crea nada', () {
        expect(own.accounts.length, count);
      });
      await f.tap('Agregar cuenta');
      await f.check('Al abrirlo otra vez el nombre está vacío', () {
        expect(_fieldText(f, 'Nombre'), isEmpty);
      });
      await f.tap('Guardar');
      await f.step(
        'Cerrado sin guardar, no queda nada; y guardar sin nombre no deja '
        'seguir: «Nombre» se pone en rojo, con un ejemplo de cómo llamarla.',
      );
      await f.check('Sin nombre no se crea ninguna cuenta', () {
        expect(own.accounts.length, count);
        expect(_errorOf(f, 'Nombre'), 'Por ejemplo, Bancolombia ahorros');
      });
      await f.type('Nombre', 'Davivienda ahorros');
      await f.check('Al escribir el nombre se quita el aviso en rojo', () {
        expect(_errorOf(f, 'Nombre'), isNull);
      });
      await f.type('Entidad (opcional)', 'Davivienda');
      await f.type('¿Cuánto tiene hoy?', '1200000');
      await f.tapFound(find.byType(SwitchListTile));
      await f.step(
        'Con nombre, entidad y 1.200.000, el rojo se fue; se apaga «Cuenta de '
        'uso diario»: es plata guardada, no para gastar en la quincena.',
      );
      await f.tap('Guardar');
      await f.reveal(find.text('Davivienda ahorros'));
      await f.step(
        'Davivienda ahorros queda en «Ahorros e inversiones», con '
        '\$1.200.000.',
      );
      await f.check('Quedó una cuenta de banco que no es de uso diario', () {
        final Account a = _named(own, 'Davivienda ahorros');
        expect(a.kind, AccountKind.bank);
        expect(a.spendable, isFalse);
        expect(a.institution, 'Davivienda');
        expect(_balance(own, a), _pesos('1200000'));
        _expectIn(f, 'Davivienda ahorros', 'AHORROS E INVERSIONES', 'CRIPTO');
      });
      await f.top();
      await f.step(
        'Arriba, el «Patrimonio» subió 1.200.000 y «En tus cuentas de uso '
        'diario» sigue igual.',
      );
      final Money now = worth + _pesos('1200000');
      await f.check('El patrimonio pasó de ${_cop(worth)} a ${_cop(now)}', () {
        expect(own.netWorth().total, now);
        expect(_headline(f), _cop(now));
      });
      await f.check(
        'Lo de uso diario sigue en ${_cop(everyday)}',
        () => expect(own.total(spendableOnly: true), everyday),
      );
    },
  ),
  AppFlow(
    '04-07-agregar-tarjeta-con-cupo',
    'Agregar una tarjeta con cupo',
    area: 'Cuentas',
    goal:
        'Saqué una Mastercard de Falabella y quiero que la app cuente lo que '
        'debo y cuánto cupo me queda.',
    data: fullAccount,
    (FlowRun f) async {
      final OwnController own = f.own;
      final Money worth = own.netWorth().total;
      final int cardDebt = own.spendableCardDebt;
      await f.tap('Cuentas');
      await f.tap('Agregar cuenta');
      await f.type('Nombre', 'Mastercard Falabella');
      await f.tap('Tarjeta de crédito');
      await f.step(
        'Al elegir «Tarjeta de crédito», el saldo pasa a «¿Cuánto debes '
        'hoy?» y aparece «Cupo total (opcional)», con lo que es.',
      );
      await f.type('Entidad (opcional)', 'Banco Falabella');
      await f.type('¿Cuánto debes hoy?', '350000');
      await f.type('Cupo total (opcional)', '0');
      await f.tap('Guardar');
      await f.reveal(find.text('Cupo total (opcional)'));
      await f.step(
        'Un cupo de 0 no sirve: el campo pide «Escribe un monto» y la '
        'tarjeta no se guarda todavía.',
      );
      await f.check('Con el cupo en 0 no se crea la tarjeta', () {
        expect(
          own.accounts.where((Account a) => a.name == 'Mastercard Falabella'),
          isEmpty,
        );
      });
      await f.type('Cupo total (opcional)', '2000000');
      await f.tap('Guardar');
      await f.reveal(find.text('Mastercard Falabella'));
      await f.step(
        'La tarjeta queda en «Tarjetas de crédito»: «Debes \$350.000» y '
        '«Cupo libre \$1.650.000».',
      );
      await f.check('Debes \$350.000 con un cupo de \$2.000.000', () {
        final Account card = _named(own, 'Mastercard Falabella');
        expect(card.kind, AccountKind.card);
        expect(_balance(own, card), _pesos('-350000'));
        expect(card.creditLimit, Decimal.parse('2000000'));
        expect(card.creditLeft(_balance(own, card)), _pesos('1650000'));
        expect(f.shows('Cupo libre \$1.650.000'), isTrue);
      });
      final String debtBefore = pesos(own.ledger!.major(cardDebt));
      final String debtNow = pesos(own.ledger!.major(cardDebt + 350000));
      await f.top();
      await f.step(
        'Arriba, «Lo que debes en tarjetas» suma los \$350.000 y el '
        '«Patrimonio» baja lo mismo.',
      );
      await f.check(
        'Lo que debes en tarjetas pasó de $debtBefore a $debtNow',
        () {
          expect(own.spendableCardDebt, cardDebt + 350000);
          expect(_rowOf(f, 'Lo que debes en tarjetas'), '−$signJoiner$debtNow');
        },
      );
      await f.check(
        'El patrimonio bajó \$350.000',
        () => expect(own.netWorth().total, worth - _pesos('350000')),
      );
    },
  ),
  AppFlow(
    '04-08-agregar-cuenta-en-dolares',
    'Agregar una cuenta en dólares',
    area: 'Cuentas',
    goal:
        'Tengo 500 dólares en Wise y quiero verlos en pesos dentro de mi '
        'patrimonio.',
    data: fullAccount,
    (FlowRun f) async {
      final OwnController own = f.own;
      final Money worth = own.netWorth().total;
      await f.tap('Cuentas');
      await f.tap('Agregar cuenta');
      await f.type('Nombre', 'Wise');
      await f.tapFound(find.byType(DropdownButtonFormField<String>));
      await f.step(
        'Abre «Moneda»: arriba las monedas, abajo las cripto y al final '
        '«Otra cripto» para cualquier otra.',
      );
      await f.tap('USD · Dólar estadounidense');
      await f.type('¿Cuánto tiene hoy?', '500');
      await f.tapFound(find.byType(SwitchListTile));
      await f.step(
        'Con «USD» elegido, el saldo lleva «USD» al lado; se apaga «Cuenta '
        'de uso diario» porque son ahorros.',
      );
      await f.tap('Guardar');
      await f.reveal(find.text('Wise'));
      await f.step(
        'Wise queda en «Ahorros e inversiones» con US\$500,00 y, debajo, lo '
        'que son en pesos con la TRM.',
      );
      final Decimal rate = own.rates.rate(Asset.usd, Asset.cop)!;
      final Money inPesos = Money(
        (Decimal.fromInt(500) * rate).round(),
        Asset.cop,
      );
      await f.check(
        'US\$500 a ${_cop(Money(rate, Asset.cop))} son ${_cop(inPesos)}',
        () {
          final Account wise = _named(own, 'Wise');
          expect(wise.asset, Asset.usd);
          expect(own.partOfTotal(wise), inPesos);
          expect(f.shows('≈ ${_cop(inPesos)}'), isTrue);
        },
      );
      await f.top();
      await f.step(
        'Arriba, el «Patrimonio» sube lo que valen esos dólares en pesos.',
      );
      await f.check('El patrimonio subió exactamente ${_cop(inPesos)}', () {
        expect(own.netWorth().total, worth + inPesos);
        expect(_headline(f), _cop(worth + inPesos));
      });
    },
  ),
  AppFlow(
    '04-09-primera-cuenta',
    'Agregar la primera cuenta',
    area: 'Cuentas',
    goal:
        'Todavía no tengo cuentas en la app y quiero empezar por el efectivo '
        'que llevo en la billetera.',
    data: _withoutAccounts,
    (FlowRun f) async {
      final OwnController own = f.own;
      await f.tap('Cuentas');
      await f.page(
        'Sin cuentas, la pestaña lo dice y ofrece «Conecta Binance» con lo '
        'que esa conexión puede y no puede hacer.',
      );
      await f.check('Cuentas dice que aún no hay cuentas', () {
        expect(own.accounts, isEmpty);
        expect(f.screenText, contains('Aún no tienes cuentas'));
      });
      await f.tap('¿De dónde sale?');
      await f.step(
        'Sin cuentas, «¿De dónde sale?» del patrimonio solo trae el total, '
        '\$0: no hay nada que sumar todavía.',
      );
      await f.check('El detalle dice que el patrimonio es \$0', () {
        expect(f.shows('Así se calcula tu patrimonio'), isTrue);
        expect(own.netWorth().total, Money.zero(Asset.cop));
      });
      await f.back();
      await f.tap('Agregar cuenta');
      await f.tap('Exchange de cripto');
      await f.step(
        'Al elegir «Exchange de cripto», «Cuenta de uso diario» se apaga '
        'sola: lo que hay en un exchange no es para gastar.',
      );
      await f.check('Con Exchange de cripto el interruptor queda apagado', () {
        expect(_switchOn(f), isFalse);
      });
      await f.tap('Ahorro o inversión');
      await f.check('Con Ahorro o inversión también queda apagado', () {
        expect(_switchOn(f), isFalse);
      });
      await f.tap('Billetera digital');
      await f.check('Con Billetera digital se vuelve a encender', () {
        expect(_switchOn(f), isTrue);
      });
      await f.tap('Otra');
      await f.tap('Efectivo');
      await f.type('Nombre', 'Billetera');
      await f.type('¿Cuánto tiene hoy?', '80000');
      await f.step(
        'Probando cada tipo, el interruptor sigue al tipo; con «Efectivo» '
        'queda encendido: es plata del día a día.',
      );
      await f.check('Con Efectivo el interruptor está encendido', () {
        expect(_switchOn(f), isTrue);
      });
      await f.tap('Guardar');
      await f.step(
        'La primera cuenta aparece en «Cuentas de uso diario» y el '
        '«Patrimonio» ya es \$80.000.',
      );
      await f.check('Quedó una cuenta de efectivo de uso diario', () {
        final Account a = _named(own, 'Billetera');
        expect(a.kind, AccountKind.cash);
        expect(a.spendable, isTrue);
        expect(own.netWorth().total, _pesos('80000'));
        expect(f.screenText, isNot(contains('Aún no tienes cuentas')));
      });
      await f.tap('Conecta Binance');
      await f.step(
        '«Conecta Binance» abre la conexión con una llave de solo lectura, '
        'para quien guarda cripto allá.',
      );
      await f.check(
        'Se abre el formulario para conectar, sin conectar aún',
        () {
          expect(find.byType(BinancePage), findsOneWidget);
          expect(find.widgetWithText(TextField, 'API Key'), findsOneWidget);
          expect(own.binance.connected, isFalse);
        },
      );
      await f.back();
    },
  ),
  AppFlow(
    '04-10-editar-una-cuenta',
    'Cambiar el nombre y el uso de una cuenta',
    area: 'Cuentas',
    goal:
        'Nequi ahora es solo para ahorrar: quiero cambiarle el nombre y que '
        'deje de contar en lo que puedo gastar.',
    data: fullAccount,
    (FlowRun f) async {
      final OwnController own = f.own;
      final Account nequi = _named(own, 'Nequi');
      final Money held = _balance(own, nequi);
      final Money everyday = _everyday(own);
      final Money worth = own.netWorth().total;
      await f.tap('Cuentas');
      await f.tap('Billetera digital · Nequi');
      await f.tapTip('Editar cuenta');
      await f.page(
        'El lápiz abre «Editar cuenta»: la moneda queda fija, y dice por '
        'qué; lo demás se puede cambiar.',
      );
      await f.type('Nombre', 'Nequi ahorros');
      await f.tap('Ahorro o inversión');
      await f.step(
        'Cambia el nombre a «Nequi ahorros» y el tipo a «Ahorro o '
        'inversión»: «Cuenta de uso diario» se apaga sola.',
      );
      await f.check('Con Ahorro o inversión el uso diario se apaga solo', () {
        expect(_switchOn(f), isFalse);
      });
      await f.tap('Guardar');
      await f.step(
        'Al guardar, el título de la cuenta ya dice «Nequi ahorros».',
      );
      await f.back();
      await f.reveal(find.text('Nequi ahorros'));
      await f.step(
        'En Cuentas, Nequi ahorros pasó a «Ahorros e inversiones» y ya no '
        'suma en lo de uso diario.',
      );
      await f.check('El cambio quedó guardado', () {
        final Account a = _account(own, nequi.id);
        expect(a.name, 'Nequi ahorros');
        expect(a.kind, AccountKind.investment);
        expect(a.spendable, isFalse);
        _expectIn(f, 'Nequi ahorros', 'AHORROS E INVERSIONES', 'CRIPTO');
      });
      await f.top();
      await f.step(
        'Arriba, «En tus cuentas de uso diario» ya no cuenta lo de Nequi; '
        'el «Patrimonio» sigue igual.',
      );
      final Money now = everyday - held;
      await f.check(
        'Lo de uso diario pasó de ${_cop(everyday)} a ${_cop(now)}, sin los '
        '${_cop(held)} de Nequi',
        () {
          expect(_everyday(own), now);
          expect(_rowOf(f, 'En tus cuentas de uso diario'), _cop(now));
        },
      );
      await f.check(
        'El patrimonio sigue en ${_cop(worth)}',
        () => expect(own.netWorth().total, worth),
      );
    },
  ),
  AppFlow(
    '04-11-ajustar-el-saldo',
    'Corregir el saldo de una cuenta',
    area: 'Cuentas',
    goal:
        'La app del banco dice que tengo \$1.180.000 en Bancolombia y quiero '
        'que Quincena diga lo mismo.',
    data: fullAccount,
    (FlowRun f) async {
      final OwnController own = f.own;
      final Account bank = _named(own, 'Bancolombia');
      final Money before = _balance(own, bank);
      final int entries = own.snapshot!.entries.length;
      final Money target = _pesos('1180000');
      final Money opening = bank.openingMoney + (target - before);
      await f.tap('Cuentas');
      await f.tap('Banco · Bancolombia');
      await f.tapTip('Editar cuenta');
      await f.reveal(find.text('¿Cuánto tiene hoy?'));
      await f.step(
        '«¿Cuánto tiene hoy?» trae el saldo de hoy, ${_plain(before)}, listo '
        'para corregirlo.',
      );
      await f.check('El campo trae el saldo de hoy', () {
        expect(f.shows(_plain(before)), isTrue);
      });
      await f.type('¿Cuánto tiene hoy?', '1180000');
      await f.tap('Guardar');
      await f.step(
        'Al guardar, el «Saldo hoy» queda en \$1.180.000, lo mismo que dice '
        'el banco.',
      );
      await f.check('El saldo hoy es \$1.180.000', () {
        expect(_balance(own, bank), target);
        expect(f.shows(_cop(target)), isTrue);
      });
      await f.check('No se agregó ni se cambió ningún movimiento', () {
        expect(own.snapshot!.entries.length, entries);
      });
      await f.tapFound(find.text('¿De dónde sale?').first);
      await f.step(
        'En «¿De dónde sale?», «Con lo que empezó» absorbió la diferencia de '
        '${_cop(before - target)}; los movimientos siguen iguales.',
      );
      await f.check('Con lo que empezó pasó de ${_cop(bank.openingMoney)} a '
          '${_cop(opening)}', () {
        expect(_account(own, bank.id).openingMoney, opening);
        expect(f.screenText, contains(_cop(opening)));
      });
      await f.back();
    },
  ),
  AppFlow(
    '04-12-cambiar-el-cupo-de-la-tarjeta',
    'Cambiar el cupo y el uso de la tarjeta',
    area: 'Cuentas',
    goal:
        'El banco me subió el cupo de la Visa y además la pago con ahorros, '
        'así que no quiero que reste de lo que puedo gastar.',
    data: fullAccount,
    (FlowRun f) async {
      final OwnController own = f.own;
      final Account visa = _named(own, 'Visa');
      final Money owed = -_balance(own, visa);
      final int free = own.ledger!.freeUntilPayday;
      final int cardDebt = own.spendableCardDebt;
      await f.tap('Cuentas');
      await f.tap('Visa');
      await f.tapTip('Editar cuenta');
      await f.reveal(find.text('Cupo total (opcional)'));
      await f.step(
        'En la tarjeta, «¿Cuánto debes hoy?» trae lo que debes, en positivo, '
        'y el cupo de \$3.000.000.',
      );
      await f.type('Cupo total (opcional)', '4000000');
      await f.tap('Guardar');
      await f.step(
        'Con el cupo nuevo, el «Cupo libre» sube en \$1.000.000: ahora es '
        'de \$4.000.000.',
      );
      final Money left = _pesos('4000000') - owed;
      await f.check(
        'Cupo libre ${_cop(left)} de \$4.000.000, y la deuda sigue en '
        '${_cop(owed)}',
        () {
          final Account a = _account(own, visa.id);
          expect(a.creditLimit, Decimal.parse('4000000'));
          expect(-_balance(own, a), owed);
          expect(
            f.screenText,
            contains('Cupo libre ${_cop(left)} de \$4.000.000'),
          );
        },
      );
      await f.tapTip('Editar cuenta');
      await f.type('Cupo total (opcional)', '');
      await f.tap('Guardar');
      await f.step(
        'Borrando el cupo, la tarjeta solo muestra lo que debes: el «Cupo '
        'libre» desaparece.',
      );
      await f.check('Sin cupo no hay cupo libre', () {
        expect(_account(own, visa.id).creditLimit, isNull);
        expect(f.screenText, isNot(contains('Cupo libre')));
      });
      await f.tapTip('Editar cuenta');
      await f.tapFound(find.byType(SwitchListTile));
      await f.step(
        'Apaga «Cuenta de uso diario»: como dice su ayuda, lo que debes en '
        'esta tarjeta y lo que se cobra en ella dejan de restarse de lo que '
        'puedes gastar.',
      );
      await f.check(
        'La ayuda dice que también cuenta lo que se cobra en la tarjeta',
        () => expect(
          f.shows(
            'Si está encendido, lo que debes en esta tarjeta y lo que se '
            'cobra en ella se restan de lo que puedes gastar, porque los '
            'pagas con tus cuentas de uso diario.',
          ),
          isTrue,
        ),
      );
      await f.tap('Guardar');
      await f.back();
      await f.top();
      await f.step(
        'En Cuentas, lo que debes en la Visa sigue restando del patrimonio, '
        'porque la deuda sigue ahí; lo que cambia es que ya no sale de lo '
        'que puedes gastar.',
      );
      await f.check(
        'Ya no resta de lo que puedes gastar, pero sigue en el patrimonio',
        () {
          expect(own.spendableCardDebt, 0);
          expect(
            _rowOf(f, 'Lo que debes en tarjetas'),
            _cop(_balance(own, _account(own, visa.id))),
          );
        },
      );
      // What is charged to the card before payday stops coming out of the
      // money to spend too: Netflix, on the 12th.
      final DateTime payday = own.ledger!.nextPayday;
      final int charged = own.recurring
          .where(
            (RecurringCharge r) =>
                r.active &&
                r.accountId == visa.id &&
                !r.nextDate.isAfter(payday),
          )
          .fold(
            0,
            (int s, RecurringCharge r) =>
                s + r.amount.amount.toBigInt().toInt(),
          );
      await f.check(
        'Lo que puedes gastar pasó de ${pesos(own.ledger!.major(free))} a '
        '${pesos(own.ledger!.major(free + cardDebt + charged))}: ya no resta '
        'los ${pesos(own.ledger!.major(cardDebt))} de la Visa ni los '
        '${pesos(own.ledger!.major(charged))} de Netflix que se cobran en ella',
        () {
          expect(cardDebt, owed.amount.toBigInt().toInt());
          expect(charged, 26900);
          expect(own.ledger!.freeUntilPayday, free + cardDebt + charged);
        },
      );
      await f.check('La Visa quedó guardada fuera del uso diario', () {
        expect(_account(own, visa.id).spendable, isFalse);
      });
    },
  ),
  AppFlow(
    '04-13-eliminar-una-cuenta',
    'Eliminar una cuenta',
    area: 'Cuentas',
    goal:
        'Cerré Nequi y quiero quitarla de la app, sabiendo qué se borra con '
        'ella.',
    data: fullAccount,
    (FlowRun f) async {
      final OwnController own = f.own;
      final Account nequi = _named(own, 'Nequi');
      final Money held = _balance(own, nequi);
      final Money worth = own.netWorth().total;
      final int entries = own.snapshot!.entries.length;
      final int inNequi = own.snapshot!.entries
          .where((Entry e) => e.accountId == nequi.id)
          .length;
      final Money now = worth - held;
      await f.tap('Cuentas');
      await f.tap('Billetera digital · Nequi');
      await f.tapTip('Editar cuenta');
      await f.tap('Eliminar');
      await f.step(
        '«Eliminar», al final del formulario, pide confirmar: cuántos '
        'movimientos se borran y que no se puede deshacer, que lo que tiene '
        'deja de contar en el patrimonio y en lo que puedes gastar, y ofrece '
        '«Archivar» en su lugar.',
      );
      await f.check('El aviso cuenta los $inNequi movimientos de Nequi', () {
        expect(
          f.screenText,
          contains('Se borran también sus $inNequi movimientos.'),
        );
      });
      await f.check(
        'El aviso dice que el patrimonio pasa de ${_cop(worth)} a '
        '${_cop(now)}: lo que tiene Nequi, ${_cop(held)}, deja de contar',
        () {
          expect(
            _said(f),
            contains(
              _plainText(
                'Lo que tiene, ${_cop(held)}, deja de contar en tu '
                'patrimonio y en lo que puedes gastar hasta el pago.',
              ),
            ),
          );
          expect(
            _said(f),
            contains(
              _plainText(
                'Tu patrimonio pasa de ${_cop(worth)} a ${_cop(now)}.',
              ),
            ),
          );
        },
      );
      await f.check('Antes de borrar, ofrece archivarla', () {
        expect(
          find.descendant(
            of: find.byType(AlertDialog),
            matching: find.text('Archivar'),
          ),
          findsOneWidget,
        );
        expect(_said(f), contains('Si la cerraste, mejor archívala'));
      });
      await f.tap('Cancelar');
      await f.step(
        'Con «Cancelar» no pasa nada: el formulario sigue abierto y Nequi '
        'sigue ahí.',
      );
      await f.check('Cancelar no borra nada', () {
        expect(own.snapshot!.account(nequi.id), isNotNull);
        expect(own.snapshot!.entries.length, entries);
      });
      await f.tap('Eliminar');
      await f.tap('Eliminar');
      await f.step(
        'Al confirmar, el formulario y la página de Nequi se cierran solos: '
        'vuelves a Cuentas, donde Nequi ya no aparece.',
      );
      await f.check('Nequi y sus $inNequi movimientos ya no están', () {
        expect(own.snapshot!.account(nequi.id), isNull);
        expect(own.snapshot!.entries.length, entries - inNequi);
        expect(f.shows('Nequi'), isFalse);
      });
      await f.check('Se vuelve solo a Cuentas, no a una página vacía', () {
        expect(f.shows('Agregar cuenta'), isTrue);
        expect(find.byType(BackButton), findsNothing);
      });
      await f.check(
        'El patrimonio pasó de ${_cop(worth)} a ${_cop(now)}, como dijo el '
        'aviso',
        () {
          expect(own.netWorth().total, now);
          expect(_headline(f), _cop(now));
        },
      );
    },
  ),
  AppFlow(
    '04-14-escribir-una-tasa',
    'Usar mi propia tasa del dólar',
    area: 'Cuentas',
    goal:
        'Me cambian los dólares a \$4.100 y quiero que la app use esa tasa, '
        'y luego volver a la automática.',
    data: fullAccount,
    (FlowRun f) async {
      final OwnController own = f.own;
      final Account usd = _named(own, 'Cuenta en dólares');
      final Decimal held = _balance(own, usd).amount;
      final Decimal trm = own.rates.rate(Asset.usd, Asset.cop)!;
      await f.tap('Cuentas');
      await f.tap('Ver tasas usadas');
      await f.page(
        '«Ver tasas usadas»: cómo se pasa a pesos cada moneda, de dónde sale '
        'cada tasa y cuándo se actualizó.',
      );
      await f.check(
        'El bitcoin se pasa a pesos en tres pasos: su precio en USDT, USDT '
        'como dólar y la TRM',
        () {
          final String said = _said(f);
          expect(said, contains('Precio de mercado: 1 BTC = 84.616,92 USDT'));
          expect(said, contains('USDT se cuenta como 1 US\$'));
          expect(said, contains('Conversión a COP: 1 US\$ = \$3.312,84'));
          final Decimal btc = own.rates.rate(Asset.btc, Asset.cop)!;
          expect(btc, Decimal.parse('84616.92') * trm);
        },
      );
      await f.check(
        'El dólar no dice su tasa dos veces: debajo de «1 USD = \$3.312,84» '
        'va solo de dónde sale y de qué día',
        () => expect(
          _said(f),
          contains('1 USD = \$3.312,84 | TRM oficial del 3 oct'),
        ),
      );
      await f.tapContaining('1 USD =');
      await f.step(
        'Tocar la línea del dólar abre «Escribir una tasa» con la de hoy ya '
        'escrita en «1 USD en», con COP al lado, y «Cancelar» y «Guardar».',
      );
      await enterTextIn(f.tester, find.byType(TextField).last, '0');
      await f.tap('Guardar');
      await f.step(
        'Guardar una tasa de 0 no cierra el cuadro: debajo del campo dice '
        '«Escribe una tasa mayor que cero.».',
      );
      await f.check(
        'Guardar una tasa de 0 no cambia nada y dice qué falta',
        () {
          expect(own.rates.rate(Asset.usd, Asset.cop), trm);
          expect(_typedRate(own, Asset.usd), isFalse);
          expect(f.shows('Escribe una tasa mayor que cero.'), isTrue);
          expect(_field(f, '1 USD en').decoration!.suffixText, 'COP');
        },
      );
      await f.tap('Cancelar');
      await f.check('«Cancelar» cierra el cuadro y deja la TRM', () {
        expect(find.byType(AlertDialog), findsNothing);
        expect(own.rates.rate(Asset.usd, Asset.cop), trm);
        expect(_typedRate(own, Asset.usd), isFalse);
      });
      await f.tapContaining('1 USD =');
      await enterTextIn(f.tester, find.byType(TextField).last, '4100');
      await f.tap('Guardar');
      await f.step(
        'Con 4.100 guardado, la línea dice «Manual» y cuándo se escribió; '
        'para volver a la automática pide actualizar las tasas, porque hoy '
        'aún no se han traído.',
      );
      final Money at4100 = _pesos('${(held * Decimal.fromInt(4100)).round()}');
      await f.check(
        'La cuenta en dólares vale ${_cop(at4100)} con la tasa escrita',
        () {
          expect(own.rates.rate(Asset.usd, Asset.cop), Decimal.fromInt(4100));
          expect(_typedRate(own, Asset.usd), isTrue);
          expect(own.partOfTotal(usd), at4100);
          expect(f.screenText, contains('1 tasa escrita a mano'));
        },
      );
      await f.check(
        'Sin la automática de hoy no ofrece volver a ella: dice cómo traerla',
        () {
          expect(
            f.shows('Para volver a la automática, actualiza las tasas.'),
            isTrue,
          );
          expect(f.shows('Usar la automática'), isFalse);
        },
      );
      await f.tapTip('Actualizar tasas');
      await f.step(
        '«Actualizar tasas», con sus flechas en círculo, trae las '
        'automáticas, pero la escrita a mano se queda; ahora se ve debajo la '
        'automática de hoy y «Usar la automática».',
      );
      await f.check('Actualizar no reemplaza la tasa escrita', () {
        expect(own.rates.rate(Asset.usd, Asset.cop), Decimal.fromInt(4100));
        expect(f.screenText, contains('La automática hoy: \$4.000'));
        expect(f.shows('Usar la automática'), isTrue);
      });
      final Decimal bitcoin = own.rates.rate(Asset.btc, Asset.usdt)!;
      await f.tap('Usar la automática');
      await f.step(
        '«Usar la automática» vuelve a la TRM de hoy, la que decía debajo: '
        'se va «Manual» y la línea dice de nuevo de dónde viene la tasa.',
      );
      final Money at4000 = _pesos('${(held * Decimal.fromInt(4000)).round()}');
      await f.check(
        'Con la TRM automática de \$4.000 la cuenta vale ${_cop(at4000)}',
        () {
          expect(own.rates.rate(Asset.usd, Asset.cop), Decimal.fromInt(4000));
          expect(_typedRate(own, Asset.usd), isFalse);
          expect(own.partOfTotal(usd), at4000);
        },
      );
      await f.check('Volver a la TRM no cambió el precio del bitcoin', () {
        expect(own.rates.rate(Asset.btc, Asset.usdt), bitcoin);
      });
      await f.back();
      await f.reveal(find.text('Cuenta en dólares'));
      await f.step(
        'En Cuentas, la cuenta en dólares ya se pasa a pesos con la TRM '
        'nueva.',
      );
      await f.check(
        'La fila muestra ≈ ${_cop(at4000)}',
        () => expect(f.shows('≈ ${_cop(at4000)}'), isTrue),
      );
    },
  ),
  AppFlow(
    '04-15-tasa-sin-conexion',
    'Poner una tasa que la app no consigue',
    area: 'Cuentas',
    goal:
        'Tengo euros y la app no trae su tasa; quiero escribirla yo y que '
        'no se pierda si no hay conexión.',
    data: fullAccount,
    (FlowRun f) async {
      final OwnController own = f.own;
      final Money worth = own.netWorth().total;
      await f.tap('Cuentas');
      await f.tap('Agregar cuenta');
      await f.type('Nombre', 'Cuenta en euros');
      await f.tapFound(find.byType(DropdownButtonFormField<String>));
      await f.tap('EUR · Euro');
      await f.type('¿Cuánto tiene hoy?', '300');
      await f.tapFound(find.byType(SwitchListTile));
      await f.tap('Guardar');
      await f.reveal(find.text('Ver tasas usadas'));
      await f.step(
        'Sin tasa para el euro, la cuenta no muestra cuánto es en pesos y '
        '«Ver tasas usadas» avisa que cuenta como cero.',
      );
      await f.check('Sin tasa, los €300 no suman al patrimonio', () {
        expect(own.partOfTotal(_named(own, 'Cuenta en euros')), isNull);
        expect(own.netWorth().total, worth);
        expect(f.screenText, contains('Sin tasa para EUR'));
      });
      await f.tapFound(find.text('¿De dónde sale?').first);
      await f.reveal(find.textContaining('Sin tasa todavía'));
      await f.step(
        'El «¿De dónde sale?» del patrimonio también lo dice, al final: la '
        'Cuenta en euros no suma porque no tiene tasa todavía.',
      );
      await f.check('El detalle nombra la cuenta que no suma', () {
        expect(f.shows('Sin tasa todavía, no suman: Cuenta en euros.'), isTrue);
      });
      await f.back();
      await f.tap('Ver tasas usadas');
      await f.tapContaining('Sin tasa para EUR');
      await f.step(
        'En las tasas, tocar la línea del euro abre «Escribir una tasa» con '
        'el campo vacío.',
      );
      await enterTextIn(f.tester, find.byType(TextField).last, '4350');
      await f.tap('Guardar');
      await f.step(
        'Con 4.350 guardado, el euro tiene tasa, marcada «Manual»; para '
        'volver a la automática, la línea pide actualizar las tasas.',
      );
      final Money euros = _pesos('1305000');
      await f.check(
        'Los €300 a \$4.350 suman ${_cop(euros)} al patrimonio',
        () {
          expect(own.partOfTotal(_named(own, 'Cuenta en euros')), euros);
          expect(own.netWorth().total, worth + euros);
        },
      );
      await f.tapContaining('1 EUR =');
      await f.step(
        'El cuadro del euro no ofrece «Volver a la tasa automática»: no hay '
        'una automática de hoy a la cual volver.',
      );
      await f.check('Sin automática, el cuadro solo deja cambiar la tuya', () {
        expect(f.shows('Volver a la tasa automática'), isFalse);
        expect(f.shows('Cancelar'), isTrue);
      });
      await f.tap('Cancelar');
      await f.tapTip('Actualizar tasas');
      await f.step(
        '«Actualizar tasas» tampoco consigue la del euro: la línea dice que '
        'hoy no hay tasa automática para EUR y que se usa la tuya.',
      );
      await f.check('La tasa escrita de \$4.350 sigue en uso', () {
        expect(own.rates.rate(Asset.eur, Asset.cop), Decimal.fromInt(4350));
        expect(_typedRate(own, Asset.eur), isTrue);
        expect(
          f.shows('Hoy no hay tasa automática para EUR: se usa la tuya.'),
          isTrue,
        );
        expect(f.shows('Usar la automática'), isFalse);
      });
    },
    manual: <String>[
      'En modo avión, «Actualizar tasas» con un dólar escrito a mano: la '
          'tasa escrita debe quedarse y no ofrecer «Usar la automática».',
    ],
  ),
  AppFlow(
    '04-16-pagar-la-tarjeta',
    'Pagar la tarjeta completa',
    area: 'Cuentas',
    goal:
        'Pagué todo lo que debía de la Visa desde Bancolombia y quiero que la '
        'tarjeta quede al día.',
    data: fullAccount,
    (FlowRun f) async {
      final OwnController own = f.own;
      final Account visa = _named(own, 'Visa');
      final Account bank = _named(own, 'Bancolombia');
      final Money owed = -_balance(own, visa);
      final Money bankBefore = _balance(own, bank);
      final Money worth = own.netWorth().total;
      final int free = own.ledger!.freeUntilPayday;
      await f.tap('Cuentas');
      await f.tap('Visa');
      await f.tapTip('Agregar movimiento');
      await f.tap('Transferencia');
      await f.step(
        'En la Visa, «+» y «Transferencia»: «Desde» y «Hacia» son tus '
        'cuentas; hay que decir de cuál salió la plata y a cuál llegó.',
      );
      await _pickAccount(f, 0, 'Bancolombia');
      await _pickAccount(f, 1, 'Visa');
      await f.type('Monto', _plain(owed));
      await f.step(
        'Desde Bancolombia hacia la Visa, por ${_cop(owed)}: todo lo que '
        'debías en ella.',
      );
      await f.tap('Guardar');
      await f.top();
      await f.step(
        'Al guardar, la Visa dice «Al día» y el cupo libre vuelve a ser todo '
        'el cupo, \$3.000.000.',
      );
      await f.check('La Visa quedó en cero, «Al día», con todo el cupo', () {
        expect(_balance(own, visa).isZero, isTrue);
        expect(f.shows('Al día'), isTrue);
        expect(f.screenText, contains('Cupo libre \$3.000.000 de \$3.000.000'));
      });
      final Money bankNow = bankBefore - owed;
      await f.check(
        'Bancolombia pasó de ${_cop(bankBefore)} a ${_cop(bankNow)}',
        () => expect(_balance(own, bank), bankNow),
      );
      await f.check(
        'El patrimonio sigue en ${_cop(worth)}: la plata pasó entre tus '
        'cuentas',
        () => expect(own.netWorth().total, worth),
      );
      await f.check(
        'Lo que puedes gastar sigue en ${pesos(own.ledger!.major(free))}: '
        'esa deuda ya se restaba',
        () => expect(own.ledger!.freeUntilPayday, free),
      );
      await f.tapFound(find.text('¿De dónde sale?').first);
      await f.step(
        '«¿De dónde sale?» suma el pago como una transferencia que entró y '
        'termina en «Al día».',
      );
      await f.check('El pago es una transferencia que entró a la Visa', () {
        expect(f.shows('Una transferencia que entró'), isTrue);
        expect(f.shows(_signed(owed)), isTrue);
      });
      await f.back();
      await f.back();
      await f.top();
      await f.step(
        'En Cuentas, la Visa dice «Al día» y ya no está la línea «Lo que '
        'debes en tarjetas».',
      );
      await f.check('Ya no hay deuda de tarjetas que reste', () {
        expect(own.spendableCardDebt, 0);
        expect(f.shows('Lo que debes en tarjetas'), isFalse);
      });
      await f.tap('Inicio');
      await f.step(
        'En Inicio, «Puedes gastar» sigue igual: la deuda de la Visa ya se '
        'restaba, y ahora salió de Bancolombia.',
      );
      await f.check('Inicio ya no muestra deuda de tarjetas', () {
        expect(f.shows('Lo que debes en tarjetas'), isFalse);
        expect(own.ledger!.freeUntilPayday, free);
      });
    },
  ),
  AppFlow(
    '04-17-tarjeta-con-saldo-a-favor',
    'Una tarjeta con saldo a favor',
    area: 'Cuentas',
    goal:
        'Le pagué de más a la Visa y quiero ver ese saldo a mi favor, y que '
        'no se pierda cuando le cambie el cupo.',
    data: fullAccount,
    (FlowRun f) async {
      final OwnController own = f.own;
      final Account visa = _named(own, 'Visa');
      final Money owed = -_balance(own, visa);
      final Money paid = _pesos('900000');
      final Money favor = paid - owed;
      await f.tap('Cuentas');
      await f.tap('Visa');
      await f.tapTip('Agregar movimiento');
      await f.tap('Transferencia');
      await _pickAccount(f, 0, 'Bancolombia');
      await _pickAccount(f, 1, 'Visa');
      await f.type('Monto', '900000');
      await f.tap('Guardar');
      await f.top();
      await f.step(
        'Con un pago de \$900.000, más de lo que debías, la Visa dice «A '
        'favor» ${_cop(favor)}.',
      );
      await f.check('La Visa tiene ${_cop(favor)} a favor', () {
        expect(_balance(own, visa), favor);
        expect(f.shows('A favor'), isTrue);
        expect(f.shows(_cop(favor)), isTrue);
      });
      await f.tapTip('Editar cuenta');
      await f.reveal(find.text('Cupo total (opcional)'));
      await f.step(
        'En «Editar cuenta», arriba del saldo está elegido «A favor», y '
        '«¿Cuánto tienes a favor hoy?» trae ${_plain(favor)}, sin signo.',
      );
      await f.check('El saldo a favor viene elegido y sin signo menos', () {
        expect(
          f.tester
              .widget<SegmentedButton<bool>>(find.byType(SegmentedButton<bool>))
              .selected,
          <bool>{true},
        );
        expect(_fieldText(f, '¿Cuánto tienes a favor hoy?'), _plain(favor));
      });
      // The amount corrected: it used to lose its sign and become a debt.
      final Money corrected = favor + _pesos('10000');
      await f.type('¿Cuánto tienes a favor hoy?', _plain(corrected));
      await f.type('Cupo total (opcional)', '3500000');
      await f.tap('Guardar');
      await f.step(
        'Corregido el saldo a ${_cop(corrected)} y con el cupo nuevo de '
        '\$3.500.000, la Visa sigue «A favor».',
      );
      await f.check(
        'Corregir el monto y el cupo no vuelve deuda el saldo a favor: queda '
        'en ${_cop(corrected)}',
        () {
          expect(_account(own, visa.id).creditLimit, Decimal.parse('3500000'));
          expect(_balance(own, visa), corrected);
          expect(f.shows('A favor'), isTrue);
        },
      );
      await f.back();
      await f.reveal(find.text('Visa'));
      await f.step(
        'En «Tarjetas de crédito», la fila de la Visa también dice «A favor».',
      );
      await f.check('La fila dice «A favor» y no «Debes»', () {
        expect(_rowOf(f, 'Visa'), _cop(_balance(own, visa)));
        expect(f.shows('A favor'), isTrue);
      });
    },
  ),
  AppFlow(
    '04-18-gasto-con-fecha-futura',
    'Anotar un pago que todavía no sale',
    area: 'Cuentas',
    goal:
        'La administración sale de Bancolombia el 10 y quiero anotarla ya, '
        'sin que me baje el saldo de hoy.',
    data: fullAccount,
    (FlowRun f) async {
      final OwnController own = f.own;
      final Account bank = _named(own, 'Bancolombia');
      final Money before = _balance(own, bank);
      await f.tap('Cuentas');
      await f.tap('Banco · Bancolombia');
      await f.tapTip('Agregar movimiento');
      await f.type('Monto', '280000');
      await f.tap('Servicios');
      await f.type('¿Dónde o a quién?', 'Administración');
      await f.tapFound(find.text('Hoy').last);
      await f.tap('10');
      await f.step(
        'En «Fecha» se elige el 10 de octubre, más adelante que hoy.',
      );
      await f.tap('Aceptar');
      await f.tap('Guardar');
      await f.top();
      await f.step(
        'Al guardar, la administración aparece arriba con su fecha, pero el '
        '«Saldo hoy» sigue igual.',
      );
      await f.check('El gasto quedó anotado el 10 de octubre', () {
        final Entry e = own.snapshot!.entries.firstWhere(
          (Entry e) => e.payee == 'Administración',
        );
        expect(e.accountId, bank.id);
        expect(e.amount, Decimal.parse('-280000'));
        expect(
          DateTime(e.date.year, e.date.month, e.date.day),
          DateTime(2026, 10, 10),
        );
      });
      await f.check('El saldo de hoy sigue en ${_cop(before)}', () {
        expect(_balance(own, bank), before);
        expect(f.shows(_cop(before)), isTrue);
      });
      await f.tapFound(find.text('¿De dónde sale?').first);
      await f.step(
        'Abajo, «¿De dónde sale?» avisa que un movimiento con fecha más '
        'adelante todavía no cuenta en el saldo.',
      );
      await f.check('El aviso dice cuánto no cuenta todavía', () {
        expect(
          _said(f),
          contains(
            'Un movimiento con fecha más adelante '
            '(${_plainSigned(_pesos('-280000'))}) todavía no cuenta.',
          ),
        );
      });
      await f.back();
    },
  ),
  AppFlow(
    '04-19-escribir-el-precio-del-bitcoin',
    'Usar mi propio precio del bitcoin',
    area: 'Cuentas',
    goal:
        'Por P2P me pagan el bitcoin a US\$90.000 y quiero ver mis totales con '
        'ese precio, no con el de Binance.',
    data: fullAccount,
    (FlowRun f) async {
      final OwnController own = f.own;
      final Account bitcoin = _named(own, 'Bitcoin');
      final Decimal trm = own.rates.rate(Asset.usd, Asset.cop)!;
      await f.tap('Cuentas');
      await f.tap('Ver tasas usadas');
      await f.tapContaining('1 BTC =');
      await f.step(
        'Tocar la línea del bitcoin abre «Escribir una tasa» en dólares: '
        'cuánto vale 1 BTC en USD, con el precio de hoy.',
      );
      await enterTextIn(f.tester, find.byType(TextField).last, '90000');
      await f.tap('Guardar');
      await f.step(
        'Con US\$90.000 guardado, la línea del bitcoin dice «Manual» y se '
        'pasa a pesos con la TRM.',
      );
      final Money mine = _pesos(
        '${(bitcoin.opening * Decimal.fromInt(90000) * trm).round()}',
      );
      await f.check('El bitcoin vale ${_cop(mine)} con el precio escrito', () {
        expect(own.rates.rate(Asset.btc, Asset.usd), Decimal.fromInt(90000));
        expect(own.partOfTotal(bitcoin), mine);
        expect(_said(f), contains('escrita a mano'));
      });
      await f.back();
      await f.reveal(find.text('Rendimiento y ganancia'));
      await f.step(
        'En Cuentas, la fila de Bitcoin y el total de Cripto ya usan tu '
        'precio.',
      );
      var coins = Money.zero(Asset.cop);
      for (final Account a in own.accounts) {
        if (a.asset.isCrypto) coins += own.partOfTotal(a)!;
      }
      await f.check(
        'La fila dice ≈ ${_cop(mine)} y Cripto suma ${_cop(coins)}',
        () {
          expect(f.shows('≈ ${_cop(mine)}'), isTrue);
          expect(_sectionTotal(f, 'CRIPTO'), _cop(coins));
        },
      );
      await f.tap('Rendimiento y ganancia');
      await f.step(
        'En la página de cripto, «Tu cripto vale» debería decir lo mismo que '
        'el total de Cripto en Cuentas.',
      );
      await f.check(
        '«Tu cripto vale» es ${_cop(coins)}, el mismo total de Cuentas',
        () => expect(_headline(f), _cop(coins)),
      );
      await f.back();
      await f.tap('Ver tasas usadas');
      await f.reveal(find.textContaining('1 BTC ='));
      await f.step(
        'Con un precio escrito, la línea del bitcoin dice «Manual» y, como '
        'hoy aún no se traen las tasas, que para volver a la automática hay '
        'que actualizarlas.',
      );
      await f.check('Sin la automática de hoy, no ofrece volver a ella', () {
        expect(
          f.shows('Para volver a la automática, actualiza las tasas.'),
          isTrue,
        );
        expect(f.shows('Usar la automática'), isFalse);
      });
      await f.tapTip('Actualizar tasas');
      await f.step(
        '«Actualizar tasas» trae el dólar y los precios de hoy; tu precio del '
        'bitcoin se queda, y debajo sale el de Binance con «Usar la '
        'automática».',
      );
      await f.check('Debajo del precio escrito sale el de Binance de hoy', () {
        expect(f.shows('La automática hoy: US\$80.000'), isTrue);
        expect(own.rates.rate(Asset.btc, Asset.usd), Decimal.fromInt(90000));
      });
      final Decimal dollarBefore = own.rates.rate(Asset.usd, Asset.cop)!;
      await f.tapContaining('1 BTC =');
      await f.step(
        'Con la automática de hoy a la mano, el cuadro del bitcoin ofrece '
        'también «Volver a la tasa automática».',
      );
      await f.tap('Volver a la tasa automática');
      await f.step(
        '«Volver a la tasa automática» deja el bitcoin en el precio de '
        'Binance de hoy y se va «Manual»; el dólar no cambia.',
      );
      await f.check('Volver al precio del bitcoin no movió el dólar', () {
        expect(own.rates.rate(Asset.usd, Asset.cop), dollarBefore);
      });
      await f.check(
        'El bitcoin vuelve al precio de Binance, 80.000 USDT, y vale eso en '
        'pesos',
        () {
          expect(_typedRate(own, Asset.btc), isFalse);
          expect(own.rates.rate(Asset.btc, Asset.usdt), Decimal.fromInt(80000));
          final Decimal dollar = own.rates.rate(Asset.usd, Asset.cop)!;
          expect(
            own.partOfTotal(bitcoin)!.amount,
            (bitcoin.opening * Decimal.fromInt(80000) * dollar).round(),
          );
          expect(f.shows('Manual'), isFalse);
          expect(f.screenText, isNot(contains('1 tasa escrita a mano')));
        },
      );
    },
  ),
  AppFlow(
    '04-20-cuentas-en-ingles',
    'Ver mis cuentas con la app en inglés',
    area: 'Cuentas',
    english: true,
    goal:
        'Tengo el teléfono en inglés y quiero entender mis cuentas, la '
        'tarjeta y la cripto sin que nada quede en español.',
    data: fullAccount,
    (FlowRun f) async {
      final OwnController own = f.own;
      final Account visa = _named(own, 'Visa');
      await f.tap('Accounts');
      await f.page(
        'En inglés, «Accounts» arriba dice «Net worth» y agrupa las cuentas '
        'en «Everyday accounts», «Credit cards», «Savings and investments» y '
        '«Crypto».',
      );
      await f.check('El patrimonio se lee en inglés, con coma de miles', () {
        final String worth = _cop(own.netWorth().total);
        expect(f.shows('Net worth'), isTrue);
        expect(_headline(f), worth);
        expect(worth, contains(','));
        expect(_rowOf(f, 'In your everyday accounts'), _cop(_everyday(own)));
      });
      await f.reveal(find.text('See the rates used'));
      await f.check('Nada de Cuentas quedó en español', () {
        _expectEnglish(f);
        expect(f.shows('EVERYDAY ACCOUNTS'), isTrue);
        expect(f.shows('CREDIT CARDS'), isTrue);
        expect(f.shows('Performance and gains'), isTrue);
      });
      await f.tap('Visa');
      final Money owed = -_balance(own, visa);
      final Money left = visa.creditLeft(_balance(own, visa))!;
      await f.step(
        'La Visa en inglés: «You owe» arriba y «… of … credit left» debajo, '
        'los montos con coma de miles.',
      );
      await f.check(
        'La Visa dice «You owe ${_cop(owed)}» y lo que queda del cupo',
        () {
          expect(f.shows('You owe'), isTrue);
          expect(_headline(f), _cop(owed));
          expect(
            f.screenText,
            contains(
              '${_cop(left)} of '
              '${_cop(Money(visa.creditLimit!, Asset.cop))} credit left',
            ),
          );
          _expectEnglish(f);
        },
      );
      await f.tapFound(find.text('Where does it come from?').first);
      await f.step(
        '«Where does it come from?» abre «How the balance adds up», que '
        'termina en «You owe».',
      );
      await f.check('El detalle de la tarjeta está en inglés', () {
        expect(f.shows('How the balance adds up'), isTrue);
        expect(f.shows('What it started with'), isTrue);
        _expectEnglish(f);
      });
      await f.back();
      await f.back();
      await f.tap('Performance and gains');
      await f.page(
        'La página de cripto en inglés: «Your crypto is worth», «Unrealized '
        'gain», la gráfica y «Manage sources».',
      );
      await f.check('La cripto se lee en inglés', () {
        expect(f.shows('Your crypto is worth'), isTrue);
        expect(f.shows('Unrealized gain'), isTrue);
        _expectEnglish(f);
      });
      await f.back();
      await f.tap('See the rates used');
      await f.step(
        '«Rates» explica en inglés cómo se pasa cada moneda a pesos y de '
        'dónde sale cada tasa.',
      );
      await f.check('Las tasas se leen en inglés, con punto decimal', () {
        final Decimal trm = own.rates.rate(Asset.usd, Asset.cop)!;
        expect(trm, Decimal.parse('3312.84'));
        expect(f.screenText, contains('1 USD = \$3,312.84'));
        _expectEnglish(f);
      });
    },
  ),
  AppFlow(
    '04-21-lo-que-me-deben-y-las-cuotas',
    'Ver lo que me deben y las cuotas en el patrimonio',
    area: 'Cuentas',
    goal:
        'Le presté a Laura para el arriendo de la finca y compré una nevera a '
        'cuotas; quiero ver cómo entran las dos cosas en mi patrimonio.',
    data: _owedAndInstalments,
    (FlowRun f) async {
      final OwnController own = f.own;
      final NetWorth worth = own.netWorth();
      await f.tap('Cuentas');
      await f.step(
        'En Cuentas, bajo el «Patrimonio», están «Te deben» y «Compras a '
        'cuotas» con sus montos: el préstamo a Laura y la nevera cuentan '
        'aunque ninguno de los dos es una cuenta, y se ven sin abrir nada.',
      );
      await f.check(
        'Bajo el patrimonio se ven «Te deben» (${_cop(worth.owed)}) y '
        '«Compras a cuotas» (${_cop(-worth.instalments)})',
        () {
          expect(_rowOf(f, 'Te deben'), _cop(worth.owed));
          expect(_rowOf(f, 'Compras a cuotas'), _cop(-worth.instalments));
        },
      );
      await f.check(
        'El patrimonio, ${_cop(worth.total)}, suma lo que te deben y resta '
        'lo que debes fuera de las cuentas',
        () {
          expect(_headline(f), _cop(worth.total));
          expect(worth.owed, _pesos('150000'));
          expect(
            worth.total,
            worth.accounts + worth.owed - worth.owing - worth.instalments,
          );
        },
      );
      await f.tapFound(find.text('¿De dónde sale?').first);
      await f.page(
        '«¿De dónde sale?»: en «Lo que tienes» entran los \$150.000 que te '
        'deben; en «Lo que debes», lo que les debes a otros y las cuotas, '
        'marcadas «estimado».',
      );
      await f.check('«Te deben» dice ${_cop(worth.owed)}', () {
        expect(_rowOf(f, 'Te deben'), _cop(worth.owed));
      });
      await f.check(
        '«Les debes a otras personas» dice ${_cop(-worth.owing)}',
        () =>
            expect(_rowOf(f, 'Les debes a otras personas'), _cop(-worth.owing)),
      );
      await f.check(
        'Las cuotas restan ${_cop(worth.instalments)} y dicen que es un '
        'estimado: la nevera no tiene tasa ni cuota',
        () {
          expect(worth.estimated, isTrue);
          expect(_rowOf(f, 'Compras a cuotas'), _cop(-worth.instalments));
          expect(
            f.screenText,
            contains('Lo que falta pagar, fuera de tus tarjetas · estimado'),
          );
        },
      );
      await f.check(
        'Lo que tienes, con lo que te deben, y el patrimonio cierran en '
        '${_cop(worth.total)}',
        () {
          var have = worth.owed;
          for (final Account a in own.accounts) {
            final Money part = own.partOfTotal(a)!;
            if (!part.isNegative) have += part;
          }
          final String said = f.screenText;
          expect(said, contains(_cop(have)));
          expect(said, contains(_cop(worth.total)));
          expect(own.netWorth().total, worth.total);
        },
      );
      await f.back();
      await f.step(
        'Al cerrar el detalle, el «Patrimonio» de arriba es el mismo con el '
        'que cerró el detalle.',
      );
      await f.check(
        'El patrimonio de arriba no cambió al mirar el detalle',
        () {
          expect(_headline(f), _cop(worth.total));
        },
      );
    },
  ),
  AppFlow(
    '04-22-eliminar-la-tarjeta-cancelada',
    'Eliminar una tarjeta que cancelé',
    area: 'Cuentas',
    goal:
        'Pagué la Visa y la cancelé; quiero quitarla de la app sin que se me '
        'olvide que Netflix, que se cobraba ahí, se sigue pagando.',
    data: fullAccount,
    (FlowRun f) async {
      final OwnController own = f.own;
      final Account visa = _named(own, 'Visa');
      final Account bank = _named(own, 'Bancolombia');
      final Money owed = -_balance(own, visa);
      await f.tap('Cuentas');
      await f.tap('Visa');
      await f.tapTip('Agregar movimiento');
      await f.tap('Transferencia');
      await _pickAccount(f, 0, 'Bancolombia');
      await _pickAccount(f, 1, 'Visa');
      await f.type('Monto', _plain(owed));
      await f.tap('Guardar');
      await f.top();
      await f.step(
        'Primero se paga: con la transferencia de ${_cop(owed)} desde '
        'Bancolombia, la Visa queda «Al día».',
      );
      final Money bankPaid = _balance(own, bank);
      final Money worth = own.netWorth().total;
      final int free = own.ledger!.freeUntilPayday;
      final int inVisa = own.snapshot!.entries
          .where((Entry e) => e.accountId == visa.id)
          .length;
      await f.check('La Visa está al día antes de eliminarla', () {
        expect(_balance(own, visa).isZero, isTrue);
        expect(own.spendableCardDebt, 0);
      });
      final Money celular = _pesos('1290000');
      final Money instalments = own.netWorth().instalments;
      // On the Visa, the phone was counted the day it was bought.
      final List<Object> comingPhone = <Object>[
        ...own.ledger!.upcoming.where((m) => m.merchant == 'Celular'),
      ];
      await f.tapTip('Editar cuenta');
      await f.tap('Eliminar');
      await f.page(
        '«Eliminar» avisa que se borran sus $inVisa movimientos, que el pago '
        'se queda en Bancolombia como gasto, que Netflix y las cuotas del '
        'Celular se pagan desde esta tarjeta y con qué cuenta se pagarán, y '
        'cuánto baja el patrimonio y por qué.',
      );
      await f.check('El aviso cuenta los $inVisa movimientos de la Visa', () {
        expect(
          f.screenText,
          contains('Se borran también sus $inVisa movimientos.'),
        );
      });
      await f.check(
        'Dice que el pago desde Bancolombia se queda allá como gasto',
        () => expect(
          _said(f),
          contains(
            'Una transferencia con otra cuenta se queda en esa cuenta como '
            'ingreso o gasto.',
          ),
        ),
      );
      await f.check('Dice que Netflix y el Celular se pagan con la Visa', () {
        expect(_said(f), contains('Netflix y Celular se pagan desde aquí.'));
        expect(f.shows('Se pagarán con'), isTrue);
        expect(f.shows('Sin cuenta'), isTrue);
      });
      await f.check(
        'Explica que el patrimonio baja ${_cop(celular)}: las cuotas que '
        'faltan del Celular iban en la deuda de la tarjeta',
        () {
          expect(
            _said(f),
            contains(
              _plainText(
                'Lo que falta de las cuotas, ${_cop(celular)}, ya no queda en '
                'la deuda de una tarjeta',
              ),
            ),
          );
          expect(
            _said(f),
            contains(
              _plainText(
                'Tu patrimonio pasa de ${_cop(worth)} a '
                '${_cop(worth - celular)}.',
              ),
            ),
          );
        },
      );
      await f.tapFound(find.text('Sin cuenta'));
      await f.step(
        '«Se pagarán con» lista tus otras cuentas: Netflix y las cuotas se '
        'pueden pasar a una de ellas.',
      );
      await f.tap('Bancolombia');
      await f.tap('Eliminar');
      await f.top();
      await f.step(
        'Eliminada, vuelves a Cuentas: sin «Tarjetas de crédito», Bancolombia '
        'con el pago hecho y el «Patrimonio» con la baja que anunció el aviso.',
      );
      await f.check('La Visa y sus movimientos ya no están', () {
        expect(own.snapshot!.account(visa.id), isNull);
        expect(
          own.snapshot!.entries.where((Entry e) => e.accountId == visa.id),
          isEmpty,
        );
        expect(f.shows('TARJETAS DE CRÉDITO'), isFalse);
      });
      await f.check(
        'El pago queda en Bancolombia como un gasto de ${_cop(owed)}, y su '
        'saldo sigue en ${_cop(bankPaid)}',
        () {
          final Entry payment = own.snapshot!.entries.firstWhere(
            (Entry e) => e.accountId == bank.id && e.amount == -owed.amount,
          );
          expect(payment.transferId, isNull);
          expect(payment.kind, EntryKind.expense);
          expect(_balance(own, bank), bankPaid);
        },
      );
      await f.check(
        'Netflix y el Celular se pagan ahora con Bancolombia: ninguno quedó '
        'en una cuenta que ya no existe',
        () {
          final RecurringCharge netflix = own.recurring.firstWhere(
            (RecurringCharge r) => r.name == 'Netflix',
          );
          final Instalments phone = own.instalments.firstWhere(
            (Instalments p) => p.name == 'Celular',
          );
          expect(netflix.accountId, bank.id);
          expect(phone.accountId, bank.id);
        },
      );
      await f.check(
        'Fuera de una tarjeta, las cuotas que vienen del Celular cuentan como '
        'comprometidas: salen de Bancolombia, como el patrimonio las resta '
        'aparte',
        () {
          expect(comingPhone, isEmpty);
          expect(
            own.ledger!.upcoming.where((m) => m.merchant == 'Celular'),
            isNotEmpty,
          );
        },
      );
      await f.check(
        'Netflix sigue entre los pagos fijos y sigue restando de lo que '
        'puedes gastar: ${pesos(own.ledger!.major(free))}',
        () {
          final RecurringCharge netflix = own.recurring.firstWhere(
            (RecurringCharge r) => r.name == 'Netflix',
          );
          expect(netflix.active, isTrue);
          expect(own.ledger!.freeUntilPayday, free);
        },
      );
      await f.check(
        'El patrimonio pasó de ${_cop(worth)} a ${_cop(worth - celular)}, '
        'como dijo el aviso: las 6 cuotas de \$215.000 del celular siguen '
        'debiéndose',
        () {
          expect(own.netWorth().total, worth - celular);
          expect(_headline(f), _cop(worth - celular));
        },
      );
      await f.tapFound(find.text('¿De dónde sale?').first);
      await f.step(
        '«¿De dónde sale?» del patrimonio muestra las cuotas del Celular '
        'aparte, en «Compras a cuotas».',
      );
      await f.check('«Compras a cuotas» pasó de ${_cop(-instalments)} a '
          '${_cop(-(instalments + celular))}, con el Celular', () {
        expect(own.netWorth().instalments, instalments + celular);
        expect(f.screenText, contains('Compras a cuotas'));
        expect(f.screenText, contains(_cop(-(instalments + celular))));
      });
      await f.back();
    },
  ),
  AppFlow(
    '04-23-archivar-y-restaurar-una-cuenta',
    'Archivar una cuenta cerrada y traerla de vuelta',
    area: 'Cuentas',
    goal:
        'Cerré Nequi pero quiero guardar sus movimientos, sin que cuente en '
        'mis totales ni me aparezca al anotar; y poder traerla si la vuelvo '
        'a abrir.',
    data: fullAccount,
    (FlowRun f) async {
      final OwnController own = f.own;
      final Account nequi = _named(own, 'Nequi');
      final Money held = own.partOfTotal(nequi)!;
      final Money worth = own.netWorth().total;
      final Money everyday = _everyday(own);
      final int free = own.ledger!.freeUntilPayday;
      final int entries = own.snapshot!.entries.length;
      final int inNequi = own.snapshot!.entries
          .where((Entry e) => e.accountId == nequi.id)
          .length;
      await f.tap('Cuentas');
      await f.tap('Billetera digital · Nequi');
      await f.tapTip('Editar cuenta');
      await f.reveal(find.text('Archivar'));
      await f.step(
        'Al final de «Editar cuenta», encima de «Eliminar», está «Archivar».',
      );
      await f.tap('Archivar');
      await f.step(
        '«Archivar» pregunta antes: sus movimientos se quedan, deja de '
        'aparecer en Cuentas y al elegir una cuenta, se restaura desde '
        '«Cuentas archivadas», y lo que tiene Nequi deja de contar en el '
        'patrimonio y en lo que puedes gastar.',
      );
      await f.check(
        'El aviso dice que sus $inNequi movimientos se quedan y dónde '
        'restaurarla',
        () {
          expect(
            _said(f),
            contains('Sus $inNequi movimientos se quedan en tu historial.'),
          );
          expect(_said(f), contains('«Cuentas archivadas»'));
        },
      );
      await f.check('Dice que el patrimonio pasa de ${_cop(worth)} a '
          '${_cop(worth - held)}, por lo que tiene Nequi', () {
        expect(
          _said(f),
          contains(
            _plainText(
              'Lo que tiene, ${_cop(held)}, deja de contar en tu '
              'patrimonio y en lo que puedes gastar hasta el pago.',
            ),
          ),
        );
        expect(
          _said(f),
          contains(
            _plainText(
              'Tu patrimonio pasa de ${_cop(worth)} a ${_cop(worth - held)}.',
            ),
          ),
        );
      });
      await f.tapFound(
        find.descendant(
          of: find.byType(AlertDialog),
          matching: find.text('Archivar'),
        ),
      );
      await f.top();
      await f.step(
        'Archivada, vuelves a Cuentas: Nequi ya no está entre las de uso '
        'diario, y abajo aparece «Cuentas archivadas».',
      );
      await f.check('Nequi quedó archivada, con sus $inNequi movimientos', () {
        expect(own.accounts.where((Account a) => a.id == nequi.id), isEmpty);
        expect(own.snapshot!.account(nequi.id)!.archived, isTrue);
        expect(own.snapshot!.entries.length, entries);
        expect(f.shows('Nequi'), isFalse);
      });
      await f.check(
        'El patrimonio es ${_cop(worth - held)} y «En tus cuentas de uso '
        'diario» ${_cop(everyday - held)}',
        () {
          expect(own.netWorth().total, worth - held);
          expect(_headline(f), _cop(worth - held));
          expect(
            _rowOf(f, 'En tus cuentas de uso diario'),
            _cop(everyday - held),
          );
        },
      );
      await f.check(
        'Lo que puedes gastar hasta el pago bajó ${_cop(held)}, lo que tiene '
        'Nequi, como dijo el aviso',
        () => expect(
          Decimal.parse(
            '${own.ledger!.major(free - own.ledger!.freeUntilPayday)}',
          ),
          held.amount,
        ),
      );
      await f.reveal(find.text('Cuentas archivadas'));
      await f.step(
        '«Cuentas archivadas» dice cuántas hay, fuera de tus totales.',
      );
      await f.check('La fila dice «Una cuenta, fuera de tus totales»', () {
        expect(f.shows('Una cuenta, fuera de tus totales'), isTrue);
      });
      await f.tap('Movimientos');
      await f.reveal(find.text('Crepes & Waffles'));
      await f.step(
        'En Movimientos sigue el historial de Nequi, como el Crepes & '
        'Waffles de hoy, que todavía dice «Nequi».',
      );
      await f.check('Los movimientos de Nequi siguen en el historial', () {
        expect(f.shows('Crepes & Waffles'), isTrue);
      });
      await f.top();
      await f.tapTip('Agregar movimiento');
      await f.tapFound(find.byType(DropdownButtonFormField<String>).first);
      await f.step(
        'Al anotar un movimiento, la lista de cuentas ya no ofrece Nequi.',
      );
      await f.check('Nequi no está entre las cuentas para elegir', () {
        expect(f.shows('Bancolombia'), isTrue);
        expect(f.shows('Nequi'), isFalse);
      });
      await f.back();
      await f.back();
      await f.tap('Cuentas');
      await f.tap('Cuentas archivadas');
      await f.step(
        '«Cuentas archivadas» lista Nequi con lo que tiene y «Restaurar».',
      );
      await f.check('Nequi está en las archivadas', () {
        expect(f.shows('Nequi'), isTrue);
        expect(f.shows('Restaurar'), isTrue);
      });
      await f.tap('Nequi');
      await f.step(
        'Su página dice que está archivada, con «Restaurar», y guarda sus '
        'movimientos; no ofrece agregar uno nuevo.',
      );
      await f.check('La página de Nequi archivada no deja anotar en ella', () {
        expect(
          f.shows(
            'Archivada: no cuenta en tus totales ni aparece al elegir una '
            'cuenta.',
          ),
          isTrue,
        );
        expect(find.byTooltip('Agregar movimiento'), findsNothing);
        expect(f.shows('Crepes & Waffles'), isTrue);
      });
      await f.back();
      await f.tap('Restaurar');
      await f.step(
        'Con «Restaurar», Nequi sale de las archivadas: ya no queda ninguna.',
      );
      await f.check('Nequi volvió a tus cuentas', () {
        expect(
          own.accounts.where((Account a) => a.id == nequi.id),
          hasLength(1),
        );
        expect(f.shows('No tienes cuentas archivadas.'), isTrue);
      });
      await f.back();
      await f.top();
      await f.step(
        'De vuelta en Cuentas, Nequi está otra vez entre las de uso diario y '
        'el patrimonio vuelve a ${_cop(worth)}.',
      );
      await f.check(
        'El patrimonio y «En tus cuentas de uso diario» son los de antes',
        () {
          expect(own.netWorth().total, worth);
          expect(_headline(f), _cop(worth));
          expect(_rowOf(f, 'En tus cuentas de uso diario'), _cop(everyday));
          expect(f.shows('Cuentas archivadas'), isFalse);
        },
      );
    },
  ),
  AppFlow(
    '05-01-ver-rendimiento-y-ganancia',
    'Ver cuánto vale mi cripto y cuánto gano',
    area: 'Cripto',
    goal:
        'Quiero saber cuánto vale hoy mi cripto, cuánto se movió en el día y '
        'cuánto le gano frente a lo que pagué.',
    data: fullAccount,
    (FlowRun f) async {
      final OwnController own = f.own;
      await f.tap('Cuentas');
      await f.reveal(find.text('Rendimiento y ganancia'));
      await f.step(
        'En Cuentas, «Cripto» suma sus monedas y la última fila, «Rendimiento '
        'y ganancia», dice cuánto ganas en plata y en porcentaje.',
      );
      var coins = Money.zero(Asset.cop);
      for (final Account a in own.accounts) {
        if (a.asset.isCrypto) coins += own.partOfTotal(a)!;
      }
      await f.check(
        'El total de Cripto, ${_cop(coins)}, es la suma de sus filas',
        () => expect(_sectionTotal(f, 'CRIPTO'), _cop(coins)),
      );
      final Portfolio held = own.portfolio.portfolio!;
      final Money gained = Money(held.gain!.base, Asset.cop);
      await f.check(
        '«Rendimiento y ganancia» dice la ganancia en plata, '
        '${_signed(gained)}, y en porcentaje, ${percentText(held.gainRatio!)}',
        () => expect(
          _said(f),
          contains(
            _plainText(
              'Ganancia no realizada ${_signed(gained)} · '
              '${percentText(held.gainRatio!)}',
            ),
          ),
        ),
      );
      await f.tap('Rendimiento y ganancia');
      await f.page(
        'La página de cripto: lo que vale, lo que se movió en 24 horas, la '
        'ganancia, la gráfica, cada moneda y de dónde sale su saldo.',
      );
      final Portfolio p = own.portfolio.portfolio!;
      await f.check(
        '«Tu cripto vale» dice ${_cop(coins)}, lo mismo que el total de '
        'Cripto en Cuentas',
        () {
          expect(_headline(f), _cop(coins));
          // Each coin as its row shows it, added.
          var rows = Decimal.zero;
          for (final Holding h in p.priced) {
            rows += h.value!.base.round();
          }
          expect(rows, coins.amount);
        },
      );
      await f.check(
        'La ganancia de cada moneda es lo que vale menos lo que costó',
        () {
          for (final Holding h in p.priced) {
            expect(h.gain!.base, h.value!.base - h.position.cost.base);
          }
          expect(
            f.screenText,
            contains(_signed(Money(p.gain!.base, Asset.cop))),
          );
        },
      );
      await f.reveal(find.text('Bitcoin'));
      await f.check(
        'Bitcoin se movió +1,82 % en 24 horas, de 83.102,40 a 84.616,92 USDT, '
        'y su fila lo dice',
        () {
          final Holding btc = p.holdings.firstWhere(
            (Holding h) => h.asset == Asset.btc,
          );
          expect(btc.change24h, closeTo(84616.92 / 83102.40 - 1, 1e-9));
          expect(_said(f), contains('0,0123 BTC · +1,82 % 24 h'));
        },
      );
      await f.tap('Actualizar');
      await f.step(
        '«Actualizar», junto a la hora de los precios, los lee otra vez; '
        'también se puede arrastrar la página hacia abajo.',
      );
      await f.check('Los precios quedaron leídos y sin error', () {
        expect(own.portfolio.pricing, isFalse);
        expect(own.portfolio.pricingFailed, isFalse);
        expect(own.portfolio.pricedAt, isNotNull);
      });
      await f.top();
      await f.tester.fling(
        find.byType(ListView).last,
        const Offset(0, 400),
        1200,
      );
      await f.tester.pump();
      await f.tester.pump(const Duration(milliseconds: 100));
      await f.check('Arrastrar hacia abajo pone a leer los precios', () {
        expect(find.byType(RefreshProgressIndicator), findsOneWidget);
      });
      await f.step(
        'Arrastrar la página hacia abajo también lee los precios otra vez: '
        'al terminar, todo queda donde estaba.',
      );
      await f.check('Después de leerlos, los totales no cambian', () {
        expect(own.portfolio.pricingFailed, isFalse);
        expect(_headline(f), _cop(coins));
      });
    },
    manual: <String>[
      'En modo avión, «Actualizar» en la página de cripto: debe salir el '
          'aviso de que no se pudieron leer los precios y quedar los últimos.',
      'Con conexión, que los precios y la hora de «Precios de Binance» cambien '
          'al actualizar.',
    ],
  ),
  AppFlow(
    '05-02-explorar-la-grafica',
    'Explorar la gráfica de la cripto',
    area: 'Cripto',
    goal:
        'Quiero ver cómo le fue a mi cripto en el día, la semana, el mes y '
        'el año, y qué valía en un momento dado.',
    data: fullAccount,
    (FlowRun f) async {
      final OwnController own = f.own;
      await f.tap('Cuentas');
      await f.tap('Rendimiento y ganancia');
      await _showChart(f);
      await f.step(
        'La gráfica abre en «7 d» y en «Rendimiento»: solo lo que movieron '
        'los precios, desde cero; arriba, lo que se ganó en esos 7 días.',
      );
      for (final (String tab, ChartRange range, String long) in _ranges) {
        await f.tap(tab);
        await _showChart(f);
        await f.step(
          'En «$tab» la línea y la cifra de arriba cuentan lo que ganó o '
          'perdió la cripto $long.',
        );
        await f.check(
          'La cifra de arriba en «$tab» es lo que ganó la línea $long',
          () {
            final List<ValuePoint> points = own.portfolio.chart(range)!;
            expect(points.length, greaterThan(1));
            final Money made = Money(points.last.gain.base.round(), Asset.cop);
            expect(_said(f), contains('${_plainSigned(made)} ('));
            expect(f.screenText, contains(long));
          },
        );
      }
      await f.tap('7 d');
      await f.tap('Valor');
      await _showChart(f);
      await f.step(
        'Con «Valor», arriba dice lo que valía la cripto al empezar los 7 '
        'días y lo que vale ahora, y debajo lo que hizo el precio; la línea '
        'sube de golpe el 1 de octubre con la plata que entró, y la nota lo '
        'dice.',
      );
      await f.check('Con Valor la nota explica que cuenta las compras', () {
        expect(
          f.shows(
            'El valor con lo que tenías en cada momento: una compra lo sube '
            'de golpe.',
          ),
          isTrue,
        );
      });
      await f.check(
        'Arriba, de cuánto a cuánto fue el valor en los 7 días; debajo, lo '
        'ganado por precio, aparte de la plata que entró',
        () {
          final List<ValuePoint> points = own.portfolio.chart(ChartRange.week)!;
          final Portfolio p = own.portfolio.portfolio!;
          final Decimal end = p.unpriced.isEmpty
              ? p.value.base
              : points.last.value.base;
          final Money from = Money(points.first.value.base.round(), Asset.cop);
          final Money to = Money(end.round(), Asset.cop);
          final Money made = Money(points.last.gain.base.round(), Asset.cop);
          final String said = _said(f);
          expect(
            said,
            contains(
              '${_plainText(_cop(from))} → ${_plainText(_cop(to))} en 7 días',
            ),
          );
          expect(said, contains('Por el precio: ${_plainSigned(made)} ('));
          // The money that came in is the rest of the change.
          expect(
            (to.amount - from.amount - made.amount).abs(),
            greaterThan(Decimal.fromInt(1000)),
          );
        },
      );
      await f.tap('Rendimiento');
      await _showChart(f);
      final Rect chart = f.tester.getRect(find.byType(PortfolioChart));
      final TestGesture finger = await f.tester.startGesture(
        Offset(chart.left + chart.width * 0.5, chart.top + 80),
      );
      await f.tester.pump(const Duration(milliseconds: 200));
      await f.step(
        'Con el dedo sobre la línea, arriba sale la fecha y cuánto se había '
        'ganado hasta ese momento.',
      );
      await f.check('Arriba se lee un momento de la línea', () {
        expect(f.screenText, contains('desde el inicio'));
      });
      await finger.moveBy(Offset(-chart.width * 0.35, 0));
      await f.tester.pump(const Duration(milliseconds: 100));
      await f.step(
        'Al deslizar el dedo a la izquierda, la fecha y la cifra cambian al '
        'momento que toca.',
      );
      await finger.up();
      await f.step(
        'Al soltar vuelve la ganancia de la semana y se va la ayuda «Toca la '
        'línea…».',
      );
      await f.check('Al soltar se quita la ayuda y vuelve el resumen', () {
        expect(f.screenText, isNot(contains('desde el inicio')));
        expect(f.screenText, isNot(contains('Toca la línea')));
        expect(f.screenText, contains('en 7 días'));
      });
    },
  ),
  AppFlow(
    '05-03-ver-una-moneda',
    'Ver una moneda por dentro',
    area: 'Cripto',
    goal:
        'Quiero ver cuánto bitcoin tengo, a qué precio está, cuánto me costó '
        'y cuánto le gano.',
    data: fullAccount,
    (FlowRun f) async {
      final OwnController own = f.own;
      await f.tap('Cuentas');
      await f.tap('Rendimiento y ganancia');
      await f.tapFound(find.text('Bitcoin'));
      await f.page(
        'Tocar Bitcoin abre su cuenta: el saldo en BTC y en pesos, el '
        'precio, lo que vale, lo que costó y la ganancia.',
      );
      final Holding btc = own.portfolio.portfolio!.holdings.firstWhere(
        (Holding h) => h.asset == Asset.btc,
      );
      await f.check('Vale es la cantidad por el precio de hoy', () {
        final Decimal worth = btc.position.quantity * btc.price!.base;
        expect(btc.value!.base, worth);
        expect(f.screenText, contains(_cop(Money(worth, Asset.cop))));
      });
      await f.check(
        'Te costó \$3.000.000 y el costo promedio es eso entre 0,0123 BTC',
        () {
          expect(btc.position.cost.base, Decimal.parse('3000000'));
          expect(f.screenText, contains('\$3.000.000'));
          final Decimal average = btc.position.averageCost!.base;
          expect(
            (average * Decimal.parse('0.0123')).round(),
            Decimal.parse('3000000'),
          );
        },
      );
      await f.tapFound(find.text('¿De dónde sale?').first);
      await f.step(
        '«¿De dónde sale?» explica el saldo en BTC y cómo se pasa a pesos: '
        'precio de Binance, USDT como dólar y TRM.',
      );
      await f.back();
      await f.back();
      await f.tapFound(find.text('Tether (USDT)'));
      await f.step(
        'El USDT de Binance: su precio es un dólar, así que no cambia en 24 '
        'horas; la ganancia sale del dólar frente al peso.',
      );
      await f.check('USDT no muestra cambio de 24 horas', () {
        final Holding usdt = own.portfolio.portfolio!.holdings.firstWhere(
          (Holding h) => h.asset == Asset.usdt,
        );
        expect(usdt.pegged, isTrue);
        expect(f.screenText, isNot(contains('· 24 h')));
      });
      await f.check(
        'Te costó lo que empezó costando más los \$400.000 que llegaron de '
        'Bancolombia',
        () {
          final Holding usdt = _holding(own, Asset.usdt);
          expect(usdt.position.cost.base, Decimal.parse('5300000'));
          expect(f.shows('\$5.300.000'), isTrue);
        },
      );
      await f.tapFound(find.text('¿De dónde sale?').first);
      await f.step(
        'Su «¿De dónde sale?»: con lo que empezó más los 118,2 USDT de la '
        'compra pagada con pesos de Bancolombia.',
      );
      await f.check(
        'Los pesos de Bancolombia que compraron USDT cuentan como una compra, '
        'no como una transferencia',
        () {
          expect(f.shows('Una compra'), isTrue);
          expect(f.shows('Una transferencia que entró'), isFalse);
          expect(_said(f), contains('+118,2 USDT'));
        },
      );
      await f.back();
    },
  ),
  AppFlow(
    '05-04-registrar-una-compra',
    'Registrar una compra de bitcoin',
    area: 'Cripto',
    goal:
        'Ayer compré bitcoin por P2P y quiero anotarlo con lo que pagué para '
        'que la ganancia salga bien.',
    data: fullAccount,
    (FlowRun f) async {
      final OwnController own = f.own;
      final Account bitcoin = _named(own, 'Bitcoin');
      final Holding before = _holding(own, Asset.btc);
      await f.tap('Cuentas');
      await f.tap('Bitcoin');
      await f.tap('Compra');
      await f.step(
        '«Compra» abre «Registrar compra»: cantidad, de dónde salió la plata '
        '(por defecto «Fuera de Quincena»), el total y la fecha.',
      );
      await f.type('Cantidad de BTC', '0,5');
      await f.back();
      await f.check('Cerrar la hoja sin guardar no registra nada', () {
        expect(
          own.snapshot!.entries.where((Entry e) => e.accountId == bitcoin.id),
          isEmpty,
        );
        expect(_balance(own, bitcoin).amount, Decimal.parse('0.0123'));
      });
      await f.tap('Compra');
      await f.check('Al abrirla otra vez la cantidad está vacía', () {
        expect(_fieldText(f, 'Cantidad de BTC'), isEmpty);
      });
      await f.tap('Guardar');
      await f.step(
        'Guardar vacío no deja: la cantidad y el total piden «Escribe un '
        'monto».',
      );
      await f.check('Sin cantidad ni total no se registra nada', () {
        expect(_balance(own, bitcoin), before.position.account.openingMoney);
        expect(f.shows('Escribe un monto'), isTrue);
      });
      await f.type('Cantidad de BTC', '0,001');
      await f.tap('USD');
      await f.type('Total pagado', '90');
      await f.step(
        'Con «USD» elegido, el total va en dólares y la app calcula el precio '
        'por unidad: US\$90.000.',
      );
      await f.check(
        'Al escribir se van los «Escribe un monto» y sale el precio por unidad',
        () {
          expect(f.shows('Escribe un monto'), isFalse);
          expect(f.shows('Precio por unidad: US\$90.000,00'), isTrue);
        },
      );
      await f.tap('USDT');
      await f.step(
        'Con «USDT» el mismo total va en tether, y el precio por unidad '
        'también: 90.000 USDT.',
      );
      await f.check('El total y el precio por unidad pasan a USDT', () {
        expect(_said(f), contains('Precio por unidad: 90.000'));
        expect(
          f.tester
              .widget<TextField>(find.widgetWithText(TextField, 'Total pagado'))
              .decoration!
              .suffixText,
          'USDT',
        );
      });
      await f.tap('USDC');
      await f.check('Con USDC el total va en USDC', () {
        expect(
          f.tester
              .widget<TextField>(find.widgetWithText(TextField, 'Total pagado'))
              .decoration!
              .suffixText,
          'USDC',
        );
      });
      await f.tap('COP');
      await f.type('Total pagado', '360000');
      await f.step(
        'De vuelta en «COP» con 360.000, el precio por unidad es '
        '\$360.000.000.',
      );
      await f.tap('Hoy');
      await f.step(
        'Tocar la fecha abre el calendario para elegir el día, con '
        '«Cancelar» y «Aceptar» escritos igual.',
      );
      await f.check('El calendario dice «Aceptar», no «ACEPTAR»', () {
        expect(f.shows('Aceptar'), isTrue);
        expect(f.shows('Cancelar'), isTrue);
        expect(f.shows('ACEPTAR'), isFalse);
      });
      await f.tap('2');
      await f.tap('Aceptar');
      await f.tap('Ayer');
      await f.tap('Cancelar');
      await f.step(
        'Elegido el 2, la fecha dice «Ayer»; volver a abrir y «Cancelar» la '
        'deja igual.',
      );
      await f.tap('Guardar');
      await f.step(
        'Al guardar, el saldo sube a 0,0133 BTC y la compra aparece en los '
        'movimientos.',
      );
      await f.check('Quedó una compra de 0,001 BTC por \$360.000, ayer', () {
        final Entry e = own.snapshot!.entries.firstWhere(
          (Entry e) => e.accountId == bitcoin.id,
        );
        expect(e.amount, Decimal.parse('0.001'));
        expect(e.cost, _pesos('360000'));
        expect(e.date, DateTime(2026, 10, 2));
      });
      await f.check('El saldo pasó de 0,0123 a 0,0133 BTC', () {
        expect(_balance(own, bitcoin).amount, Decimal.parse('0.0133'));
      });
      await f.check('Lo que costó subió exactamente \$360.000', () {
        expect(
          _holding(own, Asset.btc).position.cost.base,
          before.position.cost.base + Decimal.parse('360000'),
        );
        expect(f.shows('\$3.360.000'), isTrue);
      });
      await f.tapFound(find.text('¿De dónde sale?').first);
      await f.step(
        '«¿De dónde sale?» ya cuenta la compra: con lo que empezó más 0,001 '
        'BTC comprados da 0,0133 BTC.',
      );
      await f.check('El detalle tiene una compra de +0,001 BTC', () {
        expect(f.shows('Una compra'), isTrue);
        expect(_said(f), contains('+0,001 BTC'));
      });
      await f.back();
    },
  ),
  AppFlow(
    '05-05-registrar-una-venta',
    'Vender bitcoin y recibir en el banco',
    area: 'Cripto',
    goal:
        'Vendí parte de mi bitcoin y me consignaron en Bancolombia; quiero '
        'que las dos cuentas cambien.',
    data: fullAccount,
    (FlowRun f) async {
      final OwnController own = f.own;
      final Account bitcoin = _named(own, 'Bitcoin');
      final Account bank = _named(own, 'Bancolombia');
      final Money bankBefore = _balance(own, bank);
      final Position before = _holding(own, Asset.btc).position;
      // What the 0,005 sold had cost, at the average of what is held.
      final Decimal soldCost =
          (before.cost.base * Decimal.parse('0.005') / before.quantity)
              .toDecimal(scaleOnInfinitePrecision: 18);
      await f.tap('Cuentas');
      await f.tap('Bitcoin');
      await f.tap('Venta');
      await f.step(
        '«Venta» abre «Registrar venta»; debajo de la cantidad dice cuánto '
        'tiene la cuenta: 0,0123 BTC.',
      );
      await f.type('Cantidad de BTC', '0,02');
      await f.type('Total recibido', '6000000');
      await f.tap('Guardar');
      await f.step(
        'Vender más de lo que hay no deja: la cantidad se marca en rojo con '
        'lo que tiene la cuenta.',
      );
      await f.check('Sin saldo suficiente no se registra la venta', () {
        expect(_balance(own, bitcoin).amount, Decimal.parse('0.0123'));
      });
      await f.type('Cantidad de BTC', '0,005');
      await f.tapFound(find.byType(DropdownButtonFormField<String?>));
      await f.step(
        '«Recibido en» lista tus cuentas: si la plata llegó a una, su saldo '
        'también cambia.',
      );
      await f.tap('Bancolombia · COP');
      await f.type('Total recibido', '1650000');
      await f.step(
        'Con Bancolombia elegida, debajo dice que el total entra a esa cuenta '
        'y cómo volver a «Fuera de Quincena»; bajo el total, que va en la '
        'moneda de esa cuenta, COP, y el precio: \$330.000.000 por bitcoin.',
      );
      await f.check(
        'Con una cuenta elegida, la moneda es la de esa cuenta y lo dice',
        () {
          expect(find.byType(SegmentedButton<String>), findsNothing);
          expect(_field(f, 'Total recibido').decoration!.suffixText, 'COP');
          expect(
            _said(f),
            contains('El total va en la moneda de esa cuenta (COP).'),
          );
          expect(_said(f), contains('Precio por unidad: \$330.000.000'));
        },
      );
      await f.check(
        '«Recibido en» dice qué le pasa a la cuenta y cómo volver a «Fuera '
        'de Quincena»',
        () => expect(
          f.shows(
            'El total entra a esa cuenta y su saldo sube. Si lo recibiste por '
            'fuera, elige «Fuera de Quincena».',
          ),
          isTrue,
        ),
      );
      await f.tap('Guardar');
      await f.step(
        'Al guardar, Bitcoin baja a 0,0073 BTC y el movimiento «Bitcoin → '
        'Bancolombia» dice «Venta», no «Transferencia».',
      );
      await f.check('El movimiento de la venta dice «Venta»', () {
        expect(_movementDetail(f, 'Bitcoin → Bancolombia'), 'Venta');
      });
      await f.check('Bitcoin pasó de 0,0123 a 0,0073 BTC', () {
        expect(_balance(own, bitcoin).amount, Decimal.parse('0.0073'));
      });
      final Money bankNow = bankBefore + _pesos('1650000');
      await f.check(
        'Bancolombia pasó de ${_cop(bankBefore)} a ${_cop(bankNow)}',
        () => expect(_balance(own, bank), bankNow),
      );
      final Money kept = _pesos('${(before.cost.base - soldCost).round()}');
      await f.check('Lo que costó el bitcoin que queda es ${_cop(kept)}', () {
        final Position now = _holding(own, Asset.btc).position;
        expect(now.cost.base.round(), kept.amount);
        expect(f.shows(_cop(kept)), isTrue);
      });
      await f.check('Las dos partes son una sola transferencia', () {
        final Entry sold = own.snapshot!.entries.firstWhere(
          (Entry e) => e.accountId == bitcoin.id,
        );
        final Entry paid = own.snapshot!.entries.firstWhere(
          (Entry e) => e.transferId == sold.transferId && e.id != sold.id,
        );
        expect(sold.transferId, isNotNull);
        expect(paid.accountId, bank.id);
      });
      await f.tapFound(find.text('¿De dónde sale?').first);
      await f.step(
        '«¿De dónde sale?» del bitcoin: con lo que empezó, menos una venta '
        'de 0,005 BTC.',
      );
      await f.check('El detalle termina en 0,0073 BTC, con «Una venta»', () {
        expect(f.shows('Una venta'), isTrue);
        expect(f.shows('Una transferencia que salió'), isFalse);
        expect(_said(f), contains('−0,005 BTC'));
        expect(_said(f), contains('0,0073 BTC'));
      });
      await f.back();
      await f.back();
      await f.tap('Movimientos');
      await f.step(
        'En Movimientos la venta también dice «Venta», con lo que salió del '
        'bitcoin.',
      );
      await f.check('Movimientos dice «Venta», no «Transferencia»', () {
        expect(_movementDetail(f, 'Bitcoin → Bancolombia'), 'Venta');
      });
      await f.tap('Cuentas');
      await f.tap('Rendimiento y ganancia');
      await f.reveal(find.textContaining('Ya ganado en ventas'));
      await f.step(
        'En la página de cripto, abajo aparece lo que ya se ganó vendiendo, '
        'aparte de la ganancia no realizada.',
      );
      final Money gained = _pesos(
        '${(Decimal.parse('1650000') - soldCost).round()}',
      );
      await f.check(
        'Lo ganado en la venta es ${_cop(gained)}: lo recibido menos lo que '
        'costaron esos 0,005 BTC',
        () {
          expect(own.portfolio.portfolio!.realized.base.round(), gained.amount);
          expect(
            f.shows('Ya ganado en ventas y conversiones: ${_cop(gained)}'),
            isTrue,
          );
        },
      );
    },
  ),
  AppFlow(
    '05-06-agregar-cripto-a-mano',
    'Agregar cripto a mano',
    area: 'Cripto',
    goal:
        'Tengo ether y cardano en una billetera y quiero anotarlos con lo que '
        'me costaron.',
    data: fullAccount,
    (FlowRun f) async {
      final OwnController own = f.own;
      final Money worth = own.netWorth().total;
      await f.tap('Cuentas');
      await f.tap('Agregar cuenta');
      await f.type('Nombre', 'MetaMask ETH');
      await f.tapFound(find.byType(DropdownButtonFormField<String>));
      await f.tap('ETH · Ether');
      await f.tap('Billetera digital');
      await f.reveal(find.text('¿Cuánto te costó?'));
      await f.step(
        'Con una cripto como moneda aparece «¿Cuánto te costó?», en pesos o '
        'dólares, para calcular la ganancia, y «Cuenta de uso diario» se '
        'apaga sola: la cripto se guarda, no se gasta.',
      );
      await f.check(
        'Al elegir una cripto se apaga sola «Cuenta de uso diario», también '
        'como billetera digital',
        () => expect(_switchOn(f), isFalse),
      );
      await f.type('¿Cuánto tiene hoy?', '0,5');
      await f.tap('USD');
      await f.type('¿Cuánto te costó?', '1200');
      await f.step(
        'Con 0,5 ETH, el uso diario apagado y un costo de US\$1.200, todo '
        'listo para guardar.',
      );
      await f.tap('Guardar');
      await f.reveal(find.text('MetaMask ETH'));
      await f.step('MetaMask ETH entra en «Cripto», con su valor en pesos.');
      final Account ether = _named(own, 'MetaMask ETH');
      final Money ethPesos = own.partOfTotal(ether)!;
      await f.check('0,5 ETH con costo de US\$1.200, fuera del uso diario', () {
        expect(ether.asset, Asset.eth);
        expect(ether.spendable, isFalse);
        expect(ether.openingCost, Money(Decimal.fromInt(1200), Asset.usd));
        expect(own.netWorth().total, worth + ethPesos);
      });
      await f.tap('Agregar cuenta');
      await f.type('Nombre', 'Cardano');
      await f.tapFound(find.byType(DropdownButtonFormField<String>));
      await f.tap('Otra cripto');
      await f.type('¿Cuánto tiene hoy?', '1500,5');
      await f.reveal(find.text('¿Cuánto te costó?'));
      await f.step(
        '«Otra cripto» es cripto desde que se elige: el saldo ya no dice COP '
        'y acepta decimales, aparece «¿Cuánto te costó?» y el uso diario se '
        'apaga solo.',
      );
      await f.check(
        'Sin símbolo todavía, el saldo no dice COP, acepta decimales y se '
        'pregunta lo que costó',
        () {
          expect(
            _field(f, '¿Cuánto tiene hoy?').decoration!.suffixText,
            isNull,
          );
          expect(_fieldText(f, '¿Cuánto tiene hoy?'), '1.500,5');
          expect(f.shows('¿Cuánto te costó?'), isTrue);
          expect(_switchOn(f), isFalse);
        },
      );
      await f.type('¿Cuánto tiene hoy?', '1500');
      final int before = own.accounts.length;
      await f.tap('Guardar');
      await f.reveal(
        find.widgetWithText(TextField, 'Símbolo, por ejemplo ADA'),
      );
      await f.step(
        'Con el símbolo vacío, «Guardar» no deja seguir: debajo del símbolo '
        'dice en rojo qué escribir, en vez de crear una cuenta en pesos.',
      );
      await f.check('Sin símbolo no se crea ninguna cuenta', () {
        expect(own.accounts.length, before);
        expect(own.accounts.where((Account a) => a.name == 'Cardano'), isEmpty);
        expect(
          _errorOf(f, 'Símbolo, por ejemplo ADA'),
          'Escribe el símbolo de la moneda, por ejemplo ADA',
        );
      });
      await f.type('Símbolo, por ejemplo ADA', 'ada');
      await f.check('Al escribir el símbolo se quita el rojo y el saldo lo '
          'dice', () {
        expect(_errorOf(f, 'Símbolo, por ejemplo ADA'), isNull);
        expect(_field(f, '¿Cuánto tiene hoy?').decoration!.suffixText, 'ADA');
      });
      await f.tap('Exchange de cripto');
      await f.step(
        'Con el símbolo, ADA, al lado del saldo y «Exchange de cripto» como '
        'tipo, todo listo para guardar.',
      );
      await f.tap('Guardar');
      await f.reveal(find.text('Cardano'));
      await f.step(
        'Cardano queda en Cripto sin valor en pesos: la app no tiene precio '
        'para ADA.',
      );
      await f.check('ADA no tiene precio y no suma al patrimonio', () {
        final Account ada = _named(own, 'Cardano');
        expect(ada.asset.code, 'ADA');
        expect(ada.spendable, isFalse);
        expect(own.partOfTotal(ada), isNull);
        expect(own.netWorth().total, worth + ethPesos);
      });
      await f.tap('Rendimiento y ganancia');
      await f.page(
        'En la página de cripto, ADA dice «Sin precio» y las notas de abajo '
        'explican que no suma al total y que llegó sin precio de compra.',
      );
      await f.reveal(find.text('Sin precio'));
      await f.check('La página dice que ADA no tiene precio', () {
        expect(own.portfolio.portfolio!.unpriced, contains(Asset.of('ADA')));
        expect(f.shows('Sin precio'), isTrue);
      });
      await f.check('Las cuentas sin entidad quedan juntas en «Otras»', () {
        expect(f.shows('OTRAS'), isTrue);
        expect(
          own.portfolio.portfolio!.byInstitution['']!
              .map((Holding h) => h.account.name)
              .toSet(),
          <String>{'MetaMask ETH', 'Cardano'},
        );
      });
      await f.reveal(find.textContaining('Binance no tiene precio'));
      await f.check('Las notas dicen por qué ADA no suma ni gana', () {
        expect(
          f.shows('Binance no tiene precio para ADA: no suman al total.'),
          isTrue,
        );
        expect(_said(f), contains('1.500 ADA llegaron sin precio de compra'));
      });
    },
  ),
  AppFlow(
    '05-07-conectar-binance',
    'Conectar Binance',
    area: 'Cripto',
    goal:
        'Llevo mis saldos de Binance a mano y quiero conectarla para que se '
        'actualicen solos, sin arriesgar mi plata.',
    data: fullAccount,
    (FlowRun f) async {
      final OwnController own = f.own;
      await f.tap('Cuentas');
      await f.tap('Rendimiento y ganancia');
      await f.reveal(find.text('Billeteras propias'));
      await f.step(
        '«Gestionar fuentes»: Binance avisa que tus saldos de allá están '
        'anotados a mano y ofrece conectarla.',
      );
      await f.tap('Binance');
      await f.page(
        'La conexión explica qué trae, que la llave solo lee, que se guarda '
        'solo en el teléfono y cómo crearla.',
      );
      await f.tap('Conectar');
      await f.step(
        '«Conectar» sin llaves no se conecta y dice qué falta bajo cada campo: '
        '«Escribe tu API Key» y «Escribe tu Secret Key».',
      );
      await f.check('Sin llaves no se conecta y dice qué falta', () {
        expect(own.binance.connected, isFalse);
        expect(f.shows('Revisando la llave con Binance…'), isFalse);
        expect(f.shows('Escribe tu API Key'), isTrue);
        expect(f.shows('Escribe tu Secret Key'), isTrue);
      });
      await f.type('API Key', 'llave-de-prueba');
      await f.check('Al escribir la API Key, su aviso se va', () {
        expect(f.shows('Escribe tu API Key'), isFalse);
      });
      await f.tap('Conectar');
      await f.check('Con solo la API Key tampoco intenta conectar, y sigue '
          'pidiendo la Secret Key', () {
        expect(own.binance.connected, isFalse);
        expect(f.shows('Escribe tu Secret Key'), isTrue);
      });
      await f.type('Secret Key', 'secreto');
      await f.step(
        'La Secret Key se escribe oculta, con un ojo al lado, y su aviso se '
        'va.',
      );
      await f.check('Con las dos llaves escritas no queda ningún aviso', () {
        expect(f.shows('Escribe tu API Key'), isFalse);
        expect(f.shows('Escribe tu Secret Key'), isFalse);
      });
      await f.check(
        'El ojo dice lo que hace, «Mostrar la Secret Key», también al lector '
        'de pantalla',
        () => expect(find.byTooltip('Mostrar la Secret Key'), findsOneWidget),
      );
      await f.tapTip('Mostrar la Secret Key');
      await f.step(
        'Tocar el ojo muestra la Secret Key para revisarla; ahora está '
        'tachado y dice «Ocultar la Secret Key».',
      );
      await f.check('El ojo muestra el secreto y ofrece ocultarlo', () {
        final TextField secret = f.tester.widget<TextField>(
          find.widgetWithText(TextField, 'Secret Key'),
        );
        expect(secret.obscureText, isFalse);
        expect(find.byTooltip('Ocultar la Secret Key'), findsOneWidget);
      });
      await f.tap('Conectar');
      await f.waitFor(find.text('Conectar'));
      await f.step(
        'Con las dos llaves, «Conectar» las prueba con Binance; una llave que '
        'no sirve no se guarda y la página dice qué pasó.',
      );
      await f.check('Una llave que no sirve no conecta ni se guarda', () {
        expect(own.binance.connected, isFalse);
        expect(f.shows('Conectar'), isTrue);
        expect(
          f.screenText,
          anyOf(
            contains('Binance no reconoce esa llave'),
            contains('No se pudo hablar con Binance'),
            contains('Algo salió mal al leer Binance'),
          ),
        );
      });
    },
    manual: <String>[
      'Conectar con una llave real de solo lectura: ver «Conectada con una '
          'llave de solo lectura», «Leer ahora» y el informe de movimientos.',
      'Probar una llave que puede operar o retirar: debe rechazarla y no '
          'guardarla.',
      'Con Binance conectada, «Archivarlas» para las cuentas que llevabas a '
          'mano y «Desconectar» con su confirmación (Cancelar y Desconectar).',
      'Que la llave quede en el llavero del teléfono y no en la copia '
          'exportada.',
    ],
  ),
  AppFlow(
    '05-08-seguir-una-billetera',
    'Seguir una billetera por su dirección',
    area: 'Cripto',
    goal:
        'Tengo bitcoin en un Ledger y quiero seguirlo con su dirección '
        'pública, sin dar ninguna llave.',
    data: fullAccount,
    (FlowRun f) async {
      final OwnController own = f.own;
      final int count = own.accounts.length;
      await f.tap('Cuentas');
      await f.tap('Rendimiento y ganancia');
      await f.tap('Billeteras propias');
      await f.step(
        '«Billeteras propias» explica que solo lee la dirección pública, qué '
        'redes sirven y a qué servicios se consulta.',
      );
      await f.tap('Agregar billetera');
      await f.step(
        '«Agregar billetera»: la red (Bitcoin, Ethereum o TRON), que se elige '
        'sola por cómo empieza la dirección, la dirección y un nombre para '
        'reconocerla.',
      );
      await f.type('Dirección pública', 'mi-ledger');
      await f.tap('Agregar billetera');
      await f.step(
        'Algo que no parece una dirección de Bitcoin se rechaza en el '
        'momento, sin consultar nada.',
      );
      await f.type('Dirección pública', 'TR7NHqjeKQxGTCi8q8ZY4pL8otSzgjLj6t');
      await f.step(
        'Al pegar una dirección que empieza por T, la red pasa sola a TRON y '
        'se quita el aviso en rojo.',
      );
      await f.check('La dirección de TRON elige TRON, sin aviso', () {
        expect(_chainPicked(f), Chain.tron);
        expect(_errorOf(f, 'Dirección pública'), isNull);
      });
      await f.type('Dirección pública', _badChecksum);
      await f.check('Una que empieza por bc1 elige Bitcoin', () {
        expect(_chainPicked(f), Chain.bitcoin);
      });
      await f.tap('TRON');
      await f.tap('Agregar billetera');
      await f.step(
        'Con «TRON» elegido a mano, la dirección de Bitcoin se rechaza '
        'diciendo de qué red es.',
      );
      await f.check('Una dirección de otra red dice de cuál es', () {
        expect(f.shows('Esa dirección es de Bitcoin, no de TRON.'), isTrue);
        expect(own.wallets.wallets, isEmpty);
      });
      await f.tap('Bitcoin');
      await f.type('Nombre: Ledger, MetaMask…', 'Ledger');
      await f.tap('Agregar billetera');
      await f.step(
        'Con la forma de Bitcoin pero mal copiada, la app lo nota sin '
        'consultar nada: pide revisar que la dirección esté completa y bien '
        'copiada, sin culpar a la conexión.',
      );
      await f.check(
        'Una dirección mal copiada no se sigue, y el aviso no habla de la '
        'conexión',
        () {
          expect(own.wallets.wallets, isEmpty);
          expect(own.accounts.length, count);
          expect(
            f.shows('Revisa que la dirección esté completa y bien copiada.'),
            isTrue,
          );
          expect(f.screenText, isNot(contains('Revisa tu conexión')));
        },
      );
      await f.back();
      await f.tapTip('Actualizar');
      await f.step(
        'Al cerrar el formulario nada quedó seguido; sin billeteras, '
        '«Actualizar» arriba no tiene nada que leer.',
      );
      await f.check('Sin billeteras, actualizar no avisa de ningún error', () {
        expect(own.wallets.wallets, isEmpty);
        expect(own.wallets.failed, isNull);
        expect(f.shows('Aún no sigues ninguna billetera.'), isTrue);
      });
    },
    manual: <String>[
      'Seguir una dirección real con saldo (Bitcoin, Ethereum y TRON): '
          'deben aparecer sus monedas como cuentas.',
      'Con la billetera seguida, «Actualizar» con conexión trae el saldo '
          'nuevo como un ajuste.',
    ],
  ),
  AppFlow(
    '05-09-dejar-de-seguir-una-billetera',
    'Dejar de seguir una billetera',
    area: 'Cripto',
    goal:
        'Ya no uso ese Ledger y quiero dejar de seguirlo sin perder lo que '
        'la app ya anotó.',
    data: _followingAWallet,
    (FlowRun f) async {
      final OwnController own = f.own;
      final Account ledger = own.accounts.firstWhere(
        (Account a) => a.institution == 'Ledger',
      );
      await f.tap('Cuentas');
      await f.tap('Rendimiento y ganancia');
      await f.page(
        'El Ledger aparece como un lugar más, con la hora en que se leyó su '
        'dirección pública.',
      );
      await f.reveal(find.text('LEDGER'));
      await f.check('El Ledger dice que se lee por dirección pública', () {
        expect(f.screenText, contains('Por dirección pública · leída'));
      });
      await f.tap('Billeteras propias');
      await f.step(
        'En «Billeteras propias» está el Ledger con su dirección corta y lo '
        'que tiene: 0,05 BTC.',
      );
      final DateTime? readAt = own.wallets.syncedAt;
      await f.tapTip('Actualizar');
      await f.step(
        '«Actualizar», arriba, intenta leerla; si no puede, avisa y deja los '
        'últimos saldos.',
      );
      await f.check('Sin leerla, el saldo se queda en 0,05 BTC', () {
        expect(own.wallets.failed, isNotNull);
        expect(_balance(own, ledger).amount, Decimal.parse('0.05'));
        expect(f.screenText, contains('no se pudo leer'));
      });
      await f.check(
        'Un intento fallido no cambia la hora de la última lectura',
        () {
          expect(own.wallets.syncedAt, readAt);
        },
      );
      await f.tapTip('Dejar de seguir');
      await f.step(
        'La papelera pregunta antes: deja de leerse, y lo que trajo se queda '
        'como tuyo.',
      );
      await f.tap('Cancelar');
      await f.check('Cancelar la deja seguida', () {
        expect(own.wallets.wallets, hasLength(1));
      });
      await f.tapTip('Dejar de seguir');
      await f.tap('Dejar de seguir');
      await f.step(
        'Confirmado, ya no hay billeteras seguidas, ni aviso de una que no se '
        'pudo leer.',
      );
      await f.check('Ya no se sigue, pero la cuenta de 0,05 BTC sigue', () {
        expect(own.wallets.wallets, isEmpty);
        expect(own.snapshot!.account(ledger.id), isNotNull);
        expect(_balance(own, ledger).amount, Decimal.parse('0.05'));
      });
      await f.check('Sin billeteras, no queda el aviso de la que fallaba', () {
        expect(own.wallets.failed, isNull);
        expect(f.screenText, isNot(contains('no se pudo leer')));
      });
      await f.back();
      await f.reveal(find.text('LEDGER'));
      await f.step(
        'En la página de cripto, el Ledger ahora dice que ya no la sigues.',
      );
      await f.check('La fuente dice «ya no la sigues»', () {
        expect(f.screenText, contains('ya no la sigues'));
      });
    },
    manual: <String>[
      'Con conexión, «Actualizar» en «Billeteras propias» con una dirección '
          'real debe leer el saldo sin aviso.',
    ],
  ),
  AppFlow(
    '05-10-comprar-con-usdt',
    'Comprar bitcoin con USDT de Binance',
    area: 'Cripto',
    goal:
        'Cambié 100 USDT por bitcoin dentro de Binance y quiero que bajen los '
        'USDT y suba el bitcoin, con lo que me costaron.',
    data: fullAccount,
    (FlowRun f) async {
      final OwnController own = f.own;
      final Account bitcoin = _named(own, 'Bitcoin');
      final Account tether = _named(own, 'Binance');
      final Money tetherBefore = _balance(own, tether);
      final Position btc = _holding(own, Asset.btc).position;
      final Position usdt = _holding(own, Asset.usdt).position;
      final Decimal realized = own.portfolio.portfolio!.realized.base;
      await f.tap('Cuentas');
      await f.tap('Bitcoin');
      await f.tap('Compra');
      await f.type('Cantidad de BTC', '0,0011');
      await f.tapFound(find.byType(DropdownButtonFormField<String?>));
      await f.step(
        '«Pagado desde» lista tus cuentas, con su moneda: los USDT están en '
        '«Binance · USDT».',
      );
      await f.tap('Binance · USDT');
      await f.type('Total pagado', '5000');
      await f.tap('Guardar');
      await f.step(
        'Pagar 5.000 USDT desde Binance, que tiene 1.638,7, no deja: el total '
        'se pone en rojo con lo que tiene la cuenta.',
      );
      await f.check('Sin USDT suficientes no se registra la compra', () {
        expect(_balance(own, tether), tetherBefore);
        expect(_balance(own, bitcoin).amount, Decimal.parse('0.0123'));
        expect(
          _errorOf(f, 'Total pagado'),
          'Esa cuenta tiene ${moneyText(tetherBefore, base: Asset.cop)}.',
        );
      });
      await f.type('Total pagado', '100');
      await f.step(
        'Con Binance elegida, el total va en USDT y ya no hay que elegir '
        'moneda: lo dice debajo del total, con el precio por unidad en USDT.',
      );
      await f.check(
        'El total va en USDT, lo dice, y no se ofrece otra moneda',
        () {
          expect(find.byType(SegmentedButton<String>), findsNothing);
          expect(_said(f), contains('Precio por unidad'));
          expect(
            _said(f),
            contains('El total va en la moneda de esa cuenta (USDT).'),
          );
          expect(
            f.shows(
              'El total sale de esa cuenta y su saldo baja. Si lo pagaste por '
              'fuera, elige «Fuera de Quincena».',
            ),
            isTrue,
          );
        },
      );
      await f.tap('Guardar');
      await f.step(
        'Al guardar, Bitcoin sube a 0,0134 BTC y el cambio aparece como una '
        '«Compra» pagada desde Binance, no como una transferencia.',
      );
      await f.check('El movimiento del cambio dice «Compra»', () {
        expect(_movementDetail(f, 'Binance → Bitcoin'), 'Compra');
      });
      await f.check('Bitcoin pasó de 0,0123 a 0,0134 BTC', () {
        expect(_balance(own, bitcoin).amount, Decimal.parse('0.0134'));
      });
      final Money tetherNow =
          tetherBefore - Money(Decimal.fromInt(100), Asset.usdt);
      await f.check(
        'Binance pasó de ${moneyText(tetherBefore, base: Asset.cop)} a '
        '${moneyText(tetherNow, base: Asset.cop)}',
        () => expect(_balance(own, tether), tetherNow),
      );
      await f.check(
        'Lo que costaron esos 100 USDT pasó del tether al bitcoin, sin '
        'ganancia por el cambio',
        () {
          final Position btcNow = _holding(own, Asset.btc).position;
          final Position usdtNow = _holding(own, Asset.usdt).position;
          final Decimal moved = btcNow.cost.base - btc.cost.base;
          expect(moved, greaterThan(Decimal.zero));
          expect(usdt.cost.base - usdtNow.cost.base, moved);
          expect(own.portfolio.portfolio!.realized.base, realized);
        },
      );
    },
  ),
  AppFlow(
    '05-11-poner-lo-que-costo',
    'Poner lo que me costó una cripto',
    area: 'Cripto',
    goal:
        'El bitcoin de mi Ledger llegó sin precio de compra y quiero poner lo '
        'que me costó para que cuente en la ganancia.',
    data: _followingAWallet,
    (FlowRun f) async {
      final OwnController own = f.own;
      final Account ledger = own.accounts.firstWhere(
        (Account a) => a.institution == 'Ledger',
      );
      await f.tap('Cuentas');
      await f.tap('Bitcoin del Ledger');
      await f.step(
        'El bitcoin del Ledger dice «Te costó: Sin costo», y debajo cómo '
        'ponerlo: al editar la cuenta o registrando las compras.',
      );
      await f.check('Sin costo, la ganancia no se calcula', () {
        expect(f.shows('Sin costo'), isTrue);
        expect(
          f.shows(
            'Pon lo que te costó al editar la cuenta, o registra tus compras.',
          ),
          isTrue,
        );
        expect(_holdingIn(own, ledger).gain, isNull);
      });
      await f.tapTip('Editar cuenta');
      await f.reveal(find.text('¿Cuánto te costó?'));
      await f.step(
        'En «Editar cuenta» de una cripto está «¿Cuánto te costó?», vacío, '
        'en pesos o en dólares.',
      );
      await f.type('¿Cuánto te costó?', '12000000');
      await f.tap('Guardar');
      await f.step(
        'Con \$12.000.000 guardado, la cuenta dice lo que costó, el costo '
        'promedio y la ganancia.',
      );
      final Holding h = _holdingIn(own, ledger);
      await f.check(
        'Te costó \$12.000.000 y la ganancia es lo que vale menos eso',
        () {
          expect(_account(own, ledger.id).openingCost, _pesos('12000000'));
          expect(h.position.cost.base, Decimal.parse('12000000'));
          expect(h.gain!.base, h.value!.base - Decimal.parse('12000000'));
          expect(f.shows('\$12.000.000'), isTrue);
          expect(f.shows('Sin costo'), isFalse);
        },
      );
      await f.back();
      await f.tap('Rendimiento y ganancia');
      await f.page(
        'En la página de cripto ya no está la nota de lo que llegó sin precio '
        'de compra: el Ledger cuenta en la ganancia.',
      );
      await f.check('Ya no hay cripto sin precio de compra', () {
        expect(own.portfolio.portfolio!.uncostedValue.base, Decimal.zero);
        expect(f.screenText, isNot(contains('sin precio de compra')));
      });
    },
  ),
  AppFlow(
    '05-12-vender-todo',
    'Vender todo el bitcoin con pérdida',
    area: 'Cripto',
    goal:
        'Vendí todo mi bitcoin por menos de lo que me costó y quiero ver la '
        'pérdida y que ya no aparezca entre lo que tengo.',
    data: fullAccount,
    (FlowRun f) async {
      final OwnController own = f.own;
      final Account bitcoin = _named(own, 'Bitcoin');
      final Position before = _holding(own, Asset.btc).position;
      final Money lost = Money(
        before.cost.base - Decimal.parse('2500000'),
        Asset.cop,
      );
      await f.tap('Cuentas');
      await f.tap('Bitcoin');
      await f.tap('Venta');
      await f.tap('Todo');
      await f.check('«Todo» escribe lo que tiene la cuenta, 0,0123 BTC', () {
        expect(_fieldText(f, 'Cantidad de BTC'), '0,0123');
      });
      await f.type('Total recibido', '2500000');
      await f.step(
        '«Todo», al lado de la cantidad, escribe lo que tiene la cuenta, '
        '0,0123 BTC, sin teclearlo: se vende por \$2.500.000 recibidos fuera '
        'de Quincena, en pesos.',
      );
      await f.tap('Guardar');
      await f.step(
        'Al guardar, el saldo queda en 0 BTC y «Venta» se apaga: no hay nada '
        'más que vender.',
      );
      await f.check('Bitcoin quedó en 0 y Venta no se puede tocar', () {
        expect(_balance(own, bitcoin).isZero, isTrue);
        expect(
          f.tester
              .widget<OutlinedButton>(
                find.ancestor(
                  of: find.text('Venta'),
                  matching: find.byWidgetPredicate(
                    (Widget w) => w is OutlinedButton,
                  ),
                ),
              )
              .onPressed,
          isNull,
        );
      });
      await f.check('La venta guardó lo recibido, \$2.500.000', () {
        final Entry sale = own.snapshot!.entries.firstWhere(
          (Entry e) => e.accountId == bitcoin.id,
        );
        expect(sale.amount, Decimal.parse('-0.0123'));
        expect(sale.cost, _pesos('2500000'));
      });
      await f.back();
      await f.tap('Rendimiento y ganancia');
      await f.page(
        'En la página de cripto el bitcoin ya no está entre lo que tienes, y '
        'abajo dice lo que se perdió vendiendo.',
      );
      await f.check('El bitcoin ya no es una de tus monedas', () {
        expect(
          own.portfolio.portfolio!.holdings.where(
            (Holding h) => h.asset == Asset.btc,
          ),
          isEmpty,
        );
      });
      await f.reveal(find.textContaining('Ya perdido'));
      await f.check(
        'Lo perdido es ${_cop(lost)}: lo que costó menos lo recibido',
        () {
          expect(-own.portfolio.portfolio!.realized.base, lost.amount);
          expect(
            f.shows('Ya perdido en ventas y conversiones: ${_cop(lost)}'),
            isTrue,
          );
        },
      );
    },
  ),
  AppFlow(
    '05-13-primera-compra',
    'Empezar en cripto con una primera compra',
    area: 'Cripto',
    goal:
        'Abrí Binance para empezar a comprar bitcoin y quiero anotar mi '
        'primera compra, pagada desde Bancolombia.',
    data: _justABank,
    (FlowRun f) async {
      final OwnController own = f.own;
      final Account bank = _named(own, 'Bancolombia');
      final Money bankBefore = _balance(own, bank);
      await f.tap('Cuentas');
      await f.tap('Agregar cuenta');
      await f.type('Nombre', 'Bitcoin en Binance');
      await f.tap('Exchange de cripto');
      await f.tapFound(find.byType(DropdownButtonFormField<String>));
      await f.tap('BTC · Bitcoin');
      await f.type('Entidad (opcional)', 'Binance');
      await f.tap('Guardar');
      await f.reveal(find.text('Rendimiento y ganancia'));
      await f.step(
        'La cuenta nueva, en 0 BTC, abre la sección «Cripto» con su fila '
        '«Rendimiento y ganancia».',
      );
      await f.tap('Bitcoin en Binance');
      await f.step(
        'La cuenta en 0 BTC ya dice el precio del bitcoin y que vale \$0; '
        '«Compra» está lista y «Venta» apagada, porque no hay qué vender.',
      );
      await f.check(
        'Con 0 BTC se ve el precio del bitcoin, no «Precio —», y vale \$0',
        () {
          final Pair price = own.portfolio.portfolio!.priceOf(Asset.btc)!;
          final String said = _said(f);
          expect(
            said,
            contains(_plainText(_cop(_pesos('${price.base.round()}')))),
          );
          expect(said, contains('Vale | \$0'));
          expect(f.shows('—'), isFalse);
        },
      );
      await f.check('Venta está apagada con 0 BTC', () {
        expect(
          f.tester
              .widget<OutlinedButton>(
                find.ancestor(
                  of: find.text('Venta'),
                  matching: find.byWidgetPredicate(
                    (Widget w) => w is OutlinedButton,
                  ),
                ),
              )
              .onPressed,
          isNull,
        );
      });
      await f.back();
      await f.tap('Rendimiento y ganancia');
      await f.step(
        'La página de cripto dice que tu cuenta está en 0, con el precio del '
        'bitcoin, y ofrece «Registrar tu primera compra» en ella; debajo, '
        '«Binance» y «Billeteras propias» para traerla de allá.',
      );
      await f.check(
        'La página vacía ofrece la primera compra en la cuenta en 0',
        () {
          expect(own.portfolio.portfolio!.isEmpty, isTrue);
          expect(
            f.shows(
              'Tu cuenta de cripto está en 0: registra una compra y aquí '
              'verás lo que vale y cuánto ganas.',
            ),
            isTrue,
          );
          expect(f.shows('Bitcoin en Binance'), isTrue);
          expect(f.shows('Registrar tu primera compra'), isTrue);
        },
      );
      await f.check(
        'Debajo sigue cómo traerla: Binance y Billeteras propias',
        () {
          expect(f.shows('Billeteras propias'), isTrue);
          expect(f.shows('Binance'), isTrue);
        },
      );
      await f.tap('Registrar tu primera compra');
      await f.type('Cantidad de BTC', '0,002');
      await f.tapFound(find.byType(DropdownButtonFormField<String?>));
      await f.tap('Bancolombia · COP');
      await f.type('Total pagado', '700000');
      await f.step(
        '«Registrar tu primera compra» abre la compra de esa cuenta: 0,002 '
        'BTC pagados desde Bancolombia, \$700.000, a \$350.000.000 cada '
        'bitcoin.',
      );
      await f.tap('Guardar');
      await f.step(
        'Al guardar, la página de cripto ya muestra lo que vale tu bitcoin y '
        'lo que ganas o pierdes frente a los \$700.000.',
      );
      await f.check('La página ya no está vacía', () {
        expect(own.portfolio.portfolio!.isEmpty, isFalse);
        expect(f.shows('Tu cripto vale'), isTrue);
      });
      final Account coin = _named(own, 'Bitcoin en Binance');
      await f.check('La cuenta tiene 0,002 BTC que costaron \$700.000', () {
        expect(_balance(own, coin).amount, Decimal.parse('0.002'));
        expect(
          _holdingIn(own, coin).position.cost.base,
          Decimal.parse('700000'),
        );
      });
      final Money bankNow = bankBefore - _pesos('700000');
      await f.check(
        'Bancolombia pasó de ${_cop(bankBefore)} a ${_cop(bankNow)}',
        () => expect(_balance(own, bank), bankNow),
      );
      await f.back();
      await f.reveal(find.text('Rendimiento y ganancia'));
      final double ratio = own.portfolio.portfolio!.gainRatio!;
      final Money lost = Money(own.portfolio.portfolio!.gain!.base, Asset.cop);
      await f.step(
        'De vuelta en Cuentas, «Rendimiento y ganancia» dice en rojo «Pérdida '
        'no realizada» con cuánta plata es y su porcentaje.',
      );
      await f.check(
        'La fila dice «Pérdida no realizada ${_signed(lost)} · '
        '${percentText(ratio)}», la de lo que vale frente a los \$700.000',
        () {
          final Holding h = _holdingIn(own, coin);
          expect(ratio, lessThan(0));
          expect(
            ratio,
            closeTo(
              (h.value!.base / h.position.cost.base).toDouble() - 1,
              1e-9,
            ),
          );
          expect(lost.amount, h.value!.base - Decimal.parse('700000'));
          expect(
            _said(f),
            contains(
              _plainText(
                'Pérdida no realizada ${_signed(lost)} · ${percentText(ratio)}',
              ),
            ),
          );
        },
      );
    },
  ),
  AppFlow(
    '05-14-revisar-binance-conectada',
    'Revisar Binance ya conectada',
    area: 'Cripto',
    goal:
        'Ya conecté Binance: quiero ver si está leyendo, dejar de contar dos '
        'veces lo que llevaba a mano y poder desconectarla.',
    data: _binanceRead,
    manual: <String>[
      'Con una llave real, «Leer ahora» debe decir «Listo: …» con los '
          'movimientos nuevos y cambiar la hora de «Leída».',
      'Que al desconectar la llave desaparezca del llavero del teléfono (al '
          'volver a abrir la app, Binance pide la llave otra vez).',
    ],
    (FlowRun f) async {
      final OwnController own = f.own;
      try {
        await _keepBinanceKey(f);
        final Account manualTether = _named(own, 'Binance');
        final Account manualBitcoin = _named(own, 'Bitcoin');
        final Account synced = _named(own, 'Tether (USDT)');
        final int entries = own.snapshot!.entries.length;
        final DateTime readAt = screensNow.subtract(
          const Duration(minutes: 20),
        );
        await f.tap('Cuentas');
        await f.reveal(find.text('Hay saldos contados dos veces'));
        await f.step(
          'En «Cripto» están juntos lo que trajo Binance, «Tether (USDT)», y '
          'lo que llevabas a mano, «Binance»: el mismo USDT, contado dos '
          'veces. Debajo lo dice, «Hay saldos contados dos veces», con '
          '«Archivarlas» a la mano.',
        );
        final Money twice = own.partOfTotal(synced)!;
        await f.check(
          'Los dos USDT suman ${_cop(twice)} cada uno al patrimonio',
          () {
            expect(_balance(own, synced), _balance(own, manualTether));
            expect(own.partOfTotal(manualTether), twice);
          },
        );
        await f.check(
          'Cuentas avisa que hay saldos contados dos veces y cuáles',
          () {
            expect(f.shows('Hay saldos contados dos veces'), isTrue);
            expect(
              f.shows(
                'Binance ya trae lo que llevabas a mano en Binance, Bitcoin.',
              ),
              isTrue,
            );
            expect(f.shows('Archivarlas'), isTrue);
          },
        );
        await f.tap('Rendimiento y ganancia');
        await _binanceIdle(f, own);
        await f.reveal(find.text('Billeteras propias'));
        await f.step(
          'Cada moneda dice de dónde sale, «Conectada a Binance · leída…» o '
          '«Anotado a mano», y en «Gestionar fuentes» Binance dice cuándo se '
          'leyó, hace 20 minutos, así que abrir la cripto no la lee otra vez; '
          'debajo, también que hay saldos contados dos veces.',
        );
        await f.check(
          'La fila de Binance en «Gestionar fuentes» avisa lo contado dos veces',
          () => expect(
            find.descendant(
              of: find.byType(BinanceCard),
              matching: find.text('Hay saldos contados dos veces'),
            ),
            findsOneWidget,
          ),
        );
        await f.check(
          'Binance está conectada y leída hace 20 minutos, por el reloj de la '
          'app: no se volvió a leer',
          () {
            expect(own.binance.connected, isTrue);
            expect(own.binance.syncedAt, readAt);
            expect(own.binance.problem, isNull);
            expect(f.screenText, contains('Leída 3 oct · 9:40'));
          },
        );
        await f.tap('Binance');
        await f.page(
          'Binance conectada: cuándo se leyó, «Leer ahora», las cuentas que '
          'llevabas a mano con «Archivarlas», y «Desconectar».',
        );
        await f.check(
          'La página dice que está conectada y qué llevas a mano',
          () {
            expect(f.shows('Conectada con una llave de solo lectura'), isTrue);
            expect(
              _said(f),
              contains(
                'También tienes cuentas de Binance que llevabas a mano: '
                'Binance, Bitcoin.',
              ),
            );
          },
        );
        await f.tap('Leer ahora');
        await _binanceIdle(f, own);
        await f.step(
          '«Leer ahora» vuelve a pedirle a Binance; con una llave que no sirve, '
          'avisa en rojo y deja todo como estaba.',
        );
        await f.check(
          'Una lectura que falla no trae nada ni cambia la hora de «Leída»',
          () {
            expect(own.binance.problem, isNotNull);
            expect(own.binance.syncedAt, readAt);
            expect(own.snapshot!.entries.length, entries);
            expect(f.screenText, anyOf(_binanceTrouble));
          },
        );
        await f.back();
        await f.reveal(find.text('Billeteras propias'));
        await f.step(
          'De vuelta en la cripto, «Gestionar fuentes» también dice que '
          'Binance no se pudo leer, y de cuándo es la última lectura.',
        );
        await f.check(
          'La fila de Binance dice «No se pudo leer. Última lectura: 3 oct · '
          '9:40», no que está al día',
          () {
            expect(
              f.screenText,
              contains('No se pudo leer. Última lectura: 3 oct · 9:40'),
            );
            expect(f.screenText, isNot(contains('Leída 3 oct')));
          },
        );
        await f.tap('Binance');
        final Money worth = own.netWorth().total;
        final Money handKept =
            own.partOfTotal(manualTether)! + own.partOfTotal(manualBitcoin)!;
        await f.tap('Archivarlas');
        await f.step(
          '«Archivarlas» pregunta antes: por qué, que sus movimientos se '
          'quedan, que se restauran desde «Cuentas archivadas» y cuánto baja '
          'el patrimonio.',
        );
        await f.check(
          'El aviso dice qué hace, y que el patrimonio pasa de ${_cop(worth)} '
          'a ${_cop(worth - handKept)}',
          () {
            expect(f.shows('¿Archivar Binance y Bitcoin?'), isTrue);
            expect(_said(f), contains('archivarlas evita contarlos dos veces'));
            expect(_said(f), contains('«Cuentas archivadas»'));
            expect(
              _said(f),
              contains(
                _plainText(
                  'Tu patrimonio pasa de ${_cop(worth)} a '
                  '${_cop(worth - handKept)}.',
                ),
              ),
            );
          },
        );
        await f.tap('Cancelar');
        await f.check('«Cancelar» no archiva nada', () {
          expect(
            own.accounts.where((Account a) => a.id == manualTether.id),
            hasLength(1),
          );
          expect(f.shows('Archivarlas'), isTrue);
        });
        await f.tap('Archivarlas');
        await f.tapFound(
          find.descendant(
            of: find.byType(AlertDialog),
            matching: find.text('Archivar'),
          ),
        );
        await f.step(
          'Archivadas, el aviso se va y Binance queda como la única fuente.',
        );
        await f.check(
          'Las cuentas a mano quedaron archivadas, con sus movimientos',
          () async {
            expect(
              own.accounts.where(
                (Account a) =>
                    a.id == manualTether.id || a.id == manualBitcoin.id,
              ),
              isEmpty,
            );
            final List<Account> all = (await f.tester.runAsync(
              () => own.store.accounts(archived: true),
            ))!;
            expect(
              all
                  .where((Account a) => a.archived)
                  .map((Account a) => a.id)
                  .toSet(),
              <String>{manualTether.id, manualBitcoin.id},
            );
            expect(own.snapshot!.entries.length, entries);
            expect(f.shows('Archivarlas'), isFalse);
            expect(f.shows('Hay saldos contados dos veces'), isFalse);
          },
        );
        await f.check(
          'El patrimonio bajó ${_cop(handKept)}, como dijo el aviso: ya no '
          'cuenta dos veces',
          () => expect(own.netWorth().total, worth - handKept),
        );
        await f.tap('Desconectar');
        await f.step(
          '«Desconectar» pregunta antes: se borra la llave y lo que trajo se '
          'queda como tuyo.',
        );
        await f.tap('Cancelar');
        await f.check('Cancelar la deja conectada, con su llave', () async {
          expect(own.binance.connected, isTrue);
          expect(
            await f.tester.runAsync(() => SecureKeyVault().read()),
            isNotNull,
          );
        });
        await f.tap('Desconectar');
        await f.tapFound(
          find.descendant(
            of: find.byType(AlertDialog),
            matching: find.text('Desconectar'),
          ),
        );
        await f.top();
        await f.step(
          'Desconectada, la página vuelve a pedir la llave para conectar.',
        );
        await f.check(
          'La llave se borró y «Tether (USDT)» se queda como tuya',
          () async {
            expect(own.binance.connected, isFalse);
            expect(own.binance.syncedAt, isNull);
            expect(
              await f.tester.runAsync(() => SecureKeyVault().read()),
              isNull,
            );
            expect(own.snapshot!.account(synced.id), isNotNull);
            expect(find.widgetWithText(TextField, 'API Key'), findsOneWidget);
          },
        );
        await f.back();
        await f.reveal(find.text('BINANCE'));
        await f.step(
          'En la página de cripto, lo que trajo Binance dice que ya no está '
          'conectada.',
        );
        await f.check('La fuente dice «Leída de Binance · sin conectar»', () {
          expect(f.screenText, contains('Leída de Binance · sin conectar'));
        });
        await f.back();
        await f.tap('Cuentas archivadas');
        await f.step(
          'En Cuentas, «Cuentas archivadas» tiene las dos que llevabas a mano, '
          'cada una con lo que tiene y «Restaurar».',
        );
        await f.check('Binance y Bitcoin están entre las archivadas', () {
          expect(f.shows('Binance'), isTrue);
          expect(f.shows('Bitcoin'), isTrue);
          expect(find.text('Restaurar'), findsNWidgets(2));
        });
        await f.tapFound(find.text('Restaurar').last);
        await f.step(
          '«Restaurar» trae de vuelta el Bitcoin que llevabas a mano; Binance '
          'sigue archivada.',
        );
        await f.check(
          'Bitcoin volvió a tus cuentas y Binance sigue archivada',
          () {
            expect(
              own.accounts.where((Account a) => a.id == manualBitcoin.id),
              hasLength(1),
            );
            expect(own.snapshot!.account(manualTether.id)!.archived, isTrue);
            expect(find.text('Restaurar'), findsOneWidget);
          },
        );
      } finally {
        await f.tester.runAsync(() => SecureKeyVault().delete());
      }
    },
  ),
  AppFlow(
    '05-15-binance-sin-leer',
    'Conectar Binance que aún no lee',
    area: 'Cripto',
    goal:
        'Conecté Binance pero todavía no ha podido leer nada, y no quiero '
        'perder lo que tengo anotado a mano.',
    data: _binanceNeverRead,
    (FlowRun f) async {
      final OwnController own = f.own;
      try {
        await _keepBinanceKey(f);
        final Account manualTether = _named(own, 'Binance');
        final Money worth = own.netWorth().total;
        await f.tap('Cuentas');
        await f.tap('Rendimiento y ganancia');
        await _binanceIdle(f, own);
        await f.reveal(find.text('Billeteras propias'));
        await f.step(
          'Con la llave guardada pero sin una lectura buena, la fila de '
          'Binance dice en rojo «No se ha podido leer todavía».',
        );
        await f.check('Binance está conectada, sin ninguna lectura buena', () {
          expect(own.binance.connected, isTrue);
          expect(own.binance.syncedAt, isNull);
          expect(own.binance.problem, isNotNull);
          expect(f.shows('No se ha podido leer todavía'), isTrue);
          expect(f.shows('Aún sin leer'), isFalse);
        });
        await f.back();
        await f.tap('Rendimiento y ganancia');
        await _binanceIdle(f, own);
        await f.reveal(find.text('Billeteras propias'));
        await f.step(
          'Al abrir la cripto otra vez enseguida, Binance no se intenta leer '
          'de nuevo: tras una lectura que falla, la siguiente que hace sola '
          'espera una hora, y el doble cada vez que vuelve a fallar.',
        );
        await f.check(
          'Volver a abrir la cripto no repite la lectura que acaba de fallar',
          () {
            expect(own.binance.failures, 1);
            expect(
              own.binance.retryAfter(const Duration(minutes: 30)),
              const Duration(hours: 1),
            );
            expect(f.shows('No se ha podido leer todavía'), isTrue);
          },
        );
        await f.tap('Binance');
        await f.page(
          'La página dice «Aún sin leer» y por qué; no ofrece archivar lo que '
          'llevas a mano, porque Binance todavía no ha traído nada.',
        );
        await f.check('No ofrece «Archivarlas» antes de una lectura buena', () {
          expect(f.screenText, anyOf(_binanceTrouble));
          expect(f.shows('Archivarlas'), isFalse);
        });
        await f.check(
          'Lo que llevas a mano sigue contando: ${_cop(worth)} de patrimonio',
          () {
            expect(own.snapshot!.account(manualTether.id)!.archived, isFalse);
            expect(own.netWorth().total, worth);
          },
        );
        await f.tap('Desconectar');
        await f.tapFound(
          find.descendant(
            of: find.byType(AlertDialog),
            matching: find.text('Desconectar'),
          ),
        );
        await f.top();
        await f.step(
          'Desconectada, la página vuelve a pedir la llave; lo que llevas a '
          'mano sigue igual.',
        );
        await f.check('Al desconectarla no se pierde nada de lo anotado', () {
          expect(own.binance.connected, isFalse);
          expect(own.netWorth().total, worth);
          expect(find.widgetWithText(TextField, 'API Key'), findsOneWidget);
        });
      } finally {
        await f.tester.runAsync(() => SecureKeyVault().delete());
      }
    },
  ),
  AppFlow(
    '05-16-cambiar-la-llave-de-binance',
    'Cambiar la llave de Binance que no lee',
    area: 'Cripto',
    goal:
        'Binance dejó de leerse y sospecho de la llave: quiero pegar una '
        'nueva sin desconectarla ni perder lo que trajo.',
    data: _binanceRead,
    manual: <String>[
      'Con una llave real borrada en Binance, «Leer ahora» debe decir que '
          'Binance no reconoce la llave y ofrecer «Cambiar la llave»; con '
          'una llave nueva de solo lectura, debe leer y quedar al día.',
    ],
    (FlowRun f) async {
      final OwnController own = f.own;
      try {
        await _keepBinanceKey(f);
        await f.tap('Cuentas');
        await f.tap('Rendimiento y ganancia');
        await _binanceIdle(f, own);
        await f.tap('Binance');
        await f.tap('Leer ahora');
        await _binanceIdle(f, own);
        await f.step(
          '«Leer ahora» falla una vez: el aviso rojo dice que algo salió mal '
          'y que se intente de nuevo.',
        );
        await f.check('Con una sola falla no se culpa a la llave', () {
          expect(own.binance.failures, 1);
          expect(f.shows('Cambiar la llave'), isFalse);
        });
        await f.tap('Leer ahora');
        await _binanceIdle(f, own);
        await f.reveal(find.text('Cambiar la llave'));
        await f.step(
          'Al fallar otra vez, el aviso dice cuántas veces van seguidas y '
          'que revises tu llave o la pegues de nuevo, con «Cambiar la llave» '
          'debajo.',
        );
        await f.check(
          'Dos fallas seguidas piden revisar la llave y ofrecen cambiarla',
          () {
            expect(own.binance.failures, 2);
            expect(
              f.shows(
                'No se pudo leer Binance 2 veces seguidas. Revisa tu llave o '
                'pégala de nuevo.',
              ),
              isTrue,
            );
            expect(f.shows('Cambiar la llave'), isTrue);
          },
        );
        await f.tap('Cambiar la llave');
        await f.page(
          '«Cambiar la llave» abre el formulario de la llave: la nueva '
          'reemplaza la que hay solo si Binance la acepta, y «Cancelar» deja '
          'la de antes.',
        );
        await f.check('El formulario dice que cambia la llave', () {
          expect(f.shows('Cambiar la llave de Binance'), isTrue);
        });
        await f.reveal(find.text('Cancelar'));
        await f.check('Empieza con los campos vacíos, y deja volver', () {
          expect(_fieldText(f, 'API Key'), isEmpty);
          expect(f.shows('Cancelar'), isTrue);
        });
        await f.type('API Key', 'llave-nueva');
        await f.type('Secret Key', 'secreto-nuevo');
        await f.tap('Conectar');
        await f.waitFor(find.text('Conectar'));
        await _binanceIdle(f, own);
        await f.step(
          'Si Binance no acepta la llave nueva, la página dice qué pasó y la '
          'de antes se queda: nada se desconecta.',
        );
        await f.check(
          'Una llave que no sirve no reemplaza la que había',
          () async {
            expect(own.binance.connected, isTrue);
            expect(await f.tester.runAsync(() => SecureKeyVault().read()), (
              'llave-de-prueba',
              'secreto',
            ));
            expect(f.screenText, anyOf(_binanceTrouble));
          },
        );
        await f.tap('Cancelar');
        await f.top();
        await f.step(
          '«Cancelar» vuelve a Binance conectada, con la llave de antes.',
        );
        await f.check('«Cancelar» vuelve a la conexión de antes', () {
          expect(f.shows('Conectada con una llave de solo lectura'), isTrue);
          expect(f.shows('Cambiar la llave'), isTrue);
        });
        await f.back();
        await f.back();
        await f.tap('Rendimiento y ganancia');
        await _binanceIdle(f, own);
        await f.reveal(find.text('Billeteras propias'));
        await f.step(
          'Al abrir la cripto otra vez, Binance no se lee sola enseguida: '
          'tras dos fallas espera dos horas, y la fila dice que no se pudo '
          'leer y de cuándo es la última lectura buena.',
        );
        await f.check(
          'La cripto no vuelve a leer Binance sola tras dos fallas seguidas',
          () {
            expect(own.binance.failures, 2);
            expect(
              own.binance.retryAfter(const Duration(minutes: 30)),
              const Duration(hours: 2),
            );
            expect(
              f.screenText,
              contains('No se pudo leer. Última lectura: 3 oct · 9:40'),
            );
          },
        );
      } finally {
        await f.tester.runAsync(() => SecureKeyVault().delete());
      }
    },
  ),
];

/// What Binance says when it could not be read: a key it does not accept
/// on a phone, no answer on a test run.
final List<Matcher> _binanceTrouble = <Matcher>[
  contains('Binance no reconoce esa llave'),
  contains('No se pudo hablar con Binance'),
  contains('Algo salió mal al leer Binance'),
];

final Money _cop60k = Money(Decimal.parse('60000'), Asset.cop);

/// The chart's other ranges, as their tab and their words say them.
const List<(String, ChartRange, String)> _ranges =
    <(String, ChartRange, String)>[
      ('24 h', ChartRange.day, 'en 24 horas'),
      ('30 d', ChartRange.month, 'en 30 días'),
      ('1 a', ChartRange.year, 'en un año'),
    ];

/// A Bitcoin address with the shape of one and a checksum that is wrong:
/// no service reads it, with a connection or without one.
const String _badChecksum = 'bc1qexampleexampleexampleexample0lmg5w';

/// The chain picked in the form that follows a wallet.
Chain _chainPicked(FlowRun f) => f.tester
    .widget<SegmentedButton<Chain>>(find.byType(SegmentedButton<Chain>))
    .selected
    .single;

/// Diego, before adding any account.
Future<QuincenaStore> _withoutAccounts() async {
  final QuincenaStore store = await emptyStore();
  await store.ensureCategories();
  await store.saveProfile(
    const Profile(name: 'Diego', base: Asset.cop, schedule: TwiceMonthly()),
  );
  await store.setSetting('app.mode', 'own');
  return store;
}

/// Diego with only his bank, before any crypto, with the day's rates.
Future<QuincenaStore> _justABank() async {
  final QuincenaStore store = await _withoutAccounts();
  await store.saveRates(<Rate>[
    Rate(
      asset: 'USD',
      quote: 'COP',
      value: Decimal.parse('3312.84'),
      asOf: DateTime(2026, 10, 3),
      source: 'trm',
    ),
  ]);
  await store.addAccount(
    name: 'Bancolombia',
    kind: AccountKind.bank,
    asset: Asset.cop,
    opening: Decimal.parse('2000000'),
    institution: 'Bancolombia',
  );
  return store;
}

/// Diego's account, also following a Ledger by its public address, read
/// ten minutes ago.
Future<QuincenaStore> _followingAWallet() async {
  final QuincenaStore store = await seeded();
  await store.addAccount(
    name: 'Bitcoin del Ledger',
    kind: AccountKind.wallet,
    asset: Asset.btc,
    opening: Decimal.parse('0.05'),
    institution: 'Ledger',
    spendable: false,
    syncRef: 'wallet:bitcoin:$_badChecksum:BTC',
  );
  await store.setSetting(
    'wallets',
    jsonEncode(<String, Object?>{
      'wallets': <Object?>[
        <String, String>{
          'chain': 'bitcoin',
          'address': _badChecksum,
          'label': 'Ledger',
        },
      ],
      'syncedAt': screensNow
          .subtract(const Duration(minutes: 10))
          .toIso8601String(),
    }),
  );
  return store;
}

/// Diego's account, also owed 150.000 by Laura for the farm's rent, and
/// paying a fridge in instalments whose rate and instalment he does not
/// know.
Future<QuincenaStore> _owedAndInstalments() async {
  final QuincenaStore store = await fullAccount();
  final List<Object?> groups =
      jsonDecode((await store.setting('shared.groups'))!) as List<Object?>;
  final List<Object?> plans =
      jsonDecode((await store.setting('commitments.instalments'))!)
          as List<Object?>;
  await store.setSetting(
    'shared.groups',
    jsonEncode(<Object?>[
      ...groups,
      Group(
        id: 'group-finca',
        name: 'Arriendo de la finca',
        members: const <Member>[
          Member(id: meId, name: ''),
          Member(id: 'laura', name: 'Laura'),
        ],
        expenses: <SharedExpense>[
          SharedExpense(
            id: 'finca',
            label: 'Arriendo de la finca',
            date: DateTime(2026, 10, 1),
            paidBy: meId,
            shares: const <String, int>{meId: 150000, 'laura': 150000},
          ),
        ],
      ).toJson(),
    ]),
  );
  await store.setSetting(
    'commitments.instalments',
    jsonEncode(<Object?>[
      ...plans,
      Instalments(
        id: 'instalments-nevera',
        name: 'Nevera',
        principal: 1500000,
        count: 12,
        firstDue: DateTime(2026, 10, 25),
      ).toJson(),
    ]),
  );
  return store;
}

/// Diego's account with Binance connected and read twenty minutes ago:
/// the tether it brought sits beside the Binance balances he kept by hand.
Future<QuincenaStore> _binanceRead() async {
  final QuincenaStore store = await _binanceNeverRead();
  await store.addAccount(
    name: 'Tether (USDT)',
    kind: AccountKind.exchange,
    asset: Asset.usdt,
    opening: Decimal.parse('1638.7'),
    institution: 'Binance',
    spendable: false,
    syncRef: 'binance:USDT',
  );
  await store.setSetting(
    'binance',
    jsonEncode(<String, Object?>{
      'syncedAt': screensNow
          .subtract(const Duration(minutes: 20))
          .toIso8601String(),
    }),
  );
  return store;
}

/// Diego's account as it is when Binance was connected and has not read
/// anything yet: the key itself goes in [_keepBinanceKey].
Future<QuincenaStore> _binanceNeverRead() => fullAccount();

/// Puts a Binance key in the phone's keychain, as connecting leaves it. The
/// flow takes it out again at its end, so no other flow finds it.
Future<void> _keepBinanceKey(FlowRun f) async {
  await f.tester.runAsync(
    () => SecureKeyVault().write('llave-de-prueba', 'secreto'),
  );
}

/// Waits for a Binance read under way to end.
Future<void> _binanceIdle(FlowRun f, OwnController own) async {
  for (var i = 0; i < 60; i++) {
    await settle(f.tester);
    if (own.binance.loaded && !own.binance.syncing) break;
    await f.tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 100)),
    );
  }
  await settle(f.tester);
}

/// That nothing on screen is still in Spanish, the person's own names and
/// payees apart.
void _expectEnglish(FlowRun f) {
  final String said = _said(f);
  for (final String spanish in <String>[
    'Patrimonio',
    'Debes',
    'Cupo',
    'De dónde sale',
    'Saldo hoy',
    'Ganancia',
    'Pérdida',
    'Rendimiento',
    'Gestionar',
    'Anotado',
    'Precios de',
    'Conversión',
    'oficial',
    'Agregar',
    'Aún',
    'Así',
    'Lo que',
    ' sept',
    ' oct ',
  ]) {
    expect(said, isNot(contains(spanish)), reason: spanish);
  }
}

/// Pesos as the app writes them.
String _cop(Money m) => moneyText(m, base: Asset.cop);

/// The line under the movement titled [title]: what it was.
String? _movementDetail(FlowRun f, String title) {
  final Finder row = find.ancestor(
    of: find.text(title),
    matching: find.byType(MovementRow),
  );
  if (row.evaluate().isEmpty) return null;
  final List<String> texts = <String>[
    for (final Text t in f.tester.widgetList<Text>(
      find.descendant(of: row.first, matching: find.byType(Text)),
    ))
      ?t.data,
  ];
  return texts.length > 1 ? texts[1] : null;
}

Account _named(OwnController own, String name) =>
    own.accounts.firstWhere((Account a) => a.name == name);

Money _balance(OwnController own, Account a) =>
    own.balances[a.id] ?? a.openingMoney;

/// What [a] started with plus every movement in it up to today, worked out
/// apart from the app's own sum.
Decimal _fromMovements(OwnController own, Account a) {
  final DateTime today = own.today;
  final DateTime end = DateTime(today.year, today.month, today.day + 1);
  Decimal sum = _account(own, a.id).opening;
  for (final Entry e in own.snapshot!.entries) {
    if (e.accountId == a.id && e.date.isBefore(end)) sum += e.amount;
  }
  return sum;
}

Account _account(OwnController own, String id) => own.snapshot!.account(id)!;

/// What the everyday accounts hold in pesos, cards apart, as the tab adds
/// it.
Money _everyday(OwnController own) {
  var sum = Money.zero(Asset.cop);
  for (final Account a in own.accounts) {
    if (!a.spendable || a.kind == AccountKind.card) continue;
    sum += own.partOfTotal(a)!;
  }
  return sum;
}

/// The figure on the line that starts with [label], inside [within] when
/// the same words show elsewhere too.
String? _rowOf(FlowRun f, String label, {Finder? within}) {
  final Finder text = within == null
      ? find.text(label)
      : find.descendant(of: within, matching: find.text(label));
  final Finder row = find.ancestor(of: text, matching: find.byType(Row));
  if (row.evaluate().isEmpty) return null;
  final Iterable<Text> texts = f.tester.widgetList<Text>(
    find.descendant(of: row.first, matching: find.byType(Text)),
  );
  return texts.map((Text t) => t.data).whereType<String>().last;
}

Money _pesos(String amount) => Money(Decimal.parse(amount), Asset.cop);

/// [text] as a figure writes pesos, «−$844.800», back to a number.
Decimal _parsePesos(String text) {
  final bool negative = text.contains('−') || text.contains('-');
  final String digits = text.replaceAll(RegExp(r'[^0-9]'), '');
  final Decimal value = Decimal.parse(digits.isEmpty ? '0' : digits);
  return negative ? -value : value;
}

/// Pesos signed, as a gain is written.
String _signed(Money m) => moneyText(m, base: Asset.cop, signed: true);

/// Pesos as an amount field writes them, without the sign.
String _plain(Money m) => formatDecimal(m.amount, decimals: 0, trim: true);

/// Whether the rate in use for [asset] in pesos was typed by hand.
bool _typedRate(OwnController own, Asset asset) =>
    own.rates.used(asset, Asset.cop).any((Rate r) => r.manual);

Holding _holding(OwnController own, Asset asset) => own
    .portfolio
    .portfolio!
    .holdings
    .firstWhere((Holding h) => h.asset == asset);

/// Whether the account form's «Cuenta de uso diario» is on.
bool _switchOn(FlowRun f) =>
    f.tester.widget<SwitchListTile>(find.byType(SwitchListTile)).value;

/// That the row named [name] sits under the [section] heading, before the
/// [next] one.
void _expectIn(FlowRun f, String name, String section, String next) {
  final double y = f.tester.getTopLeft(find.text(name).first).dy;
  expect(y, greaterThan(f.tester.getTopLeft(find.text(section)).dy));
  expect(y, lessThan(f.tester.getTopLeft(find.text(next)).dy));
}

/// The figure beside a section's heading.
String? _sectionTotal(FlowRun f, String section) => _rowOf(f, section);

/// Everything the screen says, with the spaces that do not break and the
/// joiner that holds a sign to its `$` as plain text.
String _said(FlowRun f) =>
    f.screenText.replaceAll('\u00a0', ' ').replaceAll(signJoiner, '');

/// Pesos signed, as [_said] reads them.
String _plainSigned(Money m) => _plainText(_signed(m));

/// [text] as [_said] reads it.
String _plainText(String text) =>
    text.replaceAll('\u00a0', ' ').replaceAll(signJoiner, '');

/// The big figure at the top of the screen.
String? _headline(FlowRun f) {
  final Finder value = find.descendant(
    of: find.byType(Headline).first,
    matching: find.byType(Figures),
  );
  if (value.evaluate().isEmpty) return null;
  return f.tester.widget<Figures>(value.first).text;
}

TextField _field(FlowRun f, String label) =>
    f.tester.widget<TextField>(find.widgetWithText(TextField, label).first);

/// What the field labelled [label] holds.
String _fieldText(FlowRun f, String label) => _field(f, label).controller!.text;

/// What the field labelled [label] says is wrong, if anything.
String? _errorOf(FlowRun f, String label) =>
    _field(f, label).decoration?.errorText;

/// Picks [name] in the [index]th list of accounts of the movement form.
Future<void> _pickAccount(FlowRun f, int index, String name) async {
  await f.tapFound(find.byType(DropdownButtonFormField<String>).at(index));
  await f.tester.tap(find.text(name).last);
  await settle(f.tester);
}

/// The coin held in [account].
Holding _holdingIn(OwnController own, Account account) => own
    .portfolio
    .portfolio!
    .holdings
    .firstWhere((Holding h) => h.account.id == account.id);

/// Scrolls the crypto page so the whole chart card shows, from the figure
/// over it to the note under it.
Future<void> _showChart(FlowRun f) async {
  final Finder card = find
      .ancestor(
        of: find.byType(SegmentedButton<bool>),
        matching: find.byType(Block),
      )
      .first;
  await f.tester.ensureVisible(card);
  await settle(f.tester);
}
