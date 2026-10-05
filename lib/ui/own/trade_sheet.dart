import 'package:decimal/decimal.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../domain/records.dart';
import '../../format/dates.dart';
import '../../l10n/l10n.dart';
import '../../money/asset.dart';
import '../../money/money.dart';
import '../../own/own_controller.dart';
import '../../theme/tokens.dart';
import '../icons.dart';
import 'account_sheet.dart';
import 'amount_input.dart';
import 'look.dart';
import 'portfolio_page.dart';

/// Records a purchase of what [account] holds, or a sale of it when [sell].
///
/// Paid or collected in one of the person's accounts, it is a transfer and
/// both balances move. Paid or collected outside, on Binance P2P or in
/// cash, the movement keeps what it cost, so the gain can be worked out.
Future<void> showTradeSheet(
  BuildContext context, {
  required OwnController own,
  required Account account,
  bool sell = false,
}) => showModalBottomSheet<void>(
  context: context,
  isScrollControlled: true,
  showDragHandle: true,
  useSafeArea: true,
  backgroundColor: context.colors.surface,
  constraints: const BoxConstraints(maxWidth: 560),
  builder: (BuildContext context) =>
      _TradeForm(own: own, account: account, sell: sell),
);

class _TradeForm extends StatefulWidget {
  const _TradeForm({
    required this.own,
    required this.account,
    required this.sell,
  });

  final OwnController own;
  final Account account;
  final bool sell;

  @override
  State<_TradeForm> createState() => _TradeFormState();
}

class _TradeFormState extends State<_TradeForm> {
  OwnController get own => widget.own;
  Account get account => widget.account;
  bool get sell => widget.sell;

  final TextEditingController _quantity = TextEditingController();
  final TextEditingController _total = TextEditingController();

  /// The person's account on the other side, or null for outside the app.
  String? _other;
  late Asset _currency = own.profile?.base ?? Asset.cop;
  late DateTime _date = own.today;
  String? _quantityError;
  String? _totalError;
  bool _saving = false;

  List<Account> get _others => <Account>[
    for (final Account a in own.accounts)
      if (a.id != account.id) a,
  ];

  Account? get _otherAccount {
    for (final Account a in _others) {
      if (a.id == _other) return a;
    }
    return null;
  }

  /// The currency the total is in: the other account's, or the one picked.
  Asset get _totalAsset => _otherAccount?.asset ?? _currency;

  /// The currencies a total paid outside can be in.
  List<Asset> get _currencies => <Asset>{
    own.profile?.base ?? Asset.cop,
    Asset.usd,
    Asset.usdt,
    Asset.usdc,
  }.where((Asset a) => a != account.asset).toList();

  Money get _held => own.balances[account.id] ?? account.openingMoney;

  @override
  void dispose() {
    _quantity.dispose();
    _total.dispose();
    super.dispose();
  }

  Future<void> _pickDate() async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _date,
      firstDate: DateTime(2009),
      lastDate: own.today,
    );
    if (picked != null) setState(() => _date = picked);
  }

  String _dateLabel(AppLocalizations l) {
    final DateTime today = own.today;
    final DateTime day = DateTime(_date.year, _date.month, _date.day);
    if (day == today) return l.today;
    if (day == today.subtract(const Duration(days: 1))) return l.yesterday;
    return shortDate(day);
  }

  Future<void> _save() async {
    final AppLocalizations l = context.l10n;
    final Decimal? quantity = parseAmount(_quantity.text);
    final Decimal? total = parseAmount(_total.text);
    setState(() {
      _quantityError = quantity == null || quantity <= Decimal.zero
          ? l.invalidAmount
          : (sell && quantity > _held.amount
                ? l.tradeNotEnough(moneyText(_held, base: own.profile?.base))
                : null);
      _totalError = total == null || total <= Decimal.zero
          ? l.invalidAmount
          : null;
    });
    if (_quantityError != null || _totalError != null || _saving) return;
    setState(() => _saving = true);
    // A purchase today is dated now, so it sorts after what came before it.
    final DateTime now = DateTime.now();
    final DateTime when = DateUtils.isSameDay(_date, now) ? now : _date;
    final Account? other = _otherAccount;
    if (other == null) {
      await own.store.addEntry(
        accountId: account.id,
        amount: quantity!,
        kind: sell ? EntryKind.expense : EntryKind.income,
        date: when,
        cost: Money(total!, _currency),
      );
    } else if (sell) {
      await own.store.addTransfer(
        fromAccountId: account.id,
        toAccountId: other.id,
        sent: quantity!,
        received: total,
        date: when,
      );
    } else {
      await own.store.addTransfer(
        fromAccountId: other.id,
        toAccountId: account.id,
        sent: total!,
        received: quantity,
        date: when,
      );
    }
    if (mounted) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l = context.l10n;
    final Asset? base = own.profile?.base;
    final Decimal? quantity = parseAmount(_quantity.text);
    final Decimal? total = parseAmount(_total.text);
    final String? each =
        quantity != null &&
            total != null &&
            quantity > Decimal.zero &&
            total > Decimal.zero
        ? moneyText(
            Money(
              (total / quantity).toDecimal(scaleOnInfinitePrecision: 8),
              _totalAsset,
            ),
            base: base,
          )
        : null;
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Row(
              children: <Widget>[
                CoinMark(account.asset, size: 36),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Text(
                        sell ? l.tradeSell : l.tradeBuy,
                        style: context.type.headlineMedium,
                      ),
                      Text(account.name, style: context.type.bodySmall),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            // A field's error goes as soon as it is typed again: left there,
            // it would also hide the price per unit worked out below.
            TextField(
              controller: _quantity,
              autofocus: true,
              inputFormatters: <TextInputFormatter>[
                AmountInputFormatter(maxDecimals: 8),
              ],
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
              onChanged: (_) => setState(() => _quantityError = null),
              decoration: InputDecoration(
                labelText: l.tradeQuantity(account.asset.code),
                suffixText: account.asset.code,
                errorText: _quantityError,
                helperText: sell
                    ? l.tradeNotEnough(moneyText(_held, base: base))
                    : null,
              ),
            ),
            const SizedBox(height: 16),
            DropdownButtonFormField<String?>(
              icon: const Icon(Glyph.caretDown, size: 18),
              initialValue: _other,
              isExpanded: true,
              decoration: InputDecoration(
                labelText: sell ? l.tradeReceivedIn : l.tradePaidFrom,
                helperText: _other == null ? l.tradeOutsideHelp : null,
                helperMaxLines: 5,
              ),
              items: <DropdownMenuItem<String?>>[
                DropdownMenuItem<String?>(child: Text(l.tradeOutside)),
                for (final Account a in _others)
                  DropdownMenuItem<String?>(
                    value: a.id,
                    child: Text(
                      '${a.name} · ${a.asset.code}',
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
              ],
              onChanged: (String? id) => setState(() => _other = id),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _total,
              inputFormatters: <TextInputFormatter>[
                AmountInputFormatter(maxDecimals: _totalAsset.decimals),
              ],
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
              onChanged: (_) => setState(() => _totalError = null),
              decoration: InputDecoration(
                labelText: sell ? l.tradeReceived : l.tradePaid,
                suffixText: _totalAsset.code,
                errorText: _totalError,
                helperText: each == null ? null : l.tradePriceEach(each),
                helperMaxLines: 2,
              ),
            ),
            if (_other == null) ...<Widget>[
              const SizedBox(height: 10),
              CurrencyChoice(
                choices: _currencies,
                chosen: _currency,
                onChosen: (Asset a) => setState(() => _currency = a),
              ),
            ],
            const SizedBox(height: 12),
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Glyph.calendarBlank),
              title: Text(_dateLabel(l)),
              onTap: _pickDate,
            ),
            const SizedBox(height: 12),
            FilledButton(
              onPressed: _saving ? null : _save,
              child: Text(l.save),
            ),
          ],
        ),
      ),
    );
  }
}
