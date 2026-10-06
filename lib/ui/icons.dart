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
  static const IconData flag = IconData(0xe244, fontFamily: _family);
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
  static const IconData sparkle = IconData(0xe6a2, fontFamily: _family);
  static const IconData paperPlaneRight = IconData(0xe396, fontFamily: _family);

  // For the screens around the conversation: accounts, movements, settings.
  static const IconData briefcase = IconData(0xe0ee, fontFamily: _family);
  static const IconData coins = IconData(0xe78e, fontFamily: _family);
  static const IconData gift = IconData(0xe276, fontFamily: _family);
  static const IconData percent = IconData(0xe3b6, fontFamily: _family);
  static const IconData receipt = IconData(0xe3ec, fontFamily: _family);
  static const IconData bank = IconData(0xe0b4, fontFamily: _family);
  static const IconData creditCard = IconData(0xe1d2, fontFamily: _family);
  static const IconData wallet = IconData(0xe68a, fontFamily: _family);
  static const IconData money = IconData(0xe588, fontFamily: _family);
  static const IconData currencyBtc = IconData(0xe618, fontFamily: _family);
  static const IconData arrowsLeftRight = IconData(0xe0a0, fontFamily: _family);
  static const IconData arrowDown = IconData(0xe03e, fontFamily: _family);
  static const IconData arrowUp = IconData(0xe08e, fontFamily: _family);
  static const IconData trendUp = IconData(0xe4ae, fontFamily: _family);
  static const IconData trendDown = IconData(0xe4ac, fontFamily: _family);
  static const IconData pencilSimple = IconData(0xe3b4, fontFamily: _family);
  static const IconData trash = IconData(0xe4a6, fontFamily: _family);
  static const IconData plus = IconData(0xe3d4, fontFamily: _family);
  static const IconData list = IconData(0xe2f0, fontFamily: _family);
  static const IconData magnifyingGlass = IconData(0xe30c, fontFamily: _family);
  static const IconData calendar = IconData(0xe108, fontFamily: _family);
  static const IconData user = IconData(0xe4c2, fontFamily: _family);
  static const IconData x = IconData(0xe4f6, fontFamily: _family);
  static const IconData check = IconData(0xe182, fontFamily: _family);
  static const IconData checks = IconData(0xe53a, fontFamily: _family);
  static const IconData caretRight = IconData(0xe13a, fontFamily: _family);
  static const IconData caretDown = IconData(0xe136, fontFamily: _family);
  static const IconData export = IconData(0xeaf0, fontFamily: _family);
  static const IconData downloadSimple = IconData(0xe20c, fontFamily: _family);
  static const IconData uploadSimple = IconData(0xe4c0, fontFamily: _family);
  static const IconData warning = IconData(0xe4e0, fontFamily: _family);
  static const IconData tray = IconData(0xe4aa, fontFamily: _family);
  static const IconData handCoins = IconData(0xea8c, fontFamily: _family);
  static const IconData vault = IconData(0xe76e, fontFamily: _family);
  static const IconData chartLineUp = IconData(0xe156, fontFamily: _family);
  static const IconData tag = IconData(0xe478, fontFamily: _family);
  static const IconData coin = IconData(0xe60e, fontFamily: _family);
  static const IconData squaresFour = IconData(0xe464, fontFamily: _family);
  static const IconData listBullets = IconData(0xe2f2, fontFamily: _family);
  static const IconData notePencil = IconData(0xe34c, fontFamily: _family);
  static const IconData clipboardText = IconData(0xe198, fontFamily: _family);
  static const IconData arrowLeft = IconData(0xe058, fontFamily: _family);
  static const IconData dotsThreeVertical = IconData(
    0xe208,
    fontFamily: _family,
  );
  static const IconData lock = IconData(0xe2fa, fontFamily: _family);
  static const IconData globe = IconData(0xe288, fontFamily: _family);
  static const IconData deviceMobile = IconData(0xe1e0, fontFamily: _family);
  static const IconData mapPin = IconData(0xe316, fontFamily: _family);
  static const IconData clock = IconData(0xe19a, fontFamily: _family);
  static const IconData envelope = IconData(0xe214, fontFamily: _family);
  static const IconData bell = IconData(0xe0ce, fontFamily: _family);
  static const IconData camera = IconData(0xe10e, fontFamily: _family);
  static const IconData fileText = IconData(0xe23a, fontFamily: _family);
  static const IconData repeat = IconData(0xe3f6, fontFamily: _family);
  static const IconData calendarCheck = IconData(0xe712, fontFamily: _family);
  static const IconData signOut = IconData(0xe42a, fontFamily: _family);
  static const IconData arrowsDownUp = IconData(0xe098, fontFamily: _family);
  static const IconData scales = IconData(0xe750, fontFamily: _family);
  static const IconData currencyEth = IconData(0xeada, fontFamily: _family);
  static const IconData arrowUpRight = IconData(0xe092, fontFamily: _family);
  static const IconData image = IconData(0xe2ca, fontFamily: _family);
  static const IconData scan = IconData(0xebb6, fontFamily: _family);
  static const IconData filePdf = IconData(0xe702, fontFamily: _family);
  static const IconData pause = IconData(0xe39e, fontFamily: _family);
  static const IconData play = IconData(0xe3d0, fontFamily: _family);
  static const IconData bellSlash = IconData(0xe0d4, fontFamily: _family);
  static const IconData hourglass = IconData(0xe2b2, fontFamily: _family);
  static const IconData usersThree = IconData(0xe68e, fontFamily: _family);
  static const IconData handshake = IconData(0xe582, fontFamily: _family);
  static const IconData suitcaseRolling = IconData(0xe9b0, fontFamily: _family);
  static const IconData shareNetwork = IconData(0xe408, fontFamily: _family);
  static const IconData minusCircle = IconData(0xe32c, fontFamily: _family);
}
