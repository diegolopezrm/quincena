import 'package:decimal/decimal.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../capture/capture_service.dart';
import '../../capture/event.dart';
import '../../capture/inbox.dart';
import '../../capture/native_channel.dart';
import '../../domain/records.dart';
import '../../format/dates.dart';
import '../../l10n/l10n.dart';
import '../../money/asset.dart';
import '../../money/money.dart';
import '../../own/own_controller.dart';
import '../../theme/tokens.dart';
import '../icons.dart';
import '../kit.dart';
import 'capture_reasons.dart';
import 'entry_sheet.dart';
import 'look.dart';
import 'read_images.dart';

/// Captures waiting to be confirmed, the possible repeats, and what was
/// recorded on its own lately.
class InboxPage extends StatelessWidget {
  const InboxPage({super.key, required this.own});

  final OwnController own;

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: own,
      builder: (BuildContext context, _) {
        final AppLocalizations l = context.l10n;
        final List<InboxItem> pending = own.pendingInbox;
        final List<InboxItem> repeats = <InboxItem>[
          for (final InboxItem i in own.inbox)
            if (i.status == InboxStatus.duplicate) i,
        ];
        return Scaffold(
          appBar: AppBar(
            backgroundColor: context.colors.canvas,
            surfaceTintColor: Colors.transparent,
            title: Text(l.inboxTitle, style: context.type.titleLarge),
            actions: <Widget>[
              if (CaptureChannel.readsImages)
                IconButton(
                  tooltip: l.readScreenshot,
                  onPressed: () => readImages(context, own),
                  icon: const Icon(Glyph.scan),
                ),
              IconButton(
                tooltip: l.pasteMessage,
                onPressed: () => showPasteDialog(context, own),
                icon: const Icon(Glyph.notePencil),
              ),
              const SizedBox(width: 8),
            ],
          ),
          body: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 760),
              child: ListView(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
                children: <Widget>[
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
                                icon: const Icon(Glyph.notePencil, size: 18),
                                label: Text(l.pasteMessage),
                              ),
                            ],
                          ),
                        ],
                      ),
                    )
                  else
                    for (final InboxItem item in pending) ...<Widget>[
                      InboxCard(own: own, item: item),
                      const SizedBox(height: 12),
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
  CaptureSource.paste => Glyph.notePencil,
};

/// One capture: what it says, what the app proposes, and what to do.
class InboxCard extends StatefulWidget {
  const InboxCard({super.key, required this.own, required this.item});

  final OwnController own;
  final InboxItem item;

  @override
  State<InboxCard> createState() => _InboxCardState();
}

class _InboxCardState extends State<InboxCard> {
  bool _original = false;
  bool _busy = false;

  OwnController get own => widget.own;
  InboxItem get item => widget.item;

  Account? get _account {
    final String? id = item.suggestion.accountId;
    return id == null ? null : own.snapshot?.account(id);
  }

  Future<void> _confirm() async {
    final Account? account = _account;
    if (account == null) return _edit();
    final ScaffoldMessengerState messenger = ScaffoldMessenger.of(context);
    setState(() => _busy = true);
    final Accepted done = await own.capture.accept(
      item,
      accountId: account.id,
      category: item.suggestion.category,
      payee: item.suggestion.payee,
    );
    if (mounted) showLearned(messenger, context, own, done.learned);
  }

  Future<void> _edit() => showEntrySheet(context, own: own, fromInbox: item);

  /// The movement an automatic record made, to correct it in place.
  Future<void> _fix() async {
    final String? id = item.entryId;
    final Entry? entry = own.snapshot?.entries
        .where((Entry e) => e.id == id)
        .firstOrNull;
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
  /// no name. The icon beside it says how.
  String _who(AppLocalizations l) =>
      item.parsed.institution ??
      item.event.sender ??
      item.event.appName ??
      sourceLabel(l, item.event.source);

  Future<void> _ownTransfer() =>
      showEntrySheet(context, own: own, fromInbox: item, ownTransfer: true);

  void _more(_More choice) => switch (choice) {
    _More.message => setState(() => _original = !_original),
    _More.dismiss => _dismiss(),
    _More.mute => _dismiss(mute: true),
  };

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l = context.l10n;
    final InboxItem i = item;
    final Account? account = _account;
    // A bare `$` with no account yet reads as the base currency.
    final Asset? asset = i.parsed.asset ?? account?.asset ?? own.profile?.base;
    final Decimal? amount = i.parsed.amount;
    final bool income = i.parsed.kind == EntryKind.income;
    final String? category = i.suggestion.category;
    final bool repeat = i.status == InboxStatus.duplicate;
    // Recorded on its own: it can be undone or corrected, not confirmed.
    final bool recorded = i.status == InboxStatus.accepted;
    final String amountText = amount == null
        ? '—'
        : asset == null
        ? formatDecimal(amount, decimals: 2, trim: true)
        : moneyText(
            Money(income ? amount : -amount, asset),
            base: own.profile?.base,
            signed: true,
          );
    return Material(
      color: context.colors.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: BorderSide(color: context.colors.line),
      ),
      clipBehavior: Clip.antiAlias,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            Row(
              children: <Widget>[
                Icon(
                  sourceIcon(i.event.source),
                  size: 16,
                  color: context.colors.inkFaint,
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: Semantics(
                    label: sourceLabel(l, i.event.source),
                    child: Text(
                      // When the payment happened, as the receipt says, not
                      // when it was shared.
                      '${_who(l)} · ${dayAndTime(i.parsed.when ?? i.event.at)}',
                      style: context.type.bodySmall,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Row(
              children: <Widget>[
                CategoryDisc(category ?? (income ? 'other_income' : 'other')),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Text(
                        i.suggestion.payee ?? i.parsed.merchant ?? l.noMerchant,
                        style: context.type.titleSmall,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      if (<String>[
                            if (category != null)
                              categoryNameFor(
                                context,
                                category,
                                own.categories,
                              ),
                            ?account?.name,
                          ]
                          case final List<String> parts when parts.isNotEmpty)
                        Text(
                          parts.join(' · '),
                          style: context.type.bodySmall,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                Figures(
                  amountText,
                  style: context.type.titleMedium?.copyWith(
                    color: income
                        ? context.colors.positive
                        : context.colors.ink,
                  ),
                ),
              ],
            ),
            if (account == null && !recorded) ...<Widget>[
              const SizedBox(height: 8),
              Text(
                income ? l.whichAccountIn : l.whichAccountOut,
                style: context.type.bodySmall?.copyWith(
                  color: context.colors.caution,
                ),
              ),
            ],
            if (reasonsText(context, own, i) case final String why) ...<Widget>[
              const SizedBox(height: 8),
              Text(why, style: context.type.bodySmall),
            ],
            // Money that arrived may be the person's own, moved from another
            // account: recorded as income, it would count twice.
            if (income && !recorded && !repeat && own.accounts.length > 1)
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
            if (i.suggestion.place case final place?) ...<Widget>[
              const SizedBox(height: 8),
              Row(
                children: <Widget>[
                  Icon(Glyph.globe, size: 14, color: context.colors.inkFaint),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      l.nearbyPlace(place.name, place.metres.round()),
                      style: context.type.bodySmall,
                    ),
                  ),
                ],
              ),
            ],
            if (repeat) ...<Widget>[
              const SizedBox(height: 8),
              Text(
                l.duplicateLine,
                style: context.type.bodySmall?.copyWith(
                  color: context.colors.caution,
                ),
              ),
            ],
            if (_original) ...<Widget>[
              const SizedBox(height: 10),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: context.colors.sunken,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: SelectableText(
                  i.event.text,
                  style: context.type.bodySmall,
                ),
              ),
            ],
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
                      else ...<Widget>[
                        FilledButton(
                          onPressed: _busy || amount == null ? null : _confirm,
                          child: Text(
                            account == null ? l.chooseAccount : l.confirm,
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
                          value: _More.message,
                          child: Text(
                            _original ? l.hideOriginal : l.showOriginal,
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
      ),
    );
  }
}

/// What the card's menu holds: the message itself, and ways to set the
/// capture aside.
enum _More { message, dismiss, mute }

/// Reads a message the person pastes, as if it had arrived on its own.
Future<void> showPasteDialog(BuildContext context, OwnController own) async {
  final AppLocalizations l = context.l10n;
  final ScaffoldMessengerState messenger = ScaffoldMessenger.of(context);
  final ClipboardData? clip = await Clipboard.getData(Clipboard.kTextPlain);
  if (!context.mounted) return;
  final TextEditingController text = TextEditingController(
    text: clip?.text?.trim() ?? '',
  );
  final String? typed = await showDialog<String>(
    context: context,
    builder: (BuildContext context) => AlertDialog(
      title: Text(l.pasteMessage),
      content: TextField(
        controller: text,
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
          onPressed: () => Navigator.of(context).pop(text.text),
          child: Text(l.pasteRead),
        ),
      ],
    ),
  );
  text.dispose();
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
