import 'package:flutter/material.dart';

import '../../l10n/l10n.dart';
import '../../theme/tokens.dart';
import '../icons.dart';
import '../kit.dart';

/// What Gemini gets to see when the person asks their money something, in
/// plain words: what travels, what does not, and on what terms.
class GeminiNotePage extends StatelessWidget {
  const GeminiNotePage({super.key, this.perDay});

  /// The questions each person has in a day, when they are counted.
  final int? perDay;

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l = context.l10n;
    Widget paragraph(IconData icon, String text) => Padding(
      padding: const EdgeInsets.only(bottom: 18),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Padding(
            padding: const EdgeInsets.only(top: 2),
            child: Icon(icon, size: 20, color: context.colors.inkSoft),
          ),
          const SizedBox(width: 14),
          Expanded(child: Text(text, style: context.type.bodyMedium)),
        ],
      ),
    );
    return Scaffold(
      appBar: AppBar(
        backgroundColor: context.colors.canvas,
        surfaceTintColor: Colors.transparent,
        title: Text(l.askWhatSees, style: context.type.titleLarge),
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 640),
          child: ListView(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
            children: <Widget>[
              Block(
                child: Column(
                  children: <Widget>[
                    paragraph(Glyph.sparkle, l.geminiNoteHow),
                    paragraph(Glyph.chartBar, l.geminiNoteSends),
                    paragraph(Glyph.lock, l.geminiNoteNot),
                    paragraph(Glyph.info, l.geminiNoteTerms),
                    if (perDay case final int n)
                      paragraph(Glyph.checkCircle, l.geminiNoteLimit(n)),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
