import 'package:decimal/decimal.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../app.dart';
import '../../app_mode.dart';
import '../../backup/backup.dart';
import '../../data/ledger.dart';
import '../../domain/pay_schedule.dart';
import '../../domain/records.dart';
import '../../exchanges/binance_link.dart';
import '../../format/dates.dart';
import '../../format/money.dart';
import '../../l10n/l10n.dart';
import '../../money/asset.dart';
import '../../money/money.dart';
import '../../own/own_controller.dart';
import '../../platform/app_settings.dart';
import '../../sync/sync_service.dart' show SecureKeyStore;
import '../../reminders/reminders.dart';
import '../../theme/tokens.dart';
import '../../version.dart';
import '../../widget/home_widget.dart';
import '../icons.dart';
import '../kit.dart';
import 'amount_input.dart';
import 'backup_flow.dart';
import 'binance_page.dart';
import 'capture_rules_page.dart';
import 'capture_settings_page.dart';
import 'code_dialogs.dart';
import 'example_bar.dart';
import 'look.dart';
import 'pay_schedule_editor.dart';
import 'put_away_page.dart';
import 'statement_page.dart';
import 'sync_page.dart';
import 'wallets_page.dart';

/// The person's settings, in the order they look for them: who they are,
/// what the app does by itself, what it is connected to, how it looks, their
/// data and where to get help; deleting everything comes last, apart.
class OwnSettingsPage extends StatelessWidget {
  const OwnSettingsPage({
    super.key,
    required this.own,
    required this.modes,
    required this.settings,
  });

  final OwnController own;
  final AppModeController modes;
  final AppSettings settings;

  String _schedule(AppLocalizations l, PaySchedule s) => switch (s) {
    TwiceMonthly(:final int first, :final int second) => _detailed(
      l.payTwiceMonthly,
      l.payTwiceMonthlyDetail(dayOfMonth(first), dayOfMonth(second)),
    ),
    Monthly(:final int day) => _detailed(
      l.payMonthly,
      l.payMonthlyDetail(dayOfMonth(day)),
    ),
    EveryTwoWeeks() => l.payBiweekly,
    Weekly() => l.payWeekly,
  };

  /// [kind] with its [detail] after a colon, lowercased to follow it:
  /// `Twice a month: the 15th and 30th of each month`. In the editor the
  /// detail starts a line of its own.
  String _detailed(String kind, String detail) =>
      '$kind: ${detail[0].toLowerCase()}${detail.substring(1)}';

  Future<void> _editName(BuildContext context, Profile p) async {
    final String? typed = await showDialog<String>(
      context: context,
      builder: (BuildContext context) => _TextDialog(
        title: context.l10n.settingsName,
        initial: p.name,
        capitalization: TextCapitalization.words,
        // A blank name is not saved: the dialog says so instead of closing
        // as if it had been.
        check: (String text) =>
            text.trim().isEmpty ? context.l10n.settingsNameEmpty : null,
      ),
    );
    if (typed == null || typed.trim().isEmpty) return;
    await own.store.saveProfile(p.copyWith(name: typed.trim()));
  }

  /// Asks for an amount in [base]; an empty one, or "Quitar", forgets it.
  static Future<void> _editAmount(
    BuildContext context, {
    required String title,
    required String body,
    required Decimal? current,
    required Asset base,
    required Future<void> Function(Decimal? value) save,
    String? label,
    String? Function(Decimal? value)? after,
  }) async {
    final String? sign = base.localSymbol ?? base.symbol;
    // Null when cancelled; an empty text forgets the amount.
    final String? typed = await showDialog<String>(
      context: context,
      builder: (BuildContext context) => _TextDialog(
        title: title,
        body: body,
        initial: current == null
            ? ''
            : formatDecimal(current, decimals: base.decimals, trim: true),
        keyboardType: const TextInputType.numberWithOptions(decimal: true),
        formatters: <TextInputFormatter>[
          AmountInputFormatter(maxDecimals: base.decimals),
        ],
        prefix: sign == null ? null : '$sign ',
        suffix: sign == null ? base.code : null,
        label: label,
        hint: context.l10n.settingsAmountHint(
          formatDecimal(Decimal.fromInt(500000), decimals: 0),
        ),
        after: after == null
            ? null
            : (String text) =>
                  after(text.trim().isEmpty ? null : parseAmount(text)),
        canRemove: current != null,
        check: (String text) {
          if (text.trim().isEmpty) return null;
          final Decimal? value = parseAmount(text);
          return value != null && value > Decimal.zero
              ? null
              : context.l10n.settingsAmountAboveZero;
        },
      ),
    );
    if (typed == null) return;
    final Decimal? value = typed.trim().isEmpty ? null : parseAmount(typed);
    if (typed.trim().isNotEmpty && (value == null || value <= Decimal.zero)) {
      return;
    }
    await save(value);
  }

  Future<void> _editBase(BuildContext context, Profile p) async {
    final String lang = Localizations.localeOf(context).languageCode;
    final Asset? picked = await showDialog<Asset>(
      context: context,
      builder: (BuildContext context) => SimpleDialog(
        title: Text(context.l10n.settingsBase),
        children: <Widget>[
          for (final Asset a in Asset.fiat)
            SimpleDialogOption(
              onPressed: () => Navigator.of(context).pop(a),
              child: Row(
                children: <Widget>[
                  Expanded(child: Text('${a.code} · ${a.name(lang)}')),
                  if (a == p.base)
                    Icon(Glyph.check, size: 18, color: context.colors.brand),
                ],
              ),
            ),
        ],
      ),
    );
    if (picked == null || picked == p.base || !context.mounted) return;
    final AppLocalizations l = context.l10n;
    final ScaffoldMessengerState messenger = ScaffoldMessenger.of(context);
    // Everything was said in the old currency: the same money in the new
    // one takes a rate between the two. Without one the numbers would stay
    // and mean another currency, so the person types it or keeps theirs.
    final (Asset asset, Asset quote) = ratePair(p.base, picked);
    Decimal? rate = await own.rateBetween(p.base, picked);
    if (rate == null) {
      if (!context.mounted) return;
      final Decimal? typed = await showDialog<Decimal>(
        context: context,
        builder: (BuildContext context) =>
            _NoRateDialog(from: p.base, to: picked, asset: asset, quote: quote),
      );
      if (typed == null || typed <= Decimal.zero) return;
      await own.store.setManualRate(asset.code, quote.code, typed);
      rate = asset == p.base ? typed : _inverse(typed);
    }
    // The pay and the cushion, with room for the cents a way back needs.
    final Decimal by = rate;
    Decimal? same(Decimal? amount) =>
        amount == null ? null : (amount * by).round(scale: picked.decimals + 6);
    await own.store.saveProfile(
      p.copyWith(base: picked, pay: same(p.pay), cushion: same(p.cushion)),
    );
    // Said at once, with the rate it converted with: the other rates for
    // the new currency come in behind it, from the network.
    final Decimal shown = asset == p.base ? by : _inverse(by);
    messenger.showSnackBar(
      SnackBar(
        content: Text(
          l.settingsBaseConverted(
            picked.code,
            asset.code,
            '${formatDecimal(shown, decimals: quote.decimals > 0 ? 4 : 2, trim: true)} '
            '${quote.code}',
          ),
        ),
      ),
    );
    await own.refreshRates(force: true);
  }

  static Decimal _inverse(Decimal d) =>
      (Decimal.one / d).toDecimal(scaleOnInfinitePrecision: 12);

  Future<void> _editSchedule(BuildContext context, Profile p) async {
    PaySchedule value = p.schedule;
    final PaySchedule? picked = await showModalBottomSheet<PaySchedule>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      useSafeArea: true,
      backgroundColor: context.colors.surface,
      constraints: const BoxConstraints(maxWidth: 560),
      builder: (BuildContext context) => StatefulBuilder(
        builder: (BuildContext context, StateSetter setState) =>
            SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: <Widget>[
                  Text(
                    context.l10n.settingsPay,
                    style: context.type.headlineMedium,
                  ),
                  const SizedBox(height: 16),
                  PayScheduleEditor(
                    value: value,
                    today: own.today,
                    onChanged: (PaySchedule s) => setState(() => value = s),
                  ),
                  const SizedBox(height: 20),
                  FilledButton(
                    onPressed: () => Navigator.of(context).pop(value),
                    child: Text(context.l10n.save),
                  ),
                ],
              ),
            ),
      ),
    );
    if (picked == null) return;
    await own.store.saveProfile(p.copyWith(schedule: picked));
  }

  Future<void> _export(BuildContext context) async {
    if (await explainExample(context, own, context.l10n.exportData)) return;
    if (!context.mounted) return;
    await exportData(context, backups: Backups(own.store), today: own.today);
  }

  Future<void> _exportCsv(BuildContext context) async {
    if (await explainExample(context, own, context.l10n.exportCsv)) return;
    if (!context.mounted) return;
    await exportMovements(context, store: own.store, today: own.today);
  }

  Future<void> _restore(BuildContext context) async {
    if (await explainExample(context, own, context.l10n.importData)) return;
    if (!context.mounted) return;
    return restoreBackup(
      context,
      backups: Backups(own.store),
      today: own.today,
      after: () => own.refreshRates(force: true),
    );
  }

  Future<void> _deleteAll(BuildContext context) async {
    final AppLocalizations l = context.l10n;
    if (await explainExample(context, own, l.deleteAll)) return;
    if (!context.mounted) return;
    final NavigatorState navigator = Navigator.of(context);
    final ModalRoute<Object?>? page = ModalRoute.of(context);
    final Backups backups = Backups(own.store);
    // What brings the data back afterwards, and a way to keep it first:
    // saving comes back to the same question.
    while (true) {
      final String? code = await backups.code();
      if (!context.mounted) return;
      final _Delete? choice = await showDialog<_Delete>(
        context: context,
        builder: (BuildContext context) => _DeleteAllDialog(code: code),
      );
      if (choice != _Delete.backupFirst) {
        if (choice != _Delete.delete) return;
        break;
      }
      if (!context.mounted) return;
      await exportData(context, backups: backups, today: own.today);
    }
    // A Binance key lives in the keychain, apart from the data: it goes
    // first, through the link that kept it.
    if (BinanceLink.available) {
      try {
        await own.binance.disconnect();
      } on Object {
        // No keychain here, so no key either.
      }
    }
    await own.store.wipe();
    // The reminders the phone keeps name the person's payments: none stays.
    await Reminders.cancel();
    // The sync and backup keys live in the keychain too. Backups already
    // made still open with their code.
    try {
      await SecureKeyStore().delete();
    } on Object {
      // No keychain here, so no key either.
    }
    await backups.forget();
    navigator.popUntil((Route<void> r) => r.isFirst);
    await modes.wiped();
    // The theme and the language went with the rest: once this page is gone,
    // the app looks as the phone does, as it will when it opens next. Not
    // before, while it still draws the accounts it showed.
    if (page != null) await page.completed;
    settings.forget();
  }

  /// Opens [page], or in the example says why [title] is not there.
  Future<void> _open(
    BuildContext context,
    String title,
    WidgetBuilder page,
  ) async {
    if (await explainExample(context, own, title)) return;
    if (!context.mounted) return;
    await Navigator.of(context).push(MaterialPageRoute<void>(builder: page));
  }

  Widget _row(
    BuildContext context, {
    required IconData icon,
    required String title,
    String? value,
    VoidCallback? onTap,
    Color? color,
  }) => InkWell(
    onTap: onTap,
    child: Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 9),
      child: Row(
        children: <Widget>[
          SizedBox(
            width: 40,
            child: Icon(icon, size: 22, color: color ?? context.colors.inkSoft),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  title,
                  style: context.type.titleSmall?.copyWith(color: color),
                ),
                if (value != null) Text(value, style: context.type.bodySmall),
              ],
            ),
          ),
          if (onTap != null)
            Icon(Glyph.caretRight, size: 16, color: context.colors.inkFaint),
        ],
      ),
    ),
  );

  /// A row of choices, or a few lines, under a title of its own: two rows
  /// of buttons that both start with «Sistema» read apart by their titles.
  Widget _titled(BuildContext context, String title, Widget child) => Padding(
    padding: const EdgeInsets.fromLTRB(16, 10, 16, 12),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        Text(title, style: context.type.titleSmall),
        const SizedBox(height: 8),
        child,
      ],
    ),
  );

  /// Asks the phone for the payday reminder; turned down, says where to
  /// allow it, with a way there.
  Future<void> _remind(BuildContext context, bool on) async {
    final AppLocalizations l = context.l10n;
    final ScaffoldMessengerState messenger = ScaffoldMessenger.of(context);
    if (await explainExample(context, own, l.remindersTitle)) return;
    final bool done = await own.remindClose(
      on,
      title: l.reminderTitle,
      body: l.reminderBody,
    );
    if (done) return;
    messenger.showSnackBar(
      SnackBar(
        content: Text(l.remindersDenied),
        action: AppSettingsPage.available
            ? SnackBarAction(
                label: l.openPhoneSettings,
                onPressed: AppSettingsPage.open,
              )
            : null,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: Listenable.merge(<Listenable>[own, settings]),
      builder: (BuildContext context, _) {
        final AppLocalizations l = context.l10n;
        final Profile? p = own.profile;
        final String lang = Localizations.localeOf(context).languageCode;
        // Laid out the way the person looks for things: who they are, what
        // the app does by itself, what it is connected to, how it looks,
        // their data, help, and last, apart, what cannot be undone.
        return Scaffold(
          appBar: AppBar(
            backgroundColor: context.colors.canvas,
            surfaceTintColor: Colors.transparent,
            title: Text(l.settingsTitle, style: context.type.titleLarge),
          ),
          body: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 640),
              child: ListView(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
                children: <Widget>[
                  if (own.example) ..._example(context),
                  if (p != null) ..._profile(context, p),
                  ..._automation(context),
                  ..._connected(context),
                  ..._appearance(context),
                  ..._data(context),
                  ..._help(context, lang),
                  Panel(
                    children: <Widget>[
                      _row(
                        context,
                        icon: Glyph.trash,
                        title: l.deleteAll,
                        color: context.colors.negative,
                        onTap: () => _deleteAll(context),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  /// Whose example this is, and the ways out of it.
  List<Widget> _example(BuildContext context) {
    final AppLocalizations l = context.l10n;
    return <Widget>[
      SectionLabel(l.exampleSection),
      Text(
        l.exampleAboutBody(own.profile?.name ?? ''),
        style: context.type.bodySmall,
      ),
      // Where the build keeps no accounts of the person's, there is
      // nowhere else to go.
      if (modes.canUseOwn) ...<Widget>[
        const SizedBox(height: 8),
        Panel(
          children: <Widget>[
            _row(
              context,
              icon: Glyph.wallet,
              title: l.exampleUseOwn,
              onTap: () => ExampleScope.of(context)?.onUseOwn?.call(),
            ),
            if (modes.hasStart)
              _row(
                context,
                icon: Glyph.arrowLeft,
                title: l.exampleBackToStart,
                onTap: () {
                  Navigator.of(context).popUntil((Route<void> r) => r.isFirst);
                  modes.backToStart();
                },
              ),
          ],
        ),
      ],
      const SizedBox(height: 16),
    ];
  }

  List<Widget> _profile(BuildContext context, Profile p) {
    final AppLocalizations l = context.l10n;
    final String lang = Localizations.localeOf(context).languageCode;
    return <Widget>[
      SectionLabel(l.settingsProfile),
      Panel(
        children: <Widget>[
          _row(
            context,
            icon: Glyph.user,
            title: l.settingsName,
            value: p.name,
            onTap: () => _editName(context, p),
          ),
          _row(
            context,
            icon: Glyph.coins,
            title: l.settingsBase,
            value: '${p.base.code} · ${p.base.name(lang)}',
            onTap: () => _editBase(context, p),
          ),
          _row(
            context,
            icon: Glyph.calendarBlank,
            title: l.settingsPay,
            value: _schedule(l, p.schedule),
            onTap: () => _editSchedule(context, p),
          ),
          _row(
            context,
            icon: Glyph.money,
            title: l.settingsPayAmount,
            value: p.pay == null
                ? l.settingsNotSet
                : moneyText(Money(p.pay!, p.base), base: p.base),
            onTap: () => _editAmount(
              context,
              title: l.settingsPayAmount,
              body: l.settingsPayAmountBody,
              current: p.pay,
              base: p.base,
              save: (Decimal? v) => own.store.saveProfile(
                p.copyWith(pay: v, clearPay: v == null),
              ),
            ),
          ),
          _row(
            context,
            icon: Glyph.piggyBank,
            title: l.settingsCushion,
            value: p.cushion == null
                ? l.settingsNotSet
                : moneyText(Money(p.cushion!, p.base), base: p.base),
            onTap: () => _editAmount(
              context,
              title: l.settingsCushion,
              body: l.settingsCushionBody,
              current: p.cushion,
              base: p.base,
              label: l.settingsCushionField,
              // Said before saving: what can be spent until payday with it.
              after: (Decimal? v) {
                final Ledger? ledger = own.ledger;
                if (ledger == null) return null;
                final int free =
                    ledger.freeUntilPayday +
                    ledger.cushion -
                    (v == null ? 0 : ledger.minor(v.toDouble()));
                final String payday = dayMonth(ledger.nextPayday);
                return free >= 0
                    ? l.settingsCushionAfter(pesos(ledger.major(free)), payday)
                    : l.settingsCushionShort(
                        pesos(ledger.major(-free)),
                        payday,
                      );
              },
              save: (Decimal? v) => own.store.saveProfile(
                p.copyWith(cushion: v, clearCushion: v == null),
              ),
            ),
          ),
        ],
      ),
      const SizedBox(height: 16),
    ];
  }

  /// What the app does by itself: payments that arrive, what it learned
  /// from them, and the reminder on payday.
  List<Widget> _automation(BuildContext context) {
    final AppLocalizations l = context.l10n;
    return <Widget>[
      SectionLabel(l.settingsAutomation),
      Panel(
        children: <Widget>[
          _row(
            context,
            icon: Glyph.bell,
            title: l.captureTitle,
            value: l.captureSubtitle,
            onTap: () => _open(
              context,
              l.captureTitle,
              (BuildContext context) => CaptureSettingsPage(own: own),
            ),
          ),
          _row(
            context,
            icon: Glyph.listBullets,
            title: l.rulesTitle,
            value: l.rulesCount(own.captureSettings.rules.length),
            onTap: () => _open(
              context,
              l.rulesTitle,
              (BuildContext context) => CaptureRulesPage(own: own),
            ),
          ),
          if (Reminders.supported)
            SwitchListTile(
              value: own.remindsClose,
              onChanged: (bool on) => _remind(context, on),
              // Its icon lines it up with the rows above; with large text
              // the words beside the switch need that room more.
              secondary: largeText(context)
                  ? null
                  : SizedBox(
                      width: 40,
                      child: Icon(
                        Glyph.calendarCheck,
                        size: 22,
                        color: context.colors.inkSoft,
                      ),
                    ),
              minLeadingWidth: 40,
              horizontalTitleGap: 12,
              visualDensity: VisualDensity.compact,
              title: Text(l.remindersClose, style: context.type.titleSmall),
              subtitle: Text(
                l.remindersCloseHelp,
                style: context.type.bodySmall,
              ),
            ),
        ],
      ),
      const SizedBox(height: 16),
    ];
  }

  /// What keeps balances up to date from outside: an exchange and the
  /// wallets followed by their address.
  List<Widget> _connected(BuildContext context) {
    final AppLocalizations l = context.l10n;
    return <Widget>[
      SectionLabel(l.settingsConnected),
      Panel(
        children: <Widget>[
          if (BinanceLink.available)
            _row(
              context,
              icon: Glyph.currencyBtc,
              title: l.binanceTitle,
              value: own.example
                  ? l.exampleNotConnected
                  : own.binance.connected
                  ? l.binanceConnected
                  : l.binanceCardBody,
              onTap: () => _open(
                context,
                l.binanceTitle,
                (BuildContext context) => BinancePage(own: own),
              ),
            ),
          _row(
            context,
            icon: Glyph.vault,
            title: l.walletsTitle,
            value: own.example ? l.exampleNotConnected : l.walletsCardBody,
            onTap: () => _open(
              context,
              l.walletsTitle,
              (BuildContext context) => WalletsPage(own: own),
            ),
          ),
        ],
      ),
      const SizedBox(height: 16),
    ];
  }

  /// The theme and the language, each under its title, and the widget on
  /// the home screen.
  List<Widget> _appearance(BuildContext context) {
    final AppLocalizations l = context.l10n;
    // With large text one choice under the other, each word whole.
    final Axis direction = largeText(context) ? Axis.vertical : Axis.horizontal;
    return <Widget>[
      SectionLabel(l.appearance),
      Panel(
        indent: 16,
        children: <Widget>[
          _titled(
            context,
            l.themeTitle,
            SegmentedButton<ThemeMode>(
              segments: <ButtonSegment<ThemeMode>>[
                ButtonSegment<ThemeMode>(
                  value: ThemeMode.system,
                  // Heard apart from the language's «Sistema».
                  label: Text(
                    l.themeSystem,
                    semanticsLabel: l.actionOn(l.themeTitle, l.themeSystem),
                  ),
                ),
                ButtonSegment<ThemeMode>(
                  value: ThemeMode.light,
                  label: Text(l.themeLight),
                ),
                ButtonSegment<ThemeMode>(
                  value: ThemeMode.dark,
                  label: Text(l.themeDark),
                ),
              ],
              selected: <ThemeMode>{settings.themeMode},
              showSelectedIcon: false,
              direction: direction,
              onSelectionChanged: (Set<ThemeMode> s) =>
                  settings.themeMode = s.first,
            ),
          ),
          _titled(
            context,
            l.language,
            SegmentedButton<String>(
              segments: <ButtonSegment<String>>[
                ButtonSegment<String>(
                  value: '',
                  label: Text(
                    l.languageSystem,
                    semanticsLabel: l.actionOn(l.language, l.languageSystem),
                  ),
                ),
                const ButtonSegment<String>(
                  value: 'es',
                  label: Text('Español'),
                ),
                const ButtonSegment<String>(
                  value: 'en',
                  label: Text('English'),
                ),
              ],
              selected: <String>{settings.locale?.languageCode ?? ''},
              showSelectedIcon: false,
              direction: direction,
              onSelectionChanged: (Set<String> s) =>
                  settings.locale = s.first.isEmpty ? null : Locale(s.first),
            ),
          ),
          if (HomeWidget.available) ...<Widget>[
            _titled(
              context,
              l.widgetSection,
              Text(l.widgetHow, style: context.type.bodySmall),
            ),
            SwitchListTile(
              value: own.widgetHidesAmounts,
              onChanged: (bool hide) async {
                if (await explainExample(context, own, l.widgetSection)) {
                  return;
                }
                await own.hideWidgetAmounts(hide);
              },
              title: Text(l.widgetHide, style: context.type.titleSmall),
              subtitle: Text(l.widgetHideHelp, style: context.type.bodySmall),
            ),
            if (canPinWidget)
              _row(
                context,
                icon: Glyph.plus,
                title: l.widgetAdd,
                onTap: () async {
                  final ScaffoldMessengerState messenger = ScaffoldMessenger.of(
                    context,
                  );
                  if (await explainExample(context, own, l.widgetSection)) {
                    return;
                  }
                  if (!await pinWidget()) {
                    messenger.showSnackBar(
                      SnackBar(content: Text(l.widgetAddFailed)),
                    );
                  }
                },
              ),
          ],
        ],
      ),
      const SizedBox(height: 16),
    ];
  }

  /// Everything about the person's data: bringing it in, carrying it to
  /// another device, keeping a copy and bringing one back.
  List<Widget> _data(BuildContext context) {
    final AppLocalizations l = context.l10n;
    return <Widget>[
      SectionLabel(l.settingsData),
      Panel(
        children: <Widget>[
          _row(
            context,
            icon: Glyph.fileText,
            title: l.statementTitle,
            value: l.statementSubtitle,
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute<void>(
                builder: (BuildContext context) => StatementPage(
                  own: own,
                  // The example counts nothing in the person's own day of
                  // questions.
                  allowance: own.example ? null : modes.allowance,
                ),
              ),
            ),
          ),
          _row(
            context,
            icon: Glyph.deviceMobile,
            title: l.syncTitle,
            value: l.syncRow,
            onTap: () => _open(
              context,
              l.syncTitle,
              (BuildContext context) => SyncPage(own: own),
            ),
          ),
          _row(
            context,
            icon: Glyph.downloadSimple,
            title: l.exportData,
            value: l.exportDataSubtitle,
            onTap: () => _export(context),
          ),
          _row(
            context,
            icon: Glyph.squaresFour,
            title: l.exportCsv,
            value: l.exportCsvSubtitle,
            onTap: () => _exportCsv(context),
          ),
          _row(
            context,
            icon: Glyph.arrowCounterClockwise,
            title: l.importData,
            value: l.importDataSubtitle,
            onTap: () => _restore(context),
          ),
          _row(
            context,
            icon: Glyph.archive,
            title: l.putAwayTitle,
            value: l.putAwayRow,
            onTap: () => openPutAway(context, own),
          ),
          if (!own.example)
            _row(
              context,
              icon: Glyph.sparkle,
              title: l.useDemo,
              onTap: () {
                Navigator.of(context).popUntil((Route<void> r) => r.isFirst);
                modes.useDemo();
              },
            ),
        ],
      ),
      const SizedBox(height: 16),
    ];
  }

  /// Where to ask for help, what happens with the data, and whose work the
  /// app stands on.
  List<Widget> _help(BuildContext context, String lang) {
    final AppLocalizations l = context.l10n;
    return <Widget>[
      SectionLabel(l.settingsHelp),
      Text(l.privacyBody, style: context.type.bodyMedium),
      const SizedBox(height: 8),
      Panel(
        children: <Widget>[
          _row(
            context,
            icon: Glyph.envelope,
            title: l.supportTitle,
            value: 'admin@dlsoft.dev',
            onTap: () => launchUrl(
              Uri.parse(
                lang == 'en'
                    ? 'https://diegolopezrm.github.io/quincena/support/'
                    : 'https://diegolopezrm.github.io/quincena/soporte/',
              ),
              mode: LaunchMode.externalApplication,
            ),
          ),
          _row(
            context,
            icon: Glyph.lock,
            title: l.privacyPolicy,
            onTap: () => launchUrl(
              Uri.parse(
                lang == 'en'
                    ? 'https://diegolopezrm.github.io/quincena/privacy/'
                    : 'https://diegolopezrm.github.io/quincena/privacidad/',
              ),
              mode: LaunchMode.externalApplication,
            ),
          ),
          _row(
            context,
            icon: Glyph.fileText,
            title: l.licensesTitle,
            onTap: () => showLicensePage(
              context: context,
              applicationName: 'Quincena',
              applicationVersion: appVersion,
              applicationLegalese: l.licensesLegalese,
            ),
          ),
        ],
      ),
      const SizedBox(height: 16),
    ];
  }
}

/// Asks what arrives each payday, as Ajustes does, from wherever else the
/// person is offered to say it.
Future<void> askPayAmount(BuildContext context, OwnController own) async {
  final Profile? p = own.profile;
  if (p == null) return;
  final AppLocalizations l = context.l10n;
  await OwnSettingsPage._editAmount(
    context,
    title: l.settingsPayAmount,
    body: l.settingsPayAmountBody,
    current: p.pay,
    base: p.base,
    save: (Decimal? v) =>
        own.store.saveProfile(p.copyWith(pay: v, clearPay: v == null)),
  );
}

/// Asks for the cushion, as Ajustes does, from wherever else the person is
/// offered to set it.
Future<void> askCushion(BuildContext context, OwnController own) async {
  final Profile? p = own.profile;
  if (p == null) return;
  final AppLocalizations l = context.l10n;
  await OwnSettingsPage._editAmount(
    context,
    title: l.settingsCushion,
    body: l.settingsCushionBody,
    current: p.cushion,
    base: p.base,
    save: (Decimal? v) =>
        own.store.saveProfile(p.copyWith(cushion: v, clearCushion: v == null)),
  );
}

enum _Delete { delete, backupFirst }

/// Before everything goes: what it takes to get it back, the backup code
/// the phone is about to forget, and a way to save a backup first.
class _DeleteAllDialog extends StatelessWidget {
  const _DeleteAllDialog({required this.code});

  /// This phone's backup code, when it has one.
  final String? code;

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l = context.l10n;
    final String? code = this.code;
    return AlertDialog(
      scrollable: true,
      title: Text(l.deleteAllTitle),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Text(l.deleteAllBody, style: context.type.bodyMedium),
          const SizedBox(height: 12),
          Text(l.deleteAllRecover, style: context.type.bodyMedium),
          if (code != null) ...<Widget>[
            const SizedBox(height: 12),
            Text(l.deleteAllForgetsCode, style: context.type.bodyMedium),
            Align(
              alignment: Alignment.centerLeft,
              child: TextButton.icon(
                onPressed: () => showCode(
                  context,
                  code: code,
                  title: l.backupYourCode,
                  keep: l.backupCodeKeep,
                  share: l.backupCodeShareText(code),
                ),
                style: TextButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                ),
                icon: const Icon(Glyph.lock, size: 18),
                label: Text(l.backupShowCode),
              ),
            ),
          ],
          const SizedBox(height: 12),
          OutlinedButton.icon(
            onPressed: () => Navigator.of(context).pop(_Delete.backupFirst),
            icon: const Icon(Glyph.downloadSimple, size: 18),
            label: Text(l.deleteAllBackupFirst),
          ),
        ],
      ),
      actions: <Widget>[
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(l.cancel),
        ),
        TextButton(
          onPressed: () => Navigator.of(context).pop(_Delete.delete),
          style: TextButton.styleFrom(foregroundColor: context.colors.negative),
          child: Text(l.deleteAll),
        ),
      ],
    );
  }
}

/// The pair a person says a rate in: the dollar, the euro or the pound in
/// the other currency; between two others, the new one in the old.
(Asset, Asset) ratePair(Asset from, Asset to) {
  const Set<String> anchors = <String>{'GBP', 'EUR', 'USD', 'CHF', 'CAD'};
  if (anchors.contains(from.code) && !anchors.contains(to.code)) {
    return (from, to);
  }
  return (to, from);
}

/// Asks what one [asset] is worth in [quote] when no source has the rate
/// from [from] to [to], or lets the person keep [from].
class _NoRateDialog extends StatefulWidget {
  const _NoRateDialog({
    required this.from,
    required this.to,
    required this.asset,
    required this.quote,
  });

  final Asset from;
  final Asset to;
  final Asset asset;
  final Asset quote;

  @override
  State<_NoRateDialog> createState() => _NoRateDialogState();
}

class _NoRateDialogState extends State<_NoRateDialog> {
  final TextEditingController _value = TextEditingController();
  bool _missing = false;

  @override
  void dispose() {
    _value.dispose();
    super.dispose();
  }

  void _change() {
    final Decimal? typed = parseAmount(_value.text);
    if (typed == null || typed <= Decimal.zero) {
      setState(() => _missing = true);
      return;
    }
    Navigator.of(context).pop(typed);
  }

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l = context.l10n;
    return AlertDialog(
      scrollable: true,
      title: Text(
        l.settingsBaseNoRateTitle(widget.asset.code, widget.quote.code),
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Text(
            l.settingsBaseNoRateBody(widget.from.code, widget.to.code),
            style: context.type.bodyMedium,
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _value,
            autofocus: true,
            inputFormatters: <TextInputFormatter>[
              AmountInputFormatter(maxDecimals: 8),
            ],
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            onChanged: (_) {
              if (_missing) setState(() => _missing = false);
            },
            decoration: InputDecoration(
              labelText: l.settingsBaseRate(widget.asset.code),
              suffixText: widget.quote.code,
              errorText: _missing ? l.settingsBaseRateMissing : null,
            ),
          ),
        ],
      ),
      actions: <Widget>[
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(l.settingsBaseKeep(widget.from.code)),
        ),
        TextButton(
          onPressed: _change,
          child: Text(l.settingsBaseChange(widget.to.code)),
        ),
      ],
    );
  }
}

/// Asks for one line of text. It owns its controller, so the field can
/// still draw while the dialog closes.
class _TextDialog extends StatefulWidget {
  const _TextDialog({
    required this.title,
    required this.initial,
    this.body,
    this.capitalization = TextCapitalization.none,
    this.keyboardType,
    this.formatters,
    this.prefix,
    this.suffix,
    this.canRemove = false,
    this.check,
    this.label,
    this.hint,
    this.after,
  });

  final String title;
  final String initial;
  final String? body;

  /// What the field asks, above it, and an example inside it while empty.
  final String? label;
  final String? hint;

  /// What saving the text would do, said under the field as it is typed;
  /// null when there is nothing to say.
  final String? Function(String text)? after;
  final TextCapitalization capitalization;
  final TextInputType? keyboardType;
  final List<TextInputFormatter>? formatters;
  final String? prefix;
  final String? suffix;

  /// Offers "Quitar", which answers with an empty text.
  final bool canRemove;

  /// What is wrong with the text typed, said under the field instead of
  /// saving it; null when it can be saved.
  final String? Function(String text)? check;

  @override
  State<_TextDialog> createState() => _TextDialogState();
}

class _TextDialogState extends State<_TextDialog> {
  late final TextEditingController _text = TextEditingController(
    text: widget.initial,
  );
  String? _error;

  @override
  void dispose() {
    _text.dispose();
    super.dispose();
  }

  void _save() {
    final String? error = widget.check?.call(_text.text);
    if (error != null) {
      setState(() => _error = error);
      return;
    }
    Navigator.of(context).pop(_text.text);
  }

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l = context.l10n;
    return AlertDialog(
      scrollable: true,
      title: Text(widget.title),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          if (widget.body case final String body) ...<Widget>[
            Text(body, style: context.type.bodyMedium),
            const SizedBox(height: 12),
          ],
          TextField(
            controller: _text,
            autofocus: true,
            textCapitalization: widget.capitalization,
            keyboardType: widget.keyboardType,
            inputFormatters: widget.formatters,
            decoration: InputDecoration(
              labelText: widget.label,
              hintText: widget.hint,
              prefixText: widget.prefix,
              suffixText: widget.suffix,
              errorText: _error,
              errorMaxLines: 3,
            ),
            onChanged: (_) => setState(() => _error = null),
            onSubmitted: (_) => _save(),
          ),
          if (widget.after?.call(_text.text) case final String after) ...[
            const SizedBox(height: 12),
            Text(after, style: context.type.bodySmall),
          ],
        ],
      ),
      actions: <Widget>[
        if (widget.canRemove)
          TextButton(
            onPressed: () => Navigator.of(context).pop(''),
            child: Text(l.settingsRemove),
          ),
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(l.cancel),
        ),
        TextButton(onPressed: _save, child: Text(l.save)),
      ],
    );
  }
}
