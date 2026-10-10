import 'package:decimal/decimal.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../../ai/allowance.dart';
import '../../capture/merchants.dart';
import '../../capture/native_channel.dart';
import '../../data/ledger.dart';
import '../../domain/records.dart';
import '../../format/dates.dart';
import '../../format/money.dart';
import '../../data/example_account.dart';
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
import 'account_sheet.dart';
import 'category_choices.dart';
import 'entry_origin.dart';
import 'entry_sheet.dart';
import 'example_bar.dart';
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

  /// Whether the account is the first one only because the file names no
  /// bank: the menu asks to check it.
  bool _guessedAccount = false;
  List<ImportCandidate> _candidates = const <ImportCandidate>[];
  final Set<int> _chosen = <int>{};

  /// What the person made of each line, by its place in the statement:
  /// read again, flipped or for another account, the line keeps it where
  /// it still applies.
  final Map<int, ImportCandidate> _edited = <int, ImportCandidate>{};
  bool _saving = false;

  /// The last import stopped before saving every line.
  bool _saveFailed = false;

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

  /// The account's balance before the import, and whether that balance
  /// already had the lines, to show what the import did.
  Money? _before;
  bool _included = false;

  /// What could be spent until payday before the import, to say how the
  /// lines changed it.
  int? _freeBefore;

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

  /// The example's own statement, to try the import without a file. It is
  /// in the app already: there is nothing to wait for.
  Future<void> _tryExample() async {
    final StatementRead read = await exampleStatement();
    if (mounted) await _show(read);
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
    // The example sends nothing anywhere.
    if (await explainExample(context, own, l.statementGemini)) return;
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
    _guessedAccount = _accountId == null;
    _accountId ??= own.accounts.firstOrNull?.id;
    // Another statement: nothing of the last one carries over.
    _read = read;
    _flipped = false;
    _edited.clear();
    _candidates = const <ImportCandidate>[];
    await _prepare();
  }

  /// Reads the statement's lines for the account, as they are now and the
  /// way the person left them: what they made of each line, and whether
  /// they checked it, while the line is what it was.
  Future<void> _prepare() async {
    final Account? account = _account;
    final StatementRead? read = _read;
    if (account == null || read == null) return;
    final List<ImportCandidate> fresh = await StatementImporter(
      own.store,
    ).prepare(account, read, flip: _flipped);
    if (!mounted) return;
    final List<ImportCandidate> all = <ImportCandidate>[
      for (var i = 0; i < fresh.length; i++)
        if (_edited[i] case final ImportCandidate edited)
          StatementImporter.keepChanges(fresh[i], edited, account, own.accounts)
        else
          fresh[i],
    ];
    // A line that went from new to already there, or the other way, or
    // that now waits for the account that paid it, or got its card, takes
    // what is proposed now.
    final List<ImportCandidate> before = _candidates;
    bool kept(int i) =>
        before.length == all.length &&
        before[i].isNew == all[i].isNew &&
        before[i].waitsForAccount == all[i].waitsForAccount &&
        before[i].paidFromNowhere == all[i].paidFromNowhere &&
        before[i].cardMissing == all[i].cardMissing;
    final Set<int> chosen = <int>{
      for (var i = 0; i < all.length; i++)
        if (kept(i) ? _chosen.contains(i) : all[i].proposed) i,
    };
    setState(() {
      _candidates = all;
      _closing = StatementImporter.closing(account, all);
      _matchClosing = false;
      _chosen
        ..clear()
        ..addAll(chosen);
      _stage = _Stage.review;
    });
  }

  bool _flipped = false;

  Future<void> _flip() async {
    _flipped = !_flipped;
    await _prepare();
  }

  Future<void> _import() async {
    final Account? account = _account;
    if (account == null || _chosen.isEmpty || _saving) return;
    setState(() {
      _saving = true;
      _saveFailed = false;
    });
    final List<ImportCandidate> chosen = <ImportCandidate>[
      for (final int i in _chosen.toList()..sort()) _candidates[i],
    ];
    final Money before = own.balances[account.id] ?? account.openingMoney;
    final int? freeBefore = own.ledger?.freeUntilPayday;
    final BalanceRule rule = _rule;
    final int n;
    try {
      n = await StatementImporter(
        own.store,
      ).record(account, chosen, rule: rule, closing: _closing);
      await own.joinTransfers();
    } on Object catch (e) {
      if (kDebugMode) debugPrint('Statement could not be saved: $e');
      if (!mounted) return;
      setState(() {
        _saving = false;
        _saveFailed = true;
      });
      // What was saved before it stopped reads as imported now, so trying
      // again does not save it twice.
      await _prepare();
      return;
    }
    if (!mounted) return;
    // The person checks the exceptions, not every line: what came without
    // a category is what is left to look at.
    setState(() {
      _imported = n;
      _before = before;
      _freeBefore = freeBefore;
      _included = _alreadyIn(account, chosen, rule);
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

  /// Whether, under [rule], the balance of [account] already had [chosen]:
  /// the statement's own balance, or lines older than the one written.
  static bool _alreadyIn(
    Account account,
    List<ImportCandidate> chosen,
    BalanceRule rule,
  ) => switch (rule) {
    BalanceRule.add => false,
    BalanceRule.statement => true,
    BalanceRule.keep => chosen.any(
      (ImportCandidate c) => StatementImporter.older(account, c.line.date),
    ),
  };

  /// The balance of [account] from [before] to [after], or that it stays
  /// because it [included] these lines already. A card says what is owed
  /// on it.
  String _balanceText(
    AppLocalizations l,
    Account account,
    Money before,
    Money after, {
    required bool included,
  }) {
    final Asset? base = own.profile?.base;
    if (account.kind == AccountKind.card) {
      if (before == after && included) {
        return l.statementDebtSame(
          account.name,
          moneyText(-before, base: base),
        );
      }
      return l.statementDebtEffect(
        account.name,
        moneyText(-before, base: base),
        moneyText(-after, base: base),
      );
    }
    if (before == after && included) {
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

  /// How what can be spent until payday went from [before] to [after]:
  /// what is missing said as missing, never as a negative to spend.
  String _freeText(AppLocalizations l, Ledger ledger, int before, int after) {
    String side(int free) => free >= 0
        ? pesos(ledger.major(free))
        : l.statementFreeShort(pesos(ledger.major(-free)));
    if (before == after) return l.statementFreeSame(side(after));
    return l.statementFreeChange(side(before), side(after));
  }

  /// Adds the card the statement pays, at its bank and in its currency:
  /// read again, its payment goes to it, as a move and not as spending.
  Future<void> _addCard() async {
    final Account? account = _account;
    if (account == null) return;
    // Named by the brand its payment says, when it says one.
    final String said =
        ' ${normalize(<String>[for (final ImportCandidate c in _candidates)
          if (c.cardMissing) c.line.description].join(' '))} ';
    final String? brand = const <String>[
      'visa',
      'mastercard',
      'amex',
      'diners',
    ].where((String b) => said.contains(' $b ')).firstOrNull;
    final Account? card = await showAccountSheet(
      context,
      own: own,
      draft: AccountDraft(
        name: brand == null
            ? context.l10n.kindCard
            : '${brand[0].toUpperCase()}${brand.substring(1)}',
        kind: AccountKind.card,
        asset: account.asset,
        institution: account.institution,
      ),
    );
    if (card == null || !mounted) return;
    await _prepare();
    // The lines name the card once the app knows it.
    if (!own.accounts.any((Account a) => a.id == card.id)) {
      void known() {
        if (!own.accounts.any((Account a) => a.id == card.id)) return;
        own.removeListener(known);
        if (mounted) setState(() {});
      }

      own.addListener(known);
    }
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
    // A payment that waited for its account is checked once it has one,
    // or once the person said what it is.
    bool waits(ImportCandidate c) =>
        c.waitsForAccount || c.paidFromNowhere || c.cardMissing;
    final bool placed =
        waits(_candidates[i]) && !waits(changed) && changed.isNew;
    _edited[i] = changed;
    setState(() {
      _candidates = <ImportCandidate>[
        for (var j = 0; j < _candidates.length; j++)
          j == i ? changed : _candidates[j],
      ];
      if (placed) _chosen.add(i);
    });
  }

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l = context.l10n;
    // A write that started finishes: leaving would only hide how it went.
    return PopScope(
      canPop: !_saving,
      child: Scaffold(
        appBar: AppBar(
          backgroundColor: context.colors.canvas,
          surfaceTintColor: Colors.transparent,
          title: Text(l.statementTitle, style: context.type.titleLarge),
          actions: <Widget>[
            if (_stage == _Stage.review)
              IconButton(
                tooltip: l.statementFlip,
                onPressed: _saving ? null : _flip,
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
      ),
    );
  }

  Widget _pickView(AppLocalizations l) => ListView(
    padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
    children: <Widget>[
      Text(l.statementIntro, style: context.type.bodyMedium),
      const SizedBox(height: 20),
      // The example has a statement of its own to try, before any file.
      if (own.example) ...<Widget>[
        Block(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              Text(
                l.exampleStatementBody(own.profile?.name ?? ''),
                style: context.type.bodyMedium,
              ),
              const SizedBox(height: 12),
              FilledButton.tonalIcon(
                onPressed: _tryExample,
                icon: const Icon(Glyph.fileText, size: 18),
                label: Text(l.exampleStatementUse),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
      ],
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
        // What the file held, and what the app reads.
        if (_read case final StatementRead read
            when _problem == null) ...<Widget>[
          const SizedBox(height: 4),
          Text(
            read.titles && read.rows <= 1
                ? l.statementNothingTitles
                : l.statementNothingRows(read.rows),
            style: context.type.bodyMedium,
          ),
          const SizedBox(height: 4),
          Text(l.statementFormats, style: context.type.bodySmall),
        ],
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
            Icon(Glyph.checkCircle, color: context.colors.positive, size: 28),
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
              included: _included,
            ),
            style: context.type.bodyMedium,
          ),
        ],
        // What Inicio says next, before it is seen there.
        if ((_freeBefore, own.ledger) case (
          final int before,
          final Ledger ledger,
        )) ...<Widget>[
          const SizedBox(height: 4),
          Figures(
            _freeText(l, ledger, before, ledger.freeUntilPayday),
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
      boxed: true,
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
        boxed: true,
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
    final int fresh = all.where((ImportCandidate c) => c.isNew).length;
    // Card payments that wait for the account they came from, and those
    // no account of the person could have paid.
    final int waiting = all
        .where((ImportCandidate c) => c.isNew && c.waitsForAccount)
        .length;
    final int nowhere = all
        .where((ImportCandidate c) => c.isNew && c.paidFromNowhere)
        .length;
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
    final int repeatsChosen = _chosen.where((int i) => !all[i].isNew).length;
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
    // A card payment with nothing on its other side asks where it goes
    // when there is somewhere: a card for a bank's, an account for a card's.
    final bool askCard = account?.kind == AccountKind.card
        ? own.accounts.any(
            (Account a) => a.id != account?.id && a.asset == account?.asset,
          )
        : hasCards;
    // A card payment checked as a move: say why it is not spending.
    final bool cardMoves = _chosen.any((int i) {
      final ImportCandidate c = all[i];
      return c.kind == EntryKind.transfer &&
          (account?.kind == AccountKind.card ||
              _accountOf(c.otherAccountId)?.kind == AccountKind.card);
    });
    // Card payments with no card in the app to move them to.
    final bool cardless = all.any(
      (ImportCandidate c) => c.isNew && c.cardMissing,
    );
    // What is new and needs the person before it goes in: a payment that
    // waits for its account or its card, or one that may be a card's.
    final int review = all
        .where(
          (ImportCandidate c) =>
              c.isNew &&
              (c.waitsForAccount ||
                  c.paidFromNowhere ||
                  c.cardMissing ||
                  (c.cardPayment && c.kind != EntryKind.transfer && askCard)),
        )
        .length;
    // Checked as proposed: the new ones, and nothing else.
    final bool justNew =
        _chosen.isNotEmpty &&
        _chosen.length == newOnes.length &&
        _chosen.containsAll(newOnes);
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
    // What the checked lines bring in and take out, and what they leave in
    // the account.
    final List<Widget> effect = <Widget>[
      Figures(
        <String>[
          l.statementSelected(_chosen.length),
          if (account != null && inflow > Decimal.zero)
            l.statementIn(
              moneyText(Money(inflow, account.asset), base: base, signed: true),
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
            included: _alreadyIn(account, chosen, _rule),
          ),
          style: context.type.bodyMedium,
        ),
    ];
    // With large text they would leave the lines no room above the
    // button: they go under the lines instead.
    final bool large = MediaQuery.textScalerOf(context).scale(10) > 13;
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
                onChanged: _saving
                    ? null
                    : (String? id) {
                        setState(() {
                          _accountId = id;
                          _guessedAccount = false;
                        });
                        _prepare();
                      },
              ),
              // Taken as the first account only because the file names no
              // bank: worth a look before anything goes in.
              if (_guessedAccount) ...<Widget>[
                const SizedBox(height: 6),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Icon(
                      Glyph.warningCircle,
                      size: 16,
                      color: context.colors.caution,
                    ),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        l.statementAccountGuessed,
                        style: context.type.bodySmall,
                      ),
                    ),
                  ],
                ),
              ],
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
              // What the person has to look at first, then what the new
              // ones are.
              Text(
                <String>[
                  l.statementNew(fresh),
                  l.statementAlready(recorded),
                  if (review > 0) l.statementNeedsReview(review),
                ].join(' · '),
                style: context.type.bodyMedium,
              ),
              if (unsorted > 0 || between > 0)
                Text(
                  <String>[
                    if (unsorted > 0) l.statementUnsorted(unsorted),
                    if (between > 0) l.statementBetweenAccounts(between),
                  ].join(' · '),
                  style: context.type.bodySmall,
                ),
              if (cardMoves)
                Text(l.statementTransferNote, style: context.type.bodySmall),
              if (waiting > 0)
                Text(
                  l.statementPaymentWaits(waiting),
                  style: context.type.bodySmall?.copyWith(
                    color: context.colors.caution,
                  ),
                ),
              if (nowhere > 0 && account != null)
                Text(
                  l.statementPaymentNoSource(nowhere, account.asset.code),
                  style: context.type.bodySmall?.copyWith(
                    color: context.colors.caution,
                  ),
                ),
              if (cardless) ...<Widget>[
                Text(
                  l.statementCardMissing,
                  style: context.type.bodySmall?.copyWith(
                    color: context.colors.caution,
                  ),
                ),
                Align(
                  alignment: Alignment.centerLeft,
                  child: TextButton.icon(
                    onPressed: _saving ? null : _addCard,
                    style: TextButton.styleFrom(padding: EdgeInsets.zero),
                    icon: const Icon(Glyph.plus, size: 16),
                    label: Text(l.statementAddCardButton),
                  ),
                ),
              ],
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
                      askCard: askCard,
                      base: base,
                      oneYear: oneYear,
                      chosen: _chosen.contains(i),
                      // A payment waiting for its account asks for it first.
                      onChanged: (bool on) => on && all[i].waitsForAccount
                          ? _review(i)
                          : setState(
                              () => on ? _chosen.add(i) : _chosen.remove(i),
                            ),
                      onOpen: () => _review(i),
                    ),
                ],
              ),
              // What to do with the balance the person wrote, once the
              // lines are seen.
              if (account != null && older > 0 && !_matchClosing)
                _olderBlock(l, account, older),
              if (account != null &&
                  closing != null &&
                  wouldBe != null &&
                  (mismatch || _matchClosing))
                _closingBlock(l, account, closing, wouldBe, mismatch),
              if (large) ...<Widget>[const SizedBox(height: 16), ...effect],
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
                if (!large) ...<Widget>[...effect, const SizedBox(height: 8)],
                if (_saveFailed) ...<Widget>[
                  Text(
                    l.statementSaveFailed,
                    style: context.type.bodySmall?.copyWith(
                      color: context.colors.negative,
                    ),
                  ),
                  const SizedBox(height: 8),
                ],
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
                      : Text(
                          justNew
                              ? l.statementImportNew(_chosen.length)
                              : l.statementImport(_chosen.length),
                        ),
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

  /// Whether a card payment with no account on its other side asks where
  /// it goes: there is an account it could be.
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
    final Entry? match = c.match;
    // What was already there says which movement it is, to check it.
    final String? badge = c.importedBefore
        ? l.statementImportedBefore
        : match != null
        ? l.statementRecordedAs(
            <String>[
              if (match.payee.isNotEmpty) match.payee,
              if (!DateUtils.isSameDay(match.date, c.line.date))
                dayShortMonth(match.date),
              ?_origin(l, match),
            ].join(', '),
          )
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
    final bool waits = c.waitsForAccount || c.paidFromNowhere;
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
            else if (waits)
              TextSpan(text: ' · ${l.statementPaidFrom}', style: caution)
            else if (c.cardMissing)
              TextSpan(text: ' · ${l.statementCardMissingLine}', style: caution)
            else if (category != null)
              TextSpan(
                text:
                    ' · ${categoryNameFor(context, category, own.categories)}',
              )
            else
              TextSpan(text: ' · ${l.statementGiveCategory}', style: caution),
            if (badge == null &&
                move == null &&
                !waits &&
                c.cardPayment &&
                askCard)
              TextSpan(
                text: a?.kind == AccountKind.card
                    ? '\n${l.statementPaidFrom}'
                    : '\n${l.statementIsCardPayment}',
                style: caution,
              ),
          ],
        ),
        style: context.type.bodySmall,
        maxLines: 2,
        overflow: TextOverflow.ellipsis,
      ),
    );
  }
}

/// How [entry] came to be in the account, in lower case to go inside a
/// line: «anotado a mano», «de una notificación».
String? _origin(AppLocalizations l, Entry entry) {
  final String? said = entryOrigin(l, entry)?.$2;
  if (said == null || said.isEmpty) return null;
  return '${said[0].toLowerCase()}${said.substring(1)}';
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

  /// The other account of a move: the one found, a card for money out of
  /// an account that is not one, or an everyday account for a card's
  /// payment.
  late String? _other =
      c.otherAccountId ??
      _sameBankFirst(
        widget.account.kind != AccountKind.card && c.line.amount < Decimal.zero
            ? <Account>[
                for (final Account a in _others)
                  if (a.kind == AccountKind.card) a,
              ]
            : widget.account.kind == AccountKind.card &&
                  c.line.amount > Decimal.zero
            ? <Account>[
                for (final Account a in _others)
                  if (a.spendable &&
                      (a.kind == AccountKind.bank ||
                          a.kind == AccountKind.wallet))
                    a,
              ]
            : const <Account>[],
      )?.id ??
      _others.firstOrNull?.id;

  /// Of [fits], the one at the bank of the statement's account, which most
  /// likely paid its card or got paid by it; or else the first.
  Account? _sameBankFirst(List<Account> fits) =>
      fits
          .where(
            (Account a) =>
                widget.account.institution.trim().isNotEmpty &&
                normalize(a.institution) ==
                    normalize(widget.account.institution),
          )
          .firstOrNull ??
      fits.firstOrNull;

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
            // What it was taken for, to check before leaving it out.
            if (c.match case final Entry match) ...<Widget>[
              const SizedBox(height: 16),
              Text(l.statementMatches, style: context.type.labelMedium),
              const SizedBox(height: 4),
              Text(
                <String>[
                  if (match.payee.isNotEmpty) match.payee,
                  shortDate(match.date),
                  ?own.snapshot?.account(match.accountId)?.name,
                  moneyText(
                    Money(match.amount, widget.account.asset),
                    base: own.profile?.base,
                    signed: true,
                  ),
                  ?entryOrigin(l, match)?.$2,
                ].join(' · '),
                style: context.type.bodyMedium,
              ),
              Align(
                alignment: Alignment.centerLeft,
                child: TextButton(
                  onPressed: () =>
                      showEntrySheet(context, own: own, entry: match),
                  style: TextButton.styleFrom(padding: EdgeInsets.zero),
                  child: Text(l.statementSeeEntry),
                ),
              ),
            ],
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
