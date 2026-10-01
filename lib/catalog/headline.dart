import 'package:flutter/material.dart';
import 'package:genui/genui.dart';
import 'package:genui_gen/genui_gen.dart';

import '../theme/tokens.dart';

part 'headline.genui.dart';

/// The opening of an answer.
@GenUiWidget(
  description:
      'The opening of an answer: a short kicker, a headline that states the '
      'finding in one sentence, and an optional line of context. Start every '
      'surface with one. The headline is the answer; everything below it is '
      'the evidence.',
)
class Headline extends StatelessWidget {
  const Headline({super.key, required this.title, this.kicker, this.body});

  /// A few words naming the subject, shown small above the title, such as
  /// "Septiembre" or "Tu meta".
  final String? kicker;

  /// The finding itself, in one plain sentence, such as "Gastaste casi todo lo
  /// que entró". Never a question and never a label.
  final String title;

  /// One or two sentences of context under the title.
  final String? body;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 4, 4, 6),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          if (kicker case final String kicker
              when kicker.isNotEmpty) ...<Widget>[
            Text(
              kicker.toUpperCase(),
              style: context.type.labelSmall?.copyWith(
                color: context.colors.brand,
              ),
            ),
            const SizedBox(height: 8),
          ],
          Semantics(
            header: true,
            child: Text(
              title,
              style: context.type.headlineMedium,
              textWidthBasis: TextWidthBasis.longestLine,
            ),
          ),
          if (body case final String body when body.isNotEmpty) ...<Widget>[
            const SizedBox(height: 8),
            Text(body, style: context.type.bodyMedium),
          ],
        ],
      ),
    );
  }
}
