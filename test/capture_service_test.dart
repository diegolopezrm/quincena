import 'dart:convert';

import 'package:decimal/decimal.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:quincena/capture/capture_service.dart';
import 'package:quincena/capture/event.dart';
import 'package:quincena/capture/inbox.dart';
import 'package:quincena/capture/places.dart';
import 'package:quincena/domain/pay_schedule.dart';
import 'package:quincena/domain/records.dart';
import 'package:quincena/money/asset.dart';
import 'package:quincena/money/rates.dart';
import 'package:quincena/store/database.dart';
import 'package:quincena/store/store.dart';
import 'package:intl/intl.dart';

Decimal d(String s) => Decimal.parse(s);

final DateTime now = DateTime(2026, 10, 1, 13, 50);

CaptureEvent push(
  String text, {
  DateTime? at,
  String app = 'com.todo1.mobile',
  double? lat,
  double? lng,
}) => CaptureEvent(
  source: CaptureSource.notification,
  at: at ?? now,
  text: text,
  app: app,
  latitude: lat,
  longitude: lng,
);

/// Photon as it answers near a supermarket.
PlaceFinder photon() => PlaceFinder(
  client: MockClient(
    (http.Request request) async => http.Response.bytes(
      utf8.encode(
        jsonEncode(<String, Object>{
          'features': <Object>[
            <String, Object>{
              'geometry': <String, Object>{
                'coordinates': <double>[-75.5905, 6.2446],
              },
              'properties': <String, String>{
                'name': 'Éxito Laureles',
                'osm_key': 'shop',
                'osm_value': 'supermarket',
              },
            },
            <String, Object>{
              'geometry': <String, Object>{
                'coordinates': <double>[-75.5910, 6.2449],
              },
              'properties': <String, String>{
                'name': 'Banco Popular',
                'osm_key': 'amenity',
                'osm_value': 'bank',
              },
            },
          ],
        }),
      ),
      200,
    ),
  ),
);

void main() {
  late QuincenaStore store;
  late CaptureService capture;
  late Account bancolombia;
  late Account nequi;

  setUp(() async {
    Intl.defaultLocale = 'es_CO';
    store = QuincenaStore(
      QuincenaDatabase(NativeDatabase.memory()),
      now: () => now,
    );
    await store.ensureCategories();
    await store.saveProfile(
      const Profile(name: 'Diego', base: Asset.cop, schedule: TwiceMonthly()),
    );
    bancolombia = await store.addAccount(
      name: 'Bancolombia',
      kind: AccountKind.bank,
      asset: Asset.cop,
      institution: 'Bancolombia',
      opening: d('1000000'),
    );
    nequi = await store.addAccount(
      name: 'Nequi',
      kind: AccountKind.wallet,
      asset: Asset.cop,
      institution: 'Nequi',
    );
    capture = CaptureService(store, places: photon(), now: () => now);
  });

  tearDown(() => store.close());

  Future<List<InboxItem>> pending() =>
      store.inbox(statuses: <InboxStatus>{InboxStatus.pending});

  test('an alert becomes a suggestion: account, category and merchant', () async {
    final IngestReport r = await capture.ingest(<CaptureEvent>[
      push(
        r'Bancolombia: Compraste $45.900,00 en EXITO LAURELES con tu T.Deb *1234, el 01/10/2026 a las 13:45.',
      ),
    ]);
    expect(r.added, 1);
    final InboxItem item = (await pending()).single;
    expect(item.parsed.amount, d('45900'));
    expect(item.suggestion.accountId, bancolombia.id);
    expect(item.suggestion.category, 'groceries');
    expect(item.suggestion.payee, 'Exito Laureles');
  });

  test(
    'one purchase seen by Wallet, the bank and an SMS is one movement',
    () async {
      final IngestReport r = await capture.ingest(<CaptureEvent>[
        CaptureEvent(
          source: CaptureSource.wallet,
          at: now,
          text: '',
          merchant: 'Éxito Laureles',
          amount: r'$45.900,00',
          card: 'Bancolombia Visa',
        ),
        push(
          r'Bancolombia: Compraste $45.900,00 en EXITO LAURELES con tu T.Cred *1234',
          at: now.add(const Duration(seconds: 40)),
        ),
        CaptureEvent(
          source: CaptureSource.sms,
          at: now.add(const Duration(minutes: 2)),
          text:
              r'Bancolombia le informa Compra por $45.900,00 en EXITO LAURELES 13:45. 01/10/2026 T.Cred *1234.',
          sender: '85784',
        ),
      ]);
      expect(r.added, 1);
      expect(r.duplicates, 2);
      expect(await pending(), hasLength(1));
    },
  );

  test('a security code is never kept', () async {
    final IngestReport r = await capture.ingest(<CaptureEvent>[
      push('Bancolombia: Tu clave dinamica es 482913. No la compartas.'),
    ]);
    expect(r.ignored, 1);
    expect(await store.inbox(), isEmpty);
  });

  test(
    'confirming records the movement and teaches the card and the merchant',
    () async {
      await capture.ingest(<CaptureEvent>[
        push(
          r'Pagaste $23.500 en CREPES Y WAFFLES OVIEDO con tu tarjeta *9876',
          app: 'com.nequi.MobileApp',
        ),
      ]);
      final InboxItem item = (await pending()).single;
      expect(item.suggestion.accountId, nequi.id);
      final Entry entry = await capture.accept(
        item,
        accountId: nequi.id,
        category: 'restaurants',
      );
      expect(entry.amount, d('-23500'));
      expect(entry.payee, 'Crepes y Waffles Oviedo');
      expect(entry.source, 'notification');
      expect(await pending(), isEmpty);

      final CaptureSettings learned = await store.captureSettings();
      expect(learned.cardAccounts['9876'], nequi.id);
      expect(learned.merchantCategories['crepes y waffles'], 'restaurants');

      // Next time: the same card and merchant are known, and with automatic
      // recording on, it goes straight in.
      await store.saveCaptureSettings(learned.copyWith(autoRecord: true));
      final IngestReport r = await capture.ingest(<CaptureEvent>[
        push(
          r'Pagaste $18.000 en CREPES Y WAFFLES OVIEDO con tu tarjeta *9876',
          app: 'com.nequi.MobileApp',
          at: now.add(const Duration(days: 1)),
        ),
      ]);
      expect(r.recorded, 1);
      final InboxItem auto = (await store.inbox(
        statuses: <InboxStatus>{InboxStatus.accepted},
      )).firstWhere((InboxItem i) => i.automatic);
      expect(auto.suggestion.why, containsAll(<String>['card', 'learned']));

      // And it can be taken back.
      await capture.undo(auto);
      expect(await pending(), hasLength(1));
      expect(
        (await store.entries()).where((Entry e) => e.amount == d('-18000')),
        isEmpty,
      );
    },
  );

  test('an app the person mutes is not read again', () async {
    await capture.ingest(<CaptureEvent>[
      push(r'Compraste $9.900 en TIENDA X', app: 'com.some.shop'),
    ]);
    await capture.dismiss((await pending()).single, muteApp: true);
    final IngestReport r = await capture.ingest(<CaptureEvent>[
      push(
        r'Compraste $5.000 en TIENDA X',
        app: 'com.some.shop',
        at: now.add(const Duration(hours: 1)),
      ),
    ]);
    expect(r.ignored, 1);
    expect(await pending(), isEmpty);
  });

  test('where the phone was names a shop the alert left out', () async {
    await store.saveCaptureSettings(const CaptureSettings(useLocation: true));
    await capture.ingest(<CaptureEvent>[
      push(
        r'Bancolombia: Compra por $45.900 POS 4512 T.Deb *1234',
        lat: 6.2445,
        lng: -75.5905,
      ),
    ]);
    final InboxItem item = (await pending()).single;
    expect(item.suggestion.payee, 'Éxito Laureles');
    expect(item.suggestion.category, 'groceries');
    expect(item.suggestion.why, contains('place'));
    expect(item.suggestion.place!.metres, lessThan(30));
  });

  test('without the location on, nothing is looked up', () async {
    await capture.ingest(<CaptureEvent>[
      push(
        r'Bancolombia: Compra por $45.900 POS 4512 T.Deb *1234',
        lat: 6.2445,
        lng: -75.5905,
      ),
    ]);
    expect((await pending()).single.suggestion.place, isNull);
  });

  test(
    'a dollar charge on a peso account is recorded in pesos, with the original kept',
    () async {
      await store.saveRates(<Rate>[
        Rate(
          asset: 'USD',
          quote: 'COP',
          value: d('4000'),
          asOf: now,
          source: 'trm',
        ),
      ]);
      await capture.ingest(<CaptureEvent>[
        push(r'Bancolombia: Pagaste US$ 10,99 a SPOTIFY con tu T.Cred *1234'),
      ]);
      final InboxItem item = (await pending()).single;
      final Entry entry = await capture.accept(item, accountId: bancolombia.id);
      expect(entry.amount, d('-43960'));
      expect(entry.category, 'subscriptions');
      expect(entry.note, contains('10,99'));
    },
  );

  test(
    'with a single peso account, a bare \$ proposes it but waits for the person',
    () async {
      await store.deleteAccount(nequi.id);
      await store.saveCaptureSettings(const CaptureSettings(autoRecord: true));
      final IngestReport r = await capture.ingest(<CaptureEvent>[
        push(r'Compraste $12.000 en TIENDAS D1', app: 'com.some.wallet'),
      ]);
      expect(r.recorded, 0);
      expect(r.added, 1);
      final InboxItem item = (await pending()).single;
      expect(item.suggestion.accountId, bancolombia.id);
      expect(item.suggestion.category, 'groceries');
      expect(item.suggestion.why, contains('only'));

      // A bank the person has no account in is not taken for that one.
      await capture.ingest(<CaptureEvent>[
        push(
          r'Juan Pérez te envió $50.000',
          app: 'com.nequi.MobileApp',
          at: now.add(const Duration(hours: 1)),
        ),
      ]);
      final InboxItem nequiItem = (await pending()).firstWhere(
        (InboxItem i) => i.parsed.institution == 'Nequi',
      );
      expect(nequiItem.suggestion.accountId, isNull);
    },
  );

  test('an approximate location does not name a shop', () async {
    await store.saveCaptureSettings(const CaptureSettings(useLocation: true));
    await capture.ingest(<CaptureEvent>[
      CaptureEvent(
        source: CaptureSource.notification,
        at: now,
        app: 'com.todo1.mobile',
        text: r'Bancolombia: Compra por $45.900 POS 4512 T.Deb *1234',
        latitude: 6.2445,
        longitude: -75.5905,
        accuracy: 2000,
      ),
    ]);
    expect((await pending()).single.suggestion.place, isNull);
  });

  test('a muted app keeps its name for the list', () async {
    await capture.ingest(<CaptureEvent>[
      CaptureEvent(
        source: CaptureSource.notification,
        at: now,
        app: 'com.some.shop',
        appName: 'Tienda X',
        text: r'Compraste $9.900 en TIENDA X',
      ),
    ]);
    await capture.dismiss((await pending()).single, muteApp: true);
    final CaptureSettings s = await store.captureSettings();
    expect(s.mutedApps, contains('com.some.shop'));
    expect(s.appNames['com.some.shop'], 'Tienda X');
  });

  test(
    'a receipt shared hours later repeats the alert of the same payment',
    () async {
      await capture.ingest(<CaptureEvent>[
        push(
          r'Nequi: Enviaste $50.000 a Juan Pérez',
          app: 'com.nequi.MobileApp',
          at: DateTime(2026, 10, 1, 13, 30),
        ),
      ]);
      final IngestReport r = await capture.ingest(<CaptureEvent>[
        CaptureEvent(
          source: CaptureSource.screenshot,
          at: DateTime(2026, 10, 1, 21, 5),
          text: '''¡Listo! Envío exitoso
Para
Juan Pérez
¿Cuánto?
\$ 50.000,00
Fecha
1 de octubre de 2026 a las 1:30 p. m.''',
        ),
      ]);
      expect(r.duplicates, 1);
    },
  );

  test('a movement already entered by hand is not suggested again', () async {
    await store.addEntry(
      accountId: bancolombia.id,
      amount: d('45900'),
      kind: EntryKind.expense,
      date: DateTime(2026, 10, 1, 12),
      category: 'groceries',
      payee: 'Éxito',
    );
    final IngestReport r = await capture.ingest(<CaptureEvent>[
      push(
        r'Bancolombia: Compraste $45.900,00 en EXITO LAURELES con tu T.Deb *1234',
      ),
    ]);
    expect(r.duplicates, 1);
  });
}
