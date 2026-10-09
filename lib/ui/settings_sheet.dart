import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../agent/firebase_client.dart';
import '../agent/model_client.dart';
import '../ai/cloud.dart';
import '../app.dart';
import '../l10n/l10n.dart';
import '../session/session.dart';
import '../theme/tokens.dart';
import '../showcase.dart';

/// Who answers, language, appearance, the developer panel, starting over.
Future<void> showSettings(
  BuildContext context, {
  required AppSettings settings,
  required Session session,
  VoidCallback? onUseOwn,
  bool hasOwn = false,
}) => showModalBottomSheet<void>(
  context: context,
  showDragHandle: true,
  isScrollControlled: true,
  // No color of its own: the theme's surface, read as the sheet draws, so
  // it turns dark with the rest when the person picks dark in it.
  constraints: const BoxConstraints(maxWidth: 560),
  builder: (BuildContext context) => _Settings(
    settings: settings,
    session: session,
    onUseOwn: onUseOwn,
    hasOwn: hasOwn,
  ),
);

class _Settings extends StatefulWidget {
  const _Settings({
    required this.settings,
    required this.session,
    this.onUseOwn,
    this.hasOwn = false,
  });

  final AppSettings settings;
  final Session session;

  /// Leaves the sample for the person's own accounts; null where this build
  /// cannot keep them.
  final VoidCallback? onUseOwn;

  /// Whether there are own accounts to go back to.
  final bool hasOwn;

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
    } else if (mode == AgentMode.gemini &&
        widget.session.mode != AgentMode.gemini) {
      widget.session.use(AgentMode.gemini);
    } else if (mode == AgentMode.live &&
        widget.session.canGoLive &&
        widget.session.mode != AgentMode.live) {
      widget.session.use(AgentMode.live);
    }
  }

  Future<void> _copySession() async {
    final ScaffoldMessengerState messenger = ScaffoldMessenger.of(context);
    final NavigatorState navigator = Navigator.of(context);
    final String copied = context.l10n.sessionCopied;
    await Clipboard.setData(
      ClipboardData(text: widget.session.recorder.build().encode()),
    );
    // Open, the sheet would cover the line that says it was copied.
    if (mounted) navigator.pop();
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
              // Where only the script answers, as in the example account,
              // there is no one else to choose.
              if (widget.session.choosable) ...<Widget>[
                Text(t.whoAnswers, style: context.type.labelMedium),
                const SizedBox(height: 10),
                SegmentedButton<AgentMode>(
                  segments: <ButtonSegment<AgentMode>>[
                    ButtonSegment<AgentMode>(
                      value: AgentMode.demo,
                      label: Text(t.modeDemo),
                    ),
                    // Gemini with no key where Quincena's project serves the
                    // app; a key of the person's own then stays an option.
                    if (Cloud.supported)
                      ButtonSegment<AgentMode>(
                        value: AgentMode.gemini,
                        label: Text(t.modeGemini),
                      ),
                    ButtonSegment<AgentMode>(
                      value: AgentMode.live,
                      label: Text(Cloud.supported ? t.modeOwnKey : t.modeLive),
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
                  (AgentMode.gemini, _) => t.geminiExplain(
                    FirebaseGeminiClient.defaultModel,
                  ),
                }, style: context.type.bodySmall),
                // Connected, it stays, so a key that did not work can be
                // replaced where the notice about it sends the person.
                if (_mode == AgentMode.live) ...<Widget>[
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
              ],
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
              // The inspector is for developers: only the web demo has it.
              if (showcase) ...<Widget>[
                // A Material rather than a decorated box, so the switch's ink
                // shows on the tinted background instead of under it.
                Material(
                  color: context.colors.sunken,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                  clipBehavior: Clip.antiAlias,
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
              ],
              if (widget.onUseOwn case final VoidCallback useOwn) ...<Widget>[
                FilledButton(
                  onPressed: () {
                    Navigator.of(context).pop();
                    useOwn();
                  },
                  child: Text(widget.hasOwn ? t.backToOwn : t.useOwn),
                ),
                const SizedBox(height: 10),
              ],
              OutlinedButton(
                onPressed: () {
                  widget.session.restart();
                  Navigator.of(context).pop();
                },
                child: Text(t.startOver),
              ),
              const SizedBox(height: 18),
              Text(
                showcase ? t.about : t.aboutExample,
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
