import 'package:flutter/material.dart';
import 'package:genui/genui.dart';
import 'package:genui_gen/genui_gen.dart';

import '../theme/tokens.dart';
import '../ui/kit.dart';

part 'group.genui.dart';

/// A titled card holding related pieces.
@GenUiWidget(
  description:
      'A card with a title that holds related components, such as several '
      'BudgetMeters or the fields of a form, so they read as one block.',
)
class Group extends StatelessWidget {
  const Group({super.key, required this.title, required this.children});

  /// What the pieces have in common, such as "Las que más cambiaron".
  final String title;

  /// The components inside the card.
  final List<Widget> children;

  @override
  Widget build(BuildContext context) => Block(
    padding: const EdgeInsets.fromLTRB(18, 16, 18, 10),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        Text(title, style: context.type.titleMedium),
        const SizedBox(height: 6),
        ...children,
      ],
    ),
  );
}
