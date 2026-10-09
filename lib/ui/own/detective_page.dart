import 'package:decimal/decimal.dart';
import 'package:flutter/material.dart';

import '../../capture/event.dart';
import '../../domain/commitments.dart';
import '../../domain/records.dart';
import '../../format/dates.dart';
import '../../format/money.dart';
import '../../l10n/l10n.dart';
import '../../money/asset.dart';
import '../../money/money.dart';
import '../../own/own_controller.dart';
import '../../theme/tokens.dart';
import '../icons.dart';
import '../kit.dart';
import 'entry_sheet.dart';
import 'inbox_page.dart' show sourceLabel;
import 'look.dart';

/// Where a movement came from, for the person: by hand, a notification, a
/// statement.
String entrySourceLabel(AppLocalizations l, String source) {
  final String kind = source.split(':').first;
  return switch (kind) {
    'manual' => l.sourceManual,
    'statement' => l.sourceStatement,
    'gemini' => l.sourceGemini,
    'script' => l.sourceScript,
    'binance' => 'Binance',
    _ when CaptureSource.values.any((CaptureSource c) => c.name == kind) =>
      sourceLabel(l, CaptureSource.parse(kind)),
    _ => l.sourceOther,
  };
}

/// What the charge detective found, with the movements behind each alert.
/// It never deletes a movement nor calls anything fraud: the person
/// decides, and may silence any kind of alert.
class DetectivePage extends StatefulWidget {
  const DetectivePage({super.key, required this.own});

  final OwnController own;

  @override
  State<DetectivePage> createState() => _DetectivePageState();
}

class _DetectivePageState extends State<DetectivePage> {
  bool _showPutAway = false;

  OwnController get own => widget.own;

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: own,
    builder: (BuildContext context, _) {
      final AppLocalizations l = context.l10n;
      final DetectiveState state = own.detective;
      final List<ChargeAlert> shown = own.alerts;
      final List<ChargeAlert> open = <ChargeAlert>[
        for (final ChargeAlert a in shown)
          if (state.answers[a.id] == null) a,
      ];
      final List<ChargeAlert> reviewing = <ChargeAlert>[
        for (final ChargeAlert a in shown)
          if (state.answers[a.id] == AlertAnswer.review) a,
      ];
      final List<ChargeAlert> putAway = <ChargeAlert>[
        for (final ChargeAlert a in own.allAlerts)
          if (!state.muted.contains(a.kind) &&
              (state.answers[a.id] == AlertAnswer.expected ||
                  state.answers[a.id] == AlertAnswer.dismissed))
            a,
      ];
      Widget cards(List<ChargeAlert> alerts) => Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          for (final ChargeAlert a in alerts) ...<Widget>[
            _AlertCard(own: own, alert: a, answer: state.answers[a.id]),
            const SizedBox(height: 12),
          ],
        ],
      );
      return Scaffold(
        appBar: AppBar(
          backgroundColor: context.colors.canvas,
          surfaceTintColor: Colors.transparent,
          title: Text(l.detectiveTitle, style: context.type.titleLarge),
        ),
        body: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 640),
            child: ListView(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
              children: <Widget>[
                Text(l.detectiveBody, style: context.type.bodyMedium),
                const SizedBox(height: 16),
                if (open.isEmpty && reviewing.isEmpty)
                  Block(
                    child: Row(
                      children: <Widget>[
                        Icon(Glyph.checkCircle, color: context.colors.positive),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            l.detectiveEmpty,
                            style: context.type.bodyMedium,
                          ),
                        ),
                      ],
                    ),
                  ),
                if (open.isNotEmpty) ...<Widget>[
                  SectionLabel(l.detectiveOpen),
                  cards(open),
                ],
                if (reviewing.isNotEmpty) ...<Widget>[
                  const SizedBox(height: 12),
                  SectionLabel(l.detectiveReviewing),
                  cards(reviewing),
                ],
                if (putAway.isNotEmpty) ...<Widget>[
                  Align(
                    alignment: Alignment.centerLeft,
                    child: TextButton(
                      onPressed: () =>
                          setState(() => _showPutAway = !_showPutAway),
                      child: Text(
                        _showPutAway
                            ? l.detectiveHidePutAway
                            : l.detectiveShowPutAway(putAway.length),
                      ),
                    ),
                  ),
                  if (_showPutAway) cards(putAway),
                ],
                const SizedBox(height: 24),
                SectionLabel(l.detectiveWhat),
                Panel(
                  indent: 16,
                  children: <Widget>[
                    for (final AlertKind kind in AlertKind.values)
                      SwitchListTile(
                        value: !state.muted.contains(kind),
                        onChanged: (bool on) =>
                            own.muteAlerts(kind, muted: !on),
                        title: Text(switch (kind) {
                          AlertKind.twice => l.detectiveKindTwice,
                          AlertKind.priceUp => l.detectiveKindPriceUp,
                          AlertKind.unusual => l.detectiveKindUnusual,
                        }, style: context.type.titleSmall),
                        subtitle: Text(switch (kind) {
                          AlertKind.twice => l.detectiveRuleTwice,
                          AlertKind.priceUp => l.detectiveRulePriceUp,
                          AlertKind.unusual => l.detectiveRuleUnusual,
                        }, style: context.type.bodySmall),
                      ),
                  ],
                ),
              ],
            ),
          ),
        ),
      );
    },
  );
}

class _AlertCard extends StatelessWidget {
  const _AlertCard({required this.own, required this.alert, this.answer});

  final OwnController own;
  final ChargeAlert alert;
  final AlertAnswer? answer;

  Asset _assetOf(Entry e) =>
      own.snapshot?.account(e.accountId)?.asset ??
      own.profile?.base ??
      Asset.cop;

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l = context.l10n;
    final Asset? base = own.profile?.base;
    final Entry last = alert.evidence.last;
    String money(Decimal amount, Entry e) =>
        moneyText(Money(amount, _assetOf(e)), base: base);
    final (IconData icon, String title, String why) = switch (alert.kind) {
      AlertKind.twice when alert.seenTwice => (
        Glyph.arrowsDownUp,
        l.detectiveTwiceSeenTitle,
        l.detectiveTwiceSeenWhy(
          entrySourceLabel(l, alert.evidence.first.source),
          entrySourceLabel(l, last.source),
        ),
      ),
      AlertKind.twice => (
        Glyph.arrowsDownUp,
        l.detectiveTwiceTitle,
        l.detectiveTwiceWhy,
      ),
      AlertKind.priceUp => (
        Glyph.trendUp,
        l.detectivePriceUpTitle(last.payee),
        l.detectivePriceUpWhy(
          money(alert.before ?? Decimal.zero, last),
          money(-last.amount, last),
          percent(switch (alert.before) {
            final Decimal before when before > Decimal.zero =>
              (((-last.amount).toDouble() / before.toDouble() - 1) * 100)
                  .round(),
            _ => 0,
          }),
        ),
      ),
      AlertKind.unusual => (
        Glyph.warningCircle,
        l.detectiveUnusualTitle(
          categoryNameFor(context, last.category ?? 'other', own.categories),
        ),
        l.detectiveUnusualWhy(
          formatDecimal(
            Decimal.parse((alert.times ?? 0).toStringAsFixed(1)),
            decimals: 1,
            trim: true,
          ),
          categoryNameFor(context, last.category ?? 'other', own.categories),
        ),
      ),
    };
    // A price going up has every charge as evidence: the latest few say it.
    final List<Entry> evidence = alert.evidence.length > 4
        ? alert.evidence.sublist(alert.evidence.length - 4)
        : alert.evidence;
    return Block(
      padding: const EdgeInsets.fromLTRB(16, 14, 8, 6),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Icon(icon, size: 20, color: context.colors.caution),
              const SizedBox(width: 10),
              Expanded(child: Text(title, style: context.type.titleSmall)),
            ],
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(30, 4, 8, 8),
            child: Text(why, style: context.type.bodyMedium),
          ),
          for (final Entry e in evidence) _EvidenceRow(own: own, entry: e),
          Wrap(
            alignment: WrapAlignment.end,
            children: <Widget>[
              if (answer == AlertAnswer.expected ||
                  answer == AlertAnswer.dismissed)
                TextButton(
                  onPressed: () => own.answerAlert(alert.id, null),
                  child: Text(l.detectiveShowAgain),
                ),
              if (answer != AlertAnswer.expected)
                TextButton(
                  onPressed: () =>
                      own.answerAlert(alert.id, AlertAnswer.expected),
                  child: Text(l.detectiveExpected),
                ),
              if (answer == null)
                TextButton(
                  onPressed: () =>
                      own.answerAlert(alert.id, AlertAnswer.review),
                  child: Text(l.detectiveReview),
                ),
              if (answer != AlertAnswer.dismissed)
                TextButton(
                  onPressed: () =>
                      own.answerAlert(alert.id, AlertAnswer.dismissed),
                  child: Text(l.detectiveDismiss),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

/// One movement behind an alert, with where it came from. Opening it is
/// how the person changes or deletes it, never the alert.
class _EvidenceRow extends StatelessWidget {
  const _EvidenceRow({required this.own, required this.entry});

  final OwnController own;
  final Entry entry;

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l = context.l10n;
    final Account? account = own.snapshot?.account(entry.accountId);
    if (account == null) return const SizedBox.shrink();
    return InkWell(
      onTap: () => showEntrySheet(context, own: own, entry: entry),
      borderRadius: BorderRadius.circular(12),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(30, 6, 8, 6),
        child: Row(
          children: <Widget>[
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(
                    entry.payee.isEmpty ? l.kindExpense : entry.payee,
                    style: context.type.bodyMedium,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  Text(
                    <String>[
                      dayAndTime(entry.date),
                      account.name,
                      entrySourceLabel(l, entry.source),
                    ].join(' · '),
                    style: context.type.bodySmall,
                  ),
                ],
              ),
            ),
            const SizedBox(width: 12),
            Figures(
              moneyText(
                Money(entry.amount, account.asset),
                base: own.profile?.base,
                signed: true,
              ),
              style: context.type.bodyMedium,
            ),
          ],
        ),
      ),
    );
  }
}
