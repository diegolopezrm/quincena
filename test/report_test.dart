import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:genui/genui.dart' show ChatMessage;
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:intl/intl.dart';
import 'package:quincena/agent/model_client.dart';
import 'package:quincena/ai/reports.dart';
import 'package:quincena/l10n/l10n.dart';
import 'package:quincena/session/session.dart';
import 'package:quincena/theme/theme.dart';
import 'package:quincena/ui/conversation.dart';
import 'package:quincena/version.dart';

import 'fonts.dart';
import 'gemini_test.dart' show OneSurfaceModel;

/// A model whose answer has a form, with a note the person could type in.
class FormModel implements ModelClient {
  @override
  Stream<String> send(
    String prompt, {
    required List<ChatMessage> history,
  }) async* {
    yield 'Here it is.\n';
    yield '```json\n{"version": "v0.9", "createSurface": '
        '{"surfaceId": "answer", "catalogId": "dev.dlsoft.quincena"}}\n```\n';
    yield '```json\n{"version": "v0.9", "updateDataModel": '
        '{"surfaceId": "answer", "path": "/form", '
        '"value": {"amount": 5000, "note": "lunch with Ana"}}}\n```\n';
    yield '```json\n{"version": "v0.9", "updateComponents": '
        '{"surfaceId": "answer", "components": ['
        '{"id": "root", "component": "Answer", "children": ["head"]}, '
        '{"id": "head", "component": "Headline", "title": "Gasto"}]}}\n```\n';
  }
}

AnswerReport report({
  String question = '¿Cuánto me queda?',
  String answer = '{}',
  String comment = '',
}) => AnswerReport(
  reason: ReportReason.offensive,
  question: question,
  answer: answer,
  comment: comment,
  language: 'es',
  mode: 'gemini',
);

void main() {
  final DateTime now = DateTime.utc(2026, 10, 3, 5);

  group('a report', () {
    test('carries every field the rules take, and expires in 90 days', () {
      final Map<String, Object?> fields = AnswerReports(
        client: MockClient((_) async => http.Response('{}', 200)),
        now: () => now,
      ).fields(report(question: '  ¿Cuánto? ', comment: ' mal \n'));
      expect(fields.keys.toSet(), <String>{
        'reason',
        'question',
        'answer',
        'comment',
        'language',
        'mode',
        'platform',
        'version',
        'expireAt',
      });
      String text(String key) =>
          (fields[key]! as Map<String, Object?>)['stringValue']! as String;
      expect(text('reason'), 'offensive');
      expect(text('question'), '¿Cuánto?');
      expect(text('comment'), 'mal');
      expect(text('version'), appVersion);
      expect(text('platform'), 'android');
      expect(
        (fields['expireAt']! as Map<String, Object?>)['timestampValue'],
        '2027-01-01T05:00:00.000Z',
      );
    });

    test('is cut to the sizes the rules allow', () {
      final Map<String, Object?> fields = AnswerReports(
        client: MockClient((_) async => http.Response('{}', 200)),
        now: () => now,
      ).fields(report(answer: 'x' * 50000, comment: 'y' * 1500));
      String text(String key) =>
          (fields[key]! as Map<String, Object?>)['stringValue']! as String;
      expect(text('answer').length, AnswerReports.maxAnswer);
      expect(text('answer'), endsWith('…'));
      expect(text('comment').length, AnswerReports.maxComment);
    });

    test('is never cut in the middle of a character', () {
      // An emoji is two UTF-16 code units; cutting between them would leave
      // half of one.
      final String cut = AnswerReports.cut('ab😀cd', 4);
      expect(cut, 'ab…');
      expect(AnswerReports.cut('abc', 3), 'abc');
    });

    test('goes to Firestore with App Check\'s token', () async {
      late http.Request sent;
      await AnswerReports(
        client: MockClient((http.Request request) async {
          sent = request;
          return http.Response('{"name": "reports/abc"}', 200);
        }),
        token: () async => 'app-check-token',
        now: () => now,
      ).send(report());
      expect(sent.method, 'POST');
      expect(
        sent.url.toString(),
        'https://firestore.googleapis.com/v1/projects/quincena-dlsoft/'
        'databases/(default)/documents/reports',
      );
      expect(sent.headers['X-Firebase-AppCheck'], 'app-check-token');
      final Map<String, Object?> body =
          jsonDecode(sent.body) as Map<String, Object?>;
      expect(
        (body['fields']! as Map<String, Object?>)['reason'],
        <String, Object?>{'stringValue': 'offensive'},
      );
    });

    test('that Firestore refuses says so', () async {
      final AnswerReports reports = AnswerReports(
        client: MockClient((_) async => http.Response('denied', 403)),
        token: () async => null,
        now: () => now,
      );
      await expectLater(reports.send(report()), throwsA(isA<ReportNotSent>()));
    });
  });

  group('the answer a report carries', () {
    test('is what the model sent, without what the person typed', () async {
      final Session session = Session(
        mode: AgentMode.gemini,
        client: FormModel(),
        errorWindow: Duration.zero,
      );
      addTearDown(session.dispose);
      await session.ask('¿Cuánto gasté?');
      final Turn turn = session.turns.single;
      expect(session.canReport(turn), isTrue);
      final Map<String, Object?> answer =
          jsonDecode(session.answerOf(turn)) as Map<String, Object?>;
      expect(answer['text'], 'Here it is.');
      final String messages = jsonEncode(answer['messages']);
      expect(messages, contains('"Headline"'));
      expect(messages, contains('5000'));
      expect(messages, isNot(contains('lunch with Ana')));
      expect(jsonEncode(answer['data']), isNot(contains('lunch with Ana')));
    });

    test(
      'is not there to report in the demo, where no model answers',
      () async {
        final Session session = Session(thinking: Duration.zero);
        addTearDown(session.dispose);
        await session.ask('¿Cuánto me queda libre?');
        expect(session.canReport(session.turns.single), isFalse);
      },
    );
  });

  group('reporting from the conversation', () {
    setUpAll(() async {
      await loadAppFonts();
      Intl.defaultLocale = 'es_CO';
      await initializeDateFormatting('es');
    });

    Future<Session> answered(WidgetTester tester, AnswerReports reports) async {
      tester.view.physicalSize = const Size(1170, 2532);
      tester.view.devicePixelRatio = 3;
      addTearDown(tester.view.reset);
      final Session session = Session(
        mode: AgentMode.gemini,
        client: OneSurfaceModel(),
        errorWindow: Duration.zero,
      );
      addTearDown(session.dispose);
      await tester.pumpWidget(
        MaterialApp(
          theme: quincenaTheme(Brightness.light),
          locale: const Locale('es'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: appLocales,
          home: Scaffold(
            body: SingleChildScrollView(
              child: ListenableBuilder(
                listenable: session,
                builder: (BuildContext context, _) =>
                    Conversation(session: session, reports: reports),
              ),
            ),
          ),
        ),
      );
      final Future<void> asked = session.ask('¿En qué se me fue la plata?');
      await tester.pumpAndSettle();
      await asked;
      await tester.pumpAndSettle();
      return session;
    }

    testWidgets('sends the reason, the comment and the answer', (tester) async {
      final List<http.Request> sent = <http.Request>[];
      final Session session = await answered(
        tester,
        AnswerReports(
          client: MockClient((http.Request request) async {
            sent.add(request);
            return http.Response('{}', 200);
          }),
          token: () async => 'token',
          now: () => now,
        ),
      );

      await tester.tap(find.text('Reportar'));
      await tester.pumpAndSettle();
      expect(find.text('Reportar esta respuesta'), findsOneWidget);
      expect(find.textContaining('nada más de tu cuenta'), findsOneWidget);
      FilledButton send() => tester.widget<FilledButton>(
        find.widgetWithText(FilledButton, 'Enviar reporte'),
      );
      expect(send().onPressed, isNull, reason: 'no reason chosen yet');

      await tester.tap(find.text('Es ofensiva o inapropiada'));
      await tester.enterText(find.byType(TextField), 'No tiene sentido');
      await tester.pumpAndSettle();
      await tester.tap(find.text('Enviar reporte'));
      await tester.pumpAndSettle();

      expect(sent, hasLength(1));
      final Map<String, Object?> fields =
          (jsonDecode(sent.single.body) as Map<String, Object?>)['fields']!
              as Map<String, Object?>;
      expect(fields['reason'], <String, Object?>{'stringValue': 'offensive'});
      expect(fields['comment'], <String, Object?>{
        'stringValue': 'No tiene sentido',
      });
      expect(fields['question'], <String, Object?>{
        'stringValue': '¿En qué se me fue la plata?',
      });
      expect(
        (fields['answer']! as Map<String, Object?>)['stringValue'],
        contains('Listo'),
      );
      expect(find.text('Reportar esta respuesta'), findsNothing);
      expect(find.text('Gracias. Vamos a revisar esta respuesta.'), findsOne);
      expect(find.text('Reportada'), findsOneWidget);
      expect(session.turns.single.reported, isTrue);
      expect(tester.takeException(), isNull);
    });

    testWidgets('keeps the sheet open when the report does not arrive', (
      tester,
    ) async {
      await answered(
        tester,
        AnswerReports(
          client: MockClient((_) async => http.Response('denied', 403)),
          token: () async => null,
          now: () => now,
        ),
      );
      await tester.tap(find.text('Reportar'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Es incorrecta o engañosa'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Enviar reporte'));
      await tester.pumpAndSettle();
      expect(find.text('Reportar esta respuesta'), findsOneWidget);
      expect(find.textContaining('No se pudo enviar'), findsOneWidget);
      expect(find.text('Reportada'), findsNothing);
    });
  });
}
