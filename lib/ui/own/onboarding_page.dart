import 'dart:async';

import 'package:flutter/material.dart';

import '../../domain/pay_schedule.dart';
import '../../domain/records.dart';
import '../../l10n/l10n.dart';
import '../../money/asset.dart';
import '../../own/own_controller.dart';
import '../../store/store.dart';
import '../../theme/tokens.dart';
import '../icons.dart';
import 'account_sheet.dart';
import 'accounts_tab.dart';
import 'look.dart';
import 'pay_schedule_editor.dart';

/// Three steps: who, how they get paid, and where their money is.
class OnboardingPage extends StatefulWidget {
  const OnboardingPage({
    super.key,
    required this.store,
    required this.onDone,
    required this.onCancel,
    this.newOwn,
  });

  final QuincenaStore store;

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
  static const int _steps = 3;
  int _step = 0;
  final TextEditingController _name = TextEditingController();
  Asset _base = Asset.cop;
  PaySchedule _schedule = const TwiceMonthly();
  String? _nameError;

  /// Created on the last step, once there is a profile to hang accounts on.
  OwnController? _own;

  DateTime get _today {
    final DateTime now = DateTime.now();
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
    });
  }

  @override
  void dispose() {
    _name.dispose();
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
      await widget.store.saveProfile(
        Profile(name: _name.text.trim(), base: _base, schedule: _schedule),
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
    if (_step == _steps - 1) {
      if ((_own?.accounts ?? const <Account>[]).isEmpty) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(l.onboardingNeedAccount)));
        return;
      }
      widget.onDone();
      return;
    }
    if (mounted) setState(() => _step++);
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
          ],
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
                        onTap: () =>
                            showAccountSheet(context, own: own, account: a),
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
                  child: SizedBox(
                    width: double.infinity,
                    child: FilledButton(
                      onPressed: _next,
                      child: Text(last ? l.finish : l.next),
                    ),
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
