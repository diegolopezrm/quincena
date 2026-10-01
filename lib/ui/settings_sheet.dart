import 'package:flutter/material.dart';

import '../agent/model_client.dart';
import '../app.dart';
import '../session/session.dart';
import '../theme/tokens.dart';

/// Who answers, appearance, the developer panel, and starting over.
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

  @override
  Widget build(BuildContext context) {
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
              Text('Ajustes', style: context.type.headlineSmall),
              const SizedBox(height: 22),
              Text('Quién responde', style: context.type.labelMedium),
              const SizedBox(height: 10),
              SegmentedButton<AgentMode>(
                segments: const <ButtonSegment<AgentMode>>[
                  ButtonSegment<AgentMode>(
                    value: AgentMode.demo,
                    label: Text('Demo'),
                  ),
                  ButtonSegment<AgentMode>(
                    value: AgentMode.live,
                    label: Text('Gemini en vivo'),
                  ),
                ],
                selected: <AgentMode>{_mode},
                showSelectedIcon: false,
                onSelectionChanged: (Set<AgentMode> value) =>
                    _choose(value.first),
              ),
              const SizedBox(height: 10),
              Text(switch ((_mode, live)) {
                (AgentMode.demo, _) =>
                  'Las cinco preguntas del inicio, respondidas sin red con '
                      'los mismos componentes que usa el modelo.',
                (AgentMode.live, true) =>
                  'Responde ${GeminiClient.defaultModel}. Pregunta lo que '
                      'quieras sobre la cuenta.',
                (AgentMode.live, false) =>
                  'Con tu key de Gemini puedes preguntar lo que quieras. '
                      'Se queda en esta pestaña: no se guarda, y solo viaja '
                      'a Google.',
              }, style: context.type.bodySmall),
              if (_mode == AgentMode.live && !live) ...<Widget>[
                const SizedBox(height: 12),
                TextField(
                  controller: _key,
                  obscureText: true,
                  autocorrect: false,
                  enableSuggestions: false,
                  onSubmitted: (_) => _connect(),
                  decoration: const InputDecoration(
                    labelText: 'Key de Gemini',
                    hintText: 'De aistudio.google.com',
                  ),
                ),
                const SizedBox(height: 10),
                FilledButton(
                  onPressed: _connect,
                  child: const Text('Conectar'),
                ),
              ],
              const SizedBox(height: 26),
              Text('Apariencia', style: context.type.labelMedium),
              const SizedBox(height: 10),
              SegmentedButton<ThemeMode>(
                segments: const <ButtonSegment<ThemeMode>>[
                  ButtonSegment<ThemeMode>(
                    value: ThemeMode.system,
                    label: Text('Sistema'),
                  ),
                  ButtonSegment<ThemeMode>(
                    value: ThemeMode.light,
                    label: Text('Claro'),
                  ),
                  ButtonSegment<ThemeMode>(
                    value: ThemeMode.dark,
                    label: Text('Oscuro'),
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
                child: SwitchListTile(
                  value: widget.settings.developer,
                  onChanged: (bool value) => widget.settings.developer = value,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                  title: Text(
                    'Modo desarrollador',
                    style: context.type.titleSmall,
                  ),
                  subtitle: Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: Text(
                      'Muestra el inspector de genui_gen sobre la '
                      'conversación: el árbol que armó el agente, el data '
                      'model, lo que anuncia un lector de pantalla y los '
                      'mensajes.',
                      style: context.type.bodySmall,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 22),
              OutlinedButton(
                onPressed: () {
                  widget.session.restart();
                  Navigator.of(context).pop();
                },
                child: const Text('Empezar de nuevo'),
              ),
              const SizedBox(height: 18),
              Text(
                'Quincena es una demo de genui y genui_gen. La cuenta, la '
                'persona y los comercios son inventados.',
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
