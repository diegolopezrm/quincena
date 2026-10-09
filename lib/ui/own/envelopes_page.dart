import 'package:decimal/decimal.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../data/ledger.dart';
import '../../domain/plan.dart';
import '../../format/dates.dart';
import '../../format/money.dart';
import '../../l10n/l10n.dart';
import '../../money/money.dart';
import '../../own/own_controller.dart';
import '../../theme/tokens.dart';
import '../icons.dart';
import '../kit.dart';
import 'amount_input.dart';

/// The money of this pay period split into envelopes: the day to day,
/// what goes to each goal, and anything else set aside. Envelopes are on
/// paper: no money moves, and the bank knows nothing of them.
class EnvelopesPage extends StatefulWidget {
  const EnvelopesPage({super.key, required this.own});

  final OwnController own;

  @override
  State<EnvelopesPage> createState() => _EnvelopesPageState();
}

class _EnvelopesPageState extends State<EnvelopesPage> {
  late List<Envelope> _envelopes;
  final Map<String, TextEditingController> _amounts =
      <String, TextEditingController>{};
  bool _saving = false;

  OwnController get own => widget.own;

  @override
  void initState() {
    super.initState();
    final Ledger ledger = own.ledger!;
    _envelopes =
        own.plan?.envelopes ??
        proposeEnvelopes(
          ledger,
          goals: own.goalShares,
          last: own.lastPlan,
          dailyName: '',
        );
    for (final Envelope e in _envelopes) {
      _amounts[e.id] = _controller(ledger, e.amount);
    }
  }

  TextEditingController _controller(Ledger ledger, int amount) =>
      TextEditingController(
        text: amount == 0
            ? ''
            : formatDecimal(
                Decimal.parse(ledger.major(amount).toString()),
                decimals: ledger.currency.decimals,
                trim: true,
              ),
      );

  @override
  void dispose() {
    for (final TextEditingController c in _amounts.values) {
      c.dispose();
    }
    super.dispose();
  }

  int _typed(Ledger ledger, String id) {
    final Decimal? v = parseAmount(_amounts[id]?.text ?? '');
    return v == null || v < Decimal.zero ? 0 : ledger.minor(v.toDouble());
  }

  List<Envelope> _current(Ledger ledger) => <Envelope>[
    for (final Envelope e in _envelopes)
      e.copyWith(amount: _typed(ledger, e.id)),
  ];

  Future<void> _addAside() async {
    final AppLocalizations l = context.l10n;
    final TextEditingController name = TextEditingController();
    final String? typed = await showDialog<String>(
      context: context,
      builder: (BuildContext context) => AlertDialog(
        scrollable: true,
        title: Text(l.envelopeAside),
        content: TextField(
          controller: name,
          autofocus: true,
          textCapitalization: TextCapitalization.sentences,
          decoration: InputDecoration(hintText: l.envelopeAsideHint),
        ),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text(l.cancel),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(name.text),
            child: Text(l.save),
          ),
        ],
      ),
    );
    if (typed == null || typed.trim().isEmpty || !mounted) return;
    final Envelope e = Envelope(
      id: 'aside-${DateTime.now().microsecondsSinceEpoch}',
      kind: EnvelopeKind.aside,
      name: typed.trim(),
      amount: 0,
    );
    setState(() {
      _envelopes = <Envelope>[..._envelopes, e];
      _amounts[e.id] = TextEditingController();
    });
  }

  /// What the day to day of this period's plan has spent since it was
  /// made: part of what it holds, so still part of what there is to split.
  int _spent(Ledger ledger) => switch (own.plan) {
    final EnvelopePlan plan => dailySpent(ledger, plan),
    null => 0,
  };

  /// What no envelope would hold with [envelopes], as Plan's card will say.
  int _left(Ledger ledger, List<Envelope> envelopes) => unassigned(
    ledger,
    EnvelopePlan(period: periodStart(ledger), envelopes: envelopes),
    spent: _spent(ledger),
  );

  Future<void> _save(Ledger ledger) async {
    final AppLocalizations l = context.l10n;
    final List<Envelope> envelopes = _current(ledger);
    final int over = -_left(ledger, envelopes);
    if (over > 0) {
      final bool? sure = await showDialog<bool>(
        context: context,
        builder: (BuildContext context) => AlertDialog(
          title: Text(l.envelopesOverTitle),
          content: Text(l.envelopesOver(pesos(ledger.major(over)))),
          actions: <Widget>[
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: Text(l.envelopesFix),
            ),
            TextButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: Text(l.envelopesSaveAnyway),
            ),
          ],
        ),
      );
      if (sure != true) return;
    }
    setState(() => _saving = true);
    // Changed, a plan keeps what it had counted when it was made.
    await own.savePlan(
      own.plan?.copyWith(envelopes: envelopes) ??
          EnvelopePlan.made(ledger, envelopes),
    );
    if (mounted) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l = context.l10n;
    final Ledger ledger = own.ledger!;
    String amount(int minor) => pesos(ledger.major(minor));
    final int spent = _spent(ledger);
    final int money = allocatable(ledger) + spent;
    final List<Envelope> now = _current(ledger);
    final int left = _left(ledger, now);
    final int debt = own.spendableCardDebt;
    // The sum behind what there is to split, as Inicio's card says it:
    // each thing taken out only when there is some, so it adds up.
    final List<(String, String)> sum = <(String, String)>[
      (l.standingAvailable, amount(ledger.balance + debt)),
      if (debt > 0) (l.standingCardDebtLine, amount(-debt)),
      if (ledger.committedUntilPayday > 0)
        (
          l.standingPaymentsBefore(dayShortMonth(ledger.nextPayday)),
          amount(-ledger.committedUntilPayday),
        ),
      if (ledger.cushion > 0) (l.standingCushionLine, amount(-ledger.cushion)),
      if (ledger.reserved > 0)
        (l.standingReserveLine, amount(-ledger.reserved)),
      if (spent > 0)
        (l.envelopesSpentLine, pesos(ledger.major(spent), signed: true)),
    ];
    return Scaffold(
      appBar: AppBar(
        backgroundColor: context.colors.canvas,
        surfaceTintColor: Colors.transparent,
        title: Text(l.envelopesTitle, style: context.type.titleLarge),
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 640),
          child: ListView(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
            children: <Widget>[
              Text(
                l.envelopesPeriod(
                  dayMonth(periodStart(ledger)),
                  dayMonth(ledger.nextPayday),
                ),
                style: context.type.bodyMedium,
              ),
              const SizedBox(height: 12),
              Block(
                padding: const EdgeInsets.fromLTRB(18, 14, 18, 14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(l.envelopesToSplit, style: context.type.labelMedium),
                    Figures(amount(money), style: context.type.headlineMedium),
                    const SizedBox(height: 6),
                    for (final (String label, String value) in sum)
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 2),
                        child: MergeSemantics(
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: <Widget>[
                              Expanded(
                                child: Text(
                                  label,
                                  style: context.type.bodySmall,
                                ),
                              ),
                              const SizedBox(width: 12),
                              Figures(value, style: context.type.bodySmall),
                            ],
                          ),
                        ),
                      ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              for (final Envelope e in _envelopes)
                Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: Row(
                    children: <Widget>[
                      Icon(switch (e.kind) {
                        EnvelopeKind.daily => Glyph.wallet,
                        EnvelopeKind.goal => Glyph.piggyBank,
                        EnvelopeKind.aside => Glyph.handCoins,
                      }, color: context.colors.brand),
                      const SizedBox(width: 12),
                      Expanded(
                        child: TextField(
                          controller: _amounts[e.id],
                          keyboardType: const TextInputType.numberWithOptions(
                            decimal: true,
                          ),
                          inputFormatters: <TextInputFormatter>[
                            AmountInputFormatter(
                              maxDecimals: ledger.currency.decimals,
                            ),
                          ],
                          onChanged: (_) => setState(() {}),
                          decoration: InputDecoration(
                            labelText: e.kind == EnvelopeKind.daily
                                ? l.envelopeDaily
                                : e.name,
                            helperText: switch (e.kind) {
                              EnvelopeKind.daily => l.envelopeDailyHelp,
                              EnvelopeKind.goal => l.envelopeGoalHelp,
                              EnvelopeKind.aside => l.envelopeAsideHelp,
                            },
                            helperMaxLines: 2,
                          ),
                        ),
                      ),
                      if (e.kind == EnvelopeKind.aside)
                        IconButton(
                          tooltip: l.envelopeRemove,
                          onPressed: () => setState(() {
                            _envelopes = <Envelope>[
                              for (final Envelope x in _envelopes)
                                if (x.id != e.id) x,
                            ];
                            _amounts.remove(e.id)?.dispose();
                          }),
                          icon: Icon(
                            Glyph.trash,
                            size: 18,
                            color: context.colors.inkFaint,
                          ),
                        ),
                    ],
                  ),
                ),
              Align(
                alignment: Alignment.centerLeft,
                child: TextButton.icon(
                  onPressed: _addAside,
                  icon: const Icon(Glyph.plus, size: 18),
                  label: Text(l.envelopeAside),
                ),
              ),
              const SizedBox(height: 12),
              Block(
                color: left < 0 ? context.colors.cautionSoft : null,
                padding: const EdgeInsets.fromLTRB(18, 14, 18, 14),
                child: Row(
                  children: <Widget>[
                    Expanded(
                      child: Text(
                        left < 0 ? l.envelopesOverShort : l.envelopesFree,
                        style: context.type.titleSmall?.copyWith(
                          color: left < 0 ? context.colors.caution : null,
                        ),
                      ),
                    ),
                    // «Te pasas por» already says it is over: no minus.
                    Figures(amount(left.abs()), style: context.type.titleSmall),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              Text(l.envelopesOnPaper, style: context.type.bodySmall),
              const SizedBox(height: 20),
              FilledButton(
                onPressed: _saving ? null : () => _save(ledger),
                child: Text(l.envelopesSave),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
