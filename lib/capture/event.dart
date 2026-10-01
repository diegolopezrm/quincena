import 'package:flutter/foundation.dart';

/// Where a captured event came from.
enum CaptureSource {
  /// An Apple Pay payment, from the Wallet automation in iOS Shortcuts.
  wallet,

  /// A notification from a bank's or a wallet's app.
  notification,

  /// A text message.
  sms,

  /// An email, often only its subject.
  email,

  /// Text read from a screenshot.
  screenshot,

  /// Text the person pasted or shared into the app.
  paste;

  static CaptureSource parse(String? value) => switch (value?.toLowerCase()) {
    'wallet' || 'apple_pay' || 'applepay' => CaptureSource.wallet,
    'notification' || 'notificacion' || 'push' => CaptureSource.notification,
    'sms' || 'mensaje' || 'message' => CaptureSource.sms,
    'email' || 'correo' || 'mail' => CaptureSource.email,
    'screenshot' ||
    'captura_pantalla' ||
    'imagen_compartida' => CaptureSource.screenshot,
    _ => CaptureSource.paste,
  };
}

/// Something a source saw that may be a movement, as it arrived.
///
/// Every field but [source], [at] and [text] is optional: a Wallet payment
/// brings a merchant and an amount already separated, a notification brings
/// a title and a body, a pasted message brings only text. The raw form is
/// kept as it came, so a better parser can read it again later.
@immutable
class CaptureEvent {
  const CaptureEvent({
    required this.source,
    required this.at,
    required this.text,
    this.app,
    this.appName,
    this.title,
    this.sender,
    this.merchant,
    this.amount,
    this.card,
    this.latitude,
    this.longitude,
    this.accuracy,
  });

  final CaptureSource source;

  /// When it arrived on the device.
  final DateTime at;

  /// Everything readable in it, joined: title, subtitle, body or the
  /// message. The parser reads this.
  final String text;

  /// The app that posted it (a package name on Android, a name on iOS).
  final String? app;

  /// The name people know [app] by, when the platform says.
  final String? appName;
  final String? title;

  /// Who sent the SMS or the email.
  final String? sender;

  /// Fields a structured source fills in directly.
  final String? merchant;
  final String? amount;
  final String? card;

  /// Where the phone was when it arrived, when the person allowed it.
  final double? latitude;
  final double? longitude;

  /// How many metres the location may be off.
  final double? accuracy;

  bool get hasLocation => latitude != null && longitude != null;

  Map<String, Object?> toJson() => <String, Object?>{
    'source': source.name,
    'at': at.toIso8601String(),
    'text': text,
    if (app != null) 'app': app,
    if (appName != null) 'appName': appName,
    if (title != null) 'title': title,
    if (sender != null) 'sender': sender,
    if (merchant != null) 'merchant': merchant,
    if (amount != null) 'amount': amount,
    if (card != null) 'card': card,
    if (latitude != null) 'lat': latitude,
    if (longitude != null) 'lng': longitude,
    if (accuracy != null) 'accuracy': accuracy,
  };

  /// Reads an event as the native side or the iOS shortcuts write it. The
  /// Spanish keys are the ones the first experiment with shortcuts used.
  static CaptureEvent fromJson(Map<String, Object?> json) {
    String? str(List<String> keys) {
      for (final String k in keys) {
        final Object? v = json[k];
        if (v is String && v.trim().isNotEmpty) return v.trim();
      }
      return null;
    }

    double? number(List<String> keys) {
      for (final String k in keys) {
        final Object? v = json[k];
        if (v is num) return v.toDouble();
        if (v is String) {
          final double? parsed = double.tryParse(v.replaceAll(',', '.'));
          if (parsed != null) return parsed;
        }
      }
      return null;
    }

    final String? title = str(<String>['title', 'titulo']);
    final String? subtitle = str(<String>['subtitle', 'subtitulo']);
    final String? body = str(<String>['body', 'cuerpo', 'contenido']);
    final String? subject = str(<String>['subject', 'asunto']);
    final String? merchant = str(<String>['merchant', 'comercio']);
    final String? amount = str(<String>['amount', 'monto']);
    final String? card = str(<String>['card', 'tarjeta']);
    final String text =
        str(<String>['text', 'texto']) ??
        <String?>[
          title,
          subtitle,
          body,
          subject,
          merchant,
          amount,
          card,
        ].whereType<String>().join(' · ');
    return CaptureEvent(
      source: CaptureSource.parse(str(<String>['source', 'fuente'])),
      at:
          DateTime.tryParse(
            str(<String>['at', 'ts', 'fecha']) ?? '',
          )?.toLocal() ??
          DateTime.now(),
      text: text,
      app: str(<String>['app', 'package']),
      appName: str(<String>['appName', 'app_name']),
      title: title,
      sender: str(<String>['sender', 'remitente']),
      merchant: merchant,
      amount: amount,
      card: card,
      latitude: number(<String>['lat', 'latitude', 'latitud']),
      longitude: number(<String>['lng', 'lon', 'longitude', 'longitud']),
      accuracy: number(<String>['accuracy', 'precision']),
    );
  }
}
