import 'package:flutter/material.dart';
import 'package:genui/genui.dart';
import 'package:genui_gen/genui_gen.dart';

part 'answer.genui.dart';

/// The root of every answer.
@GenUiWidget(
  description:
      'The root of every answer: stacks its children top to bottom with even '
      'spacing. Make it the `root` component of every surface, with a '
      'Headline first.',
)
class Answer extends StatelessWidget {
  const Answer({super.key, required this.children});

  /// The parts of the answer, in reading order.
  final List<Widget> children;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    mainAxisSize: MainAxisSize.min,
    children: <Widget>[
      for (var i = 0; i < children.length; i++) ...<Widget>[
        if (i > 0) const SizedBox(height: 12),
        children[i],
      ],
    ],
  );
}
