import 'package:decimal/decimal.dart';
import 'package:flutter/material.dart';

import '../../domain/records.dart';
import '../../l10n/l10n.dart';
import '../../money/asset.dart';
import '../../money/money.dart';
import '../../own/own_controller.dart';
import '../../portfolio/cost_basis.dart';
import '../../portfolio/portfolio.dart';
import '../../portfolio/portfolio_controller.dart';
import '../../theme/tokens.dart';
import '../icons.dart';
import '../kit.dart';
import 'look.dart';
import 'portfolio_page.dart';
import 'trade_sheet.dart';

/// What an investment account holds, priced now, against what it cost,
/// with the purchase and the sale a tap away.
class PositionPanel extends StatefulWidget {
  const PositionPanel({super.key, required this.own, required this.account});

  final OwnController own;
  final Account account;

  @override
  State<PositionPanel> createState() => _PositionPanelState();
}

class _PositionPanelState extends State<PositionPanel> {
  PortfolioController get _controller => widget.own.portfolio;

  @override
  void initState() {
    super.initState();
    _controller.watch();
  }

  @override
  void dispose() {
    _controller.unwatch();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: _controller,
    builder: (BuildContext context, _) {
      final AppLocalizations l = context.l10n;
      final Portfolio? p = _controller.portfolio;
      Holding? holding;
      for (final Holding h in p?.holdings ?? const <Holding>[]) {
        if (h.account.id == widget.account.id) holding = h;
      }
      final Asset base = p?.base ?? widget.own.profile?.base ?? Asset.cop;
      final Holding? h = holding;
      final Position? position = h?.position;
      final Pair? price = h?.price;
      final Pair? value = h?.value;
      final Pair? gain = h?.gain;
      final double? ratio = h?.gainRatio;
      final double? day = h?.change24h;
      final Pair? average = position?.averageCost;
      final bool noCost =
          position != null &&
          position.quantity > Decimal.zero &&
          position.cost.base == Decimal.zero;
      String inBase(Decimal amount, {bool signed = false}) =>
          moneyText(Money(amount, base), base: base, signed: signed);

      return Block(
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            Row(
              children: <Widget>[
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Text(l.holdingPrice, style: context.type.labelMedium),
                      Figures(
                        price == null ? '—' : inBase(price.base),
                        style: context.type.titleMedium,
                      ),
                      if (price != null && base.code != 'USD')
                        Figures(
                          moneyText(Money(price.usd, Asset.usd), base: base),
                          style: context.type.bodySmall,
                        ),
                    ],
                  ),
                ),
                if (day != null)
                  Figures(
                    '${percentText(day)} · ${l.rangeDay}',
                    style: context.type.labelMedium?.copyWith(
                      color: changeColor(context, day),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 14),
            Divider(height: 1, color: context.colors.line),
            const SizedBox(height: 12),
            _Line(
              label: l.holdingWorth,
              value: value == null ? '—' : inBase(value.base),
            ),
            _Line(
              label: l.holdingCost,
              value: noCost || position == null
                  ? l.holdingNoCost
                  : inBase(position.cost.base),
            ),
            if (average != null && !noCost)
              _Line(label: l.holdingAverage, value: inBase(average.base)),
            if (gain != null && !noCost)
              _Line(
                label: gain.base >= Decimal.zero
                    ? l.portfolioGain
                    : l.portfolioLoss,
                value: ratio == null
                    ? inBase(gain.base, signed: true)
                    : '${inBase(gain.base, signed: true)} · ${percentText(ratio)}',
                color: changeColor(context, gain.base.toDouble()),
              ),
            if (noCost) ...<Widget>[
              const SizedBox(height: 6),
              Text(l.holdingNoCostHelp, style: context.type.bodySmall),
            ],
            const SizedBox(height: 14),
            _Buttons(
              first: FilledButton.tonalIcon(
                onPressed: () => showTradeSheet(
                  context,
                  own: widget.own,
                  account: widget.account,
                ),
                icon: const Icon(Glyph.plus, size: 18),
                label: Text(l.tradeBought),
              ),
              second: OutlinedButton.icon(
                onPressed: position == null || position.quantity <= Decimal.zero
                    ? null
                    : () => showTradeSheet(
                        context,
                        own: widget.own,
                        account: widget.account,
                        sell: true,
                      ),
                icon: const Icon(Glyph.arrowsLeftRight, size: 18),
                label: Text(l.tradeSold),
              ),
            ),
          ],
        ),
      );
    },
  );
}

/// The purchase and the sale side by side, or one over the other where
/// there is no room for both.
class _Buttons extends StatelessWidget {
  const _Buttons({required this.first, required this.second});

  final Widget first;
  final Widget second;

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (BuildContext context, BoxConstraints box) {
      if (box.maxWidth >= 300) {
        return Row(
          children: <Widget>[
            Expanded(child: first),
            const SizedBox(width: 10),
            Expanded(child: second),
          ],
        );
      }
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[first, const SizedBox(height: 8), second],
      );
    },
  );
}

/// A label and its figure on one line; the figure shrinks before the label
/// breaks.
class _Line extends StatelessWidget {
  const _Line({required this.label, required this.value, this.color});

  final String label;
  final String value;
  final Color? color;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 4),
    child: Row(
      children: <Widget>[
        Text(label, style: context.type.bodyMedium),
        const SizedBox(width: 12),
        Expanded(
          child: FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerRight,
            child: Figures(
              value,
              style: context.type.bodyMedium?.copyWith(
                color: color,
                fontWeight: color == null ? null : FontWeight.w600,
              ),
            ),
          ),
        ),
      ],
    ),
  );
}
