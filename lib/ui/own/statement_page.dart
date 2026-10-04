import 'package:decimal/decimal.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../../ai/allowance.dart';
import '../../capture/merchants.dart';
import '../../capture/native_channel.dart';
import '../../domain/records.dart';
import '../../format/dates.dart';
import '../../l10n/l10n.dart';
import '../../money/asset.dart';
import '../../money/money.dart';
import '../../own/own_controller.dart';
import '../../statements/gemini_statement.dart';
import '../../statements/statement.dart';
import '../../statements/statement_import.dart';
import '../../statements/tables.dart';
import '../../statements/text_statement.dart';
import '../../store/store.dart';
import '../../theme/tokens.dart';
import '../icons.dart';
import '../kit.dart';
import 'category_choices.dart';
import 'look.dart';
import 'movement_list.dart';

/// Brings a bank's statement into one of the person's accounts: picked as
/// a file, read on the device, and reviewed line by line before anything
/// is saved.
class StatementPage extends StatefulWidget {
  const StatementPage({
    super.key,
    required this.own,
    this.accountId,
    this.allowance,
    this.statement,
  });

  final OwnController own;

  /// A statement already read, such as one shared from another app, to
  /// review straight away.
  final StatementRead? statement;

  /// The account it was opened from, proposed first.
  final String? accountId;

  /// The day's Gemini questions, which reading with Gemini takes one of.
  final Allowance? allowance;

  @override
  State<StatementPage> createState() => _StatementPageState();
}

enum _Stage { pick, reading, nothing, review, done }

class _StatementPageState extends State<StatementPage> {
  _Stage _stage = _Stage.pick;
  String? _problem;
  StatementRead? _read;

  /// What the device read from a PDF, kept for Gemini if it is asked to.
  String? _pdfText;
  Uint8List? _pdfBytes;
  String? _accountId;
  List<ImportCandidate> _candidates = const <ImportCandidate>[];
  final Set<int> _chosen = <int>{};
  bool _saving = false;

  /// What the import does with lines older than the balance the person
  /// wrote, and whether it matches the statement's own last balance
  /// instead, when the statement prints one that adds up.
  BalanceRule _olderRule = BalanceRule.keep;
  bool _matchClosing = false;
  ClosingBalance? _closing;

  BalanceRule get _rule =>
      _matchClosing && _closing != null ? BalanceRule.statement : _olderRule;

  /// What the import recorded: how many, how many of them as moves
  /// between the person's accounts, and the statement references of those
  /// that came without a category, to give them one before leaving.
  int _imported = 0;
  int _transfers = 0;
  Set<String> _uncategorized = const <String>{};

  /// The account's balance before the import and the rule it followed, to
  /// show what it did.
  Money? _before;
  BalanceRule _applied = BalanceRule.add;

  OwnController get own => widget.own;

  late final Allowance _allowance =
      widget.allowance ?? (Allowance(own.store)..load());

  @override
  void initState() {
    super.initState();
    _accountId = widget.accountId;
    final StatementRead? given = widget.statement;
    if (given != null) {
      _stage = _Stage.reading;
      WidgetsBinding.instance.addPostFrameCallback((_) => _show(given));
    }
  }

  Account? get _account => _accountOf(_accountId);

  Account? _accountOf(String? id) {
    for (final Account a in own.accounts) {
      if (a.id == id) return a;
    }
    return null;
  }

  Future<void> _pick() async {
    final List<PlatformFile> files = await FilePicker.pickFiles(
      type: FileType.custom,
      allowedExtensions: const <String>['csv', 'txt', 'xlsx', 'pdf'],
    );
    if (files.isEmpty) return;
    final PlatformFile file = files.first;
    setState(() {
      _stage = _Stage.reading;
      _problem = null;
      _pdfText = null;
      _pdfBytes = null;
    });
    try {
      final Uint8List bytes = await file.xFile.readAsBytes();
      final String name = file.name.toLowerCase();
      StatementRead read;
      if (name.endsWith('.xlsx')) {
        read = readTable(readXlsx(bytes), source: StatementSource.xlsx);
      } else if (name.endsWith('.pdf')) {
        _pdfBytes = bytes;
        final String? text = await CaptureChannel.readStatement(bytes);
        _pdfText = text;
        read = text == null
            ? const StatementRead(
                lines: <StatementLine>[],
                source: StatementSource.pdf,
              )
            : readStatementText(text);
      } else {
        read = readTable(parseCsv(decodeText(bytes)));
      }
      await _show(read);
    } on Object catch (e) {
      // An error can quote what it failed on; a release build keeps it
      // out of the device's logs.
      if (kDebugMode) debugPrint('Statement could not be read: $e');
      setState(() {
        _stage = _Stage.pick;
        _problem = context.l10n.statementFailed;
      });
    }
  }

  /// Gemini sorts out the statement the device could not: its text, or on
  /// the web, the PDF itself.
  Future<void> _gemini() async {
    final AppLocalizations l = context.l10n;
    if (!await _allowance.take()) {
      setState(() => _problem = l.problemLimit);
      return;
    }
    setState(() => _stage = _Stage.reading);
    try {
      final String? text = _pdfText;
      final StatementRead read = text != null && text.trim().isNotEmpty
          ? await const GeminiStatementReader().read(text)
          : await const GeminiStatementReader().readPdf(_pdfBytes!);
      await _show(read);
    } on Object catch (e) {
      if (kDebugMode) debugPrint('Gemini could not read the statement: $e');
      setState(() {
        _stage = _Stage.nothing;
        _problem = l.statementFailed;
      });
    }
  }

  Future<void> _show(StatementRead read) async {
    if (read.isEmpty) {
      setState(() {
        _read = read;
        _stage = _Stage.nothing;
      });
      return;
    }
    // The account the statement names, unless one was given.
    if (_accountId == null && read.institution != null) {
      for (final Account a in own.accounts) {
        if (normalize(a.institution) == normalize(read.institution!) ||
            normalize(a.name) == normalize(read.institution!)) {
          _accountId = a.id;
          break;
        }
      }
    }
    _accountId ??= own.accounts.firstOrNull?.id;
    _read = read;
    await _prepare();
  }

  Future<void> _prepare({bool flip = false}) async {
    final Account? account = _account;
    final StatementRead? read = _read;
    if (account == null || read == null) return;
    final List<ImportCandidate> all = await StatementImporter(
      own.store,
    ).prepare(account, read, flip: flip);
    if (!mounted) return;
    setState(() {
      _candidates = all;
      _closing = StatementImporter.closing(account, all);
      _matchClosing = false;
      _chosen
        ..clear()
        ..addAll(<int>[
          for (var i = 0; i < all.length; i++)
            if (all[i].proposed) i,
        ]);
      _stage = _Stage.review;
    });
  }

  bool _flipped = false;

  Future<void> _flip() async {
    _flipped = !_flipped;
    await _prepare(flip: _flipped);
  }

  Future<void> _import() async {
    final Account? account = _account;
    if (account == null || _chosen.isEmpty || _saving) return;
    setState(() => _saving = true);
    final List<ImportCandidate> chosen = <ImportCandidate>[
      for (final int i in _chosen.toList()..sort()) _candidates[i],
    ];
    final Money before = own.balances[account.id] ?? account.openingMoney;
    final BalanceRule rule = _rule;
    final int n = await StatementImporter(
      own.store,
    ).record(account, chosen, rule: rule, closing: _closing);
    await own.joinTransfers();
    if (!mounted) return;
    // The person checks the exceptions, not every line: what came without
    // a category is what is left to look at.
    setState(() {
      _imported = n;
      _before = before;
      _applied = rule;
      _transfers = chosen
          .where((ImportCandidate c) => c.kind == EntryKind.transfer)
          .length;
      _uncategorized = <String>{
        for (final ImportCandidate c in chosen)
          if (c.kind != EntryKind.transfer && c.category == null) c.ref,
      };
      _saving = false;
      _stage = _Stage.done;
    });
  }

  List<Entry> _entriesOf(Account account) => <Entry>[
    for (final Entry e in own.snapshot?.entries ?? const <Entry>[])
      if (e.accountId == account.id) e,
  ];

  /// What [account] would hold today after recording [chosen] under
  /// [rule].
  Money _after(
    Account account,
    List<ImportCandidate> chosen,
    BalanceRule rule,
  ) {
    final Money before = own.balances[account.id] ?? account.openingMoney;
    final DateTime today = endOfDay(own.today);
    var moved = Decimal.zero;
    for (final ImportCandidate c in chosen) {
      if (!c.line.date.isAfter(today)) moved += c.line.amount;
    }
    final Decimal opening = StatementImporter.openingAfter(
      account,
      chosen,
      rule,
      entries: _entriesOf(account),
      closing: _closing,
    );
    return Money(
      before.amount + moved + opening - account.opening,
      account.asset,
    );
  }

  /// The balance of [account] from [before] to [after], or that it stays
  /// because it already had these lines. A card says what is owed on it.
  String _balanceText(
    AppLocalizations l,
    Account account,
    Money before,
    Money after,
    BalanceRule rule,
  ) {
    final Asset? base = own.profile?.base;
    if (account.kind == AccountKind.card) {
      return l.statementDebtEffect(
        account.name,
        moneyText(-before, base: base),
        moneyText(-after, base: base),
      );
    }
    if (before == after && rule != BalanceRule.add) {
      return l.statementBalanceSame(
        account.name,
        moneyText(before, base: base),
      );
    }
    return l.statementBalanceEffect(
      account.name,
      moneyText(before, base: base),
      moneyText(after, base: base),
    );
  }

  /// Opens line [i] to change what it is recorded as.
  Future<void> _review(int i) async {
    final Account? account = _account;
    if (account == null) return;
    final ImportCandidate? changed =
        await showModalBottomSheet<ImportCandidate>(
          context: context,
          isScrollControlled: true,
          showDragHandle: true,
          useSafeArea: true,
          backgroundColor: context.colors.surface,
          constraints: const BoxConstraints(maxWidth: 560),
          builder: (BuildContext context) =>
              _LineSheet(own: own, account: account, candidate: _candidates[i]),
        );
    if (changed == null || !mounted) return;
    setState(
      () => _candidates = <ImportCandidate>[
        for (var j = 0; j < _candidates.length; j++)
          j == i ? changed : _candidates[j],
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l = context.l10n;
    return Scaffold(
      appBar: AppBar(
        backgroundColor: context.colors.canvas,
        surfaceTintColor: Colors.transparent,
        title: Text(l.statementTitle, style: context.type.titleLarge),
        actions: <Widget>[
          if (_stage == _Stage.review)
            IconButton(
              tooltip: l.statementFlip,
              onPressed: _flip,
              icon: const Icon(Glyph.arrowsDownUp),
            ),
        ],
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 760),
          child: switch (_stage) {
            _Stage.pick => _pickView(l),
            _Stage.reading => Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  const CircularProgressIndicator(),
                  const SizedBox(height: 16),
                  Text(l.statementReading, style: context.type.bodyMedium),
                ],
              ),
            ),
            _Stage.nothing => _nothingView(l),
            _Stage.review => _reviewView(l),
            _Stage.done => ListenableBuilder(
              listenable: own,
              builder: (BuildContext context, _) => _doneView(l),
            ),
          },
        ),
      ),
    );
  }

  Widget _pickView(AppLocalizations l) => ListView(
    padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
    children: <Widget>[
      Text(l.statementIntro, style: context.type.bodyMedium),
      const SizedBox(height: 20),
      if (_problem != null) ...<Widget>[
        Text(
          _problem!,
          style: context.type.bodySmall?.copyWith(
            color: context.colors.negative,
          ),
        ),
        const SizedBox(height: 12),
      ],
      FilledButton.icon(
        onPressed: _pick,
        icon: const Icon(Glyph.uploadSimple, size: 18),
        label: Text(l.statementPick),
      ),
    ],
  );

  Widget _nothingView(AppLocalizations l) {
    final bool canAsk =
        (_pdfText?.trim().isNotEmpty ?? false) || (kIsWeb && _pdfBytes != null);
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
      children: <Widget>[
        Text(l.statementNothing, style: context.type.titleMedium),
        if (_problem != null) ...<Widget>[
          const SizedBox(height: 8),
          Text(
            _problem!,
            style: context.type.bodySmall?.copyWith(
              color: context.colors.negative,
            ),
          ),
        ],
        const SizedBox(height: 16),
        if (canAsk) ...<Widget>[
          Block(
            child: Text(
              _pdfText?.trim().isNotEmpty ?? false
                  ? l.statementGeminiNote
                  : l.statementGeminiPdf,
              style: context.type.bodySmall,
            ),
          ),
          const SizedBox(height: 12),
          FilledButton.icon(
            onPressed: _gemini,
            icon: const Icon(Glyph.sparkle, size: 18),
            label: Text(l.statementGemini),
          ),
          const SizedBox(height: 8),
        ],
        OutlinedButton.icon(
          onPressed: _pick,
          icon: const Icon(Glyph.uploadSimple, size: 18),
          label: Text(l.statementPick),
        ),
      ],
    );
  }

  /// What the import left: how many came in, and the ones without a
  /// category, each a tap away from getting one.
  Widget _doneView(AppLocalizations l) {
    final List<Entry> unsorted = <Entry>[
      for (final Entry e in own.snapshot?.entries ?? const <Entry>[])
        if (e.sourceRef != null &&
            _uncategorized.contains(e.sourceRef) &&
            (e.category == 'other' || e.category == 'other_income'))
          e,
    ];
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
      children: <Widget>[
        Row(
          children: <Widget>[
            Icon(Glyph.checkCircle, color: context.colors.brand, size: 28),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                l.statementDone(_imported),
                style: context.type.titleMedium,
              ),
            ),
          ],
        ),
        if ((_account, _before) case (
          final Account account,
          final Money before,
        )) ...<Widget>[
          const SizedBox(height: 8),
          Figures(
            _balanceText(
              l,
              account,
              before,
              own.balances[account.id] ?? account.openingMoney,
              _applied,
            ),
            style: context.type.bodyMedium,
          ),
        ],
        const SizedBox(height: 8),
        if (_transfers > 0) ...<Widget>[
          Text(
            l.statementDoneTransfers(_transfers),
            style: context.type.bodyMedium,
          ),
          const SizedBox(height: 4),
        ],
        Text(
          unsorted.isEmpty
              ? l.statementDoneSorted
              : l.statementDoneUnsorted(unsorted.length),
          style: context.type.bodyMedium,
        ),
        if (unsorted.isNotEmpty) ...<Widget>[
          const SizedBox(height: 20),
          SectionLabel(l.statementGiveCategory),
          Panel(
            children: <Widget>[
              for (final Entry e in unsorted) MovementRow(own: own, entry: e),
            ],
          ),
        ],
        const SizedBox(height: 24),
        FilledButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(l.statementFinish),
        ),
      ],
    );
  }

  /// Lines older than the balance the person wrote: whether that balance
  /// already has them.
  Widget _olderBlock(AppLocalizations l, Account account, int older) => Padding(
    padding: const EdgeInsets.only(top: 12),
    child: Panel(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 6),
      children: <Widget>[
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text(
              l.statementOlder(
                older,
                dayMonth(account.balanceSince!),
                account.name,
              ),
              style: context.type.bodyMedium,
            ),
            RadioGroup<BalanceRule>(
              groupValue: _olderRule,
              onChanged: (BalanceRule? rule) {
                if (rule != null) setState(() => _olderRule = rule);
              },
              child: Column(
                children: <Widget>[
                  RadioListTile<BalanceRule>(
                    value: BalanceRule.keep,
                    contentPadding: EdgeInsets.zero,
                    title: Text(l.statementOlderKeep),
                    subtitle: Text(l.statementOlderNote),
                  ),
                  RadioListTile<BalanceRule>(
                    value: BalanceRule.add,
                    contentPadding: EdgeInsets.zero,
                    title: Text(l.statementOlderAdd),
                  ),
                ],
              ),
            ),
          ],
        ),
      ],
    ),
  );

  /// The statement's last balance next to what the app would show that
  /// day, and a way to take the statement's.
  Widget _closingBlock(
    AppLocalizations l,
    Account account,
    ClosingBalance closing,
    Money wouldBe,
    bool mismatch,
  ) {
    final Asset? base = own.profile?.base;
    return Padding(
      padding: const EdgeInsets.only(top: 12),
      child: Panel(
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 6),
        children: <Widget>[
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Figures(
                l.statementEndsAt(
                  dayMonth(closing.day),
                  moneyText(Money(closing.amount, account.asset), base: base),
                ),
                style: context.type.bodyMedium,
              ),
              if (mismatch)
                Figures(
                  l.statementMismatch(moneyText(wouldBe, base: base)),
                  style: context.type.bodySmall,
                ),
              SwitchListTile(
                value: _matchClosing,
                onChanged: (bool on) => setState(() => _matchClosing = on),
                contentPadding: EdgeInsets.zero,
                title: Text(l.statementUseBalance),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _reviewView(AppLocalizations l) {
    final List<ImportCandidate> all = _candidates;
    final List<DateTime> dates =
        all.map((ImportCandidate c) => c.line.date).toList()..sort();
    final int recorded = all
        .where((ImportCandidate c) => c.recorded || c.importedBefore)
        .length;
    final List<int> newOnes = <int>[
      for (var i = 0; i < all.length; i++)
        if (all[i].proposed) i,
    ];
    final int fresh = newOnes.length;
    final int unsorted = all
        .where(
          (ImportCandidate c) =>
              c.proposed && c.kind != EntryKind.transfer && c.category == null,
        )
        .length;
    final int between = all
        .where(
          (ImportCandidate c) => c.proposed && c.kind == EntryKind.transfer,
        )
        .length;
    // What was already there and the person checked anyway: it would be
    // recorded a second time.
    final int repeatsChosen = _chosen.where((int i) => !all[i].proposed).length;
    final bool everything = _chosen.isNotEmpty && _chosen.containsAll(newOnes);
    final Account? account = _account;
    // What the checked lines bring in and take out.
    var inflow = Decimal.zero;
    var outflow = Decimal.zero;
    for (final int i in _chosen) {
      final Decimal amount = all[i].line.amount;
      if (amount > Decimal.zero) {
        inflow += amount;
      } else {
        outflow += amount;
      }
    }
    final Asset? base = own.profile?.base;
    final bool hasCards = own.accounts.any(
      (Account a) => a.kind == AccountKind.card && a.id != account?.id,
    );
    // A card payment checked as a move: say why it is not spending.
    final bool cardMoves = _chosen.any((int i) {
      final ImportCandidate c = all[i];
      return c.kind == EntryKind.transfer &&
          (account?.kind == AccountKind.card ||
              _accountOf(c.otherAccountId)?.kind == AccountKind.card);
    });
    // Card payments with no card to move them to.
    final bool cardless =
        account?.kind != AccountKind.card &&
        !hasCards &&
        all.any(
          (ImportCandidate c) =>
              c.proposed && c.cardPayment && c.kind != EntryKind.transfer,
        );
    final List<ImportCandidate> chosen = <ImportCandidate>[
      for (final int i in _chosen.toList()..sort()) all[i],
    ];
    // Lines from before the balance the person wrote, which it may
    // already have.
    final int older = account == null
        ? 0
        : chosen
              .where(
                (ImportCandidate c) =>
                    StatementImporter.older(account, c.line.date),
              )
              .length;
    // What the statement says the account ended on, next to what the app
    // would show that day.
    final ClosingBalance? closing = _closing;
    Money? wouldBe;
    if (account != null && closing != null) {
      final DateTime until = endOfDay(closing.day);
      var held = StatementImporter.openingAfter(account, chosen, _olderRule);
      for (final Entry e in _entriesOf(account)) {
        if (!e.date.isAfter(until)) held += e.amount;
      }
      for (final ImportCandidate c in chosen) {
        if (!c.line.date.isAfter(until)) held += c.line.amount;
      }
      wouldBe = Money(held, account.asset);
    }
    final bool mismatch =
        closing != null && wouldBe != null && wouldBe.amount != closing.amount;
    // A statement within one year says it once, in its summary.
    final bool oneYear =
        dates.isNotEmpty && dates.first.year == dates.last.year;
    return Column(
      children: <Widget>[
        Expanded(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
            children: <Widget>[
              DropdownButtonFormField<String>(
                icon: const Icon(Glyph.caretDown, size: 18),
                initialValue: _accountId,
                isExpanded: true,
                decoration: InputDecoration(labelText: l.account),
                items: <DropdownMenuItem<String>>[
                  for (final Account a in own.accounts)
                    DropdownMenuItem<String>(
                      value: a.id,
                      child: Text(
                        '${a.name} · ${a.asset.code}',
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                ],
                onChanged: (String? id) {
                  setState(() => _accountId = id);
                  _prepare(flip: _flipped);
                },
              ),
              const SizedBox(height: 16),
              if (dates.isNotEmpty)
                Text(
                  l.statementSummary(
                    all.length,
                    dayRange(dates.first, dates.last),
                  ),
                  style: context.type.titleSmall,
                ),
              const SizedBox(height: 4),
              Text(
                <String>[
                  l.statementNew(fresh),
                  l.statementAlready(recorded),
                  if (unsorted > 0) l.statementUnsorted(unsorted),
                  if (between > 0) l.statementBetweenAccounts(between),
                ].join(' · '),
                style: context.type.bodyMedium,
              ),
              if (cardMoves)
                Text(l.statementTransferNote, style: context.type.bodySmall),
              if (cardless)
                Text(
                  l.statementAddCard,
                  style: context.type.bodySmall?.copyWith(
                    color: context.colors.caution,
                  ),
                ),
              if (recorded > 0 && repeatsChosen == 0)
                Text(
                  l.statementAlreadyUnchecked,
                  style: context.type.bodySmall,
                ),
              if (_read?.source == StatementSource.gemini) ...<Widget>[
                const SizedBox(height: 6),
                Text(
                  l.statementByGemini,
                  style: context.type.bodySmall?.copyWith(
                    color: context.colors.caution,
                  ),
                ),
              ],
              if (account != null && older > 0 && !_matchClosing)
                _olderBlock(l, account, older),
              if (account != null &&
                  closing != null &&
                  wouldBe != null &&
                  (mismatch || _matchClosing))
                _closingBlock(l, account, closing, wouldBe, mismatch),
              // Checking everything checks what is new: a line already there
              // is checked only on purpose, one by one.
              if (newOnes.isNotEmpty || _chosen.isNotEmpty)
                Align(
                  alignment: Alignment.centerRight,
                  child: TextButton(
                    onPressed: () => setState(() {
                      if (everything) {
                        _chosen.clear();
                      } else {
                        _chosen.addAll(newOnes);
                      }
                    }),
                    child: Text(
                      everything
                          ? l.statementSelectNone
                          : recorded > 0
                          ? l.statementSelectNew
                          : l.statementSelectAll,
                    ),
                  ),
                )
              else
                const SizedBox(height: 12),
              Panel(
                indent: 56,
                children: <Widget>[
                  for (var i = 0; i < all.length; i++)
                    _CandidateRow(
                      own: own,
                      candidate: all[i],
                      account: account,
                      other: _accountOf(all[i].otherAccountId),
                      askCard: hasCards || account?.kind == AccountKind.card,
                      base: base,
                      oneYear: oneYear,
                      chosen: _chosen.contains(i),
                      onChanged: (bool on) => setState(
                        () => on ? _chosen.add(i) : _chosen.remove(i),
                      ),
                      onOpen: () => _review(i),
                    ),
                ],
              ),
            ],
          ),
        ),
        SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: <Widget>[
                Figures(
                  <String>[
                    l.statementSelected(_chosen.length),
                    if (account != null && inflow > Decimal.zero)
                      l.statementIn(
                        moneyText(
                          Money(inflow, account.asset),
                          base: base,
                          signed: true,
                        ),
                      ),
                    if (account != null && outflow < Decimal.zero)
                      l.statementOut(
                        moneyText(
                          Money(outflow, account.asset),
                          base: base,
                          signed: true,
                        ),
                      ),
                  ].join(' · '),
                  style: context.type.bodyMedium,
                ),
                if (account != null && chosen.isNotEmpty)
                  Figures(
                    _balanceText(
                      l,
                      account,
                      own.balances[account.id] ?? account.openingMoney,
                      _after(account, chosen, _rule),
                      _rule,
                    ),
                    style: context.type.bodyMedium,
                  ),
                const SizedBox(height: 8),
                if (repeatsChosen > 0) ...<Widget>[
                  Text(
                    l.statementRepeatsChosen(repeatsChosen),
                    style: context.type.bodySmall?.copyWith(
                      color: context.colors.caution,
                    ),
                  ),
                  const SizedBox(height: 8),
                ],
                FilledButton(
                  onPressed: _chosen.isEmpty || _saving ? null : _import,
                  child: _saving
                      ? Row(
                          mainAxisSize: MainAxisSize.min,
                          children: <Widget>[
                            const SizedBox.square(
                              dimension: 16,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            ),
                            const SizedBox(width: 10),
                            Text(l.statementImporting),
                          ],
                        )
                      : Text(l.statementImport(_chosen.length)),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

/// One line of the statement: checked to import or not, and a tap away
/// from what it is recorded as.
class _CandidateRow extends StatelessWidget {
  const _CandidateRow({
    required this.own,
    required this.candidate,
    required this.account,
    required this.other,
    required this.askCard,
    required this.base,
    required this.oneYear,
    required this.chosen,
    required this.onChanged,
    required this.onOpen,
  });

  final OwnController own;
  final ImportCandidate candidate;
  final Account? account;

  /// The other account of a move between the person's accounts.
  final Account? other;

  /// Whether a card payment with no account on its other side asks which
  /// it is: there is an account it could be.
  final bool askCard;
  final Asset? base;

  /// Whether the statement's lines share a year, which the row then leaves
  /// out of its date.
  final bool oneYear;
  final bool chosen;
  final ValueChanged<bool> onChanged;
  final VoidCallback onOpen;

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l = context.l10n;
    final ImportCandidate c = candidate;
    final String? badge = c.importedBefore
        ? l.statementImportedBefore
        : c.recorded
        ? l.statementRecorded
        : null;
    final Account? a = account;
    final String amount = a == null
        ? c.line.amount.toString()
        : moneyText(Money(c.line.amount, a.asset), base: base, signed: true);
    final String name = c.payee.isEmpty ? c.line.description : c.payee;
    final TextStyle? caution = context.type.bodySmall?.copyWith(
      color: context.colors.caution,
    );
    final String? category = c.category;
    final Account? to = c.kind == EntryKind.transfer ? other : null;
    final bool out = c.line.amount < Decimal.zero;
    final String? move = to == null
        ? null
        : out && to.kind == AccountKind.card && a?.kind != AccountKind.card
        ? l.statementCardPayment(to.name)
        : out
        ? l.statementOwnTransferTo(to.name)
        : l.statementOwnTransferFrom(to.name);
    return ListTile(
      onTap: onOpen,
      contentPadding: const EdgeInsets.symmetric(horizontal: 8),
      leading: Checkbox(
        value: chosen,
        semanticLabel: name,
        onChanged: (bool? on) => onChanged(on ?? false),
      ),
      title: Row(
        children: <Widget>[
          if (move != null) ...<Widget>[
            Icon(
              Glyph.arrowsLeftRight,
              size: 16,
              color: context.colors.inkSoft,
            ),
            const SizedBox(width: 6),
          ],
          Expanded(
            child: Text(
              name,
              style: context.type.titleSmall,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          const SizedBox(width: 8),
          Figures(
            amount,
            style: context.type.titleSmall?.copyWith(
              color: c.line.amount > Decimal.zero
                  ? context.colors.positive
                  : context.colors.ink,
            ),
          ),
        ],
      ),
      // What was already there says so; a new line says what it will be.
      subtitle: Text.rich(
        TextSpan(
          children: <InlineSpan>[
            TextSpan(
              text: oneYear
                  ? dayShortMonth(c.line.date)
                  : shortDate(c.line.date),
            ),
            if (badge != null)
              TextSpan(text: ' · $badge', style: caution)
            else if (move != null)
              TextSpan(text: ' · $move')
            else if (category != null)
              TextSpan(
                text:
                    ' · ${categoryNameFor(context, category, own.categories)}',
              )
            else
              TextSpan(text: ' · ${l.statementGiveCategory}', style: caution),
            if (badge == null && move == null && c.cardPayment && askCard)
              TextSpan(text: '\n${l.statementIsCardPayment}', style: caution),
          ],
        ),
        style: context.type.bodySmall,
        maxLines: 2,
        overflow: TextOverflow.ellipsis,
      ),
    );
  }
}

/// What one line of the statement is recorded as: an expense or an income
/// and its category, or a move between the person's accounts, next to the
/// bank's own words for it.
class _LineSheet extends StatefulWidget {
  const _LineSheet({
    required this.own,
    required this.account,
    required this.candidate,
  });

  final OwnController own;
  final Account account;
  final ImportCandidate candidate;

  @override
  State<_LineSheet> createState() => _LineSheetState();
}

class _LineSheetState extends State<_LineSheet> {
  ImportCandidate get c => widget.candidate;
  OwnController get own => widget.own;

  late EntryKind _kind = c.kind;
  late String? _category = c.category;

  /// The person's other accounts a move can go to or come from: those in
  /// the same currency.
  late final List<Account> _others = <Account>[
    for (final Account a in own.accounts)
      if (a.id != widget.account.id && a.asset == widget.account.asset) a,
  ];

  /// The other account of a move: the one found, or a card for money out
  /// of an account that is not one.
  late String? _other =
      c.otherAccountId ??
      (widget.account.kind != AccountKind.card && c.line.amount < Decimal.zero
              ? _others
                    .where((Account a) => a.kind == AccountKind.card)
                    .firstOrNull
              : null)
          ?.id ??
      _others.firstOrNull?.id;

  /// The line's amount as what it is recorded as: money out for an
  /// expense, money in for an income, as the statement says for a move.
  Decimal get _amount => switch (_kind) {
    EntryKind.expense => -c.line.amount.abs(),
    EntryKind.income => c.line.amount.abs(),
    _ => c.line.amount,
  };

  void _save() {
    final bool transfer = _kind == EntryKind.transfer && _other != null;
    Navigator.of(context).pop(
      c.copyWith(
        amount: _amount,
        kind: _kind,
        category: _category,
        clearCategory: _category == null,
        // A move keeps the side found for it only with the same account.
        clearOther: true,
        otherAccountId: transfer ? _other : null,
        otherLeg: transfer && c.otherLeg?.accountId == _other
            ? c.otherLeg
            : null,
        cardPayment: false,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l = context.l10n;
    final Decimal amount = _amount;
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Text(l.statementReviewLine, style: context.type.headlineMedium),
            const SizedBox(height: 16),
            Row(
              children: <Widget>[
                Expanded(
                  child: Text(
                    c.payee.isEmpty ? c.line.description : c.payee,
                    style: context.type.titleMedium,
                  ),
                ),
                const SizedBox(width: 8),
                Figures(
                  moneyText(
                    Money(amount, widget.account.asset),
                    base: own.profile?.base,
                    signed: true,
                  ),
                  style: context.type.titleMedium?.copyWith(
                    color: amount > Decimal.zero
                        ? context.colors.positive
                        : context.colors.ink,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Text(shortDate(c.line.date), style: context.type.bodySmall),
            const SizedBox(height: 16),
            Text(l.statementOriginal, style: context.type.labelMedium),
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: context.colors.sunken,
                borderRadius: BorderRadius.circular(12),
              ),
              child: SelectableText(
                c.line.description,
                style: context.type.bodyMedium,
              ),
            ),
            const SizedBox(height: 20),
            SegmentedButton<EntryKind>(
              segments: <ButtonSegment<EntryKind>>[
                ButtonSegment<EntryKind>(
                  value: EntryKind.expense,
                  label: Text(l.kindExpense),
                ),
                ButtonSegment<EntryKind>(
                  value: EntryKind.income,
                  label: Text(l.kindIncome),
                ),
                if (_others.isNotEmpty)
                  ButtonSegment<EntryKind>(
                    value: EntryKind.transfer,
                    label: Text(l.kindTransfer),
                  ),
              ],
              selected: <EntryKind>{_kind},
              showSelectedIcon: false,
              onSelectionChanged: (Set<EntryKind> s) => setState(() {
                // A category belongs to one side: the line's own comes
                // back with its side.
                _category = s.first == c.kind ? c.category : null;
                _kind = s.first;
              }),
            ),
            const SizedBox(height: 20),
            if (_kind == EntryKind.transfer)
              DropdownButtonFormField<String>(
                icon: const Icon(Glyph.caretDown, size: 18),
                initialValue: _other,
                isExpanded: true,
                decoration: InputDecoration(
                  labelText: amount < Decimal.zero
                      ? l.toAccount
                      : l.fromAccount,
                ),
                items: <DropdownMenuItem<String>>[
                  for (final Account a in _others)
                    DropdownMenuItem<String>(
                      value: a.id,
                      child: Row(
                        children: <Widget>[
                          Icon(
                            accountIcon(a.kind),
                            size: 18,
                            color: context.colors.inkSoft,
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              a.name,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                    ),
                ],
                onChanged: (String? id) => setState(() => _other = id),
              )
            else ...<Widget>[
              Text(l.category, style: context.type.labelMedium),
              const SizedBox(height: 8),
              CategoryChoices(
                own: own,
                income: _kind == EntryKind.income,
                selected: _category,
                onChanged: (String? key) => setState(() => _category = key),
              ),
            ],
            const SizedBox(height: 20),
            FilledButton(onPressed: _save, child: Text(l.save)),
          ],
        ),
      ),
    );
  }
}
