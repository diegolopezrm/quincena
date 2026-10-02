import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../capture/inbox.dart';
import '../../capture/native_channel.dart';
import '../../capture/ready_shortcuts.dart';
import '../../l10n/l10n.dart';
import '../../own/own_controller.dart';
import '../../theme/tokens.dart';
import '../icons.dart';
import '../kit.dart';
import 'inbox_page.dart';
import 'look.dart';
import 'read_images.dart';

/// How payments get into Quincena on their own on this device, and the two
/// choices about them: recording what is clear, and using the location.
class CaptureSettingsPage extends StatefulWidget {
  const CaptureSettingsPage({super.key, required this.own});

  final OwnController own;

  @override
  State<CaptureSettingsPage> createState() => _CaptureSettingsPageState();
}

class _CaptureSettingsPageState extends State<CaptureSettingsPage>
    with WidgetsBindingObserver {
  bool? _access;
  LocationAccess? _location;

  OwnController get own => widget.own;

  bool get _ios => !kIsWeb && defaultTargetPlatform == TargetPlatform.iOS;
  bool get _android =>
      !kIsWeb && defaultTargetPlatform == TargetPlatform.android;

  /// Only the phone knows where a payment happened.
  bool get _phone => _ios || _android;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _checkAccess();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  /// Back from the system settings: the access may have changed.
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) _checkAccess();
  }

  Future<void> _checkAccess() async {
    if (!_android) return;
    final bool granted = await CaptureChannel.notificationAccess();
    final LocationAccess location = await CaptureChannel.locationAccess();
    if (mounted) {
      setState(() {
        _access = granted;
        _location = location;
      });
    }
  }

  Future<void> _save(CaptureSettings s) => own.store.saveCaptureSettings(s);

  /// Turning the location on asks for it while the app is in use and then,
  /// after saying why, for all the time: payments arrive with the app
  /// closed. Either way the person decides; with only the first, it works
  /// while the app is open.
  Future<void> _useLocation(bool on) async {
    if (!on) return _save(own.captureSettings.copyWith(useLocation: false));
    final AppLocalizations l = context.l10n;
    final ScaffoldMessengerState messenger = ScaffoldMessenger.of(context);
    LocationAccess access = await CaptureChannel.locationAccess();
    if (access == LocationAccess.none) {
      access = await CaptureChannel.askForLocation();
    }
    if (access == LocationAccess.foreground && await _explainAlways()) {
      access = await CaptureChannel.askForBackgroundLocation();
    }
    await _save(
      own.captureSettings.copyWith(useLocation: access != LocationAccess.none),
    );
    if (mounted) setState(() => _location = access);
    if (access == LocationAccess.none) {
      messenger.showSnackBar(
        SnackBar(
          content: Text(l.captureLocationDenied),
          action: SnackBarAction(
            label: l.openPhoneSettings,
            onPressed: CaptureChannel.openAppSettings,
          ),
        ),
      );
    }
  }

  Future<void> _allowAlways() async {
    final LocationAccess access =
        await CaptureChannel.askForBackgroundLocation();
    if (mounted) setState(() => _location = access);
  }

  Future<bool> _explainAlways() async {
    if (!mounted) return false;
    final AppLocalizations l = context.l10n;
    return await showDialog<bool>(
          context: context,
          builder: (BuildContext context) => AlertDialog(
            title: Text(l.captureAlwaysTitle),
            content: Text(l.captureAlwaysBody),
            actions: <Widget>[
              TextButton(
                onPressed: () => Navigator.of(context).pop(false),
                child: Text(l.notNow),
              ),
              FilledButton(
                onPressed: () => Navigator.of(context).pop(true),
                child: Text(l.continueLabel),
              ),
            ],
          ),
        ) ??
        false;
  }

  Widget _platform(AppLocalizations l) {
    if (_ios) {
      // iOS 27 adds a whole automation from a link; iOS 26 still needs the
      // person to make it, around one of Quincena's shortcuts.
      final int major = iosMajorVersion() ?? 0;
      final List<ReadyShortcut> ready = ReadyShortcut.forIos(major);
      final bool oneTap = major >= 27 && ready.isNotEmpty;
      return Block(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text(l.captureIosTitle, style: context.type.titleSmall),
            const SizedBox(height: 8),
            Text(
              oneTap
                  ? l.captureIosReady
                  : ready.isEmpty
                  ? l.captureIosSteps
                  : l.captureIos26Steps,
              style: context.type.bodyMedium,
            ),
            for (final ReadyShortcut shortcut in ready)
              _ReadyRow(shortcut: shortcut),
            if (!oneTap) ...<Widget>[
              const SizedBox(height: 14),
              FilledButton.icon(
                onPressed: () => launchUrl(Uri.parse('shortcuts://')),
                icon: const Icon(Glyph.arrowUpRight, size: 18),
                label: Text(l.captureOpenShortcuts),
              ),
            ],
          ],
        ),
      );
    }
    if (_android) {
      final bool granted = _access ?? false;
      return Block(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text(l.captureAndroidTitle, style: context.type.titleSmall),
            const SizedBox(height: 8),
            Text(l.captureAndroidBody, style: context.type.bodyMedium),
            const SizedBox(height: 14),
            if (granted)
              Row(
                children: <Widget>[
                  Icon(
                    Glyph.checkCircle,
                    size: 20,
                    color: context.colors.positive,
                  ),
                  const SizedBox(width: 8),
                  Text(l.captureAndroidGranted, style: context.type.titleSmall),
                ],
              )
            else
              FilledButton.icon(
                onPressed: CaptureChannel.openNotificationAccess,
                icon: const Icon(Glyph.bell, size: 18),
                label: Text(l.captureAndroidGrant),
              ),
          ],
        ),
      );
    }
    return Block(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(l.captureOtherTitle, style: context.type.titleSmall),
          const SizedBox(height: 8),
          Text(l.captureOtherBody, style: context.type.bodyMedium),
          const SizedBox(height: 14),
          OutlinedButton.icon(
            onPressed: () => showPasteDialog(context, own),
            icon: const Icon(Glyph.notePencil, size: 18),
            label: Text(l.pasteMessage),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: own,
      builder: (BuildContext context, _) {
        final AppLocalizations l = context.l10n;
        final CaptureSettings s = own.captureSettings;
        return Scaffold(
          appBar: AppBar(
            backgroundColor: context.colors.canvas,
            surfaceTintColor: Colors.transparent,
            title: Text(l.captureTitle, style: context.type.titleLarge),
          ),
          body: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 640),
              child: ListView(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
                children: <Widget>[
                  Text(l.captureSubtitle, style: context.type.bodyMedium),
                  const SizedBox(height: 16),
                  _platform(l),
                  if (CaptureChannel.readsImages) ...<Widget>[
                    const SizedBox(height: 12),
                    Block(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: <Widget>[
                          Text(
                            l.captureImagesTitle,
                            style: context.type.titleSmall,
                          ),
                          const SizedBox(height: 8),
                          Text(
                            _ios
                                ? l.captureImagesIos
                                : _android
                                ? l.captureImagesAndroid
                                : l.captureImagesDesktop,
                            style: context.type.bodyMedium,
                          ),
                          const SizedBox(height: 14),
                          OutlinedButton.icon(
                            onPressed: () => readImages(context, own),
                            icon: const Icon(Glyph.scan, size: 18),
                            label: Text(l.readScreenshot),
                          ),
                        ],
                      ),
                    ),
                  ],
                  const SizedBox(height: 20),
                  Panel(
                    indent: 16,
                    children: <Widget>[
                      SwitchListTile(
                        value: s.autoRecord,
                        onChanged: (bool v) => _save(s.copyWith(autoRecord: v)),
                        title: Text(
                          l.captureAuto,
                          style: context.type.titleSmall,
                        ),
                        subtitle: Text(
                          l.captureAutoHelp,
                          style: context.type.bodySmall,
                        ),
                      ),
                      if (_phone)
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: <Widget>[
                            SwitchListTile(
                              value: s.useLocation,
                              onChanged: _useLocation,
                              title: Text(
                                l.captureLocation,
                                style: context.type.titleSmall,
                              ),
                              subtitle: Text(
                                l.captureLocationHelp,
                                style: context.type.bodySmall,
                              ),
                            ),
                            if (s.useLocation &&
                                _location == LocationAccess.foreground)
                              Padding(
                                padding: const EdgeInsets.fromLTRB(
                                  16,
                                  0,
                                  16,
                                  8,
                                ),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: <Widget>[
                                    Text(
                                      l.captureLocationOnlyOpen,
                                      style: context.type.bodySmall?.copyWith(
                                        color: context.colors.caution,
                                      ),
                                    ),
                                    TextButton(
                                      onPressed: _allowAlways,
                                      style: TextButton.styleFrom(
                                        padding: EdgeInsets.zero,
                                      ),
                                      child: Text(l.captureAllowAlways),
                                    ),
                                  ],
                                ),
                              ),
                          ],
                        ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 4),
                    child: Text(
                      l.learnedCount(s.merchantCategories.length),
                      style: context.type.bodySmall,
                    ),
                  ),
                  if (s.mutedApps.isNotEmpty) ...<Widget>[
                    const SizedBox(height: 24),
                    SectionLabel(l.mutedApps),
                    Panel(
                      indent: 16,
                      children: <Widget>[
                        for (final String app in s.mutedApps)
                          ListTile(
                            title: Text(
                              s.appNames[app] ?? app,
                              style: context.type.bodyMedium,
                            ),
                            trailing: TextButton(
                              onPressed: () => _save(
                                s.copyWith(
                                  mutedApps: <String>{...s.mutedApps}
                                    ..remove(app),
                                  appNames: <String, String>{...s.appNames}
                                    ..remove(app),
                                ),
                              ),
                              child: Text(l.unmute),
                            ),
                          ),
                      ],
                    ),
                  ],
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

/// One of Quincena's ready shortcuts, and the button that adds it.
class _ReadyRow extends StatelessWidget {
  const _ReadyRow({required this.shortcut});

  final ReadyShortcut shortcut;

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l = context.l10n;
    final (IconData icon, String title, String help) = switch (shortcut) {
      ReadyShortcut.bankNotifications => (
        Glyph.bell,
        l.readyBankNotifications,
        l.readyBankNotificationsHelp,
      ),
      ReadyShortcut.bankMessages || ReadyShortcut.bankMessagesForIos26 => (
        Glyph.chatCircleDots,
        l.readyBankMessages,
        l.readyBankMessagesHelp,
      ),
      ReadyShortcut.applePay || ReadyShortcut.applePayForIos26 => (
        Glyph.creditCard,
        l.readyApplePay,
        l.readyApplePayHelp,
      ),
      ReadyShortcut.screenshots => (
        Glyph.scan,
        l.readyScreenshots,
        l.readyScreenshotsHelp,
      ),
    };
    return Padding(
      padding: const EdgeInsets.only(top: 16),
      child: Row(
        children: <Widget>[
          Icon(icon, size: 22, color: context.colors.inkSoft),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(title, style: context.type.titleSmall),
                Text(help, style: context.type.bodySmall),
              ],
            ),
          ),
          const SizedBox(width: 8),
          OutlinedButton(
            onPressed: () => launchUrl(
              Uri.parse(shortcut.link),
              mode: LaunchMode.externalApplication,
            ),
            child: Text(l.captureAdd),
          ),
        ],
      ),
    );
  }
}
