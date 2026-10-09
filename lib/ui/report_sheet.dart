import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../ai/reports.dart';
import '../l10n/l10n.dart';
import '../session/session.dart';
import '../theme/tokens.dart';

/// Lets the person report [turn]'s answer to DL SOFT: what is wrong with
/// it, anything they want to add, and exactly what goes with the report.
Future<void> showReportSheet(
  BuildContext context, {
  required Session session,
  required Turn turn,
  required AnswerReports reports,
}) async {
  final ScaffoldMessengerState? messenger = ScaffoldMessenger.maybeOf(context);
  final String thanks = context.l10n.reportThanks;
  final bool? sent = await showModalBottomSheet<bool>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    useSafeArea: true,
    backgroundColor: context.colors.surface,
    constraints: const BoxConstraints(maxWidth: 560),
    builder: (BuildContext context) =>
        _ReportSheet(session: session, turn: turn, reports: reports),
  );
  if (sent != true) return;
  session.markReported(turn);
  messenger?.showSnackBar(SnackBar(content: Text(thanks)));
}

/// What was chosen and written in a report not sent yet, kept with its
/// answer: a sheet closed by a slip of the finger loses nothing.
final Expando<(ReportReason?, String)> _drafts =
    Expando<(ReportReason?, String)>('report drafts');

class _ReportSheet extends StatefulWidget {
  const _ReportSheet({
    required this.session,
    required this.turn,
    required this.reports,
  });

  final Session session;
  final Turn turn;
  final AnswerReports reports;

  @override
  State<_ReportSheet> createState() => _ReportSheetState();
}

class _ReportSheetState extends State<_ReportSheet> {
  late final TextEditingController _comment = TextEditingController(
    text: _drafts[widget.turn]?.$2 ?? '',
  )..addListener(_keep);
  late ReportReason? _reason = _drafts[widget.turn]?.$1;
  bool _sending = false;
  bool _failed = false;

  void _keep() => _drafts[widget.turn] = (_reason, _comment.text);

  @override
  void dispose() {
    _comment.dispose();
    super.dispose();
  }

  Future<void> _send() async {
    final ReportReason? reason = _reason;
    if (reason == null) return;
    setState(() {
      _sending = true;
      _failed = false;
    });
    final Session session = widget.session;
    try {
      await widget.reports.send(
        AnswerReport(
          reason: reason,
          question: widget.turn.question ?? '',
          answer: session.answerOf(widget.turn),
          comment: _comment.text,
          language: session.language,
          mode: session.mode.name,
        ),
      );
      // Sent, there is no draft left to keep.
      _drafts[widget.turn] = null;
      if (mounted) Navigator.of(context).pop(true);
    } on Object catch (error) {
      if (kDebugMode) debugPrint('The report did not arrive: $error');
      if (mounted) {
        setState(() {
          _sending = false;
          _failed = true;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l = context.l10n;
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Text(l.reportTitle, style: context.type.headlineMedium),
            const SizedBox(height: 12),
            Text(l.reportWhy, style: context.type.bodyMedium),
            RadioGroup<ReportReason>(
              groupValue: _reason,
              onChanged: (ReportReason? reason) {
                if (_sending) return;
                setState(() => _reason = reason);
                _keep();
              },
              child: Column(
                children: <Widget>[
                  for (final ReportReason reason in ReportReason.values)
                    RadioListTile<ReportReason>(
                      value: reason,
                      enabled: !_sending,
                      contentPadding: EdgeInsets.zero,
                      title: Text(switch (reason) {
                        ReportReason.offensive => l.reportOffensive,
                        ReportReason.wrong => l.reportWrong,
                        ReportReason.other => l.reportOther,
                      }),
                    ),
                ],
              ),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _comment,
              enabled: !_sending,
              minLines: 2,
              maxLines: 5,
              maxLength: AnswerReports.maxComment,
              textCapitalization: TextCapitalization.sentences,
              decoration: InputDecoration(labelText: l.reportComment),
            ),
            const SizedBox(height: 4),
            Text(l.reportWhat, style: context.type.bodySmall),
            if (_failed) ...<Widget>[
              const SizedBox(height: 12),
              Semantics(
                liveRegion: true,
                child: Text(
                  l.reportFailed,
                  style: context.type.bodySmall?.copyWith(
                    color: context.colors.negative,
                  ),
                ),
              ),
            ],
            const SizedBox(height: 20),
            FilledButton(
              onPressed: _reason == null || _sending ? null : _send,
              child: Text(_sending ? l.reportSending : l.reportSend),
            ),
          ],
        ),
      ),
    );
  }
}
