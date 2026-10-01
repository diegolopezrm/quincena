import 'package:flutter/widgets.dart';

/// The icons Quincena uses, from Phosphor's regular weight.
///
/// The font ships with the app (MIT license, next to the file in
/// `assets/icons`) and the code points are Phosphor's own. `phosphor_flutter`
/// would provide the same glyphs, but its icon class extends `IconData`,
/// which Flutter made final, and it has not been released since May 2024.
abstract final class Glyph {
  static const String _family = 'Phosphor';

  static const IconData house = IconData(0xe2c2, fontFamily: _family);
  static const IconData shoppingCart = IconData(0xe41e, fontFamily: _family);
  static const IconData forkKnife = IconData(0xe262, fontFamily: _family);
  static const IconData train = IconData(0xe496, fontFamily: _family);
  static const IconData lightning = IconData(0xe2de, fontFamily: _family);
  static const IconData arrowsClockwise = IconData(0xe094, fontFamily: _family);
  static const IconData heartbeat = IconData(0xe2ac, fontFamily: _family);
  static const IconData shoppingBag = IconData(0xe416, fontFamily: _family);
  static const IconData ticket = IconData(0xe490, fontFamily: _family);
  static const IconData graduationCap = IconData(0xe62c, fontFamily: _family);
  static const IconData dotsThree = IconData(0xe1fe, fontFamily: _family);
  static const IconData info = IconData(0xe2ce, fontFamily: _family);
  static const IconData checkCircle = IconData(0xe184, fontFamily: _family);
  static const IconData warningCircle = IconData(0xe4e2, fontFamily: _family);
  static const IconData arrowRight = IconData(0xe06c, fontFamily: _family);
  static const IconData airplaneTilt = IconData(0xe5d6, fontFamily: _family);
  static const IconData calendarBlank = IconData(0xe10a, fontFamily: _family);
  static const IconData piggyBank = IconData(0xea04, fontFamily: _family);
  static const IconData chatCircleDots = IconData(0xe16c, fontFamily: _family);
  static const IconData chartDonut = IconData(0xeaa6, fontFamily: _family);
  static const IconData chartBar = IconData(0xe150, fontFamily: _family);
  static const IconData plusCircle = IconData(0xe3d6, fontFamily: _family);
  static const IconData arrowCounterClockwise = IconData(
    0xe038,
    fontFamily: _family,
  );
  static const IconData gear = IconData(0xe270, fontFamily: _family);
  static const IconData paperPlaneRight = IconData(0xe396, fontFamily: _family);
}
