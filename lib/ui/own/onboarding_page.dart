import 'dart:async';

import 'package:decimal/decimal.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../domain/pay_schedule.dart';
import '../../domain/records.dart';
import '../../format/dates.dart';
import '../../l10n/l10n.dart';
import '../../money/asset.dart';
import '../../money/money.dart';
import '../../own/own_controller.dart';
import '../../store/store.dart';
import '../../theme/tokens.dart';
import '../icons.dart';
import '../kit.dart';
import 'account_sheet.dart';
import 'accounts_tab.dart';
import 'amount_input.dart';
import 'charge_sheet.dart';
import 'look.dart';
import 'pay_schedule_editor.dart';

/// Four steps: who, how and how much they get paid, where their money is,
/// and what they pay regularly.
class OnboardingPage extends StatefulWidget {
  const OnboardingPage({
    super.key,
    required this.store,
    required this.onDone,
    required this.onCancel,
    this.newOwn,
    this.now,
  });

  final QuincenaStore store;

  /// The app's clock: the pay schedule's dates start from its today.
  final DateTime Function()? now;

  /// Makes the controller the accounts step adds accounts through.
  ///
  /// It does not read what was captured: a payment shared before the
  /// accounts exist would wait in "Por revisar" without its account. The
  /// app's own controller reads it once onboarding is done.
  final OwnController Function()? newOwn;
  final VoidCallback onDone;

  /// Back to the first screen.
  final VoidCallback onCancel;

  @override
  State<OnboardingPage> createState() => _OnboardingPageState();
}

class _OnboardingPageState extends State<OnboardingPage> {
  static const int _steps = 4;

  /// The step that adds accounts: the fixed payments after it are paid
  /// from one.
  static const int _accountsStep = 2;
  int _step = 0;
  final TextEditingController _name = TextEditingController();

  /// What arrives each payday, when the person says.
  final TextEditingController _pay = TextEditingController();
  Asset _base = Asset.cop;
  PaySchedule _schedule = const TwiceMonthly();
  String? _nameError;

  /// Created on the accounts step, once there is a profile to hang accounts
  /// on.
  OwnController? _own;

  DateTime get _today {
    final DateTime now = (widget.now ?? DateTime.now)();
    return DateTime(now.year, now.month, now.day);
  }

  @override
  void initState() {
    super.initState();
    unawaited(_restore());
  }

  /// Picks up where a previous attempt stopped.
  Future<void> _restore() async {
    final Profile? p = await widget.store.profile();
    if (p == null || !mounted) return;
    setState(() {
      _name.text = p.name;
      _base = p.base;
      _schedule = p.schedule;
      if (p.pay case final Decimal pay) {
        _pay.text = formatDecimal(pay, decimals: p.base.decimals, trim: true);
      }
    });
  }

  @override
  void dispose() {
    _name.dispose();
    _pay.dispose();
    _own?.dispose();
    super.dispose();
  }

  Future<void> _next() async {
    final AppLocalizations l = context.l10n;
    if (_step == 0) {
      final bool missing = _name.text.trim().isEmpty;
      setState(() => _nameError = missing ? l.onboardingNameHint : null);
      if (missing) return;
    }
    if (_step == 1) {
      final Decimal? pay = parseAmount(_pay.text);
      await widget.store.saveProfile(
        Profile(
          name: _name.text.trim(),
          base: _base,
          schedule: _schedule,
          pay: pay != null && pay > Decimal.zero ? pay : null,
        ),
      );
      if (_own == null) {
        final OwnController own =
            widget.newOwn?.call() ??
            OwnController(widget.store, readNative: false);
        _own = own;
        await own.start();
      }
    }
    if (!mounted) return;
    if (_step == _accountsStep &&
        (_own?.accounts ?? const <Account>[]).isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(l.onboardingNeedAccount)));
      return;
    }
    if (_step == _steps - 1) {
      widget.onDone();
      return;
    }
    if (mounted) setState(() => _step++);
  }

  /// Done, having said there is nothing paid regularly: the money to spend
  /// is not waiting for anything.
  Future<void> _noFixed() async {
    await _own?.sayNoFixedPayments(true);
    if (mounted) widget.onDone();
  }

  void _back() {
    if (_step == 0) {
      widget.onCancel();
    } else {
      setState(() => _step--);
    }
  }

  List<AccountDraft> _suggestions(AppLocalizations l) {
    final bool colombia = _base == Asset.cop;
    return <AccountDraft>[
      if (colombia) ...<AccountDraft>[
        const AccountDraft(
          name: 'Bancolombia',
          kind: AccountKind.bank,
          asset: Asset.cop,
          institution: 'Bancolombia',
        ),
        const AccountDraft(
          name: 'Nequi',
          kind: AccountKind.wallet,
          asset: Asset.cop,
          institution: 'Nequi',
        ),
      ] else
        AccountDraft(name: l.kindBank, kind: AccountKind.bank, asset: _base),
      AccountDraft(name: l.kindCash, kind: AccountKind.cash, asset: _base),
      AccountDraft(name: l.kindCard, kind: AccountKind.card, asset: _base),
      if (_base != Asset.usd)
        AccountDraft(
          name: Localizations.localeOf(context).languageCode == 'en'
              ? 'Dollar account'
              : 'Cuenta en dólares',
          kind: AccountKind.bank,
          asset: Asset.usd,
        ),
      const AccountDraft(
        name: 'Binance',
        kind: AccountKind.exchange,
        asset: Asset.usdt,
        institution: 'Binance',
      ),
    ];
  }

  /// What most people pay each month, to start one from. The first of next
  /// month is a guess the sheet lets them change.
  List<ChargeDraft> _fixedSuggestions(AppLocalizations l, DateTime today) {
    final DateTime next = DateTime(today.year, today.month + 1, 1);
    ChargeDraft draft(String name, String category) => ChargeDraft(
      name: name,
      amount: Money(Decimal.zero, _base),
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

  Widget _stepBody(AppLocalizations l) {
    switch (_step) {
      case 0:
        final String lang = Localizations.localeOf(context).languageCode;
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            Text(l.onboardingNameTitle, style: context.type.displaySmall),
            const SizedBox(height: 20),
            TextField(
              controller: _name,
              autofocus: true,
              textCapitalization: TextCapitalization.words,
              textInputAction: TextInputAction.next,
              onSubmitted: (_) => _next(),
              decoration: InputDecoration(
                hintText: l.onboardingNameHint,
                errorText: _nameError,
              ),
            ),
            const SizedBox(height: 36),
            Text(l.onboardingBaseTitle, style: context.type.headlineSmall),
            const SizedBox(height: 6),
            Text(l.onboardingBaseBody, style: context.type.bodyMedium),
            const SizedBox(height: 16),
            DropdownButtonFormField<String>(
              icon: const Icon(Glyph.caretDown, size: 18),
              initialValue: _base.code,
              isExpanded: true,
              items: <DropdownMenuItem<String>>[
                for (final Asset a in Asset.fiat)
                  DropdownMenuItem<String>(
                    value: a.code,
                    child: Text('${a.code} · ${a.name(lang)}'),
                  ),
              ],
              onChanged: (String? code) {
                if (code != null) setState(() => _base = Asset.of(code));
              },
            ),
          ],
        );
      case 1:
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            Text(l.onboardingPayTitle, style: context.type.displaySmall),
            const SizedBox(height: 8),
            Text(l.onboardingPayBody, style: context.type.bodyMedium),
            const SizedBox(height: 24),
            PayScheduleEditor(
              value: _schedule,
              today: _today,
              onChanged: (PaySchedule s) => setState(() => _schedule = s),
            ),
            const SizedBox(height: 36),
            Text(
              l.onboardingPayAmount(
                _schedule is TwiceMonthly ? 'fortnight' : 'other',
              ),
              style: context.type.headlineSmall,
            ),
            const SizedBox(height: 6),
            Text(l.onboardingPayAmountHelp, style: context.type.bodyMedium),
            const SizedBox(height: 16),
            TextField(
              controller: _pay,
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
              inputFormatters: <TextInputFormatter>[
                AmountInputFormatter(maxDecimals: _base.decimals),
              ],
              decoration: InputDecoration(
                labelText: l.amount,
                prefixText: switch (_base.localSymbol ?? _base.symbol) {
                  final String sign => '$sign ',
                  null => null,
                },
                suffixText: _base.code,
              ),
            ),
          ],
        );
      case 3:
        final OwnController? own = _own;
        if (own == null) return const SizedBox.shrink();
        final String suggestionSubscription = l.fixedSuggestSubscription;
        return ListenableBuilder(
          listenable: own,
          builder: (BuildContext context, _) => Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              Text(l.onboardingFixedTitle, style: context.type.displaySmall),
              const SizedBox(height: 8),
              Text(l.onboardingFixedBody, style: context.type.bodyMedium),
              const SizedBox(height: 24),
              if (own.recurring.isNotEmpty) ...<Widget>[
                Panel(
                  children: <Widget>[
                    for (final RecurringCharge r in own.recurring)
                      _FixedRow(
                        charge: r,
                        base: _base,
                        onTap: () =>
                            showChargeSheet(context, own: own, charge: r),
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
                  for (final ChargeDraft d in _fixedSuggestions(l, own.today))
                    ActionChip(
                      avatar: Icon(categoryIconFor(d.category!), size: 18),
                      label: Text(
                        d.name.isEmpty ? suggestionSubscription : d.name,
                      ),
                      onPressed: () =>
                          showChargeSheet(context, own: own, draft: d),
                    ),
                ],
              ),
            ],
          ),
        );
      default:
        final OwnController? own = _own;
        if (own == null) return const SizedBox.shrink();
        return ListenableBuilder(
          listenable: own,
          builder: (BuildContext context, _) => Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              Text(l.onboardingAccountsTitle, style: context.type.displaySmall),
              const SizedBox(height: 8),
              Text(l.onboardingAccountsBody, style: context.type.bodyMedium),
              const SizedBox(height: 24),
              if (own.accounts.isNotEmpty) ...<Widget>[
                Panel(
                  children: <Widget>[
                    for (final Account a in own.accounts)
                      InkWell(
                        // An account just made has nothing to keep:
                        // removing it here is deleting it.
                        onTap: () => showAccountSheet(
                          context,
                          own: own,
                          account: a,
                          archive: false,
                        ),
                        child: IgnorePointer(
                          child: AccountRow(own: own, account: a),
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 16),
              ],
              OutlinedButton.icon(
                onPressed: () => showAccountSheet(context, own: own),
                icon: const Icon(Glyph.plus, size: 18),
                label: Text(l.addAccount),
              ),
              const SizedBox(height: 24),
              SectionLabel(l.onboardingSuggestions),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: <Widget>[
                  for (final AccountDraft d in _suggestions(l))
                    ActionChip(
                      avatar: Icon(accountIcon(d.kind), size: 18),
                      label: Text('${d.name} · ${d.asset.code}'),
                      onPressed: () =>
                          showAccountSheet(context, own: own, draft: d),
                    ),
                ],
              ),
            ],
          ),
        );
    }
  }

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l = context.l10n;
    final bool last = _step == _steps - 1;
    return Scaffold(
      appBar: AppBar(
        backgroundColor: context.colors.canvas,
        surfaceTintColor: Colors.transparent,
        leading: IconButton(
          tooltip: l.back,
          onPressed: _back,
          icon: const Icon(Glyph.arrowLeft),
        ),
        title: Text(
          l.onboardingStep(_step + 1, _steps),
          style: context.type.labelMedium,
        ),
      ),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 560),
            child: Column(
              children: <Widget>[
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(99),
                    child: LinearProgressIndicator(
                      value: (_step + 1) / _steps,
                      minHeight: 6,
                      backgroundColor: context.colors.sunken,
                    ),
                  ),
                ),
                Expanded(
                  child: ListView(
                    padding: const EdgeInsets.fromLTRB(24, 28, 24, 24),
                    children: <Widget>[_stepBody(l)],
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(24, 8, 24, 20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: <Widget>[
                      FilledButton(
                        onPressed: _next,
                        child: Text(last ? l.finish : l.next),
                      ),
                      // Only before any is added: with one, there are some.
                      if (_own case final OwnController own when last)
                        ListenableBuilder(
                          listenable: own,
                          builder: (BuildContext context, _) =>
                              own.recurring.isNotEmpty
                              ? const SizedBox.shrink()
                              : Padding(
                                  padding: const EdgeInsets.only(top: 4),
                                  child: TextButton(
                                    onPressed: _noFixed,
                                    child: Text(l.noFixedPayments),
                                  ),
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
  }
}

/// A fixed payment told during onboarding: what, when it is next charged
/// and how much. With large text the amount goes under the date: beside
/// them, the name would have no room.
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
