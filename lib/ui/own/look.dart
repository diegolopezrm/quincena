import 'package:flutter/material.dart';

import '../../domain/categories.dart';
import '../../domain/records.dart';
import '../../l10n/l10n.dart';
import '../../money/asset.dart';
import '../../money/money.dart';
import '../../theme/tokens.dart';
import '../icons.dart';
import '../kit.dart';

IconData accountIcon(AccountKind kind) => switch (kind) {
  AccountKind.bank => Glyph.bank,
  AccountKind.card => Glyph.creditCard,
  AccountKind.cash => Glyph.money,
  AccountKind.wallet => Glyph.wallet,
  AccountKind.exchange => Glyph.currencyBtc,
  AccountKind.investment => Glyph.chartLineUp,
  AccountKind.other => Glyph.coins,
};

String accountKindLabel(BuildContext context, AccountKind kind) {
  final AppLocalizations l = context.l10n;
  return switch (kind) {
    AccountKind.bank => l.kindBank,
    AccountKind.card => l.kindCard,
    AccountKind.cash => l.kindCash,
    AccountKind.wallet => l.kindWallet,
    AccountKind.exchange => l.kindExchange,
    AccountKind.investment => l.kindInvestment,
    AccountKind.other => l.kindOther,
  };
}

const Map<String, IconData> _incomeIcons = <String, IconData>{
  'salary': Glyph.briefcase,
  'freelance': Glyph.handCoins,
  'interest': Glyph.percent,
  'refund': Glyph.arrowCounterClockwise,
  'gift': Glyph.gift,
  'other_income': Glyph.coins,
};

/// The icon of the category with [key]; a transfer when there is none.
IconData categoryIconFor(String? key) {
  if (key == null) return Glyph.arrowsLeftRight;
  return expenseCategory(key)?.icon ?? _incomeIcons[key] ?? Glyph.tag;
}

/// The color of the category with [key]: its own for a built-in expense,
/// the brand's for income, one of the palette's for the person's own.
Color categoryColorFor(BuildContext context, String? key) {
  final QuincenaColors c = context.colors;
  if (key == null) return c.inkSoft;
  if (expenseCategory(key) != null) return c.category(key);
  if (isIncomeCategory(key)) return c.positive;
  final List<Color> palette = c.categories.values.toList();
  return palette[key.hashCode.abs() % palette.length];
}

/// What the person calls the category with [key].
String categoryNameFor(
  BuildContext context,
  String key,
  List<CategoryItem> categories,
) {
  String? custom;
  for (final CategoryItem c in categories) {
    if (c.key == key) custom = c.name;
  }
  return categoryLabel(
    key,
    Localizations.localeOf(context).languageCode,
    custom: custom,
  );
}

/// A category's icon on a soft disc of its color.
class CategoryDisc extends StatelessWidget {
  const CategoryDisc(this.categoryKey, {super.key, this.size = 40});

  final String? categoryKey;
  final double size;

  @override
  Widget build(BuildContext context) {
    final Color color = categoryColorFor(context, categoryKey);
    return ExcludeSemantics(
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.14),
          shape: BoxShape.circle,
        ),
        alignment: Alignment.center,
        child: Icon(
          categoryIconFor(categoryKey),
          size: size * 0.5,
          color: color,
        ),
      ),
    );
  }
}

/// An account kind's icon on a soft rounded square.
class AccountTile extends StatelessWidget {
  const AccountTile(this.kind, {super.key, this.size = 40});

  final AccountKind kind;
  final double size;

  @override
  Widget build(BuildContext context) => ExcludeSemantics(
    child: Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: context.colors.brandSoft,
        borderRadius: BorderRadius.circular(size * 0.3),
      ),
      alignment: Alignment.center,
      child: Icon(
        accountIcon(kind),
        size: size * 0.5,
        color: context.colors.brand,
      ),
    ),
  );
}

/// [money] written for the screen, with [base] deciding whose `$` is bare.
String moneyText(Money money, {Asset? base, bool signed = false}) =>
    formatAmount(money.amount, money.asset, base: base, signed: signed);

/// A section title over a group of rows.
class SectionLabel extends StatelessWidget {
  const SectionLabel(this.text, {super.key, this.trailing});

  final String text;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(4, 0, 4, 10),
    child: Row(
      children: <Widget>[
        Expanded(
          child: Semantics(
            header: true,
            child: Text(text.toUpperCase(), style: context.type.labelSmall),
          ),
        ),
        ?trailing,
      ],
    ),
  );
}

/// A rounded group of rows on the surface color.
class Panel extends StatelessWidget {
  const Panel({
    super.key,
    required this.children,
    this.padding,
    this.indent = 68,
  });

  final List<Widget> children;
  final EdgeInsetsGeometry? padding;

  /// Where the line between rows starts: after the icon of a row that has
  /// one, at the text of a row that does not.
  final double indent;

  @override
  Widget build(BuildContext context) => Material(
    color: context.colors.surface,
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(20),
      side: BorderSide(color: context.colors.line),
    ),
    clipBehavior: Clip.antiAlias,
    child: Padding(
      padding: padding ?? EdgeInsets.zero,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          for (var i = 0; i < children.length; i++) ...<Widget>[
            if (i > 0)
              Divider(height: 1, indent: indent, color: context.colors.line),
            children[i],
          ],
        ],
      ),
    ),
  );
}

/// The large figure at the top of a screen, with a caption above it.
class Headline extends StatelessWidget {
  const Headline({
    super.key,
    required this.caption,
    required this.value,
    this.detail,
  });

  final String caption;
  final String value;
  final String? detail;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: <Widget>[
      Text(caption, style: context.type.labelMedium),
      const SizedBox(height: 4),
      FittedBox(
        fit: BoxFit.scaleDown,
        alignment: Alignment.centerLeft,
        child: Figures(value, style: context.type.displayMedium),
      ),
      if (detail != null) ...<Widget>[
        const SizedBox(height: 4),
        Text(detail!, style: context.type.bodySmall),
      ],
    ],
  );
}
