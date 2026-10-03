import 'dart:async';
import 'dart:convert';

import 'package:firebase_app_check/firebase_app_check.dart';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import '../version.dart';
import 'cloud.dart';

/// What is wrong with an answer, as the person reporting it says.
enum ReportReason { offensive, wrong, other }

/// A report about one of Gemini's answers.
@immutable
class AnswerReport {
  const AnswerReport({
    required this.reason,
    required this.question,
    required this.answer,
    required this.language,
    required this.mode,
    this.comment = '',
  });

  final ReportReason reason;

  /// What the person asked; empty when the answer followed something they
  /// did on a surface.
  final String question;

  /// What answered, as the model sent it: see `Session.answerOf`.
  final String answer;

  /// Anything the person adds.
  final String comment;

  /// The language of the answers: `es` or `en`.
  final String language;

  /// Who answered: `gemini` through Quincena's project, `live` with the
  /// person's own key.
  final String mode;
}

/// Thrown when a report did not arrive.
class ReportNotSent implements Exception {
  const ReportNotSent(this.status);

  /// The HTTP status Firestore answered with.
  final int status;

  @override
  String toString() => 'ReportNotSent($status)';
}

/// Sends reports about answers to DL SOFT, into a collection of Quincena's
/// Firebase project that the app can add to and never read.
///
/// The collection's rules, in `firestore.rules`, take these fields and no
/// others, within these sizes, and only from an app App Check vouches for.
/// Each report says when it expires, 90 days on, and Firestore deletes it
/// then. Nothing in it says who sent it: no account, no device.
///
/// Firestore's REST API carries it, so the app needs no database client:
/// a report is one request, and nothing is ever read back.
class AnswerReports {
  AnswerReports({
    http.Client? client,
    Future<String?> Function()? token,
    DateTime Function()? now,
    this.timeout = const Duration(seconds: 20),
  }) : _client = client ?? http.Client(),
       _token = token ?? _appCheckToken,
       _now = now ?? DateTime.now;

  /// The longest question, answer and comment a report keeps, in UTF-16
  /// code units; `firestore.rules` allows the same.
  static const int maxQuestion = 2000;
  static const int maxAnswer = 40000;
  static const int maxComment = 1000;

  /// How long a report is kept before Firestore deletes it.
  static const Duration kept = Duration(days: 90);

  /// Where Quincena has a Firebase app to send them through.
  static bool get supported => Cloud.supported;

  /// The one the app uses, made the first time it is needed.
  static AnswerReports? get standard =>
      supported ? _standard ??= AnswerReports() : null;
  static AnswerReports? _standard;

  static final Uri _endpoint = Uri.parse(
    'https://firestore.googleapis.com/v1/projects/quincena-dlsoft/'
    'databases/(default)/documents/reports',
  );

  final http.Client _client;
  final Future<String?> Function() _token;
  final DateTime Function() _now;
  final Duration timeout;

  /// Sends [report]. Throws when it did not arrive.
  Future<void> send(AnswerReport report) async {
    final String? token = await _token();
    final http.Response response = await _client
        .post(
          _endpoint,
          headers: <String, String>{
            'Content-Type': 'application/json',
            'X-Firebase-AppCheck': ?token,
          },
          body: jsonEncode(<String, Object?>{'fields': fields(report)}),
        )
        .timeout(timeout);
    if (response.statusCode != 200) throw ReportNotSent(response.statusCode);
  }

  /// The document, as Firestore's REST API takes it.
  @visibleForTesting
  Map<String, Object?> fields(AnswerReport report) {
    Map<String, Object?> text(String value) => <String, Object?>{
      'stringValue': value,
    };
    return <String, Object?>{
      'reason': text(report.reason.name),
      'question': text(cut(report.question.trim(), maxQuestion)),
      'answer': text(cut(report.answer, maxAnswer)),
      'comment': text(cut(report.comment.trim(), maxComment)),
      'language': text(report.language),
      'mode': text(report.mode),
      'platform': text(platform),
      'version': text(appVersion),
      'expireAt': <String, Object?>{
        'timestampValue': _now().toUtc().add(kept).toIso8601String(),
      },
    };
  }

  /// What the report says it was sent from.
  @visibleForTesting
  static String get platform => kIsWeb
      ? 'web'
      : switch (defaultTargetPlatform) {
          TargetPlatform.android => 'android',
          TargetPlatform.iOS => 'ios',
          TargetPlatform.macOS => 'macos',
          _ => 'other',
        };

  /// [text], at most [max] UTF-16 code units long: cut short with an
  /// ellipsis, never in the middle of a character.
  @visibleForTesting
  static String cut(String text, int max) {
    if (text.length <= max) return text;
    var end = max - 1;
    final int last = text.codeUnitAt(end - 1);
    // A high surrogate with its other half cut off is no character at all.
    if (last >= 0xD800 && last <= 0xDBFF) end--;
    return '${text.substring(0, end)}…';
  }

  /// Firestore wants App Check's word that the request comes from Quincena,
  /// as the questions to Gemini do.
  static Future<String?> _appCheckToken() async {
    if (!await Cloud.start()) return null;
    return FirebaseAppCheck.instance.getToken();
  }
}
