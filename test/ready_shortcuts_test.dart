import 'package:flutter_test/flutter_test.dart';
import 'package:quincena/capture/ready_shortcuts.dart';

void main() {
  test('the major iOS version is read from what iOS reports', () {
    expect(parseIosMajor('Version 27.0 (Build 24A335)'), 27);
    expect(parseIosMajor('Version 26.1 (Build 23B86)'), 26);
    expect(parseIosMajor('Darwin Kernel'), isNull);
  });

  test('iOS 27 gets the shortcuts with a trigger, iOS 26 the others', () {
    for (final ReadyShortcut s in ReadyShortcut.forIos(27)) {
      expect(s.withTrigger, isTrue);
    }
    for (final ReadyShortcut s in ReadyShortcut.forIos(26)) {
      expect(s.withTrigger, isFalse);
    }
  });

  test('iOS 27 offers every capture, each from its own link', () {
    final List<ReadyShortcut> ready = ReadyShortcut.forIos(27);
    expect(ready, <ReadyShortcut>[
      ReadyShortcut.bankNotifications,
      ReadyShortcut.bankMessages,
      ReadyShortcut.applePay,
      ReadyShortcut.screenshots,
    ]);
    expect(ready.map((ReadyShortcut s) => s.link).toSet(), hasLength(4));
  });

  test('a shortcut with no link yet is not offered', () {
    for (final ReadyShortcut s in <ReadyShortcut>[
      ...ReadyShortcut.forIos(27),
      ...ReadyShortcut.forIos(26),
    ]) {
      expect(s.link, startsWith('https://www.icloud.com/shortcuts/'));
    }
  });
}
