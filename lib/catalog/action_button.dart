import 'package:flutter/material.dart';
import 'package:genui/genui.dart';
import 'package:genui_gen/genui_gen.dart';

import 'tone.dart';

part 'action_button.genui.dart';

/// A button that sends something back.
@GenUiWidget(
  description:
      'A full-width button that sends an event back to you, such as saving a '
      'form. Put the primary one last. Include in the event context whatever '
      'you need to act on it, bound to the data paths the form wrote.',
)
class ActionButton extends StatelessWidget {
  const ActionButton({
    super.key,
    required this.label,
    this.emphasis = Emphasis.primary,
    @GenUiAction(eventName: 'submit') this.onPressed,
  });

  /// What pressing it does, as a verb: "Guardar", "Apartar cada quincena".
  final String label;

  /// `primary` for the main action of the surface, `secondary` for the rest.
  final Emphasis emphasis;

  /// What happens when it is pressed.
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    final Widget text = Text(label);
    return Padding(
      padding: const EdgeInsets.only(top: 6),
      child: SizedBox(
        width: double.infinity,
        child: switch (emphasis) {
          Emphasis.primary => FilledButton(onPressed: onPressed, child: text),
          Emphasis.secondary => OutlinedButton(
            onPressed: onPressed,
            child: text,
          ),
        },
      ),
    );
  }
}
