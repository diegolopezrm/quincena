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
import '../../theme/tokens.dart';
import '../icons.dart';
import '../kit.dart';
import 'look.dart';

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

enum _Stage { pick, reading, nothing, review }

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

  Account? get _account {
    for (final Account a in own.accounts) {
      if (a.id == _accountId) return a;
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
      debugPrint('Statement could not be read: $e');
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
      debugPrint('Gemini could not read the statement: $e');
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
    List<ImportCandidate> all = await StatementImporter(
      own.store,
    ).prepare(account, read);
    if (flip) all = <ImportCandidate>[for (final c in all) c.flipped()];
    if (!mounted) return;
    setState(() {
      _candidates = all;
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
    final int n = await StatementImporter(own.store).record(account, chosen);
    await own.joinTransfers();
    if (!mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(context.l10n.statementDone(n))));
    Navigator.of(context).pop();
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

  Widget _reviewView(AppLocalizations l) {
    final List<ImportCandidate> all = _candidates;
    final List<DateTime> dates =
        all.map((ImportCandidate c) => c.line.date).toList()..sort();
    final int recorded = all
        .where((ImportCandidate c) => c.recorded || c.importedBefore)
        .length;
    final Account? account = _account;
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
                    shortDate(dates.first),
                    shortDate(dates.last),
                  ),
                  style: context.type.titleSmall,
                ),
              Text(
                l.statementRecordedCount(recorded),
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
              const SizedBox(height: 12),
              Panel(
                indent: 56,
                children: <Widget>[
                  for (var i = 0; i < all.length; i++)
                    _CandidateRow(
                      candidate: all[i],
                      account: account,
                      base: own.profile?.base,
                      chosen: _chosen.contains(i),
                      onChanged: (bool on) => setState(
                        () => on ? _chosen.add(i) : _chosen.remove(i),
                      ),
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
            child: SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: _chosen.isEmpty || _saving ? null : _import,
                child: Text(l.statementImport(_chosen.length)),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

/// One line of the statement, checked to import or not.
class _CandidateRow extends StatelessWidget {
  const _CandidateRow({
    required this.candidate,
    required this.account,
    required this.base,
    required this.chosen,
    required this.onChanged,
  });

  final ImportCandidate candidate;
  final Account? account;
  final Asset? base;
  final bool chosen;
  final ValueChanged<bool> onChanged;

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
    return CheckboxListTile(
      value: chosen,
      onChanged: (bool? on) => onChanged(on ?? false),
      controlAffinity: ListTileControlAffinity.leading,
      contentPadding: const EdgeInsets.symmetric(horizontal: 8),
      title: Row(
        children: <Widget>[
          Expanded(
            child: Text(
              c.payee.isEmpty ? c.line.description : c.payee,
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
      subtitle: Text(
        <String>[
          shortDate(c.line.date),
          if (c.payee.isNotEmpty && c.payee != c.line.description)
            c.line.description,
          ?badge,
        ].join(' · '),
        style: context.type.bodySmall?.copyWith(
          color: badge == null ? null : context.colors.caution,
        ),
        maxLines: 2,
        overflow: TextOverflow.ellipsis,
      ),
    );
  }
}
