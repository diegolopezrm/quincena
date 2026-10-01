import 'package:flutter/material.dart';
import 'package:genui_gen/tracing.dart';

import '../agent/catalog.dart';
import '../session/recordings.dart';
import '../theme/theme.dart';
import '../theme/tokens.dart';
import 'icons.dart';
import 'mark.dart';

/// Sessions Gemini answered for real, replayed with no network.
class RecordedPage extends StatelessWidget {
  const RecordedPage({super.key, required this.recordings});

  final List<Recording> recordings;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: context.colors.canvas,
        surfaceTintColor: Colors.transparent,
        title: Text('Lo que respondió Gemini', style: context.type.titleLarge),
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 760),
          child: ListView(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
            children: <Widget>[
              Text(
                'Estas sesiones no son del guion de la demo. Gemini recibió '
                'cada pregunta, consultó la cuenta con herramientas y compuso '
                'la pantalla con el catálogo de la app. genui_gen grabó todo '
                'lo que mandó, y aquí se reproduce paso a paso, sin red.',
                style: context.type.bodyMedium,
              ),
              const SizedBox(height: 20),
              for (final Recording recording in recordings)
                Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: _Entry(recording: recording),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Entry extends StatelessWidget {
  const _Entry({required this.recording});

  final Recording recording;

  @override
  Widget build(BuildContext context) {
    final int steps = recording.trace.steps.length;
    return Material(
      color: context.colors.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(18),
        side: BorderSide(color: context.colors.line),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => Navigator.of(context).push(
          MaterialPageRoute<void>(
            builder: (BuildContext context) => ReplayPage(recording: recording),
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: <Widget>[
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(recording.question, style: context.type.titleSmall),
                    const SizedBox(height: 4),
                    Text(
                      '${recording.model} · $steps pasos'
                      '${recording.seconds == null ? '' : ' · ${recording.seconds!.toStringAsFixed(1)} s'}',
                      style: context.type.bodySmall,
                    ),
                  ],
                ),
              ),
              Icon(Glyph.arrowRight, size: 18, color: context.colors.inkFaint),
            ],
          ),
        ),
      ),
    );
  }
}

/// One recorded session, with a control to step through what was sent.
class ReplayPage extends StatefulWidget {
  const ReplayPage({super.key, required this.recording});

  final Recording recording;

  @override
  State<ReplayPage> createState() => _ReplayPageState();
}

class _ReplayPageState extends State<ReplayPage> {
  late final GenUiTracePlayer _player = GenUiTracePlayer(
    widget.recording.trace,
    catalog: quincenaCatalog,
  )..seekToEnd();

  @override
  void dispose() {
    _player.dispose();
    super.dispose();
  }

  /// What the step the replay stopped at was, in a few words.
  String _describe(int position) {
    if (position == 0) return 'Antes de la respuesta';
    final GenUiTraceStep step = widget.recording.trace.steps[position - 1];
    return switch (step) {
      GenUiMessageStep(:final message) => switch (message.keys
          .where((String k) => k != 'version')
          .firstOrNull) {
        'createSurface' => 'Crea la superficie',
        'updateComponents' => 'Manda los componentes',
        'updateDataModel' => 'Manda los datos',
        final String other => other,
        null => 'Mensaje',
      },
      GenUiDataStep() => 'Cambian los datos',
      GenUiEventStep() => 'La app le responde al agente',
    };
  }

  @override
  Widget build(BuildContext context) {
    final int length = _player.length;
    return Scaffold(
      appBar: AppBar(
        backgroundColor: context.colors.canvas,
        surfaceTintColor: Colors.transparent,
        title: Text(widget.recording.model, style: context.type.titleMedium),
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 760),
          child: ListView(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
            children: <Widget>[
              Align(
                alignment: Alignment.centerRight,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 11,
                  ),
                  decoration: BoxDecoration(
                    color: context.colors.ink,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    widget.recording.question,
                    style: context.type.bodyLarge?.copyWith(
                      color: context.colors.surface,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 18),
              Container(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
                decoration: BoxDecoration(
                  color: context.colors.surface,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: context.colors.line),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Row(
                      children: <Widget>[
                        const QuincenaMark(size: 16),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            _describe(_player.position),
                            style: context.type.labelMedium,
                          ),
                        ),
                        Text(
                          '${_player.position} de $length',
                          style: context.type.bodySmall?.copyWith(
                            fontFeatures: tabular,
                          ),
                        ),
                      ],
                    ),
                    Slider(
                      value: _player.position.toDouble(),
                      max: length.toDouble(),
                      divisions: length < 1 ? 1 : length,
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      semanticFormatterCallback: (double value) =>
                          'Paso ${value.round()} de $length',
                      onChanged: (double value) =>
                          setState(() => _player.seek(value.round())),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 18),
              GenUiTraceView(player: _player),
            ],
          ),
        ),
      ),
    );
  }
}
