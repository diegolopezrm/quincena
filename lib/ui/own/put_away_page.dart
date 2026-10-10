import 'package:decimal/decimal.dart';
import 'package:flutter/material.dart';

import '../../capture/inbox.dart';
import '../../domain/commitments.dart';
import '../../domain/records.dart';
import '../../domain/trips.dart';
import '../../format/dates.dart';
import '../../l10n/l10n.dart';
import '../../money/asset.dart';
import '../../money/money.dart';
import '../../own/own_controller.dart';
import '../../own/undo.dart';
import '../../theme/tokens.dart';
import '../icons.dart';
import '../kit.dart';
import 'accounts_tab.dart' show AccountRow;
import 'capture_reasons.dart' show merchantShown;
import 'detective_page.dart' show alertSaid;
import 'discard_capture.dart';
import 'inbox_page.dart' show sourceIcon, sourceLabel;
import 'look.dart';

/// Opens what was archived and discarded.
Future<void> openPutAway(BuildContext context, OwnController own) =>
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (BuildContext context) => PutAwayPage(own: own),
      ),
    );

/// At the end of Por revisar, the way to what was discarded there and to
/// the apps that are not read, when there is any.
class DiscardedLink extends StatelessWidget {
  const DiscardedLink({super.key, required this.own});

  final OwnController own;

  @override
  Widget build(BuildContext context) {
    final int count =
        own.discardedInbox.length + own.captureSettings.mutedApps.length;
    if (count == 0) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(top: 16),
      child: Align(
        alignment: Alignment.centerLeft,
        child: TextButton.icon(
          onPressed: () => openPutAway(context, own),
          icon: const Icon(Glyph.archive, size: 18),
          label: Text(context.l10n.inboxDiscardedLink(count)),
        ),
      ),
    );
  }
}

/// Everything the person archived or discarded without deleting it, each
/// with the way to bring it back: what was discarded in Por revisar first,
/// where it is looked for most, then the apps not read, the charges put
/// away, what is not a fixed payment, the expenses taken out of a trip,
/// and the archived accounts.
class PutAwayPage extends StatelessWidget {
  const PutAwayPage({super.key, required this.own});

  final OwnController own;

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: own,
    builder: (BuildContext context, _) {
      final AppLocalizations l = context.l10n;
      final List<Widget> shown = <Widget>[
        ..._captures(context),
        ..._apps(context),
        ..._alerts(context),
        ..._notRecurring(context),
        ..._trips(context),
        ..._accounts(context),
      ];
      return Scaffold(
        appBar: AppBar(
          backgroundColor: context.colors.canvas,
          surfaceTintColor: Colors.transparent,
          title: Text(l.putAwayTitle, style: context.type.titleLarge),
        ),
        body: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 760),
            child: ListView(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 40),
              children: <Widget>[
                Padding(
                  padding: const EdgeInsets.only(bottom: 20),
                  child: Text(
                    shown.isEmpty ? l.putAwayEmpty : l.putAwayBody,
                    style: context.type.bodyMedium,
                  ),
                ),
                ...shown,
              ],
            ),
          ),
        ),
      );
    },
  );

  /// A section: its title, what to know about it, and its rows; nothing
  /// when it has none.
  List<Widget> _section(
    BuildContext context,
    String title,
    List<Widget> rows, {
    String? note,
    double indent = 68,
  }) => rows.isEmpty
      ? const <Widget>[]
      : <Widget>[
          SectionLabel(title),
          if (note != null)
            Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: Text(note, style: context.type.bodySmall),
            ),
          Panel(indent: indent, children: rows),
          const SizedBox(height: 24),
        ];

  List<Widget> _captures(BuildContext context) {
    final AppLocalizations l = context.l10n;
    final Asset base = own.profile?.base ?? Asset.cop;
    return _section(
      context,
      l.putAwayCaptures,
      note: l.putAwayCapturesNote,
      <Widget>[
        for (final InboxItem item in own.discardedInbox)
          PutAwayRow(
            leading: Icon(
              sourceIcon(item.event.source),
              color: context.colors.inkSoft,
            ),
            title: capturePayee(l, item),
            subtitle: <String>[
              dayAndTime(item.parsed.when ?? item.event.at),
              item.parsed.institution ??
                  item.event.sender ??
                  item.event.appName ??
                  sourceLabel(l, item.event.source),
            ].join(' · '),
            amount: switch (item.parsed.amount) {
              final Decimal amount => moneyText(
                Money(
                  item.parsed.kind == EntryKind.income ? amount : -amount,
                  item.parsed.asset ?? base,
                ),
                base: base,
                signed: item.parsed.kind != null,
              ),
              null => null,
            },
            action: l.bringBack,
            onPressed: () async {
              final ScaffoldMessengerState messenger = ScaffoldMessenger.of(
                context,
              );
              final String said = l.captureBroughtBack(capturePayee(l, item));
              await own.bringBack(item);
              messenger.showSnackBar(SnackBar(content: Text(said)));
            },
          ),
      ],
    );
  }

  List<Widget> _apps(BuildContext context) {
    final AppLocalizations l = context.l10n;
    final CaptureSettings s = own.captureSettings;
    return _section(context, l.mutedApps, <Widget>[
      for (final String app in s.mutedApps.toList()..sort())
        PutAwayRow(
          leading: Icon(Glyph.bellSlash, color: context.colors.inkSoft),
          title: s.appNames[app] ?? app,
          action: l.unmute,
          onPressed: () => own.readAgain(app),
        ),
    ]);
  }

  List<Widget> _alerts(BuildContext context) {
    final AppLocalizations l = context.l10n;
    final DetectiveState state = own.detective;
    return _section(context, l.putAwayAlerts, <Widget>[
      for (final ChargeAlert a in own.allAlerts)
        if (!state.muted.contains(a.kind) &&
            (state.answers[a.id] == AlertAnswer.expected ||
                state.answers[a.id] == AlertAnswer.dismissed))
          if (alertSaid(context, own, a) case (
            final IconData icon,
            final String title,
            _,
          ))
            PutAwayRow(
              leading: Icon(icon, color: context.colors.caution),
              title: title,
              subtitle: <String>[
                state.answers[a.id] == AlertAnswer.expected
                    ? l.detectiveExpected
                    : l.putAwayAlertDismissed,
                dayShortMonth(a.evidence.last.date),
              ].join(' · '),
              action: l.detectiveShowAgain,
              onPressed: () => own.answerAlert(a.id, null),
            ),
    ]);
  }

  List<Widget> _notRecurring(BuildContext context) {
    final AppLocalizations l = context.l10n;
    return _section(context, l.putAwayNotRecurring, <Widget>[
      for (final String key in own.detective.notRecurring.toList()..sort())
        PutAwayRow(
          leading: Icon(Glyph.repeat, color: context.colors.inkSoft),
          title: merchantShown(key),
          action: l.offerAgain,
          onPressed: () => own.recurringAgain(key),
        ),
    ]);
  }

  List<Widget> _trips(BuildContext context) {
    final AppLocalizations l = context.l10n;
    final Asset? base = own.profile?.base;
    return _section(context, l.putAwayTrips, <Widget>[
      for (final Trip trip in own.trips)
        for (final String id in trip.excluded)
          if (own.entryById(id) case final Entry e
              when e.kind == EntryKind.expense)
            PutAwayRow(
              leading: Icon(
                Glyph.suitcaseRolling,
                color: context.colors.inkSoft,
              ),
              title: e.payee.isEmpty
                  ? categoryNameFor(
                      context,
                      e.category ?? 'other',
                      own.categories,
                    )
                  : e.payee,
              subtitle: '${trip.name} · ${dayShortMonth(e.date)}',
              amount: switch (own.snapshot?.account(e.accountId)) {
                final Account a => moneyText(
                  Money(e.amount, a.asset),
                  base: base,
                  signed: true,
                ),
                null => null,
              },
              action: l.tripPutBack,
              onPressed: () => own.backInTrip(trip, e),
            ),
    ]);
  }

  List<Widget> _accounts(BuildContext context) {
    final AppLocalizations l = context.l10n;
    return _section(context, l.archivedAccountsTitle, indent: 16, <Widget>[
      for (final Account a in own.archivedAccounts)
        Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            AccountRow(own: own, account: a),
            _BringBack(
              action: l.restore,
              onPressed: () => own.restoreAccount(a.id),
            ),
          ],
        ),
    ]);
  }
}

/// One thing put away: what it is, and the way to bring it back under it.
class PutAwayRow extends StatelessWidget {
  const PutAwayRow({
    super.key,
    this.leading,
    required this.title,
    this.subtitle,
    this.amount,
    required this.action,
    required this.onPressed,
  });

  final Widget? leading;
  final String title;
  final String? subtitle;
  final String? amount;
  final String action;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    // With large text the amount goes under the name, which keeps the room
    // to be read.
    final bool large = largeText(context);
    final String? detail = large && amount != null
        ? <String>[?subtitle, amount!].join(' · ')
        : subtitle;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        ListTile(
          leading: large ? null : leading,
          title: Text(title, style: context.type.titleSmall),
          subtitle: detail == null
              ? null
              : Text(detail, style: context.type.bodySmall),
          trailing: large || amount == null
              ? null
              : Figures(amount!, style: context.type.bodyMedium),
        ),
        _BringBack(action: action, onPressed: onPressed),
      ],
    );
  }
}

/// The button that brings something put away back where it was.
class _BringBack extends StatelessWidget {
  const _BringBack({required this.action, required this.onPressed});

  final String action;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) => Align(
    alignment: AlignmentDirectional.centerEnd,
    child: Padding(
      padding: const EdgeInsets.fromLTRB(8, 0, 8, 8),
      child: TextButton.icon(
        onPressed: onPressed,
        icon: const Icon(Glyph.arrowCounterClockwise, size: 18),
        label: Text(action),
      ),
    ),
  );
}
