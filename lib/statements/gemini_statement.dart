import 'dart:convert';
import 'dart:typed_data';

import 'package:decimal/decimal.dart';
import 'package:firebase_ai/firebase_ai.dart' as ai;

import '../agent/firebase_client.dart';
import '../ai/cloud.dart';
import '../capture/merchants.dart';
import 'statement.dart';

/// Reads a statement's text with Gemini, when the device could not make out
/// its movements.
///
/// Only the text read on the device goes, never the PDF, and only when the
/// person asks for it: the screen says what is sent before sending it. The
/// answer comes back as JSON in a fixed shape, so nothing Gemini writes is
/// taken as a figure without being parsed and shown for review.
class GeminiStatementReader {
  const GeminiStatementReader();

  static final ai.Schema _shape = ai.Schema.object(
    properties: <String, ai.Schema>{
      'lines': ai.Schema.array(
        items: ai.Schema.object(
          properties: <String, ai.Schema>{
            'date': ai.Schema.string(description: 'The date, as YYYY-MM-DD.'),
            'description': ai.Schema.string(
              description: 'What the statement says the movement was.',
            ),
            'amount': ai.Schema.string(
              description:
                  'The amount as a plain decimal with a dot and no thousands '
                  'separators, negative when money left the account: '
                  '-45900.00 for a purchase, 1250000 for a deposit.',
            ),
            'balance': ai.Schema.string(
              description: 'The balance after it, in the same form, or empty.',
              nullable: true,
            ),
          },
          optionalProperties: <String>['balance'],
        ),
      ),
    },
  );

  static const String _instructions =
      'Below is the text of a bank or card statement, read from a PDF. List '
      'every movement in it, in the order it appears, with its date, its '
      'description and its signed amount. Leave out totals, balances carried '
      'over, interest summaries and anything that is not a movement. Do not '
      'invent movements or amounts: if a line is unclear, leave it out.';

  /// The movements in a statement's [text], read on the device.
  Future<StatementRead> read(String text) async {
    final ai.GenerateContentResponse response = await (await _model())
        .generateContent(<ai.Content>[
          ai.Content.text('$_instructions\n\n$text'),
        ]);
    return parseAnswer(response.text ?? '', text);
  }

  /// The movements in a statement's PDF, where the device cannot read it,
  /// as on the web.
  Future<StatementRead> readPdf(Uint8List pdf) async {
    final ai.GenerateContentResponse response = await (await _model())
        .generateContent(<ai.Content>[
          ai.Content.multi(<ai.Part>[
            ai.TextPart(
              _instructions.replaceFirst('the text of', 'the PDF of'),
            ),
            ai.InlineDataPart('application/pdf', pdf),
          ]),
        ]);
    final String answer = response.text ?? '';
    return parseAnswer(answer, answer);
  }

  Future<ai.GenerativeModel> _model() async {
    if (!await Cloud.start()) {
      throw StateError('Firebase is not available on this platform');
    }
    await Cloud.signIn();
    return ai.FirebaseAI.agentPlatform(
      location: FirebaseGeminiClient.location,
    ).generativeModel(
      model: FirebaseGeminiClient.defaultModel,
      generationConfig: ai.GenerationConfig(
        responseMimeType: 'application/json',
        responseSchema: _shape,
        thinkingConfig: ai.ThinkingConfig.withThinkingLevel(
          ai.ThinkingLevel.low,
        ),
      ),
    );
  }

  /// The movements in Gemini's JSON answer; any line that does not parse is
  /// left out rather than guessed.
  static StatementRead parseAnswer(String json, String statement) {
    final List<StatementLine> lines = <StatementLine>[];
    Object? body;
    try {
      body = jsonDecode(json);
    } on FormatException {
      body = null;
    }
    final Object? list = body is Map ? body['lines'] : null;
    for (final Object? item in list is List ? list : const <Object?>[]) {
      if (item is! Map) continue;
      final DateTime? date = DateTime.tryParse('${item['date']}');
      final Decimal? amount = Decimal.tryParse('${item['amount']}');
      final String description = '${item['description'] ?? ''}'.trim();
      if (date == null || amount == null || amount == Decimal.zero) continue;
      lines.add(
        StatementLine(
          date: DateTime(date.year, date.month, date.day),
          description: description,
          amount: amount,
          balance: Decimal.tryParse('${item['balance'] ?? ''}'),
        ),
      );
    }
    return StatementRead(
      lines: lines,
      source: StatementSource.gemini,
      institution: firstInstitution(statement),
    );
  }
}
