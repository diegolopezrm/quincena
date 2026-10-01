import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:genui/genui.dart';
import 'package:genui_gen/genui_gen.dart';
import 'package:intl/intl.dart';

import '../theme/theme.dart';
import '../theme/tokens.dart';

part 'money_field.genui.dart';

final NumberFormat _grouped = NumberFormat('#,##0', 'es_CO');

/// An amount of pesos the person types.
@GenUiWidget(
  description:
      'An input for an amount of pesos, grouped with dots as it is typed. '
      'Bind `value` to a data path and the field writes the number there. '
      'Attach `checks` to validate it, such as a minimum with the `numeric` '
      'function; the message of the first failing rule shows under the field.',
)
class MoneyField extends StatefulWidget {
  const MoneyField({
    super.key,
    required this.label,
    required this.value,
    @GenUiWrites('value') this.onChanged,
    @GenUiChecked() this.error,
  });

  /// The caption above the field, such as "Monto".
  final String label;

  /// The amount in the field, in pesos. Zero shows an empty field.
  final double value;

  /// Called with the new amount as the person types.
  final ValueChanged<double>? onChanged;

  /// The message of the first failing check, or null while all pass.
  final String? error;

  @override
  State<MoneyField> createState() => _MoneyFieldState();
}

class _MoneyFieldState extends State<MoneyField> {
  late final TextEditingController _text = TextEditingController(
    text: _show(widget.value),
  );

  static String _show(double value) =>
      value <= 0 ? '' : _grouped.format(value.round());

  @override
  void didUpdateWidget(MoneyField old) {
    super.didUpdateWidget(old);
    // Follow a value that changed from outside, without fighting the
    // person's own typing.
    final double typed = _parse(_text.text);
    if (widget.value != typed) _text.text = _show(widget.value);
  }

  static double _parse(String text) =>
      double.tryParse(text.replaceAll(RegExp(r'[^0-9]'), '')) ?? 0;

  @override
  void dispose() {
    _text.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: TextField(
        controller: _text,
        keyboardType: TextInputType.number,
        inputFormatters: <TextInputFormatter>[
          FilteringTextInputFormatter.digitsOnly,
          LengthLimitingTextInputFormatter(11),
          TextInputFormatter.withFunction((
            TextEditingValue old,
            TextEditingValue next,
          ) {
            final String formatted = _show(_parse(next.text));
            return TextEditingValue(
              text: formatted,
              selection: TextSelection.collapsed(offset: formatted.length),
            );
          }),
        ],
        style: context.type.headlineSmall?.copyWith(fontFeatures: tabular),
        onChanged: (String text) => widget.onChanged?.call(_parse(text)),
        decoration: InputDecoration(
          labelText: widget.label,
          prefixText: r'$ ',
          prefixStyle: context.type.headlineSmall?.copyWith(
            color: context.colors.inkFaint,
          ),
          errorText: widget.error,
        ),
      ),
    );
  }
}
