import 'package:flutter/services.dart';

import '../../l10n/l10n.dart';
import '../../money/asset.dart';

/// What goes before an amount typed in [asset], the same in every form:
/// its sign and a space, as in `$ 80.000`, or nothing for a currency
/// without one, whose code goes after the amount instead.
String? amountPrefix(Asset asset) =>
    switch (asset.localSymbol ?? asset.symbol) {
      final String sign => '$sign ',
      null => null,
    };

/// Groups the thousands of an amount as it is typed: `45900` shows as
/// `45.900` in Spanish and `45,900` in English.
///
/// Only digits and one decimal separator get through. A group separator
/// typed where a decimal could go becomes one, since some keypads offer the
/// point and not the comma.
class AmountInputFormatter extends TextInputFormatter {
  AmountInputFormatter({this.maxDecimals = 8, this.english});

  final int maxDecimals;

  /// The language's separators to use; the interface's when null.
  final bool? english;

  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    final bool en = english ?? englishFormatting;
    final String point = en ? '.' : ',';
    final String group = en ? ',' : '.';
    String text = newValue.text;
    final bool typedGroupAtEnd =
        text.length == oldValue.text.length + 1 &&
        text.endsWith(group) &&
        !oldValue.text.contains(point);
    if (typedGroupAtEnd && maxDecimals > 0) {
      text = '${text.substring(0, text.length - 1)}$point';
    }
    text = text.replaceAll(group, '');
    final int at = text.indexOf(point);
    String whole = (at < 0 ? text : text.substring(0, at)).replaceAll(
      RegExp(r'[^0-9]'),
      '',
    );
    String? decimals = at < 0
        ? null
        : text.substring(at + 1).replaceAll(RegExp(r'[^0-9]'), '');
    if (decimals != null && decimals.length > maxDecimals) {
      decimals = decimals.substring(0, maxDecimals);
    }
    if (whole.length > 1) whole = whole.replaceFirst(RegExp(r'^0+(?=\d)'), '');
    if (whole.isEmpty && decimals != null) whole = '0';
    final StringBuffer out = StringBuffer();
    for (var i = 0; i < whole.length; i++) {
      if (i > 0 && (whole.length - i) % 3 == 0) out.write(group);
      out.write(whole[i]);
    }
    if (decimals != null && maxDecimals > 0) out.write('$point$decimals');
    final String formatted = out.toString();
    return TextEditingValue(
      text: formatted,
      selection: TextSelection.collapsed(offset: formatted.length),
    );
  }
}
