import 'dart:async';

import 'package:decimal/decimal.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../capture/capture_service.dart';
import '../../capture/event.dart';
import '../../capture/inbox.dart';
import '../../capture/native_channel.dart';
import '../../capture/parser.dart';
import '../../domain/records.dart';
import '../../format/dates.dart';
import '../../l10n/l10n.dart';
import '../../money/asset.dart';
import '../../money/money.dart';
import '../../own/own_controller.dart';
import '../../theme/tokens.dart';
import '../icons.dart';
import '../exit_list.dart';
import '../kit.dart';
import 'capture_reasons.dart';
import 'entry_sheet.dart';
import 'look.dart';
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
        // What automatic recording would take on its own can go together.
        final List<InboxItem> clear = <InboxItem>[
          for (final InboxItem i in ready)
            if (CaptureService.isClear(i, accounts)) i,
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
                          Text(l.inboxEmpty, style: context.type.titleSmall),
                          const SizedBox(height: 4),
                          Text(
                            l.inboxEmptyBody,
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
                        ready: ready.length,
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
    required this.ready,
  });

  final OwnController own;
  final List<InboxItem> items;

  /// How many are ready in all: a category the app had to guess, or a
  /// picture's reading, leaves one of them for the person to record.
  final int ready;

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
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 8),
    child: Align(
      alignment: Alignment.centerLeft,
      child: TextButton.icon(
        onPressed: _busy ? null : _record,
        icon: const Icon(Glyph.checks, size: 18),
        label: Text(
          widget.items.length < widget.ready
              ? context.l10n.inboxRecordSome(widget.items.length, widget.ready)
              : context.l10n.inboxRecordReady(widget.items.length),
        ),
      ),
    ),
  );
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

  /// What recording it does, said on what records it.
  String _recordLabel(AppLocalizations l) =>
      item.parsed.kind == EntryKind.income ? l.recordIncome : l.recordExpense;

  Future<void> _confirm() async {
    final Account? account = _account;
    if (account != null) return _record(account.id);
    final String? picked = await _pickAccount();
    if (picked != null && mounted) await _record(picked);
  }

  Future<void> _record(String accountId) async {
    final ScaffoldMessengerState messenger = ScaffoldMessenger.of(context);
    setState(() => _busy = true);
    unawaited(HapticFeedback.lightImpact());
    final Accepted done = await own.capture.accept(
      item,
      accountId: accountId,
      category: item.suggestion.category,
      payee: item.suggestion.payee,
    );
    showRecorded(messenger, own, done);
  }

  /// Asks which account it was, those at the bank the alert names first,
  /// then the everyday ones in its currency, and says what the answer will
  /// teach.
  Future<String?> _pickAccount() {
    final AppLocalizations l = context.l10n;
    final ParsedCapture p = item.parsed;
    final String? institution = p.institution;
    final String? card = p.card;
    final Asset asset = p.asset ?? own.profile?.base ?? Asset.cop;
    bool likely(Account a) => a.spendable && a.asset == asset;
    final List<Account> there = institution == null
        ? const <Account>[]
        : accountsAt(institution, own.accounts);
    final Set<String> first = <String>{for (final Account a in there) a.id};
    final List<Account> choices = <Account>[
      ...there,
      for (final Account a in own.accounts)
        if (!first.contains(a.id) && likely(a)) a,
      for (final Account a in own.accounts)
        if (!first.contains(a.id) && !likely(a)) a,
    ];
    // Only what confirming will learn: a card's rule, or else the bank's,
    // unless the person turned it off.
    final Set<String> off = own.captureSettings.disabledRules;
    final String? note = card != null
        ? off.contains(CaptureRule.idOf(RuleKind.card, card))
              ? null
              : l.pickAccountCardNote(card)
        : institution != null &&
              CaptureService.teachesInstitution(p, own.profile?.base) &&
              !off.contains(CaptureRule.idOf(RuleKind.institution, institution))
        ? l.pickAccountBankNote(institution)
        : null;
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
            for (final Account a in choices)
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: AccountTile(a.kind, size: 36),
                title: Text(a.name),
                subtitle: Text(
                  '${accountKindLabel(context, a.kind)} · ${a.asset.code}',
                ),
                onTap: () => Navigator.of(context).pop(a.id),
              ),
          ],
        ),
      ),
    );
  }

  Future<void> _edit() => showEntrySheet(context, own: own, fromInbox: item);

  /// The movement an automatic record made, to correct it in place.
  Future<void> _fix() async {
    final Entry? entry = _made;
    if (entry == null) return;
    await showEntrySheet(context, own: own, entry: entry);
  }

  Future<void> _undo() async {
    setState(() => _busy = true);
    await own.capture.undo(item);
  }

  Future<void> _dismiss({bool mute = false}) async {
    setState(() => _busy = true);
    await own.capture.dismiss(item, muteApp: mute);
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

  /// A line that says what is missing or worth a second look.
  Widget _caution(BuildContext context, String text) => Padding(
    padding: const EdgeInsets.only(top: 8),
    child: Text(
      text,
      style: context.type.bodySmall?.copyWith(color: context.colors.caution),
    ),
  );

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
    final String categoryName = categoryNameFor(
      context,
      category,
      own.categories,
    );
    final bool repeat = i.status == InboxStatus.duplicate;
    // Recorded on its own: it can be undone or corrected, not recorded
    // again.
    final bool recorded = i.status == InboxStatus.accepted;
    final bool waiting = !repeat && !recorded;
    final String payee =
        (made == null || made.payee.isEmpty ? null : made.payee) ??
        i.suggestion.payee ??
        i.parsed.merchant ??
        l.noMerchant;
    // When the payment happened, as the receipt says, not when it was
    // shared.
    final DateTime when = made?.date ?? i.parsed.when ?? i.event.at;
    final String amountText = amount == null
        ? '—'
        : asset == null
        ? formatDecimal(amount, decimals: 2, trim: true)
        // Which way it went is not known yet: no sign either.
        : moneyText(
            Money(income || kind == null ? amount : -amount, asset),
            base: own.profile?.base,
            signed: kind != null,
          );
    final Color amountColor = income
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
                CategoryDisc(category, size: 32),
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
                          categoryName,
                          ?account?.name,
                          dayShortMonth(when),
                        ].join(' · '),
                        style: context.type.bodySmall,
                        // The account is what the tick records into: it
                        // wraps rather than goes.
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      if (large) figures,
                    ],
                  ),
                ),
                if (!large) ...<Widget>[const SizedBox(width: 8), figures],
                IconButton(
                  tooltip: _recordLabel(l),
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
                    TextSpan(text: categoryName),
                    if (account != null)
                      TextSpan(text: ' · ${account.name}')
                    else if (waiting)
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
              CategoryDisc(category),
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
            if (waiting && kind == null) _caution(context, l.kindMissing),
            if (waiting && account == null)
              _caution(context, missingAccountText(context, own, i)),
            if (waiting && account != null && i.suggestion.why.contains('only'))
              _caution(context, l.accountGuessed(account.asset.code)),
            // Every automatic record says why it went in without asking.
            if (recorded)
              if (reasonsText(context, own, i) case final String why)
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Text(why, style: context.type.bodySmall),
                ),
            if (repeat) _caution(context, l.duplicateLine),
            // Money that arrived may be the person's own, moved from another
            // account: recorded as income, it would count twice.
            if (income && waiting && own.accounts.length > 1)
              Align(
                alignment: Alignment.centerLeft,
                child: TextButton.icon(
                  onPressed: _busy ? null : _ownTransfer,
                  style: TextButton.styleFrom(
                    padding: const EdgeInsets.symmetric(horizontal: 4),
                    foregroundColor: context.colors.inkSoft,
                  ),
                  icon: const Icon(Glyph.arrowsLeftRight, size: 16),
                  label: Text(l.fromOwnAccount),
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
                      ] else if (repeat)
                        OutlinedButton(
                          onPressed: _busy
                              ? null
                              : () => own.capture.notDuplicate(i),
                          child: Text(l.notDuplicate),
                        )
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
                            account == null ? l.chooseAccount : _recordLabel(l),
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

/// What the card's menu holds: how the capture was detected, and ways to
/// set it aside.
enum _More { details, dismiss, mute }

/// Reads a message the person pastes, as if it had arrived on its own.
Future<void> showPasteDialog(BuildContext context, OwnController own) async {
  final AppLocalizations l = context.l10n;
  final ScaffoldMessengerState messenger = ScaffoldMessenger.of(context);
  final ClipboardData? clip = await Clipboard.getData(Clipboard.kTextPlain);
  if (!context.mounted) return;
  final String? typed = await showDialog<String>(
    context: context,
    builder: (BuildContext context) =>
        _PasteDialog(initial: clip?.text?.trim() ?? ''),
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
  const _PasteDialog({required this.initial});

  /// What the clipboard held when it opened.
  final String initial;

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
      title: Text(l.pasteMessage),
      content: TextField(
        controller: _text,
        autofocus: true,
        minLines: 3,
        maxLines: 6,
        decoration: InputDecoration(hintText: l.pasteHint),
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
