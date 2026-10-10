import 'package:decimal/decimal.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../../capture/inbox.dart';
import '../../domain/records.dart';
import '../../format/dates.dart';
import '../../l10n/l10n.dart';
import '../../money/asset.dart';
import '../../money/money.dart';
import '../../own/own_controller.dart';
import '../../theme/tokens.dart';
import '../icons.dart';
import '../kit.dart';
import 'capture_settings_page.dart';
import 'charge_sheet.dart';
import 'look.dart';
import 'own_settings_page.dart';

/// One thing setting up left for later: what it is, why it helps, what
/// doing it is called and where it is done.
@immutable
class SetupStep {
  const SetupStep({
    required this.icon,
    required this.title,
    required this.body,
    required this.action,
    required this.done,
    required this.open,
  });

  final IconData icon;
  final String title;
  final String body;
  final String action;
  final bool done;
  final Future<void> Function(BuildContext context) open;
}

/// Where Quincena can hear of payments by itself: a phone's notifications
/// and messages, or Shortcuts on an iPhone.
bool get _phone =>
    !kIsWeb &&
    (defaultTargetPlatform == TargetPlatform.android ||
        defaultTargetPlatform == TargetPlatform.iOS);

/// How payments that came in by themselves arrive.
const Set<String> _automatic = <String>{
  'wallet',
  'notification',
  'sms',
  'email',
};

/// Whether a payment ever came in by itself, from the bank's alerts. A
/// wallet followed by its address writes the same source, with a reference
/// of its own, and says nothing of payments.
bool _captured(OwnController own) =>
    own.inbox.any((InboxItem i) => _automatic.contains(i.event.source.name)) ||
    (own.snapshot?.entries ?? const <Entry>[]).any(
      (Entry e) =>
          _automatic.contains(e.source) &&
          !(e.sourceRef?.startsWith('wallet:') ?? false),
    );

/// What setting up left for later, in the order it changes the figure
/// most: the fixed payments, what arrives each payday, the cushion and,
/// on a phone, payments that come in by themselves.
List<SetupStep> setupSteps(AppLocalizations l, OwnController own) {
  final Profile? p = own.profile;
  return <SetupStep>[
    SetupStep(
      icon: Glyph.repeat,
      title: l.setupFixedTitle,
      body: l.setupFixedBody,
      action: l.todoAdd,
      done: !own.provisional,
      open: (BuildContext context) => Navigator.of(context).push(
        MaterialPageRoute<void>(
          builder: (BuildContext context) => FixedSetupPage(own: own),
        ),
      ),
    ),
    SetupStep(
      icon: Glyph.money,
      title: l.setupPayTitle,
      body: l.setupPayBody,
      action: l.setupPayAction,
      done: p?.pay != null,
      open: (BuildContext context) => askPayAmount(context, own),
    ),
    SetupStep(
      icon: Glyph.piggyBank,
      title: l.setupCushionTitle,
      body: l.setupCushionBody,
      action: l.setupCushionAction,
      done: p?.cushion != null,
      open: (BuildContext context) => askCushion(context, own),
    ),
    if (_phone)
      SetupStep(
        icon: Glyph.bell,
        title: l.setupCaptureTitle,
        body: l.setupCaptureBody,
        action: l.setupCaptureAction,
        done: _captured(own),
        open: (BuildContext context) => Navigator.of(context).push(
          MaterialPageRoute<void>(
            builder: (BuildContext context) => CaptureSettingsPage(own: own),
          ),
        ),
      ),
  ];
}

/// Whether Inicio shows «Termina de preparar Quincena»: after the three
/// questions of setting up, while something in it is still to do and the
/// person has not hidden it. Never on the example, which is all set up.
bool showsSetup(AppLocalizations l, OwnController own) =>
    !own.example &&
    own.setupOpen &&
    own.accounts.isNotEmpty &&
    setupSteps(l, own).any((SetupStep s) => !s.done);

/// Whether all that setting up left for later is done: then the list goes
/// for good, and does not come back if something is undone later.
bool setupFinished(AppLocalizations l, OwnController own) =>
    own.setupOpen && setupSteps(l, own).every((SetupStep s) => s.done);

/// «Termina de preparar Quincena»: what setting up left for later, each
/// with the place where it is done, those already done ticked. It can be
/// hidden; all of it stays in Ajustes and Plan.
class SetupChecklist extends StatelessWidget {
  const SetupChecklist({super.key, required this.own});

  final OwnController own;

  Future<void> _hide(BuildContext context) async {
    final AppLocalizations l = context.l10n;
    final ScaffoldMessengerState messenger = ScaffoldMessenger.of(context);
    await own.keepSetupOpen(false);
    messenger.showSnackBar(
      SnackBar(
        content: Text(l.setupHidden),
        action: SnackBarAction(
          label: l.undo,
          onPressed: () => own.keepSetupOpen(true),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l = context.l10n;
    final List<SetupStep> steps = setupSteps(l, own);
    final int done = steps.where((SetupStep s) => s.done).length;
    final SetupStep? next = steps.where((SetupStep s) => !s.done).firstOrNull;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        SectionLabel(
          l.setupTitle,
          trailing: IconButton(
            tooltip: l.setupHide,
            visualDensity: VisualDensity.compact,
            onPressed: () => _hide(context),
            icon: Icon(Glyph.x, size: 18, color: context.colors.inkSoft),
          ),
        ),
        Panel(
          children: <Widget>[
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 14, 16, 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(l.setupBody, style: context.type.bodyMedium),
                  // How far it went, once it went somewhere.
                  if (done > 0) ...<Widget>[
                    const SizedBox(height: 2),
                    Text(
                      l.setupProgress(done, steps.length),
                      style: context.type.bodySmall,
                    ),
                  ],
                ],
              ),
            ),
            for (final SetupStep s in steps)
              _StepRow(step: s, first: identical(s, next)),
          ],
        ),
      ],
    );
  }
}

/// A step of the list: done, with its tick; to do, with what doing it is
/// called, on a button for the first one.
class _StepRow extends StatelessWidget {
  const _StepRow({required this.step, this.first = false});

  final SetupStep step;
  final bool first;

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l = context.l10n;
    final bool large = largeText(context);
    final Widget action = step.done
        ? Text(
            l.setupDone,
            style: context.type.labelLarge?.copyWith(
              color: context.colors.inkSoft,
            ),
          )
        : first
        ? FilledButton.tonal(
            onPressed: () => step.open(context),
            style: FilledButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              visualDensity: VisualDensity.compact,
            ),
            child: Text(step.action),
          )
        : Row(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              Text(
                step.action,
                style: context.type.labelLarge?.copyWith(
                  color: context.colors.brand,
                ),
              ),
              Icon(Glyph.caretRight, size: 16, color: context.colors.brand),
            ],
          );
    final Widget words = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text(
          step.title,
          style: context.type.titleSmall?.copyWith(
            color: step.done ? context.colors.inkSoft : null,
          ),
        ),
        if (!step.done) Text(step.body, style: context.type.bodySmall),
        // With large text what doing it is called goes under what it is.
        if (large) ...<Widget>[const SizedBox(height: 4), action],
      ],
    );
    return InkWell(
      onTap: step.done ? null : () => step.open(context),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 12, 12),
        child: Row(
          children: <Widget>[
            Icon(
              step.done ? Glyph.checkCircle : step.icon,
              size: 24,
              color: step.done
                  ? context.colors.positive
                  : context.colors.inkSoft,
            ),
            const SizedBox(width: 14),
            Expanded(child: words),
            if (!large) ...<Widget>[const SizedBox(width: 8), action],
          ],
        ),
      ),
    );
  }
}

/// What the person pays regularly, asked as setting up asked it once: the
/// payments most people have, to start from one, and a way to say there
/// are none. Opened from «Termina de preparar Quincena».
class FixedSetupPage extends StatelessWidget {
  const FixedSetupPage({super.key, required this.own});

  final OwnController own;

  /// What most people pay each month, to start one from. The first of next
  /// month is a guess the sheet lets them change.
  List<ChargeDraft> _suggestions(
    AppLocalizations l,
    Asset base,
    DateTime today,
  ) {
    final DateTime next = DateTime(today.year, today.month + 1, 1);
    ChargeDraft draft(String name, String category) => ChargeDraft(
      name: name,
      amount: Money(Decimal.zero, base),
      next: next,
      category: category,
    );
    return <ChargeDraft>[
      draft(l.fixedSuggestRent, 'housing'),
      draft(l.fixedSuggestAdmin, 'housing'),
      draft(l.fixedSuggestUtilities, 'utilities'),
      draft(l.fixedSuggestInternet, 'utilities'),
      draft(l.fixedSuggestPhone, 'utilities'),
      // The name is the person's own: Netflix, Spotify.
      draft('', 'subscriptions'),
    ];
  }

  /// Done, having said there is nothing paid regularly: the money to spend
  /// is not waiting for anything, and Inicio says so.
  Future<void> _none(BuildContext context) async {
    final NavigatorState navigator = Navigator.of(context);
    final ScaffoldMessengerState messenger = ScaffoldMessenger.of(context);
    final String done = context.l10n.fixedNoneDone;
    await own.sayNoFixedPayments(true);
    navigator.pop();
    messenger.showSnackBar(SnackBar(content: Text(done)));
  }

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: own,
    builder: (BuildContext context, _) {
      final AppLocalizations l = context.l10n;
      final Asset base = own.profile?.base ?? Asset.cop;
      return Scaffold(
        appBar: AppBar(
          backgroundColor: context.colors.canvas,
          surfaceTintColor: Colors.transparent,
          title: Text(l.setupFixedTitle, style: context.type.titleLarge),
        ),
        body: SafeArea(
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 560),
              child: Column(
                children: <Widget>[
                  Expanded(
                    child: ListView(
                      padding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
                      children: <Widget>[
                        Text(
                          l.onboardingFixedTitle,
                          style: context.type.displaySmall,
                        ),
                        const SizedBox(height: 8),
                        Text(
                          l.onboardingFixedBody,
                          style: context.type.bodyMedium,
                        ),
                        const SizedBox(height: 24),
                        if (own.recurring.isNotEmpty) ...<Widget>[
                          Panel(
                            children: <Widget>[
                              for (final RecurringCharge r in own.recurring)
                                _FixedRow(
                                  charge: r,
                                  base: base,
                                  onTap: () => showChargeSheet(
                                    context,
                                    own: own,
                                    charge: r,
                                  ),
                                ),
                            ],
                          ),
                          const SizedBox(height: 16),
                        ],
                        OutlinedButton.icon(
                          onPressed: () => showChargeSheet(context, own: own),
                          icon: const Icon(Glyph.plus, size: 18),
                          label: Text(l.chargeAdd),
                        ),
                        const SizedBox(height: 24),
                        SectionLabel(l.onboardingSuggestions),
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: <Widget>[
                            for (final ChargeDraft d in _suggestions(
                              l,
                              base,
                              own.today,
                            ))
                              ActionChip(
                                avatar: Icon(
                                  categoryIconFor(d.category!),
                                  size: 18,
                                ),
                                label: Text(
                                  d.name.isEmpty
                                      ? l.fixedSuggestSubscription
                                      : d.name,
                                ),
                                onPressed: () => showChargeSheet(
                                  context,
                                  own: own,
                                  draft: d,
                                ),
                              ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(24, 8, 24, 20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: <Widget>[
                        FilledButton(
                          onPressed: () => Navigator.of(context).pop(),
                          child: Text(l.setupDone),
                        ),
                        // Only before any is added: with one, there are
                        // some.
                        if (own.recurring.isEmpty && own.provisional)
                          Padding(
                            padding: const EdgeInsets.only(top: 4),
                            child: TextButton(
                              onPressed: () => _none(context),
                              child: Text(l.noFixedPayments),
                            ),
                          ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
    },
  );
}

/// A fixed payment already told: what, when it is next charged and how
/// much. With large text the amount goes under the date: beside them, the
/// name would have no room.
class _FixedRow extends StatelessWidget {
  const _FixedRow({
    required this.charge,
    required this.base,
    required this.onTap,
  });

  final RecurringCharge charge;
  final Asset base;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final bool large = largeText(context);
    final Widget amount = Figures(
      moneyText(charge.amount, base: base),
      style: context.type.titleSmall,
    );
    final Widget next = Text(
      context.l10n.fixedNextOn(dayShortMonth(charge.nextDate)),
      style: context.type.bodySmall,
    );
    return ListTile(
      onTap: onTap,
      title: Text(charge.name, style: context.type.titleSmall),
      subtitle: large
          ? Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[next, amount],
            )
          : next,
      trailing: large ? null : amount,
    );
  }
}
