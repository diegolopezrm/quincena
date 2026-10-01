import 'package:flutter/material.dart';

import '../app.dart';
import '../session/session.dart';
import '../theme/tokens.dart';

/// Appearance, the developer panel, and starting over.
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
  builder: (BuildContext context) => ListenableBuilder(
    listenable: settings,
    builder: (BuildContext context, _) => SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            Text('Ajustes', style: context.type.headlineSmall),
            const SizedBox(height: 22),
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
              selected: <ThemeMode>{settings.themeMode},
              showSelectedIcon: false,
              onSelectionChanged: (Set<ThemeMode> value) =>
                  settings.themeMode = value.first,
            ),
            const SizedBox(height: 22),
            Container(
              decoration: BoxDecoration(
                color: context.colors.sunken,
                borderRadius: BorderRadius.circular(16),
              ),
              child: SwitchListTile(
                value: settings.developer,
                onChanged: (bool value) => settings.developer = value,
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
                    'Muestra el inspector de genui_gen sobre la conversación: '
                    'el árbol que armó el agente, el data model, lo que '
                    'anuncia un lector de pantalla y los mensajes.',
                    style: context.type.bodySmall,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 22),
            OutlinedButton(
              onPressed: () {
                session.restart();
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
  ),
);
