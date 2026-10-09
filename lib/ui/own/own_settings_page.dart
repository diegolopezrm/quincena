import 'package:decimal/decimal.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../app.dart';
import '../../app_mode.dart';
import '../../backup/backup.dart';
import '../../domain/pay_schedule.dart';
import '../../domain/records.dart';
import '../../exchanges/binance_link.dart';
import '../../format/dates.dart';
import '../../l10n/l10n.dart';
import '../../money/asset.dart';
import '../../money/money.dart';
import '../../own/own_controller.dart';
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
import 'capture_settings_page.dart';
import 'example_bar.dart';
import 'look.dart';
import 'pay_schedule_editor.dart';
import 'statement_page.dart';
import 'sync_page.dart';
import 'wallets_page.dart';

/// The person's profile, appearance, and what they can do with their data.
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
      ),
    );
    if (typed == null || typed.trim().isEmpty) return;
    await own.store.saveProfile(p.copyWith(name: typed.trim()));
  }

  /// Asks for an amount in [base]; an empty one, or "Quitar", forgets it.
  Future<void> _editAmount(
    BuildContext context, {
    required String title,
    required String body,
    required Decimal? current,
    required Asset base,
    required Future<void> Function(Decimal? value) save,
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
    if (picked == null || picked == p.base) return;
    // The pay and the cushion were said in the old currency: the same money
    // in the new one, with room for the cents a way back needs. With no rate
    // between the two they stay as they were.
    final Decimal? rate = p.pay == null && p.cushion == null
        ? null
        : await own.rateBetween(p.base, picked);
    Decimal? same(Decimal? amount) => amount == null || rate == null
        ? amount
        : (amount * rate).round(scale: picked.decimals + 6);
    await own.store.saveProfile(
      p.copyWith(base: picked, pay: same(p.pay), cushion: same(p.cushion)),
    );
    await own.refreshRates(force: true);
  }

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

  Future<void> _import(BuildContext context) async {
    final AppLocalizations l = context.l10n;
    if (await explainExample(context, own, l.importData)) return;
    if (!context.mounted) return;
    return importData(
      context,
      backups: Backups(own.store),
      confirm: () => _confirm(
        context,
        title: l.importConfirmTitle,
        body: l.importConfirmBody,
        action: l.importConfirm,
      ),
      after: () => own.refreshRates(force: true),
    );
  }

  Future<void> _deleteAll(BuildContext context) async {
    final AppLocalizations l = context.l10n;
    if (await explainExample(context, own, l.deleteAll)) return;
    if (!context.mounted) return;
    final NavigatorState navigator = Navigator.of(context);
    final ModalRoute<Object?>? page = ModalRoute.of(context);
    final bool? sure = await _confirm(
      context,
      title: l.deleteAllTitle,
      body: l.deleteAllBody,
      action: l.deleteAll,
      destructive: true,
    );
    if (sure != true) return;
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
    await Backups(own.store).forget();
    navigator.popUntil((Route<void> r) => r.isFirst);
    await modes.wiped();
    // The theme and the language went with the rest: once this page is gone,
    // the app looks as the phone does, as it will when it opens next. Not
    // before, while it still draws the accounts it showed.
    if (page != null) await page.completed;
    settings.forget();
  }

  Future<bool?> _confirm(
    BuildContext context, {
    required String title,
    required String body,
    required String action,
    bool destructive = false,
  }) => showDialog<bool>(
    context: context,
    builder: (BuildContext context) => AlertDialog(
      title: Text(title),
      content: Text(body),
      actions: <Widget>[
        TextButton(
          onPressed: () => Navigator.of(context).pop(false),
          child: Text(context.l10n.cancel),
        ),
        TextButton(
          onPressed: () => Navigator.of(context).pop(true),
          style: destructive
              ? TextButton.styleFrom(foregroundColor: context.colors.negative)
              : null,
          child: Text(action),
        ),
      ],
    ),
  );

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
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
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

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: Listenable.merge(<Listenable>[own, settings]),
      builder: (BuildContext context, _) {
        final AppLocalizations l = context.l10n;
        final Profile? p = own.profile;
        final String lang = Localizations.localeOf(context).languageCode;
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
                  if (own.example) ...<Widget>[
                    SectionLabel(l.exampleSection),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 4),
                      child: Text(
                        l.exampleAboutBody(p?.name ?? ''),
                        style: context.type.bodySmall,
                      ),
                    ),
                    // Where the build keeps no accounts of the person's,
                    // there is nowhere else to go.
                    if (modes.canUseOwn) ...<Widget>[
                      const SizedBox(height: 8),
                      Panel(
                        children: <Widget>[
                          _row(
                            context,
                            icon: Glyph.wallet,
                            title: l.exampleUseOwn,
                            onTap: () =>
                                ExampleScope.of(context)?.onUseOwn?.call(),
                          ),
                          if (modes.hasStart)
                            _row(
                              context,
                              icon: Glyph.arrowLeft,
                              title: l.exampleBackToStart,
                              onTap: () {
                                Navigator.of(
                                  context,
                                ).popUntil((Route<void> r) => r.isFirst);
                                modes.backToStart();
                              },
                            ),
                        ],
                      ),
                    ],
                    const SizedBox(height: 24),
                  ],
                  if (p != null) ...<Widget>[
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
                              : moneyText(
                                  Money(p.cushion!, p.base),
                                  base: p.base,
                                ),
                          onTap: () => _editAmount(
                            context,
                            title: l.settingsCushion,
                            body: l.settingsCushionBody,
                            current: p.cushion,
                            base: p.base,
                            save: (Decimal? v) => own.store.saveProfile(
                              p.copyWith(cushion: v, clearCushion: v == null),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 24),
                  ],
                  if (Reminders.supported) ...<Widget>[
                    SectionLabel(l.remindersTitle),
                    Panel(
                      children: <Widget>[
                        SwitchListTile(
                          value: own.remindsClose,
                          onChanged: (bool on) async {
                            final ScaffoldMessengerState messenger =
                                ScaffoldMessenger.of(context);
                            if (await explainExample(
                              context,
                              own,
                              l.remindersTitle,
                            )) {
                              return;
                            }
                            final bool done = await own.remindClose(
                              on,
                              title: l.reminderTitle,
                              body: l.reminderBody,
                            );
                            if (!done) {
                              messenger.showSnackBar(
                                SnackBar(content: Text(l.remindersDenied)),
                              );
                            }
                          },
                          title: Text(
                            l.remindersClose,
                            style: context.type.titleSmall,
                          ),
                          subtitle: Text(
                            l.remindersCloseHelp,
                            style: context.type.bodySmall,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 24),
                  ],
                  if (HomeWidget.available) ...<Widget>[
                    SectionLabel(l.widgetSection),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 4),
                      child: Text(l.widgetHow, style: context.type.bodySmall),
                    ),
                    const SizedBox(height: 8),
                    Panel(
                      children: <Widget>[
                        SwitchListTile(
                          value: own.widgetHidesAmounts,
                          onChanged: (bool hide) async {
                            if (await explainExample(
                              context,
                              own,
                              l.widgetSection,
                            )) {
                              return;
                            }
                            await own.hideWidgetAmounts(hide);
                          },
                          title: Text(
                            l.widgetHide,
                            style: context.type.titleSmall,
                          ),
                          subtitle: Text(
                            l.widgetHideHelp,
                            style: context.type.bodySmall,
                          ),
                        ),
                        if (canPinWidget)
                          _row(
                            context,
                            icon: Glyph.plus,
                            title: l.widgetAdd,
                            onTap: () async {
                              final ScaffoldMessengerState messenger =
                                  ScaffoldMessenger.of(context);
                              if (await explainExample(
                                context,
                                own,
                                l.widgetSection,
                              )) {
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
                    ),
                    const SizedBox(height: 24),
                  ],
                  SectionLabel(l.captureTitle),
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
                          (BuildContext context) =>
                              CaptureSettingsPage(own: own),
                        ),
                      ),
                      _row(
                        context,
                        icon: Glyph.vault,
                        title: l.walletsTitle,
                        value: own.example
                            ? l.exampleNotConnected
                            : l.walletsCardBody,
                        onTap: () => _open(
                          context,
                          l.walletsTitle,
                          (BuildContext context) => WalletsPage(own: own),
                        ),
                      ),
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
                    ],
                  ),
                  const SizedBox(height: 24),
                  SectionLabel(l.appearance),
                  Panel(
                    padding: const EdgeInsets.all(16),
                    children: <Widget>[
                      // One row: the two choices belong together.
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: <Widget>[
                          SegmentedButton<ThemeMode>(
                            segments: <ButtonSegment<ThemeMode>>[
                              ButtonSegment<ThemeMode>(
                                value: ThemeMode.system,
                                label: Text(l.themeSystem),
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
                            // With large text one choice under the other,
                            // each word whole.
                            direction: largeText(context)
                                ? Axis.vertical
                                : Axis.horizontal,
                            onSelectionChanged: (Set<ThemeMode> s) =>
                                settings.themeMode = s.first,
                          ),
                          const SizedBox(height: 12),
                          SegmentedButton<String>(
                            segments: <ButtonSegment<String>>[
                              ButtonSegment<String>(
                                value: '',
                                label: Text(l.languageSystem),
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
                            selected: <String>{
                              settings.locale?.languageCode ?? '',
                            },
                            showSelectedIcon: false,
                            direction: largeText(context)
                                ? Axis.vertical
                                : Axis.horizontal,
                            onSelectionChanged: (Set<String> s) =>
                                settings.locale = s.first.isEmpty
                                ? null
                                : Locale(s.first),
                          ),
                        ],
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),
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
                              // The example counts nothing in the person's
                              // own day of questions.
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
                        onTap: () => _export(context),
                      ),
                      _row(
                        context,
                        icon: Glyph.uploadSimple,
                        title: l.importData,
                        onTap: () => _import(context),
                      ),
                      if (!own.example)
                        _row(
                          context,
                          icon: Glyph.sparkle,
                          title: l.useDemo,
                          onTap: () {
                            Navigator.of(
                              context,
                            ).popUntil((Route<void> r) => r.isFirst);
                            modes.useDemo();
                          },
                        ),
                      _row(
                        context,
                        icon: Glyph.trash,
                        title: l.deleteAll,
                        color: context.colors.negative,
                        onTap: () => _deleteAll(context),
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),
                  SectionLabel(l.privacyTitle),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 4),
                    child: Text(l.privacyBody, style: context.type.bodyMedium),
                  ),
                  const SizedBox(height: 12),
                  Panel(
                    children: <Widget>[
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
                ],
              ),
            ),
          ),
        );
      },
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
  });

  final String title;
  final String initial;
  final String? body;
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
              prefixText: widget.prefix,
              suffixText: widget.suffix,
              errorText: _error,
              errorMaxLines: 3,
            ),
            onChanged: (_) {
              if (_error != null) setState(() => _error = null);
            },
            onSubmitted: (_) => _save(),
          ),
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
