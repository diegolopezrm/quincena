import 'dart:convert';
import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';

import '../../app.dart';
import '../../app_mode.dart';
import '../../domain/pay_schedule.dart';
import '../../domain/records.dart';
import '../../exchanges/binance_link.dart';
import '../../l10n/l10n.dart';
import '../../money/asset.dart';
import '../../own/own_controller.dart';
import '../../theme/tokens.dart';
import '../icons.dart';
import 'binance_page.dart';
import 'capture_settings_page.dart';
import 'look.dart';
import 'pay_schedule_editor.dart';

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
    TwiceMonthly(:final int first, :final int second) =>
      '${l.payTwiceMonthly}: ${l.payTwiceMonthlyDetail(first, second)}',
    Monthly(:final int day) => '${l.payMonthly}: ${l.payMonthlyDetail(day)}',
    EveryTwoWeeks() => l.payBiweekly,
    Weekly() => l.payWeekly,
  };

  Future<void> _editName(BuildContext context, Profile p) async {
    final AppLocalizations l = context.l10n;
    final TextEditingController name = TextEditingController(text: p.name);
    final String? typed = await showDialog<String>(
      context: context,
      builder: (BuildContext context) => AlertDialog(
        title: Text(l.settingsName),
        content: TextField(
          controller: name,
          autofocus: true,
          textCapitalization: TextCapitalization.words,
          onSubmitted: (String v) => Navigator.of(context).pop(v),
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
    name.dispose();
    if (typed == null || typed.trim().isEmpty) return;
    await own.store.saveProfile(p.copyWith(name: typed.trim()));
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
    await own.store.saveProfile(p.copyWith(base: picked));
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
    final AppLocalizations l = context.l10n;
    final ScaffoldMessengerState messenger = ScaffoldMessenger.of(context);
    final Map<String, Object?> data = await own.store.exportJson();
    final String day = own.today.toIso8601String().substring(0, 10);
    final Uri? saved = await FilePicker.saveFile(
      fileName: 'quincena-$day.json',
      bytes: Uint8List.fromList(
        utf8.encode(const JsonEncoder.withIndent('  ').convert(data)),
      ),
      mimeType: 'application/json',
      allowedExtensions: <String>['json'],
    );
    if (saved != null) {
      messenger.showSnackBar(SnackBar(content: Text(l.exportDone)));
    }
  }

  Future<void> _import(BuildContext context) async {
    final AppLocalizations l = context.l10n;
    final ScaffoldMessengerState messenger = ScaffoldMessenger.of(context);
    final List<PlatformFile> files = await FilePicker.pickFiles(
      type: FileType.custom,
      allowedExtensions: <String>['json'],
    );
    if (files.isEmpty || !context.mounted) return;
    final bool? sure = await _confirm(
      context,
      title: l.importConfirmTitle,
      body: l.importConfirmBody,
      action: l.importConfirm,
    );
    if (sure != true) return;
    try {
      final String text = await files.first.xFile.readAsString();
      await own.store.importJson(jsonDecode(text) as Map<String, Object?>);
      await own.refreshRates(force: true);
      messenger.showSnackBar(SnackBar(content: Text(l.importDone)));
    } on Object catch (e) {
      final String reason = e is FormatException ? e.message : '$e';
      messenger.showSnackBar(SnackBar(content: Text(l.importFailed(reason))));
    }
  }

  Future<void> _deleteAll(BuildContext context) async {
    final AppLocalizations l = context.l10n;
    final NavigatorState navigator = Navigator.of(context);
    final bool? sure = await _confirm(
      context,
      title: l.deleteAllTitle,
      body: l.deleteAllBody,
      action: l.deleteAll,
      destructive: true,
    );
    if (sure != true) return;
    await own.store.wipe();
    navigator.popUntil((Route<void> r) => r.isFirst);
    await modes.wiped();
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
                        onTap: () => Navigator.of(context).push(
                          MaterialPageRoute<void>(
                            builder: (BuildContext context) =>
                                CaptureSettingsPage(own: own),
                          ),
                        ),
                      ),
                      if (BinanceLink.available)
                        _row(
                          context,
                          icon: Glyph.currencyBtc,
                          title: l.binanceTitle,
                          value: own.binance.connected
                              ? l.binanceConnected
                              : l.binanceCardBody,
                          onTap: () => Navigator.of(context).push(
                            MaterialPageRoute<void>(
                              builder: (BuildContext context) =>
                                  BinancePage(own: own),
                            ),
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
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}
