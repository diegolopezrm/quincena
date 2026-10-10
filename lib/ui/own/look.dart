import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';

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
  Widget build(BuildContext context) => IconTile(accountIcon(kind), size: size);
}

/// [icon] on a soft rounded square, in ink: it only says what a row is
/// about, so it takes none of the colors that mean something. A tint of
/// ink rather than a fill of its own, so it shows on the canvas and on a
/// sheet alike.
class IconTile extends StatelessWidget {
  const IconTile(this.icon, {super.key, this.size = 40});

  final IconData icon;
  final double size;

  @override
  Widget build(BuildContext context) => ExcludeSemantics(
    child: Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: context.colors.ink.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(size * 0.3),
      ),
      alignment: Alignment.center,
      child: Icon(icon, size: size * 0.5, color: context.colors.inkSoft),
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
  Widget build(BuildContext context) {
    final Widget label = Semantics(
      header: true,
      child: Text(text.toUpperCase(), style: context.type.labelSmall),
    );
    return Padding(
      // At the margin, where a list's rows and a card's edge start.
      padding: const EdgeInsets.only(bottom: 8),
      // With large text the button goes under the title when the two do
      // not fit side by side.
      child: trailing != null && largeText(context)
          ? SizedBox(
              width: double.infinity,
              child: Wrap(
                alignment: WrapAlignment.spaceBetween,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: <Widget>[label, ?trailing],
              ),
            )
          : Row(
              children: <Widget>[
                Expanded(child: label),
                ?trailing,
              ],
            ),
    );
  }
}

/// A row that opens what it names, read as one button: its icon in ink in
/// a column of its own, the name with a line under it, and a caret. With
/// large text the icon goes above the name, as iOS lays out its own rows at
/// those sizes, and the words have the whole width.
class LinkRow extends StatelessWidget {
  const LinkRow({
    super.key,
    required this.icon,
    required this.title,
    required this.onTap,
    this.detail,
    this.warning,
  });

  final IconData icon;
  final String title;
  final VoidCallback onTap;
  final String? detail;

  /// A line under [detail] in amber, for what the row is missing.
  final String? warning;

  @override
  Widget build(BuildContext context) {
    final bool large = largeText(context);
    final Widget mark = Icon(icon, color: context.colors.inkSoft);
    return InkWell(
      onTap: onTap,
      child: Semantics(
        button: true,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 9),
          child: Row(
            children: <Widget>[
              if (!large) ...<Widget>[
                SizedBox(width: 40, child: mark),
                const SizedBox(width: 12),
              ],
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    if (large) ...<Widget>[mark, const SizedBox(height: 4)],
                    Text(title, style: context.type.titleSmall),
                    if (detail case final String text)
                      Text(text, style: context.type.bodySmall),
                    if (warning case final String text)
                      Text(
                        text,
                        style: context.type.bodySmall?.copyWith(
                          color: context.colors.caution,
                        ),
                      ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Icon(Glyph.caretRight, size: 18, color: context.colors.inkFaint),
            ],
          ),
        ),
      ),
    );
  }
}

/// A group of rows with a line between them.
///
/// A list or a group of settings goes without a box: its rows sit on the
/// screen, reach past the margin so a row lights up across its width, and
/// keep their text in line with the text around the list. [boxed] puts the
/// rows on a rounded card instead, for what asks a decision or warns, as
/// the things to do on Inicio.
class Panel extends StatelessWidget {
  const Panel({
    super.key,
    required this.children,
    this.padding,
    this.indent = 68,
    this.boxed = false,
  });

  final List<Widget> children;
  final EdgeInsetsGeometry? padding;

  /// Where the line between rows starts: after the icon of a row that has
  /// one, at the text of a row that does not.
  final double indent;

  /// Whether the rows sit on a card, for a decision or a warning.
  final bool boxed;

  /// How far rows without a box reach past the margin on each side: the
  /// room each row keeps at its sides, so its text starts at the margin.
  static const double reach = 16;

  @override
  Widget build(BuildContext context) {
    final Widget rows = Padding(
      padding: padding ?? EdgeInsets.zero,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          for (var i = 0; i < children.length; i++) ...<Widget>[
            if (i > 0)
              Divider(
                height: 1,
                indent: indent,
                // Without a box the line ends where the text does.
                endIndent: boxed ? 0 : reach,
                color: context.colors.line,
              ),
            children[i],
          ],
        ],
      ),
    );
    if (!boxed) {
      return _Reach(
        by: reach,
        child: Material(type: MaterialType.transparency, child: rows),
      );
    }
    return Material(
      color: context.colors.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: BorderSide(color: context.colors.line),
      ),
      clipBehavior: Clip.antiAlias,
      child: rows,
    );
  }
}

/// Lays [child] out [by] wider on each side than the room it is given and
/// centered on it, so rows without a box reach past the margin the text
/// around them keeps. Where the room has no edge, it takes the room as it
/// is.
class _Reach extends SingleChildRenderObjectWidget {
  const _Reach({required this.by, super.child});

  final double by;

  @override
  RenderObject createRenderObject(BuildContext context) => _RenderReach(by);

  @override
  void updateRenderObject(BuildContext context, _RenderReach renderObject) {
    renderObject.by = by;
  }
}

class _RenderReach extends RenderShiftedBox {
  _RenderReach(this._by) : super(null);

  double _by;
  set by(double value) {
    if (value == _by) return;
    _by = value;
    markNeedsLayout();
  }

  /// How much wider the child is than this, both sides together.
  double _extra(BoxConstraints constraints) =>
      constraints.hasBoundedWidth ? 2 * _by : 0;

  BoxConstraints _inner(BoxConstraints constraints) {
    final double extra = _extra(constraints);
    return BoxConstraints(
      minWidth: constraints.minWidth + extra,
      maxWidth: constraints.maxWidth + extra,
      minHeight: constraints.minHeight,
      maxHeight: constraints.maxHeight,
    );
  }

  @override
  double computeMinIntrinsicWidth(double height) =>
      math.max(0, super.computeMinIntrinsicWidth(height) - 2 * _by);

  @override
  double computeMaxIntrinsicWidth(double height) =>
      math.max(0, super.computeMaxIntrinsicWidth(height) - 2 * _by);

  @override
  double computeMinIntrinsicHeight(double width) =>
      super.computeMinIntrinsicHeight(width + 2 * _by);

  @override
  double computeMaxIntrinsicHeight(double width) =>
      super.computeMaxIntrinsicHeight(width + 2 * _by);

  @override
  Size computeDryLayout(BoxConstraints constraints) {
    final RenderBox? child = this.child;
    if (child == null) return constraints.smallest;
    final Size inner = child.getDryLayout(_inner(constraints));
    return constraints.constrain(
      Size(inner.width - _extra(constraints), inner.height),
    );
  }

  @override
  void performLayout() {
    final RenderBox? child = this.child;
    if (child == null) {
      size = constraints.smallest;
      return;
    }
    final double extra = _extra(constraints);
    child.layout(_inner(constraints), parentUsesSize: true);
    size = constraints.constrain(
      Size(child.size.width - extra, child.size.height),
    );
    (child.parentData! as BoxParentData).offset = Offset(-extra / 2, 0);
  }
}

/// A screen's floating button, out of the way while the list under it
/// scrolls down, so it never sits on an amount, and back when the list
/// scrolls up or reaches its top or its end. It follows every scroll of
/// its Scaffold, a jump included. With a screen reader on it stays, and
/// with reduced motion it goes and comes without moving.
class ScrollAwareFab extends StatefulWidget {
  const ScrollAwareFab({super.key, required this.child});

  /// The button; one with another key, as on another tab, starts in sight.
  final Widget child;

  @override
  State<ScrollAwareFab> createState() => _ScrollAwareFabState();
}

class _ScrollAwareFabState extends State<ScrollAwareFab> {
  ScrollNotificationObserverState? _observer;
  bool _shown = true;

  /// How far the list has gone in its latest direction, down positive.
  double _run = 0;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _observer?.removeListener(_onScroll);
    _observer = ScrollNotificationObserver.maybeOf(context);
    _observer?.addListener(_onScroll);
  }

  @override
  void didUpdateWidget(ScrollAwareFab oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.child.key != oldWidget.child.key) {
      _shown = true;
      _run = 0;
    }
  }

  @override
  void dispose() {
    _observer?.removeListener(_onScroll);
    super.dispose();
  }

  void _onScroll(ScrollNotification notification) {
    if (notification is! ScrollUpdateNotification ||
        notification.depth != 0 ||
        notification.metrics.axis != Axis.vertical) {
      return;
    }
    final ScrollMetrics m = notification.metrics;
    final double delta = notification.scrollDelta ?? 0;
    _run = delta.sign == _run.sign ? _run + delta : delta;
    // A few points of slack, so a finger at rest does not flicker it.
    final bool shown = switch (_run) {
      _ when m.extentBefore <= 0 || m.extentAfter < 24 => true,
      > 16 => false,
      < -16 => true,
      _ => _shown,
    };
    if (shown != _shown) setState(() => _shown = shown);
  }

  @override
  Widget build(BuildContext context) {
    // A screen reader moves through the screen without scrolling it.
    final bool shown = _shown || MediaQuery.accessibleNavigationOf(context);
    final Duration duration = MediaQuery.disableAnimationsOf(context)
        ? Duration.zero
        : const Duration(milliseconds: 200);
    return IgnorePointer(
      ignoring: !shown,
      child: ExcludeFocus(
        excluding: !shown,
        child: ExcludeSemantics(
          excluding: !shown,
          // Out of sight, it does not fly to the next page's button either.
          child: HeroMode(
            enabled: shown,
            child: AnimatedSlide(
              offset: shown ? Offset.zero : const Offset(0, 2),
              duration: duration,
              curve: Curves.easeOutCubic,
              child: AnimatedOpacity(
                opacity: shown ? 1 : 0,
                duration: duration,
                child: widget.child,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// The large figure at the top of a screen, with a caption above it.
class Headline extends StatelessWidget {
  const Headline({
    super.key,
    required this.caption,
    required this.value,
    this.detail,
    this.onExplain,
    this.unit,
    this.counting,
  });

  final String caption;
  final String value;
  final String? detail;

  /// [value] as a number and the way to write it, when the figure should
  /// count its way to a new value, as Inicio's does.
  final (double, String Function(double value))? counting;

  /// Shows where [value] comes from.
  final VoidCallback? onExplain;

  /// The currency of [value], written as its code after it on a screen
  /// that mixes currencies, where a bare `$` could be any of them; read out
  /// by its name.
  final Asset? unit;

  @override
  Widget build(BuildContext context) {
    final Widget figure = switch (counting) {
      (final double amount, final String Function(double) format) =>
        CountingFigures(
          value: amount,
          format: format,
          style: context.type.displayMedium,
        ),
      null => Figures(value, style: context.type.displayMedium),
    };
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text(caption, style: context.type.labelMedium),
        const SizedBox(height: 4),
        FittedBox(
          fit: BoxFit.scaleDown,
          alignment: Alignment.centerLeft,
          child: switch (unit) {
            null => figure,
            final Asset unit => MergeSemantics(
              child: Row(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.baseline,
                textBaseline: TextBaseline.alphabetic,
                children: <Widget>[
                  figure,
                  const SizedBox(width: 6),
                  Text(
                    unit.code,
                    semanticsLabel: unit.name(
                      Localizations.localeOf(context).languageCode,
                    ),
                    style: context.type.labelLarge?.copyWith(
                      color: context.colors.inkSoft,
                    ),
                  ),
                ],
              ),
            ),
          },
        ),
        if (detail != null) ...<Widget>[
          const SizedBox(height: 4),
          Text(detail!, style: context.type.bodySmall),
        ],
        if (onExplain case final VoidCallback explain)
          TextButton.icon(
            onPressed: explain,
            style: TextButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 4),
            ),
            icon: const Icon(Glyph.info, size: 18),
            label: Text(context.l10n.freeExplainAction),
          ),
      ],
    );
  }
}
