// Where the app goes when the person backs out of onboarding or deletes
// everything: the first screen, or the sample where the app opens on it,
// as the web does, which never shows that screen.
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:quincena/app_mode.dart';
import 'package:quincena/store/database.dart';
import 'package:quincena/store/store.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  Future<AppModeController> open({required bool startInDemo}) async {
    final QuincenaStore store = QuincenaStore(
      QuincenaDatabase(NativeDatabase.memory()),
    );
    addTearDown(store.close);
    final AppModeController modes = AppModeController(
      store: store,
      startInDemo: startInDemo,
    );
    addTearDown(modes.dispose);
    await modes.start();
    return modes;
  }

  test('where the app opens on the sample, it never reaches the first '
      'screen', () async {
    final AppModeController modes = await open(startInDemo: true);
    expect(modes.mode, AppMode.demo);

    await modes.useOwn();
    expect(modes.mode, AppMode.onboarding);
    modes.cancelOnboarding();
    await pumpEventQueue();
    expect(modes.mode, AppMode.demo);

    await modes.wiped();
    expect(modes.mode, AppMode.demo);
    expect(modes.hasOwn, isFalse);
  });

  test('elsewhere, both go back to the first screen', () async {
    final AppModeController modes = await open(startInDemo: false);
    expect(modes.mode, AppMode.choosing);

    await modes.useOwn();
    expect(modes.mode, AppMode.onboarding);
    modes.cancelOnboarding();
    expect(modes.mode, AppMode.choosing);

    await modes.wiped();
    expect(modes.mode, AppMode.choosing);
  });
}
