import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:quincena/version.dart';

void main() {
  test('the version the app reports is the one in pubspec.yaml', () {
    final String pubspec = File('pubspec.yaml').readAsStringSync();
    final String version = RegExp(
      r'^version:\s*(\S+)',
      multiLine: true,
    ).firstMatch(pubspec)!.group(1)!;
    expect(appVersion, version);
  });
}
