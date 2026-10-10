import 'dart:math' as math;

import 'package:decimal/decimal.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../domain/records.dart';
import '../../l10n/l10n.dart';
import '../../money/asset.dart';
import '../../money/money.dart';
import '../../own/own_controller.dart';
import '../../theme/tokens.dart';
import '../icons.dart';
import 'account_leaving.dart';
import 'amount_input.dart';
import 'look.dart';

/// A starting point for a new account, such as the suggestions onboarding
/// offers.
class AccountDraft {
  const AccountDraft({
    required this.name,
    required this.kind,
    required this.asset,
    this.institution = '',
  });

  final String name;
  final AccountKind kind;
  final Asset asset;
  final String institution;
}

/// Adds an account, or edits [account]. Returns the saved account. With
/// [archive] false, as while setting up, an account can be deleted but is
/// not offered to be archived.
Future<Account?> showAccountSheet(
  BuildContext context, {
  required OwnController own,
  Account? account,
  AccountDraft? draft,
  bool archive = true,
}) => showModalBottomSheet<Account>(
  context: context,
  isScrollControlled: true,
  showDragHandle: true,
  useSafeArea: true,
  backgroundColor: context.colors.surface,
  constraints: const BoxConstraints(maxWidth: 560),
  builder: (BuildContext context) =>
      _AccountForm(own: own, account: account, draft: draft, archive: archive),
);

class _AccountForm extends StatefulWidget {
  const _AccountForm({
    required this.own,
    this.account,
    this.draft,
    this.archive = true,
  });

  final OwnController own;
  final Account? account;
  final AccountDraft? draft;
  final bool archive;

  @override
  State<_AccountForm> createState() => _AccountFormState();
}

class _AccountFormState extends State<_AccountForm> {
  late final Account? _editing = widget.account;
  late final TextEditingController _name = TextEditingController(
    text: _editing?.name ?? widget.draft?.name ?? '',
  );
  late final TextEditingController _institution = TextEditingController(
    text: _editing?.institution ?? widget.draft?.institution ?? '',
  );
  late final TextEditingController _otherAsset = TextEditingController();
  late final TextEditingController _balance = TextEditingController(
    text: _editing == null ? '' : _initialBalanceText(),
  );
  late final TextEditingController _cost = TextEditingController(
    text: _editing?.openingCost == null
        ? ''
        : formatDecimal(
            _editing!.openingCost!.amount,
            decimals: _editing.openingCost!.asset.decimals,
            trim: true,
          ),
  );
  late Asset _costAsset = _editing?.openingCost?.asset ?? _defaultAsset;
  String? _costError;
  late final TextEditingController _limit = TextEditingController(
    text: _editing?.creditLimit == null
        ? ''
        : formatDecimal(
            _editing!.creditLimit!,
            decimals: _editing.asset.decimals,
            trim: true,
          ),
  );
  String? _limitError;
  late AccountKind _kind =
      _editing?.kind ?? widget.draft?.kind ?? AccountKind.bank;
  late Asset _asset = _editing?.asset ?? widget.draft?.asset ?? _defaultAsset;
  late bool _spendable = _editing?.spendable ?? _spendableFor(_kind);
  bool _spendableTouched = false;
  bool _other = false;
  String? _otherError;
  String? _nameError;
  String? _balanceError;
  bool _saving = false;

  Asset get _defaultAsset => widget.own.profile?.base ?? Asset.cop;

  Money get _currentBalance =>
      widget.own.balances[_editing!.id] ?? _editing.openingMoney;

  /// Today's balance without its sign: which side of zero it is on is
  /// [_otherSide], chosen apart, as a sign is not something to type.
  String _initialBalanceText() => formatDecimal(
    _currentBalance.amount.abs(),
    decimals: _editing!.asset.decimals,
    trim: true,
  );

  /// Whether today's balance is on the side a [kind] is not usually on: a
  /// card in the person's favor, a bank account overdrawn.
  static bool _isOtherSide(AccountKind kind, Decimal balance) =>
      kind == AccountKind.card
      ? balance > Decimal.zero
      : balance < Decimal.zero;

  /// The side of zero the balance is on, as the person chose it: «A favor»
  /// for a card, «Está en sobregiro» for a bank account.
  late bool _otherSide =
      _editing != null && _isOtherSide(_editing.kind, _currentBalance.amount);

  /// Today's balance as the form showed it on opening, and its side.
  late final String _shownBalance;
  late final bool _shownSide;

  @override
  void initState() {
    super.initState();
    _shownBalance = _balance.text;
    _shownSide = _otherSide;
  }

  @override
  void dispose() {
    _name.dispose();
    _institution.dispose();
    _otherAsset.dispose();
    _balance.dispose();
    _cost.dispose();
    _limit.dispose();
    super.dispose();
  }

  /// The currency the account will hold. Another crypto is crypto from the
  /// moment it is picked: until its ticker is typed, a coin with no name
  /// yet, whose balance takes decimals and whose cost is asked for.
  Asset get _chosenAsset => _other ? Asset.of(_otherAsset.text) : _asset;

  /// Whether the day to day counts an account of [kind] unless the person
  /// says otherwise: never crypto, which is kept rather than spent, as
  /// savings and exchanges are.
  bool _spendableFor(AccountKind kind) =>
      kind.spendableByDefault && !_chosenAsset.isCrypto;

  Future<void> _save() async {
    final AppLocalizations l = context.l10n;
    final String name = _name.text.trim();
    final Decimal? typed = _balance.text.trim().isEmpty
        ? Decimal.zero
        : parseAmount(_balance.text);
    // What the opening balance cost, for an investment: optional.
    final bool investment = _chosenAsset.isCrypto;
    final Decimal? cost = !investment || _cost.text.trim().isEmpty
        ? null
        : parseAmount(_cost.text);
    final bool costInvalid =
        investment &&
        _cost.text.trim().isNotEmpty &&
        (cost == null || cost < Decimal.zero);
    // A card's limit: optional, and only a card has one.
    final bool card = _kind == AccountKind.card;
    final Decimal? limit = !card || _limit.text.trim().isEmpty
        ? null
        : parseAmount(_limit.text);
    final bool limitInvalid =
        card &&
        _limit.text.trim().isNotEmpty &&
        (limit == null || limit <= Decimal.zero);
    // Another crypto needs its ticker: without one the account would be
    // made in the base currency, as if no crypto had been picked.
    final bool noTicker = _other && _otherAsset.text.trim().isEmpty;
    setState(() {
      _nameError = name.isEmpty ? l.accountNameHint : null;
      _otherError = noTicker ? l.assetOtherMissing : null;
      _balanceError = typed == null ? l.invalidAmount : null;
      _costError = costInvalid ? l.invalidAmount : null;
      _limitError = limitInvalid ? l.invalidAmount : null;
    });
    if (_nameError != null ||
        noTicker ||
        typed == null ||
        costInvalid ||
        limitInvalid ||
        _saving) {
      return;
    }
    final Money? openingCost = cost == null ? null : Money(cost, _costAsset);
    setState(() => _saving = true);
    // The amount is typed without a sign; the side it is on was chosen
    // apart. A card owes unless it is in the person's favor, and any other
    // account has money unless it is overdrawn.
    final bool below = _kind == AccountKind.card ? !_otherSide : _otherSide;
    final Decimal balance = below ? -typed.abs() : typed.abs();
    final Account saved;
    if (_editing == null) {
      saved = await widget.own.store.addAccount(
        name: name,
        kind: _kind,
        asset: _chosenAsset,
        opening: balance,
        institution: _institution.text,
        spendable: _spendable,
        openingCost: openingCost,
        creditLimit: limit,
      );
    } else {
      final Account edited = _editing.copyWith(
        name: name,
        kind: _kind,
        institution: _institution.text,
        spendable: _spendable,
        // The person corrected today's balance or its side: the opening
        // absorbs the difference, and the movements stay as they were. Left
        // as it was shown, it stays exactly as it is.
        opening: _balance.text == _shownBalance && _otherSide == _shownSide
            ? _editing.opening
            : _editing.opening + (balance - _currentBalance.amount),
        openingCost: openingCost,
        clearOpeningCost: openingCost == null,
        creditLimit: limit,
        clearCreditLimit: limit == null,
      );
      await widget.own.store.updateAccount(edited);
      saved = edited;
    }
    if (mounted) Navigator.of(context).pop(saved);
  }

  /// Takes a field's error away, redrawing only when there was one.
  void _clear(VoidCallback error) {
    if (_nameError == null &&
        _otherError == null &&
        _balanceError == null &&
        _limitError == null &&
        _costError == null) {
      return;
    }
    setState(error);
  }

  /// Archives or deletes the account, once the person saw what goes with
  /// it; the form closes when it is done.
  Future<void> _leave({required bool delete}) async {
    final Leaving? done = await confirmLeaving(
      context,
      widget.own,
      <Account>[_editing!],
      delete: delete,
      // One already archived is not offered to be archived again.
      archive: widget.archive && !_editing.archived,
    );
    if (done != null && mounted) Navigator.of(context).pop();
  }

  Future<void> _restore() async {
    await widget.own.restoreAccount(_editing!.id);
    if (mounted) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l = context.l10n;
    final bool editing = _editing != null;
    final Asset asset = _chosenAsset;
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Text(
              editing ? l.editAccount : l.addAccount,
              style: context.type.headlineMedium,
            ),
            const SizedBox(height: 20),
            // A field's error goes as soon as it is typed again: left there,
            // it would still say the name is missing once it is written.
            TextField(
              controller: _name,
              autofocus: !editing && widget.draft == null,
              textCapitalization: TextCapitalization.sentences,
              onChanged: (_) => _clear(() => _nameError = null),
              decoration: InputDecoration(
                labelText: l.accountName,
                hintText: l.accountNameHint,
                errorText: _nameError,
              ),
            ),
            const SizedBox(height: 20),
            Text(l.accountKind, style: context.type.labelMedium),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: <Widget>[
                for (final AccountKind k in AccountKind.values)
                  ChoiceChip(
                    avatar: Icon(
                      accountIcon(k),
                      size: 18,
                      color: context.colors.inkSoft,
                    ),
                    label: Text(accountKindLabel(context, k)),
                    selected: _kind == k,
                    onSelected: (_) => setState(() {
                      // Each kind has its own usual side of zero.
                      if (k != _kind) _otherSide = false;
                      _kind = k;
                      if (!_spendableTouched) _spendable = _spendableFor(k);
                    }),
                  ),
              ],
            ),
            const SizedBox(height: 20),
            if (editing)
              _LockedAsset(asset: asset)
            else
              _AssetPicker(
                asset: _asset,
                other: _other,
                otherController: _otherAsset,
                otherError: _otherError,
                // A crypto turns the day to day off by itself, as a savings
                // kind does, unless the person set it.
                onChanged: (Asset? a) => setState(() {
                  _other = a == null;
                  if (a != null) _asset = a;
                  if (!_spendableTouched) _spendable = _spendableFor(_kind);
                }),
                onOtherChanged: () => setState(() {
                  _otherError = null;
                  if (!_spendableTouched) _spendable = _spendableFor(_kind);
                }),
              ),
            const SizedBox(height: 16),
            TextField(
              controller: _institution,
              textCapitalization: TextCapitalization.words,
              decoration: InputDecoration(labelText: l.accountInstitution),
            ),
            const SizedBox(height: 16),
            // What a card owes or has in favor, said with a choice: a minus
            // sign is not something a person types, nor reads as a debt.
            if (_kind == AccountKind.card) ...<Widget>[
              SegmentedButton<bool>(
                segments: <ButtonSegment<bool>>[
                  ButtonSegment<bool>(
                    value: false,
                    label: Text(l.cardOwedLabel),
                  ),
                  ButtonSegment<bool>(
                    value: true,
                    label: Text(l.cardInFavorLabel),
                  ),
                ],
                selected: <bool>{_otherSide},
                showSelectedIcon: false,
                onSelectionChanged: (Set<bool> side) =>
                    setState(() => _otherSide = side.single),
              ),
              const SizedBox(height: 12),
            ],
            TextField(
              controller: _balance,
              // A suggested account comes named: what it holds is all that
              // is missing, and the button that saves comes up with it, as
              // far as half of what the keyboard leaves.
              autofocus: !editing && widget.draft != null,
              scrollPadding: EdgeInsets.fromLTRB(
                20,
                20,
                20,
                math.min(
                  60 + MediaQuery.textScalerOf(context).scale(160),
                  (MediaQuery.sizeOf(context).height -
                          MediaQuery.viewInsetsOf(context).bottom) /
                      2,
                ),
              ),
              inputFormatters: <TextInputFormatter>[
                AmountInputFormatter(maxDecimals: asset.decimals),
              ],
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
              onChanged: (_) => _clear(() => _balanceError = null),
              decoration: InputDecoration(
                labelText: switch ((_kind, _otherSide)) {
                  (AccountKind.card, false) => l.accountDebtNow,
                  (AccountKind.card, true) => l.accountInFavorNow,
                  (_, true) => l.accountOverdraftNow,
                  _ => l.accountBalanceNow,
                },
                // Another crypto's ticker once it is typed, never the
                // pesos it is not.
                suffixText: asset.code.isEmpty ? null : asset.code,
                errorText: _balanceError,
              ),
            ),
            if (_kind == AccountKind.bank)
              CheckboxListTile(
                value: _otherSide,
                onChanged: (bool? v) => setState(() => _otherSide = v ?? false),
                title: Text(l.accountOverdrawn),
                controlAffinity: ListTileControlAffinity.leading,
                contentPadding: EdgeInsets.zero,
                dense: true,
              ),
            if (_kind == AccountKind.card) ...<Widget>[
              const SizedBox(height: 16),
              TextField(
                controller: _limit,
                inputFormatters: <TextInputFormatter>[
                  AmountInputFormatter(maxDecimals: asset.decimals),
                ],
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                onChanged: (_) => _clear(() => _limitError = null),
                decoration: InputDecoration(
                  labelText: l.cardLimitField,
                  helperText: l.cardLimitHelp,
                  helperMaxLines: 6,
                  suffixText: asset.code,
                  errorText: _limitError,
                ),
              ),
            ],
            if (asset.isCrypto) ...<Widget>[
              const SizedBox(height: 16),
              _OpeningCost(
                controller: _cost,
                asset: _costAsset,
                choices: <Asset>{_defaultAsset, Asset.usd}.toList(),
                error: _costError,
                onChanged: () => _clear(() => _costError = null),
                onAsset: (Asset a) => setState(() => _costAsset = a),
              ),
            ],
            const SizedBox(height: 8),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              value: _spendable,
              onChanged: (bool v) => setState(() {
                _spendable = v;
                _spendableTouched = true;
              }),
              title: Text(l.accountSpendable, style: context.type.titleSmall),
              subtitle: Text(
                _kind == AccountKind.card
                    ? l.cardSpendableHelp
                    : l.accountSpendableHelp,
                style: context.type.bodySmall,
              ),
            ),
            const SizedBox(height: 20),
            FilledButton(
              onPressed: _saving ? null : _save,
              child: Text(l.save),
            ),
            if (editing) ...<Widget>[
              const SizedBox(height: 8),
              // A closed account is archived, its history kept; one
              // archived comes back from here too.
              if (_editing.archived)
                TextButton.icon(
                  onPressed: _restore,
                  icon: const Icon(Glyph.arrowCounterClockwise, size: 18),
                  label: Text(l.restore),
                )
              else if (widget.archive)
                TextButton.icon(
                  onPressed: () => _leave(delete: false),
                  icon: const Icon(Glyph.archive, size: 18),
                  label: Text(l.archive),
                ),
              TextButton.icon(
                onPressed: () => _leave(delete: true),
                style: TextButton.styleFrom(
                  foregroundColor: context.colors.negative,
                ),
                icon: const Icon(Glyph.trash, size: 18),
                label: Text(l.delete),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// What an investment's opening balance cost, in pesos or dollars.
class _OpeningCost extends StatelessWidget {
  const _OpeningCost({
    required this.controller,
    required this.asset,
    required this.choices,
    required this.error,
    required this.onChanged,
    required this.onAsset,
  });

  final TextEditingController controller;
  final Asset asset;
  final List<Asset> choices;
  final String? error;
  final VoidCallback onChanged;
  final ValueChanged<Asset> onAsset;

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l = context.l10n;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        TextField(
          controller: controller,
          inputFormatters: <TextInputFormatter>[
            AmountInputFormatter(maxDecimals: asset.decimals),
          ],
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          onChanged: (_) => onChanged(),
          decoration: InputDecoration(
            labelText: l.accountOpeningCost,
            helperText: l.accountOpeningCostHelp,
            helperMaxLines: 3,
            suffixText: asset.code,
            errorText: error,
          ),
        ),
        if (choices.length > 1) ...<Widget>[
          const SizedBox(height: 10),
          CurrencyChoice(choices: choices, chosen: asset, onChosen: onAsset),
        ],
      ],
    );
  }
}

/// A row of currencies to pick one from, for an amount just typed.
class CurrencyChoice extends StatelessWidget {
  const CurrencyChoice({
    super.key,
    required this.choices,
    required this.chosen,
    required this.onChosen,
  });

  final List<Asset> choices;
  final Asset chosen;
  final ValueChanged<Asset> onChosen;

  @override
  Widget build(BuildContext context) => Align(
    alignment: Alignment.centerLeft,
    child: SegmentedButton<String>(
      showSelectedIcon: false,
      segments: <ButtonSegment<String>>[
        for (final Asset a in choices)
          ButtonSegment<String>(value: a.code, label: Text(a.code)),
      ],
      selected: <String>{chosen.code},
      onSelectionChanged: (Set<String> picked) =>
          onChosen(Asset.of(picked.single)),
    ),
  );
}

/// The currency of an account that already has one.
class _LockedAsset extends StatelessWidget {
  const _LockedAsset({required this.asset});

  final Asset asset;

  @override
  Widget build(BuildContext context) {
    final String lang = Localizations.localeOf(context).languageCode;
    return InputDecorator(
      decoration: InputDecoration(
        labelText: context.l10n.accountAsset,
        helperText: context.l10n.accountAssetLocked,
        helperMaxLines: 2,
      ),
      child: Text('${asset.code} · ${asset.name(lang)}'),
    );
  }
}

/// Picks the currency of a new account: the common ones, or any ticker.
class _AssetPicker extends StatelessWidget {
  const _AssetPicker({
    required this.asset,
    required this.other,
    required this.otherController,
    required this.onChanged,
    required this.onOtherChanged,
    this.otherError,
  });

  final Asset asset;
  final bool other;
  final TextEditingController otherController;

  /// What is wrong with the ticker typed, if anything.
  final String? otherError;

  /// Null means "another crypto", typed below.
  final ValueChanged<Asset?> onChanged;
  final VoidCallback onOtherChanged;

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l = context.l10n;
    final String lang = Localizations.localeOf(context).languageCode;
    const String otherValue = '__other__';
    DropdownMenuItem<String> item(Asset a) => DropdownMenuItem<String>(
      value: a.code,
      child: Text('${a.code} · ${a.name(lang)}'),
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        DropdownButtonFormField<String>(
          icon: const Icon(Glyph.caretDown, size: 18),
          initialValue: other ? otherValue : asset.code,
          isExpanded: true,
          decoration: InputDecoration(labelText: l.accountAsset),
          items: <DropdownMenuItem<String>>[
            DropdownMenuItem<String>(
              enabled: false,
              child: Text(l.assetFiat, style: context.type.labelSmall),
            ),
            for (final Asset a in Asset.fiat) item(a),
            DropdownMenuItem<String>(
              enabled: false,
              child: Text(l.assetCrypto, style: context.type.labelSmall),
            ),
            for (final Asset a in Asset.crypto) item(a),
            DropdownMenuItem<String>(
              value: otherValue,
              child: Text(l.assetOther),
            ),
          ],
          onChanged: (String? code) {
            if (code == null) return;
            onChanged(code == otherValue ? null : Asset.of(code));
          },
        ),
        if (other) ...<Widget>[
          const SizedBox(height: 12),
          TextField(
            controller: otherController,
            textCapitalization: TextCapitalization.characters,
            onChanged: (_) => onOtherChanged(),
            decoration: InputDecoration(
              labelText: l.assetOtherHint,
              errorText: otherError,
            ),
          ),
        ],
      ],
    );
  }
}
