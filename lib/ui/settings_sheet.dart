import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../agent/model_client.dart';
import '../app.dart';
import '../l10n/l10n.dart';
import '../session/session.dart';
import '../theme/tokens.dart';

/// Who answers, language, appearance, the developer panel, starting over.
Future<void> showSettings(
  BuildContext context, {
  required AppSettings settings,
  required Session session,
}) => showModalBottomSheet<void>(
  context: context,
  showDragHandle: true,
  isScrollControlled: true,
  backgroundColor: context.colors.surface,
  constraints: const BoxConstraints(maxWidth: 560),
  builder: (BuildContext context) =>
      _Settings(settings: settings, session: session),
);

class _Settings extends StatefulWidget {
  const _Settings({required this.settings, required this.session});

  final AppSettings settings;
  final Session session;

  @override
  State<_Settings> createState() => _SettingsState();
}

class _SettingsState extends State<_Settings> {
  final TextEditingController _key = TextEditingController();
  late AgentMode _mode = widget.session.mode;

  @override
  void dispose() {
    _key.dispose();
    super.dispose();
  }

  void _connect() {
    final String key = _key.text.trim();
    if (key.isEmpty) return;
    widget.session.use(AgentMode.live, apiKey: key);
    Navigator.of(context).pop();
  }

  void _choose(AgentMode mode) {
    setState(() => _mode = mode);
    if (mode == AgentMode.demo && widget.session.mode != AgentMode.demo) {
      widget.session.use(AgentMode.demo);
    } else if (mode == AgentMode.live &&
        widget.session.canGoLive &&
        widget.session.mode != AgentMode.live) {
      widget.session.use(AgentMode.live);
    }
  }

  Future<void> _copySession() async {
    final ScaffoldMessengerState messenger = ScaffoldMessenger.of(context);
    final String copied = context.l10n.sessionCopied;
    await Clipboard.setData(
      ClipboardData(text: widget.session.recorder.build().encode()),
    );
    messenger.showSnackBar(SnackBar(content: Text(copied)));
  }

  @override
  Widget build(BuildContext context) {
    final AppLocalizations t = context.l10n;
    final bool live = widget.session.mode == AgentMode.live;
    return ListenableBuilder(
      listenable: Listenable.merge(<Listenable>[
        widget.settings,
        widget.session,
      ]),
      builder: (BuildContext context, _) => SafeArea(
        child: SingleChildScrollView(
          padding: EdgeInsets.fromLTRB(
            24,
            0,
            24,
            24 + MediaQuery.viewInsetsOf(context).bottom,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              Text(t.settings, style: context.type.headlineSmall),
              const SizedBox(height: 22),
              Text(t.whoAnswers, style: context.type.labelMedium),
              const SizedBox(height: 10),
              SegmentedButton<AgentMode>(
                segments: <ButtonSegment<AgentMode>>[
                  ButtonSegment<AgentMode>(
                    value: AgentMode.demo,
                    label: Text(t.modeDemo),
                  ),
                  ButtonSegment<AgentMode>(
                    value: AgentMode.live,
                    label: Text(t.modeLive),
                  ),
                ],
                selected: <AgentMode>{_mode},
                showSelectedIcon: false,
                onSelectionChanged: (Set<AgentMode> value) =>
                    _choose(value.first),
              ),
              const SizedBox(height: 10),
              Text(switch ((_mode, live)) {
                (AgentMode.demo, _) => t.demoExplain,
                (AgentMode.live, true) => t.liveActive(
                  GeminiClient.defaultModel,
                ),
                (AgentMode.live, false) => t.liveNeedsKey,
              }, style: context.type.bodySmall),
              if (_mode == AgentMode.live && !live) ...<Widget>[
                const SizedBox(height: 12),
                TextField(
                  controller: _key,
                  obscureText: true,
                  autocorrect: false,
                  enableSuggestions: false,
                  onSubmitted: (_) => _connect(),
                  decoration: InputDecoration(
                    labelText: t.keyLabel,
                    hintText: t.keyHint,
                  ),
                ),
                const SizedBox(height: 10),
                FilledButton(onPressed: _connect, child: Text(t.connect)),
              ],
              const SizedBox(height: 26),
              Text(t.language, style: context.type.labelMedium),
              const SizedBox(height: 10),
              SegmentedButton<String>(
                segments: <ButtonSegment<String>>[
                  ButtonSegment<String>(
                    value: 'system',
                    label: Text(t.languageSystem),
                  ),
                  // Each language named in itself, so a person who opened
                  // the app in the wrong one can still find theirs.
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
                  widget.settings.locale?.languageCode ?? 'system',
                },
                showSelectedIcon: false,
                onSelectionChanged: (Set<String> value) =>
                    widget.settings.locale = value.first == 'system'
                    ? null
                    : Locale(value.first),
              ),
              const SizedBox(height: 22),
              Text(t.appearance, style: context.type.labelMedium),
              const SizedBox(height: 10),
              SegmentedButton<ThemeMode>(
                segments: <ButtonSegment<ThemeMode>>[
                  ButtonSegment<ThemeMode>(
                    value: ThemeMode.system,
                    label: Text(t.themeSystem),
                  ),
                  ButtonSegment<ThemeMode>(
                    value: ThemeMode.light,
                    label: Text(t.themeLight),
                  ),
                  ButtonSegment<ThemeMode>(
                    value: ThemeMode.dark,
                    label: Text(t.themeDark),
                  ),
                ],
                selected: <ThemeMode>{widget.settings.themeMode},
                showSelectedIcon: false,
                onSelectionChanged: (Set<ThemeMode> value) =>
                    widget.settings.themeMode = value.first,
              ),
              const SizedBox(height: 22),
              Container(
                decoration: BoxDecoration(
                  color: context.colors.sunken,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Column(
                  children: <Widget>[
                    SwitchListTile(
                      value: widget.settings.developer,
                      onChanged: (bool value) =>
                          widget.settings.developer = value,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                      title: Text(
                        t.developerMode,
                        style: context.type.titleSmall,
                      ),
                      subtitle: Padding(
                        padding: const EdgeInsets.only(top: 4),
                        child: Text(
                          t.developerExplain,
                          style: context.type.bodySmall,
                        ),
                      ),
                    ),
                    if (widget.settings.developer)
                      Padding(
                        padding: const EdgeInsets.fromLTRB(16, 0, 16, 14),
                        child: SizedBox(
                          width: double.infinity,
                          child: OutlinedButton(
                            onPressed: widget.session.turns.isEmpty
                                ? null
                                : _copySession,
                            child: Text(t.copySession),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
              const SizedBox(height: 22),
              OutlinedButton(
                onPressed: () {
                  widget.session.restart();
                  Navigator.of(context).pop();
                },
                child: Text(t.startOver),
              ),
              const SizedBox(height: 18),
              Text(
                t.about,
                style: context.type.bodySmall,
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
