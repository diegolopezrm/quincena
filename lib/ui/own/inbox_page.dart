import 'dart:async';

import 'package:decimal/decimal.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../capture/capture_service.dart';
import '../../capture/event.dart';
import '../../capture/inbox.dart';
import '../../capture/native_channel.dart';
import '../../capture/parser.dart';
import '../../data/example_account.dart' show exampleMessage;
import '../../data/ledger.dart';
import '../../domain/freelance.dart';
import '../../domain/payment_match.dart';
import '../../domain/records.dart';
import '../../domain/shared.dart';
import '../../format/dates.dart';
import '../../format/money.dart';
import '../../l10n/l10n.dart';
import '../../money/asset.dart';
import '../../money/money.dart';
import '../../own/own_controller.dart';
import '../../theme/tokens.dart';
import '../icons.dart';
import '../exit_list.dart';
import '../kit.dart';
import 'account_sheet.dart';
import 'capture_reasons.dart';
import 'discard_capture.dart';
import 'entry_origin.dart';
import 'entry_sheet.dart';
import 'look.dart';
import 'put_away_page.dart';
import 'read_images.dart';

/// Captures waiting to be recorded, those one tap records apart from those
/// that need something from the person; the possible repeats; and what was
/// recorded on its own lately.
class InboxPage extends StatelessWidget {
  const InboxPage({super.key, required this.own});

  final OwnController own;

  /// With more than this many waiting, each one that is ready takes a line.
  static const int compactAfter = 5;

  /// Where the payment to read is: a picture or a PDF, or a message the
  /// person copied.
  Future<void> _addFrom(BuildContext context) async {
    final AppLocalizations l = context.l10n;
    final bool? paste = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      useSafeArea: true,
      backgroundColor: context.colors.surface,
      constraints: const BoxConstraints(maxWidth: 560),
      builder: (BuildContext context) => SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Text(l.inboxAddTitle, style: context.type.headlineMedium),
            const SizedBox(height: 8),
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Glyph.image),
              title: Text(l.inboxAddImage),
              subtitle: Text(l.inboxAddImageBody),
              onTap: () => Navigator.of(context).pop(false),
            ),
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Glyph.clipboardText),
              title: Text(l.inboxAddPaste),
              subtitle: Text(l.inboxAddPasteBody),
              onTap: () => Navigator.of(context).pop(true),
            ),
          ],
        ),
      ),
    );
    if (paste == null || !context.mounted) return;
    await (paste ? showPasteDialog(context, own) : readImages(context, own));
  }

  /// Whether the title and [action] both fit whole in the bar, beside the
  /// back button, at the person's text size.
  static bool _barHolds(BuildContext context, String title, String action) {
    final TextScaler scaler = MediaQuery.textScalerOf(context);
    final TextDirection direction = Directionality.of(context);
    double wide(String text, TextStyle? style) {
      final TextPainter painter = TextPainter(
        text: TextSpan(text: text, style: style),
        textScaler: scaler,
        textDirection: direction,
        maxLines: 1,
      )..layout();
      final double width = painter.width;
      painter.dispose();
      return width;
    }

    // The back button, when there is one, and the gaps on each side of the
    // title; then the button's padding, its icon and the space after it.
    final bool back = ModalRoute.of(context)?.impliesAppBarDismissal ?? false;
    final double around = (back ? 72 : 16) + 16 + 12 + 18 + 8 + 16 + 8;
    return around +
            wide(title, context.type.titleLarge) +
            wide(action, context.type.labelLarge) <=
        MediaQuery.sizeOf(context).width;
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: own,
      builder: (BuildContext context, _) {
        final AppLocalizations l = context.l10n;
        final List<InboxItem> pending = own.pendingInbox;
        final List<Account> accounts = own.accounts;
        final List<InboxItem> ready = <InboxItem>[
          for (final InboxItem i in pending)
            if (CaptureService.isReady(i, accounts)) i,
        ];
        final List<InboxItem> needs = <InboxItem>[
          for (final InboxItem i in pending)
            if (!CaptureService.isReady(i, accounts)) i,
        ];
        // Money that only changed accounts is recorded as a move, one by
        // one; of the rest, what automatic recording would take on its own
        // can go together, and what it would not is said by name.
        final List<InboxItem> moves = <InboxItem>[
          for (final InboxItem i in ready)
            if (CaptureService.ownMove(
                  i,
                  accounts,
                  person: own.profile?.name,
                ) !=
                null)
              i,
        ];
        final List<InboxItem> clear = <InboxItem>[
          for (final InboxItem i in ready)
            if (!moves.contains(i) && CaptureService.isClear(i, accounts)) i,
        ];
        final List<InboxItem> leftOut = <InboxItem>[
          for (final InboxItem i in ready)
            if (!moves.contains(i) && !clear.contains(i)) i,
        ];
        final bool compact = pending.length > compactAfter;
        final List<InboxItem> repeats = <InboxItem>[
          for (final InboxItem i in own.inbox)
            if (i.status == InboxStatus.duplicate) i,
        ];
        final String addLabel = CaptureChannel.readsImages
            ? l.inboxAddFrom
            : l.pasteMessage;
        final Widget add = CaptureChannel.readsImages
            ? TextButton.icon(
                onPressed: () => _addFrom(context),
                icon: const Icon(Glyph.scan, size: 18),
                label: Text(addLabel),
              )
            : TextButton.icon(
                onPressed: () => showPasteDialog(context, own),
                icon: const Icon(Glyph.clipboardText, size: 18),
                label: Text(addLabel),
              );
        // On a narrow phone or with large text the title needs the whole
        // bar: the way to read a payment goes at the top of the list instead.
        final bool crowded = !_barHolds(context, l.inboxTitle, addLabel);
        return Scaffold(
          appBar: AppBar(
            backgroundColor: context.colors.canvas,
            surfaceTintColor: Colors.transparent,
            title: Text(l.inboxTitle, style: context.type.titleLarge),
            actions: <Widget>[
              if (!crowded) ...<Widget>[add, const SizedBox(width: 8)],
            ],
          ),
          body: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 760),
              child: ListView(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
                children: <Widget>[
                  if (crowded && pending.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: Align(alignment: Alignment.centerLeft, child: add),
                    ),
                  if (pending.isEmpty)
                    Block(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: <Widget>[
                          // Nothing to record is not all done while a
                          // possible repeat waits below.
                          Text(
                            repeats.isEmpty ? l.inboxEmpty : l.inboxOnlyRepeats,
                            style: context.type.titleSmall,
                          ),
                          const SizedBox(height: 4),
                          Text(
                            repeats.isEmpty
                                ? l.inboxEmptyBody
                                : l.inboxOnlyRepeatsBody(repeats.length),
                            style: context.type.bodyMedium,
                          ),
                          const SizedBox(height: 14),
                          Wrap(
                            spacing: 8,
                            runSpacing: 8,
                            children: <Widget>[
                              if (CaptureChannel.readsImages)
                                OutlinedButton.icon(
                                  onPressed: () => readImages(context, own),
                                  icon: const Icon(Glyph.scan, size: 18),
                                  label: Text(l.readScreenshot),
                                ),
                              OutlinedButton.icon(
                                onPressed: () => showPasteDialog(context, own),
                                icon: const Icon(Glyph.clipboardText, size: 18),
                                label: Text(l.pasteMessage),
                              ),
                            ],
                          ),
                        ],
                      ),
                    )
                  else if (compact)
                    Padding(
                      padding: const EdgeInsets.fromLTRB(4, 0, 4, 16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: <Widget>[
                          Text(
                            l.inboxWaiting(pending.length),
                            style: context.type.titleMedium,
                          ),
                          Text(
                            <String>[
                              if (ready.isNotEmpty)
                                l.inboxReadyCount(ready.length),
                              if (needs.isNotEmpty)
                                l.inboxNeedsCount(needs.length),
                            ].join(' · '),
                            style: context.type.bodySmall,
                          ),
                        ],
                      ),
                    ),
                  if (ready.isNotEmpty) ...<Widget>[
                    SectionLabel(l.inboxReadySection),
                    if (clear.length >= 2)
                      _RecordReady(
                        key: const ValueKey<String>('record-ready'),
                        own: own,
                        items: clear,
                        leftOut: leftOut,
                      ),
                    if (compact) ...<Widget>[
                      Material(
                        key: const ValueKey<String>('ready-lines'),
                        color: context.colors.surface,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(20),
                          side: BorderSide(color: context.colors.line),
                        ),
                        clipBehavior: Clip.antiAlias,
                        child: ExitList<InboxItem>(
                          items: ready,
                          keyOf: (InboxItem i) => i.id,
                          gap: 0,
                          builder: (BuildContext context, InboxItem item) =>
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.stretch,
                                children: <Widget>[
                                  if (item.id != ready.first.id)
                                    Divider(
                                      height: 1,
                                      indent: 60,
                                      color: context.colors.line,
                                    ),
                                  InboxCard(
                                    own: own,
                                    item: item,
                                    compact: true,
                                  ),
                                ],
                              ),
                        ),
                      ),
                      const SizedBox(height: 16),
                    ] else
                      ExitList<InboxItem>(
                        key: const ValueKey<String>('ready'),
                        items: ready,
                        keyOf: (InboxItem i) => i.id,
                        builder: (BuildContext context, InboxItem item) =>
                            InboxCard(own: own, item: item),
                      ),
                  ],
                  if (needs.isNotEmpty) ...<Widget>[
                    SectionLabel(l.inboxNeedsInfoSection),
                    ExitList<InboxItem>(
                      key: const ValueKey<String>('needs'),
                      items: needs,
                      keyOf: (InboxItem i) => i.id,
                      builder: (BuildContext context, InboxItem item) =>
                          InboxCard(own: own, item: item),
                    ),
                  ],
                  if (repeats.isNotEmpty) ...<Widget>[
                    const SizedBox(height: 16),
                    SectionLabel(l.possibleDuplicates),
                    for (final InboxItem item in repeats) ...<Widget>[
                      InboxCard(own: own, item: item),
                      const SizedBox(height: 12),
                    ],
                  ],
                  if (own.recentAutomatic.isNotEmpty) ...<Widget>[
                    const SizedBox(height: 16),
                    SectionLabel(l.recordedAutomatically),
                    Padding(
                      padding: const EdgeInsets.fromLTRB(4, 0, 4, 10),
                      child: Text(
                        l.autoRecordedBody,
                        style: context.type.bodySmall,
                      ),
                    ),
                    for (final InboxItem item
                        in own.recentAutomatic) ...<Widget>[
                      InboxCard(own: own, item: item),
                      const SizedBox(height: 12),
                    ],
                  ],
                  DiscardedLink(own: own),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

/// Records every capture that is clear at once, with one way to take them
/// all back.
class _RecordReady extends StatefulWidget {
  const _RecordReady({
    super.key,
    required this.own,
    required this.items,
    required this.leftOut,
  });

  final OwnController own;
  final List<InboxItem> items;

  /// The others that are ready: a category the app did not recognize, or
  /// a picture's reading, leaves them for the person to record one by one.
  final List<InboxItem> leftOut;

  @override
  State<_RecordReady> createState() => _RecordReadyState();
}

class _RecordReadyState extends State<_RecordReady> {
  bool _busy = false;

  Future<void> _record() async {
    final ScaffoldMessengerState messenger = ScaffoldMessenger.of(context);
    setState(() => _busy = true);
    unawaited(HapticFeedback.lightImpact());
    final List<Accepted> done = await widget.own.capture.acceptAll(
      widget.items,
    );
    showRecordedMany(messenger, widget.own, done);
    if (mounted) setState(() => _busy = false);
  }

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l = context.l10n;
    final List<InboxItem> out = widget.leftOut;
    final int ready = widget.items.length + out.length;
    final List<String> names = <String>[
      for (final InboxItem i in out)
        i.suggestion.payee ?? i.parsed.merchant ?? l.noMerchant,
    ];
    final String listed = names.length < 2
        ? names.join()
        : l.listAnd(
            names.take(names.length - 1).join(', '),
            names.last,
            listSound(names.last),
          );
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          TextButton.icon(
            onPressed: _busy ? null : _record,
            icon: const Icon(Glyph.checks, size: 18),
            label: Text(
              out.isNotEmpty
                  ? l.inboxRecordSome(widget.items.length, ready)
                  : l.inboxRecordReady(widget.items.length),
            ),
          ),
          // Which of the ready ones stay out, and why.
          if (out.isNotEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: Text(
                out.every((InboxItem i) => i.suggestion.category == null)
                    ? l.inboxLeftOutCategory(out.length, listed)
                    : l.inboxLeftOut(out.length, listed),
                style: context.type.bodySmall,
              ),
            ),
        ],
      ),
    );
  }
}

String sourceLabel(AppLocalizations l, CaptureSource s) => switch (s) {
  CaptureSource.wallet => l.sourceWallet,
  CaptureSource.notification => l.sourceNotification,
  CaptureSource.sms => l.sourceSms,
  CaptureSource.email => l.sourceEmail,
  CaptureSource.screenshot => l.sourceScreenshot,
  CaptureSource.paste => l.sourcePaste,
};

IconData sourceIcon(CaptureSource s) => switch (s) {
  CaptureSource.wallet => Glyph.creditCard,
  CaptureSource.notification => Glyph.bell,
  CaptureSource.sms => Glyph.chatCircleDots,
  CaptureSource.email => Glyph.envelope,
  CaptureSource.screenshot => Glyph.camera,
  CaptureSource.paste => Glyph.clipboardText,
};

/// One capture: who was paid and how much, where it goes, and what to do
/// with it. How it was detected waits in its menu.
class InboxCard extends StatefulWidget {
  const InboxCard({
    super.key,
    required this.own,
    required this.item,
    this.compact = false,
  });

  final OwnController own;
  final InboxItem item;

  /// A line among others that are ready, which a tap opens into the whole
  /// card; the group around it draws the frame.
  final bool compact;

  @override
  State<InboxCard> createState() => _InboxCardState();
}

class _InboxCardState extends State<InboxCard> {
  bool _details = false;
  bool _busy = false;

  /// A compact line opened into the whole card.
  bool _open = false;

  OwnController get own => widget.own;
  InboxItem get item => widget.item;

  /// The movement an automatic record made, as it stands now: the person
  /// may have corrected it since.
  Entry? get _made {
    if (item.status != InboxStatus.accepted) return null;
    final String? id = item.entryId;
    return own.snapshot?.entries.where((Entry e) => e.id == id).firstOrNull;
  }

  Account? get _account {
    final String? id = _made?.accountId ?? item.suggestion.accountId;
    for (final Account a in own.accounts) {
      if (a.id == id) return a;
    }
    return null;
  }

  /// The accounts of the move a recorded notice is a side of: where the
  /// money left and where it arrived.
  (Account, Account)? get _moved {
    final Entry? made = _made;
    final String? transfer = made?.transferId;
    if (made == null || transfer == null) return null;
    final Entry? other = own.snapshot?.entries
        .where((Entry e) => e.transferId == transfer && e.id != made.id)
        .firstOrNull;
    final Account? here = own.snapshot?.account(made.accountId);
    final Account? there = other == null
        ? null
        : own.snapshot?.account(other.accountId);
    if (here == null || there == null) return null;
    return made.amount < Decimal.zero ? (here, there) : (there, here);
  }

  /// The move between the person's accounts the capture most likely is,
  /// while it waits.
  OwnMove? get _move =>
      CaptureService.ownMove(item, own.accounts, person: own.profile?.name);

  /// What recording it does, said on what records it.
  String _recordLabel(
    AppLocalizations l, {
    OwnMove? move,
    PaymentMatch? paid,
  }) => move != null
      ? l.recordTransfer
      : paid?.member != null
      ? l.recordRepaid(paid!.member!.name)
      : paid != null
      ? l.recordCollected
      : item.parsed.kind == EntryKind.income
      ? l.recordIncome
      : l.recordExpense;

  /// What [paid] is, said on the card before it is recorded.
  String _paidDetail(AppLocalizations l, PaymentMatch paid) {
    final Ledger? ledger = own.ledger;
    String amount(int minor) =>
        ledger == null ? '$minor' : pesos(ledger.major(minor));
    if (paid.income case final ExpectedIncome income) {
      return l.clientPaidDetail(income.client, amount(income.amount));
    }
    return l.friendPaidDetail(
      paid.member!.name,
      amount(paid.owed),
      paid.group!.name,
    );
  }

  Future<void> _confirm() async {
    if (_move case final OwnMove move) return _recordMove(move);
    final Account? account = _account;
    if (account != null) return _record(account.id);
    final String? picked = await _pickAccount();
    if (picked != null && mounted) await _record(picked);
  }

  /// Records [move] as it is proposed, in one tap: what the alert says left
  /// or arrived, and across currencies, the other side at the day's rate.
  /// Without a rate, the form asks.
  Future<void> _recordMove(OwnMove move) async {
    final Account? from = own.snapshot?.account(move.fromId);
    final Account? to = own.snapshot?.account(move.toId);
    final Decimal? amount = item.parsed.amount;
    if (from == null || to == null || amount == null) return;
    final bool out = item.parsed.kind == EntryKind.expense;
    // The side the alert is about says the amount, in its own currency.
    final Account said = out ? from : to;
    final Account other = out ? to : from;
    final Asset? written = item.parsed.asset;
    final Decimal? converted = written != null && written != said.asset
        ? null
        : said.asset == other.asset
        ? amount
        : own.rates
              .convert(Money(amount, said.asset), other.asset)
              ?.amount
              .round(scale: other.asset.decimals);
    if (converted == null) return _ownTransfer();
    final ScaffoldMessengerState messenger = ScaffoldMessenger.of(context);
    setState(() => _busy = true);
    unawaited(HapticFeedback.lightImpact());
    final bool across = said.asset != other.asset;
    final Accepted done = await own.capture.acceptTransfer(
      item,
      fromAccountId: from.id,
      toAccountId: to.id,
      sent: out ? amount : converted,
      received: !across ? null : (out ? converted : amount),
      date: item.parsed.when ?? item.event.at,
    );
    showRecorded(messenger, own, done);
  }

  /// Why [move] reads as money moved between the person's accounts.
  String _moveWhy(AppLocalizations l, OwnMove move) {
    String name(String id) => own.snapshot?.account(id)?.name ?? '';
    return switch (move.why) {
      'own' when item.parsed.kind == EntryKind.income => l.moveWhyOwnIn(
        name(move.fromId),
      ),
      'own' => l.moveWhyOwnOut(name(move.toId)),
      'self' => l.moveWhySelf,
      'bank' => l.moveWhyBank(
        own.snapshot?.account(move.fromId)?.institution ?? '',
        name(move.fromId),
      ),
      'cash' => l.moveWhyCash(name(move.toId)),
      _ => l.moveWhyCard(name(move.toId)),
    };
  }

  Future<void> _record(String accountId) async {
    final ScaffoldMessengerState messenger = ScaffoldMessenger.of(context);
    final AppLocalizations l = context.l10n;
    final PaymentMatch? paid = _paid;
    final String? category = item.suggestion.category;
    setState(() => _busy = true);
    unawaited(HapticFeedback.lightImpact());
    final Accepted done = await own.capture.accept(
      item,
      accountId: accountId,
      // A client's payment is variable income, whatever it was taken for.
      category:
          paid?.income != null &&
              (category == null || category == 'other_income')
          ? 'freelance'
          : category,
      payee: item.suggestion.payee,
    );
    if (paid == null) return showRecorded(messenger, own, done);
    final (String, Future<void> Function()) settled = await _settle(
      l,
      paid,
      done.entry,
    );
    showRecorded(messenger, own, done, also: settled.$1, undoAlso: settled.$2);
  }

  /// What the money that came in settles while it waits: the client's
  /// payment the person was expecting, or what someone owed them.
  PaymentMatch? get _paid {
    final ParsedCapture p = item.parsed;
    final Decimal? amount = p.amount;
    final Ledger? ledger = own.ledger;
    final Asset base = own.profile?.base ?? Asset.cop;
    if (item.status != InboxStatus.pending ||
        p.kind != EntryKind.income ||
        amount == null ||
        ledger == null ||
        (p.asset != null && p.asset != base)) {
      return null;
    }
    return matchPayment(
      from: item.suggestion.payee ?? p.merchant ?? '',
      amount: ledger.minor(amount.toDouble()),
      freelance: own.freelance,
      groups: own.groups,
    );
  }

  /// Marks what [paid] settles with [entry], the income just recorded: the
  /// client's payment as collected, or the payment of what someone owed.
  /// Gives back what to say, and how to take it back.
  Future<(String, Future<void> Function())> _settle(
    AppLocalizations l,
    PaymentMatch paid,
    Entry entry,
  ) async {
    final Ledger? ledger = own.ledger;
    final ExpectedIncome? income = paid.income;
    if (income != null) {
      await own.saveFreelance(
        own.freelance.withIncome(
          income.copyWith(
            status: IncomeStatus.collected,
            collectedOn: entry.date,
            entryId: entry.id,
          ),
        ),
      );
      return (
        l.collectedDone(income.client),
        () => own.saveFreelance(own.freelance.withIncome(income)),
      );
    }
    final Group group = paid.group!;
    final Member member = paid.member!;
    final int received = ledger?.minor(entry.amount.toDouble()) ?? paid.owed;
    final int amount = received < paid.owed ? received : paid.owed;
    final Settlement settlement = Settlement(
      id: 'settle-${DateTime.now().microsecondsSinceEpoch}',
      from: member.id,
      to: meId,
      amount: amount,
      date: entry.date,
      entryId: entry.id,
    );
    await own.settle(group, settlement);
    final int left = paid.owed - amount;
    return (
      left > 0 && ledger != null
          ? l.repaidLeft(member.name, pesos(ledger.major(left)))
          : l.repaidAll(member.name),
      () => own.unsettle(
        own.groups.where((Group g) => g.id == group.id).firstOrNull ?? group,
        settlement,
      ),
    );
  }

  /// Asks which account it was: those at the bank the alert names first,
  /// then the everyday ones in its currency, and the rest apart under
  /// «Otras cuentas»; and says what the answer will teach.
  Future<String?> _pickAccount() {
    final AppLocalizations l = context.l10n;
    final ParsedCapture p = item.parsed;
    final String? institution = p.institution;
    final String? card = p.card;
    final String? number = p.account;
    final Asset asset = p.asset ?? own.profile?.base ?? Asset.cop;
    // Money that came in reached a bank or a wallet, not a card.
    bool likely(Account a) =>
        a.spendable &&
        a.asset == asset &&
        !(p.kind == EntryKind.income && a.kind == AccountKind.card);
    final List<Account> there = institution == null
        ? const <Account>[]
        : accountsAt(institution, own.accounts);
    final List<Account> choices = <Account>[
      for (final Account a in there)
        if (likely(a)) a,
      for (final Account a in own.accounts)
        if (!there.contains(a) && likely(a)) a,
    ];
    final List<Account> others = <Account>[
      for (final Account a in own.accounts)
        if (!choices.contains(a)) a,
    ];
    // Only what confirming will learn: a card's rule, or else the
    // account's, or else the bank's when the person has an account there,
    // unless they turned it off.
    final Set<String> off = own.captureSettings.disabledRules;
    final String? note = card != null
        ? off.contains(CaptureRule.idOf(RuleKind.card, card))
              ? null
              : l.pickAccountCardNote(card)
        : number != null
        ? off.contains(CaptureRule.idOf(RuleKind.account, number))
              ? null
              : l.pickAccountNumberNote(number)
        : institution != null &&
              there.isNotEmpty &&
              CaptureService.teachesInstitution(p, own.profile?.base) &&
              !off.contains(CaptureRule.idOf(RuleKind.institution, institution))
        ? l.pickAccountBankNote(institution)
        : null;
    Widget choice(BuildContext context, Account a) => ListTile(
      contentPadding: EdgeInsets.zero,
      leading: AccountTile(a.kind, size: 36),
      title: Text(a.name),
      subtitle: Text('${accountKindLabel(context, a.kind)} · ${a.asset.code}'),
      onTap: () => Navigator.of(context).pop(a.id),
    );
    return showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      useSafeArea: true,
      backgroundColor: context.colors.surface,
      constraints: const BoxConstraints(maxWidth: 560),
      builder: (BuildContext context) => SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Text(
              p.kind == EntryKind.income ? l.pickAccountIn : l.pickAccountOut,
              style: context.type.headlineMedium,
            ),
            if (note != null) ...<Widget>[
              const SizedBox(height: 6),
              Text(note, style: context.type.bodyMedium),
            ],
            const SizedBox(height: 8),
            for (final Account a in choices) choice(context, a),
            if (others.isNotEmpty) ...<Widget>[
              if (choices.isNotEmpty) ...<Widget>[
                const SizedBox(height: 12),
                Text(l.pickAccountOthers, style: context.type.labelMedium),
              ],
              for (final Account a in others) choice(context, a),
            ],
          ],
        ),
      ),
    );
  }

  Future<void> _edit() => showEntrySheet(context, own: own, fromInbox: item);

  /// Adds the person's account at [bank], which the alert came from: the
  /// capture then waits ready to record in it.
  Future<void> _addBankAccount(String bank) => showAccountSheet(
    context,
    own: own,
    draft: AccountDraft(
      name: bank,
      kind: AccountKind.bank,
      asset: item.parsed.asset ?? own.profile?.base ?? Asset.cop,
      institution: bank,
    ),
  );

  /// The movement an automatic record made, to correct it in place: what
  /// the person changes there is what the app learns, and says so.
  Future<void> _fix() async {
    final Entry? entry = _made;
    if (entry == null) return;
    final ScaffoldMessengerState messenger = ScaffoldMessenger.of(context);
    final InboxItem before = item;
    final bool? saved = await showEntrySheet(context, own: own, entry: entry);
    if (saved != true) return;
    final List<RuleChange> learned = await own.capture.corrected(before);
    if (learned.isEmpty) return;
    showLearned(messenger, own, learned, before);
  }

  Future<void> _undo() async {
    setState(() => _busy = true);
    await own.capture.undo(item);
  }

  /// Sets the capture aside with a way back; stopping reading its app asks
  /// first.
  Future<void> _dismiss({bool mute = false}) async {
    setState(() => _busy = true);
    if (!await discardCapture(context, own, item, muteApp: mute) && mounted) {
      setState(() => _busy = false);
    }
  }

  /// Who sent it, as the person knows them; how it arrived when there is
  /// no name.
  String _who(AppLocalizations l) =>
      item.parsed.institution ??
      item.event.sender ??
      item.event.appName ??
      sourceLabel(l, item.event.source);

  Future<void> _ownTransfer() =>
      showEntrySheet(context, own: own, fromInbox: item, ownTransfer: true);

  void _more(_More choice) => switch (choice) {
    _More.details => setState(() => _details = !_details),
    _More.dismiss => _dismiss(),
    _More.mute => _dismiss(mute: true),
  };

  /// What a capture still waiting is, or what it lacks, in a word and a
  /// line: the one question its button answers.
  Widget? _stateOf(
    BuildContext context, {
    required OwnMove? move,
    required PaymentMatch? paid,
    required Account? account,
    required String categoryName,
  }) {
    final AppLocalizations l = context.l10n;
    final InboxItem i = item;
    final Color caution = context.colors.caution;
    final Color brand = context.colors.brand;
    if (i.status == InboxStatus.duplicate) {
      final (String, Entry?)? twin = _twin(l);
      final Entry? entry = twin?.$2;
      return _StateLine(
        icon: Glyph.copy,
        label: l.stateRepeat,
        color: caution,
        detail: twin?.$1,
        onTap: entry == null
            ? null
            : () => showEntrySheet(context, own: own, entry: entry),
      );
    }
    if (i.status != InboxStatus.pending) return null;
    if (move != null) {
      return _StateLine(
        icon: Glyph.arrowsLeftRight,
        label: l.stateMove,
        color: brand,
        detail: _moveWhy(l, move),
      );
    }
    if (i.parsed.kind == null) {
      return _StateLine(
        icon: Glyph.warningCircle,
        label: l.stateKind,
        color: caution,
      );
    }
    if (account == null) {
      return _StateLine(
        icon: Glyph.warningCircle,
        label: l.stateAccount,
        color: caution,
        detail: <String>[
          missingAccountText(context, own, i),
          if (paid != null) _paidDetail(l, paid),
        ].join(' '),
      );
    }
    if (paid != null) {
      return _StateLine(
        icon: Glyph.handCoins,
        label: paid.income != null ? l.stateClientPaid : l.stateFriendPaid,
        color: brand,
        detail: _paidDetail(l, paid),
      );
    }
    if (i.suggestion.why.contains('only')) {
      return _StateLine(
        icon: Glyph.warningCircle,
        label: l.stateGuessed,
        color: caution,
        detail: l.accountGuessedWhy(account.asset.code),
      );
    }
    // Ready, and what keeps it out of what is recorded all at once.
    return _StateLine(
      icon: Glyph.checkCircle,
      label: l.stateReady,
      color: brand,
      detail: CaptureService.isClear(i, own.accounts)
          ? null
          : i.suggestion.category == null
          ? l.stateCheckCategory(categoryName)
          : i.event.source == CaptureSource.screenshot
          ? l.stateCheckImage
          : null,
    );
  }

  /// What a possible repeat repeats, said so the person can check it before
  /// taking it out: the movement already in the accounts, which a tap
  /// opens, or the other notice that arrived.
  (String, Entry?)? _twin(AppLocalizations l) {
    final String? id = item.duplicateOf;
    if (id == null) return null;
    final Entry? e = own.entryById(id);
    if (e != null) {
      final Account? a = own.snapshot?.account(e.accountId);
      final String? origin = entryOrigin(l, e)?.$2;
      return (
        l.repeatOf(
          <String>[
            if (e.payee.isNotEmpty) e.payee,
            moneyText(
              Money(e.amount.abs(), a?.asset ?? own.profile?.base ?? Asset.cop),
              base: own.profile?.base,
            ),
            dayShortMonth(e.date),
            ?a?.name,
            if (origin != null && origin.isNotEmpty)
              '${origin[0].toLowerCase()}${origin.substring(1)}',
          ].join(' · '),
        ),
        e,
      );
    }
    final InboxItem? other = own.inbox
        .where((InboxItem x) => x.id == id)
        .firstOrNull;
    if (other == null) return null;
    return (
      l.repeatOfNotice(
        <String>[
          sourceLabel(l, other.event.source),
          ?other.parsed.institution,
          dayAndTime(other.event.at),
        ].join(' · '),
      ),
      null,
    );
  }

  /// How it arrived, why the app proposed what it did, and the message
  /// itself: what explains the card, not what decides it.
  Widget _detection(BuildContext context) {
    final AppLocalizations l = context.l10n;
    final InboxItem i = item;
    final String how = sourceLabel(l, i.event.source);
    final String who = _who(l);
    final List<String> reasons = <String>[
      for (final String r in reasonList(context, own, i))
        r.isEmpty ? r : '${r[0].toUpperCase()}${r.substring(1)}.',
    ];
    final TextStyle? title = context.type.labelMedium;
    final TextStyle? body = context.type.bodySmall;
    return Container(
      margin: const EdgeInsets.only(top: 10),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: context.colors.sunken,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(l.detectionHow, style: title),
          const SizedBox(height: 4),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Icon(
                sourceIcon(i.event.source),
                size: 16,
                color: context.colors.inkFaint,
              ),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  <String>[
                    how,
                    if (who != how) who,
                    dayAndTime(i.event.at),
                  ].join(' · '),
                  style: body,
                ),
              ),
            ],
          ),
          if (reasons.isNotEmpty || i.suggestion.place != null) ...<Widget>[
            const SizedBox(height: 12),
            Text(l.detectionWhy, style: title),
            const SizedBox(height: 4),
            for (final String r in reasons) Text(r, style: body),
            if (i.suggestion.place case final place?)
              Text(
                l.nearbyPlace(place.name, place.metres.round()),
                style: body,
              ),
          ],
          if (i.event.text.trim().isNotEmpty) ...<Widget>[
            const SizedBox(height: 12),
            Text(l.detectionMessage, style: title),
            const SizedBox(height: 4),
            SelectableText(i.event.text, style: body),
          ],
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l = context.l10n;
    final InboxItem i = item;
    final Account? account = _account;
    // What was recorded shows as it is now, corrected or not; what waits
    // shows what the app read.
    final Entry? made = _made;
    // A bare `$` with no account yet reads as the base currency.
    final Asset? asset = made != null
        ? account?.asset
        : i.parsed.asset ?? account?.asset ?? own.profile?.base;
    final Decimal? amount = made?.amount.abs() ?? i.parsed.amount;
    final EntryKind? kind = made?.kind ?? i.parsed.kind;
    final bool income = made != null
        ? made.amount > Decimal.zero
        : kind == EntryKind.income;
    // What recording it saves, also when the app found no category.
    final String category =
        made?.category ??
        i.suggestion.category ??
        (income ? 'other_income' : 'other');
    // Which way it went is not known yet: neither spending nor income.
    final String categoryName = kind == null
        ? l.unclassified
        : categoryNameFor(context, category, own.categories);
    final bool repeat = i.status == InboxStatus.duplicate;
    // Recorded on its own: it can be undone or corrected, not recorded
    // again.
    final bool recorded = i.status == InboxStatus.accepted;
    final bool waiting = !repeat && !recorded;
    // Money that only changed accounts reads as the move it is: from one
    // to the other, neither spent nor earned.
    final OwnMove? move = waiting ? _move : null;
    // Money that came in may be what a client or a friend owed.
    final PaymentMatch? paid = waiting && move == null ? _paid : null;
    final (Account, Account)? moved = _moved;
    final (String, String)? between = move != null
        ? (
            own.snapshot?.account(move.fromId)?.name ?? '',
            own.snapshot?.account(move.toId)?.name ?? '',
          )
        : moved == null
        ? null
        : (moved.$1.name, moved.$2.name);
    final String payee = between != null
        ? '${between.$1} → ${between.$2}'
        : (made == null || made.payee.isEmpty ? null : made.payee) ??
              i.suggestion.payee ??
              i.parsed.merchant ??
              l.noMerchant;
    final String? disc = between != null ? null : category;
    final String what = between != null ? l.moveBetween : categoryName;
    // When the payment happened, as the receipt says, not when it was
    // shared.
    final DateTime when = made?.date ?? i.parsed.when ?? i.event.at;
    final String amountText = amount == null
        ? '—'
        : asset == null
        ? formatDecimal(amount, decimals: 2, trim: true)
        // Which way it went is not known yet, or it stayed the person's:
        // no sign either.
        : moneyText(
            Money(income || kind == null ? amount : -amount, asset),
            base: own.profile?.base,
            signed: kind != null && between == null,
          );
    final Color amountColor = income && between == null
        ? context.colors.positive
        : context.colors.ink;
    // With large text the amount and the day go under the name, which
    // keeps the room to be read.
    final bool large = MediaQuery.textScalerOf(context).scale(10) > 13;

    final Widget body;
    if (widget.compact && !_open) {
      final Widget figures = Figures(
        amountText,
        style: context.type.titleSmall?.copyWith(color: amountColor),
      );
      body = Semantics(
        expanded: false,
        child: InkWell(
          onTap: () => setState(() => _open = true),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 4, 8),
            child: Row(
              children: <Widget>[
                CategoryDisc(disc, size: 32),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Text(
                        payee,
                        style: context.type.titleSmall,
                        maxLines: large ? 2 : 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      Text(
                        <String>[
                          what,
                          if (move == null) ?account?.name,
                          // The day and its month stay together.
                          dayShortMonth(when).replaceAll(' ', '\u00a0'),
                        ].join(' · '),
                        style: context.type.bodySmall,
                        // The account is what the tick records into: it
                        // wraps rather than goes.
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      // Left out of what is recorded all at once: why.
                      if (move == null &&
                          i.suggestion.category == null &&
                          !CaptureService.isClear(i, own.accounts))
                        Text(
                          l.categoryToConfirm,
                          style: context.type.bodySmall?.copyWith(
                            color: context.colors.caution,
                          ),
                        ),
                      if (large) figures,
                    ],
                  ),
                ),
                if (!large) ...<Widget>[const SizedBox(width: 8), figures],
                IconButton(
                  tooltip: _recordLabel(l, move: move, paid: paid),
                  onPressed: _busy ? null : _confirm,
                  icon: Icon(Glyph.check, color: context.colors.brand),
                ),
              ],
            ),
          ),
        ),
      );
    } else {
      // Who was paid, where it goes and how much come first; how the app
      // found out waits in the menu.
      final Widget amountFigures = Figures(
        amountText,
        style: context.type.titleMedium?.copyWith(color: amountColor),
      );
      // With large text, or on a narrow card, the amount and the day go
      // under the name, which keeps the room to be read.
      final Widget main = LayoutBuilder(
        builder: (BuildContext context, BoxConstraints box) {
          final bool stack =
              large ||
              box.maxWidth < MediaQuery.textScalerOf(context).scale(280);
          final Widget day = Text(
            dayAndTime(when),
            textAlign: stack ? TextAlign.start : TextAlign.end,
            style: context.type.labelSmall?.copyWith(
              color: context.colors.inkFaint,
            ),
          );
          final Widget names = Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Text(
                payee,
                style: context.type.titleSmall,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
              Text.rich(
                TextSpan(
                  children: <InlineSpan>[
                    TextSpan(text: what),
                    if (move == null && account != null)
                      TextSpan(text: ' · ${account.name}')
                    else if (move == null && waiting)
                      TextSpan(
                        text: ' · ${l.accountMissingShort}',
                        style: TextStyle(color: context.colors.caution),
                      ),
                  ],
                ),
                style: context.type.bodySmall,
              ),
              if (stack) ...<Widget>[
                const SizedBox(height: 4),
                amountFigures,
                day,
              ],
            ],
          );
          return Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              CategoryDisc(disc),
              const SizedBox(width: 12),
              Expanded(child: names),
              if (!stack) ...<Widget>[
                const SizedBox(width: 12),
                // The amount and the day never take more than half the row:
                // the name keeps its room.
                ConstrainedBox(
                  constraints: BoxConstraints(maxWidth: box.maxWidth / 2),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: <Widget>[
                      FittedBox(fit: BoxFit.scaleDown, child: amountFigures),
                      day,
                    ],
                  ),
                ),
              ],
            ],
          );
        },
      );

      body = Padding(
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            if (widget.compact)
              Semantics(
                expanded: true,
                child: InkWell(
                  onTap: () => setState(() => _open = false),
                  borderRadius: BorderRadius.circular(12),
                  child: main,
                ),
              )
            else
              main,
            // The shop's name, or its kind, came from OpenStreetMap: its
            // credit goes right under them.
            if (i.suggestion.place != null)
              Padding(
                padding: const EdgeInsets.only(left: 52, top: 2),
                child: Row(
                  children: <Widget>[
                    Icon(Glyph.globe, size: 12, color: context.colors.inkFaint),
                    const SizedBox(width: 4),
                    Flexible(
                      child: Text(l.placeShort, style: context.type.bodySmall),
                    ),
                  ],
                ),
              ),
            ?_stateOf(
              context,
              move: move,
              paid: paid,
              account: account,
              categoryName: categoryName,
            ),
            // A bank the person has no account at in the app: that account
            // is what is missing, not one of the others.
            if (waiting && account == null)
              if (i.parsed.institution case final String bank
                  when accountsAt(bank, own.accounts).isEmpty)
                Align(
                  alignment: Alignment.centerLeft,
                  child: TextButton.icon(
                    onPressed: _busy ? null : () => _addBankAccount(bank),
                    style: TextButton.styleFrom(
                      padding: const EdgeInsets.symmetric(horizontal: 4),
                    ),
                    icon: const Icon(Glyph.plus, size: 16),
                    label: Text(l.addAccountAt(bank)),
                  ),
                ),
            // Every automatic record says why it went in without asking: a
            // notice of a move already recorded, which side of it it was.
            if (recorded)
              if (moved != null &&
                  i.suggestion.why.contains(CaptureService.joined))
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Text(
                    made != null && made.amount > Decimal.zero
                        ? l.joinedArrival(moved.$2.name, moved.$1.name)
                        : l.joinedDeparture(moved.$1.name, moved.$2.name),
                    style: context.type.bodySmall,
                  ),
                )
              else if (reasonsText(context, own, i) case final String why)
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Text(why, style: context.type.bodySmall),
                ),
            // Money that arrived may be the person's own, moved from another
            // account, and money with no one named that left may have gone
            // to another of theirs: recorded as income or spending, it would
            // count twice.
            if (waiting &&
                move == null &&
                own.accounts.length > 1 &&
                (income ||
                    (kind == EntryKind.expense &&
                        i.suggestion.payee == null &&
                        i.parsed.merchant == null)))
              Align(
                alignment: Alignment.centerLeft,
                child: TextButton.icon(
                  onPressed: _busy ? null : _ownTransfer,
                  style: TextButton.styleFrom(
                    padding: const EdgeInsets.symmetric(horizontal: 4),
                    foregroundColor: context.colors.inkSoft,
                  ),
                  icon: const Icon(Glyph.arrowsLeftRight, size: 16),
                  label: Text(income ? l.fromOwnAccount : l.fromOwnAccountOut),
                ),
              ),
            if (_details) _detection(context),
            const SizedBox(height: 8),
            Row(
              children: <Widget>[
                Expanded(
                  child: Wrap(
                    spacing: 8,
                    runSpacing: 4,
                    children: <Widget>[
                      if (recorded) ...<Widget>[
                        OutlinedButton(
                          onPressed: _busy ? null : _undo,
                          child: Text(l.undo),
                        ),
                        TextButton(
                          onPressed: _busy ? null : _fix,
                          style: TextButton.styleFrom(
                            foregroundColor: context.colors.ink,
                          ),
                          child: Text(l.fixMovement),
                        ),
                      ] else if (repeat) ...<Widget>[
                        // What arrived twice is most often a repeat: taking
                        // it out comes first.
                        FilledButton(
                          onPressed: _busy ? null : _dismiss,
                          child: Text(l.removeRepeat),
                        ),
                        TextButton(
                          onPressed: _busy
                              ? null
                              : () => own.capture.notDuplicate(i),
                          style: TextButton.styleFrom(
                            foregroundColor: context.colors.ink,
                          ),
                          child: Text(l.notDuplicate),
                        ),
                      ] else if (move != null) ...<Widget>[
                        FilledButton(
                          onPressed: _busy || amount == null
                              ? null
                              : () => _recordMove(move),
                          child: Text(l.recordTransfer),
                        ),
                        TextButton(
                          onPressed: _busy
                              ? null
                              : () => own.capture.notOwnMove(i),
                          style: TextButton.styleFrom(
                            foregroundColor: context.colors.ink,
                          ),
                          child: Text(l.notMove),
                        ),
                      ]
                      // Which way the money went is the form's to ask.
                      else if (kind == null)
                        FilledButton(
                          onPressed: _busy ? null : _edit,
                          child: Text(l.reviewMovement),
                        )
                      else ...<Widget>[
                        FilledButton(
                          onPressed: _busy || amount == null ? null : _confirm,
                          child: Text(
                            account == null
                                ? l.chooseAccount
                                : _recordLabel(l, paid: paid),
                          ),
                        ),
                        TextButton(
                          onPressed: _busy ? null : _edit,
                          style: TextButton.styleFrom(
                            foregroundColor: context.colors.ink,
                          ),
                          child: Text(l.edit),
                        ),
                      ],
                    ],
                  ),
                ),
                PopupMenuButton<_More>(
                  tooltip: l.moreActions,
                  icon: Icon(
                    Glyph.dotsThreeVertical,
                    color: context.colors.inkSoft,
                  ),
                  onSelected: _more,
                  itemBuilder: (BuildContext context) =>
                      <PopupMenuEntry<_More>>[
                        PopupMenuItem<_More>(
                          value: _More.details,
                          child: Text(
                            _details
                                ? l.hideDetectionDetails
                                : l.detectionDetails,
                          ),
                        ),
                        if (!recorded) ...<PopupMenuEntry<_More>>[
                          PopupMenuItem<_More>(
                            value: _More.dismiss,
                            child: Text(l.dismiss),
                          ),
                          if (i.event.app case final String app)
                            PopupMenuItem<_More>(
                              value: _More.mute,
                              child: Text(
                                l.dismissAndMute(
                                  i.parsed.institution ??
                                      i.event.appName ??
                                      app,
                                ),
                              ),
                            ),
                        ],
                      ],
                ),
              ],
            ),
          ],
        ),
      );
    }

    if (widget.compact) {
      return AnimatedSize(
        duration: MediaQuery.disableAnimationsOf(context)
            ? Duration.zero
            : const Duration(milliseconds: 200),
        curve: Curves.easeOutCubic,
        alignment: Alignment.topCenter,
        child: body,
      );
    }
    return Material(
      color: context.colors.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: BorderSide(color: context.colors.line),
      ),
      clipBehavior: Clip.antiAlias,
      child: body,
    );
  }
}

/// A capture's state on its card: a short label in its color and, under
/// it, the line that explains it; a tap opens what that line names.
class _StateLine extends StatelessWidget {
  const _StateLine({
    required this.icon,
    required this.label,
    required this.color,
    this.detail,
    this.onTap,
  });

  final IconData icon;
  final String label;
  final Color color;
  final String? detail;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final Widget line = Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Padding(
            padding: const EdgeInsets.only(top: 1),
            child: Icon(icon, size: 16, color: color),
          ),
          const SizedBox(width: 6),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  label,
                  style: context.type.labelMedium?.copyWith(color: color),
                ),
                if (detail case final String text)
                  Text(text, style: context.type.bodySmall),
              ],
            ),
          ),
          if (onTap != null)
            Icon(Glyph.caretRight, size: 16, color: context.colors.inkFaint),
        ],
      ),
    );
    return Padding(
      padding: const EdgeInsets.only(top: 6),
      child: onTap == null
          ? line
          : InkWell(
              onTap: onTap,
              borderRadius: BorderRadius.circular(8),
              child: line,
            ),
    );
  }
}

/// What the card's menu holds: how the capture was detected, and ways to
/// set it aside.
enum _More { details, dismiss, mute }

/// Reads a message the person pastes, as if it had arrived on its own.
Future<void> showPasteDialog(BuildContext context, OwnController own) async {
  final AppLocalizations l = context.l10n;
  final ScaffoldMessengerState messenger = ScaffoldMessenger.of(context);
  // The example brings a bank's message of its own to try, and leaves what
  // the person copied alone.
  final ClipboardData? clip = own.example
      ? null
      : await Clipboard.getData(Clipboard.kTextPlain);
  if (!context.mounted) return;
  final String? typed = await showDialog<String>(
    context: context,
    builder: (BuildContext context) => own.example
        ? _PasteDialog(initial: exampleMessage, note: l.examplePasteNote)
        : _PasteDialog(initial: clip?.text?.trim() ?? ''),
  );
  if (typed == null || typed.trim().isEmpty) return;
  final IngestReport r = await own.ingestText(typed.trim());
  messenger.showSnackBar(
    SnackBar(
      content: Text(
        r.recorded > 0
            ? l.pasteRecorded
            : r.added > 0
            ? l.pasteAdded
            : r.joined > 0
            ? l.pasteJoined
            : r.duplicates > 0
            ? l.pasteDuplicate
            : l.pasteNothing,
      ),
    ),
  );
}

/// Where the person pastes a message. It owns its controller, so the field
/// can still draw while the dialog closes.
class _PasteDialog extends StatefulWidget {
  const _PasteDialog({required this.initial, this.note});

  /// What the clipboard held when it opened.
  final String initial;

  /// What to know about [initial], under the field.
  final String? note;

  @override
  State<_PasteDialog> createState() => _PasteDialogState();
}

class _PasteDialogState extends State<_PasteDialog> {
  late final TextEditingController _text = TextEditingController(
    text: widget.initial,
  );

  @override
  void dispose() {
    _text.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l = context.l10n;
    return AlertDialog(
      scrollable: true,
      title: Text(l.pasteMessage),
      content: TextField(
        controller: _text,
        autofocus: true,
        minLines: 3,
        maxLines: 6,
        decoration: InputDecoration(
          hintText: l.pasteHint,
          helperText: widget.note,
          helperMaxLines: 3,
        ),
      ),
      actions: <Widget>[
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(l.cancel),
        ),
        FilledButton(
          onPressed: () => Navigator.of(context).pop(_text.text),
          child: Text(l.pasteRead),
        ),
      ],
    );
  }
}
