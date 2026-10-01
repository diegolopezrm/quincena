import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../capture/inbox.dart';
import '../../capture/native_channel.dart';
import '../../l10n/l10n.dart';
import '../../own/own_controller.dart';
import '../../theme/tokens.dart';
import '../icons.dart';
import '../kit.dart';
import 'inbox_page.dart';
import 'look.dart';

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

  OwnController get own => widget.own;

  bool get _ios => !kIsWeb && defaultTargetPlatform == TargetPlatform.iOS;
  bool get _android =>
      !kIsWeb && defaultTargetPlatform == TargetPlatform.android;

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
    if (mounted) setState(() => _access = granted);
  }

  Future<void> _save(CaptureSettings s) => own.store.saveCaptureSettings(s);

  Future<void> _useLocation(bool on) async {
    final bool allowed = await CaptureChannel.setUseLocation(on);
    await _save(own.captureSettings.copyWith(useLocation: on && allowed));
  }

  Widget _platform(AppLocalizations l) {
    if (_ios) {
      return Block(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text(l.captureIosTitle, style: context.type.titleSmall),
            const SizedBox(height: 8),
            Text(l.captureIosSteps, style: context.type.bodyMedium),
            const SizedBox(height: 14),
            FilledButton.icon(
              onPressed: () => launchUrl(Uri.parse('shortcuts://')),
              icon: const Icon(Glyph.arrowUpRight, size: 18),
              label: Text(l.captureOpenShortcuts),
            ),
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
                  const SizedBox(height: 20),
                  Panel(
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
                      children: <Widget>[
                        for (final String app in s.mutedApps)
                          ListTile(
                            title: Text(app, style: context.type.bodyMedium),
                            trailing: TextButton(
                              onPressed: () => _save(
                                s.copyWith(
                                  mutedApps: <String>{...s.mutedApps}
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
