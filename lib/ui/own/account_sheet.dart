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

/// Adds an account, or edits [account]. Returns the saved account.
Future<Account?> showAccountSheet(
  BuildContext context, {
  required OwnController own,
  Account? account,
  AccountDraft? draft,
}) => showModalBottomSheet<Account>(
  context: context,
  isScrollControlled: true,
  showDragHandle: true,
  useSafeArea: true,
  backgroundColor: context.colors.surface,
  constraints: const BoxConstraints(maxWidth: 560),
  builder: (BuildContext context) =>
      _AccountForm(own: own, account: account, draft: draft),
);

class _AccountForm extends StatefulWidget {
  const _AccountForm({required this.own, this.account, this.draft});

  final OwnController own;
  final Account? account;
  final AccountDraft? draft;

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
  late bool _spendable = _editing?.spendable ?? _kind.spendableByDefault;
  bool _spendableTouched = false;
  bool _other = false;
  String? _nameError;
  String? _balanceError;
  bool _saving = false;

  Asset get _defaultAsset => widget.own.profile?.base ?? Asset.cop;

  Money get _currentBalance =>
      widget.own.balances[_editing!.id] ?? _editing.openingMoney;

  String _initialBalanceText() {
    final Decimal value = _currentBalance.amount;
    final Decimal shown = _editing!.kind == AccountKind.card ? -value : value;
    return formatDecimal(shown, decimals: _editing.asset.decimals, trim: true);
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

  Asset get _chosenAsset => _other && _otherAsset.text.trim().isNotEmpty
      ? Asset.of(_otherAsset.text)
      : _asset;

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
    setState(() {
      _nameError = name.isEmpty ? l.accountNameHint : null;
      _balanceError = typed == null ? l.invalidAmount : null;
      _costError = costInvalid ? l.invalidAmount : null;
      _limitError = limitInvalid ? l.invalidAmount : null;
    });
    if (_nameError != null ||
        typed == null ||
        costInvalid ||
        limitInvalid ||
        _saving) {
      return;
    }
    final Money? openingCost = cost == null ? null : Money(cost, _costAsset);
    setState(() => _saving = true);
    // A card shows what is owed, a positive number; its balance is negative.
    final Decimal balance = _kind == AccountKind.card ? -typed.abs() : typed;
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
        // The person corrected today's balance: the opening absorbs the
        // difference, and the movements stay as they were.
        opening: _editing.opening + (balance - _currentBalance.amount),
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

  Future<void> _delete() async {
    final AppLocalizations l = context.l10n;
    final Account account = _editing!;
    final int count =
        widget.own.snapshot?.entries
            .where((Entry e) => e.accountId == account.id)
            .length ??
        0;
    final bool? sure = await showDialog<bool>(
      context: context,
      builder: (BuildContext context) => AlertDialog(
        title: Text(l.deleteAccountTitle(account.name)),
        content: Text(l.deleteAccountBody(count)),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text(l.cancel),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: TextButton.styleFrom(
              foregroundColor: context.colors.negative,
            ),
            child: Text(l.delete),
          ),
        ],
      ),
    );
    if (sure != true) return;
    await widget.own.store.deleteAccount(account.id);
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
            TextField(
              controller: _name,
              autofocus: !editing && widget.draft == null,
              textCapitalization: TextCapitalization.sentences,
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
                      color: context.colors.brand,
                    ),
                    label: Text(accountKindLabel(context, k)),
                    selected: _kind == k,
                    onSelected: (_) => setState(() {
                      _kind = k;
                      if (!_spendableTouched) _spendable = k.spendableByDefault;
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
                onChanged: (Asset? a) => setState(() {
                  _other = a == null;
                  if (a != null) _asset = a;
                }),
                onOtherChanged: () => setState(() {}),
              ),
            const SizedBox(height: 16),
            TextField(
              controller: _institution,
              textCapitalization: TextCapitalization.words,
              decoration: InputDecoration(labelText: l.accountInstitution),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _balance,
              inputFormatters: <TextInputFormatter>[
                AmountInputFormatter(maxDecimals: asset.decimals),
              ],
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
              decoration: InputDecoration(
                labelText: _kind == AccountKind.card
                    ? l.accountDebtNow
                    : l.accountBalanceNow,
                suffixText: asset.code,
                errorText: _balanceError,
              ),
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
                decoration: InputDecoration(
                  labelText: l.cardLimitField,
                  helperText: l.cardLimitHelp,
                  helperMaxLines: 3,
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
              TextButton.icon(
                onPressed: _delete,
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
    required this.onAsset,
  });

  final TextEditingController controller;
  final Asset asset;
  final List<Asset> choices;
  final String? error;
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
  });

  final Asset asset;
  final bool other;
  final TextEditingController otherController;

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
            decoration: InputDecoration(labelText: l.assetOtherHint),
          ),
        ],
      ],
    );
  }
}
