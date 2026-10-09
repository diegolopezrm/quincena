import 'package:flutter/material.dart';
import 'package:genui/genui.dart';
import 'package:genui_gen/genui_gen.dart';

import '../theme/tokens.dart';
import '../ui/icons.dart';

part 'account_choice.genui.dart';

/// Which account a payment comes from, said before it is saved and easy to
/// change.
@GenUiWidget(
  description:
      'Chips for choosing the account a payment comes from, one per name in '
      '`options`. Bind `value` to a data path and the choice is written '
      'there. Preselect the account the person named, or else the likely '
      'one expense_accounts gives.',
)
class AccountChoice extends StatelessWidget {
  const AccountChoice({
    super.key,
    required this.label,
    required this.options,
    required this.value,
    @GenUiWrites('value') this.onChanged,
  });

  /// The caption above the chips, such as "Desde".
  final String label;

  /// The accounts to choose from, named as the app names them.
  final List<String> options;

  /// The name of the chosen account.
  final String value;

  /// Called with the name of the account the person picked.
  final ValueChanged<String>? onChanged;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Text(label, style: context.type.labelMedium),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: <Widget>[
              for (final String name in options)
                ChoiceChip(
                  selected: name == value,
                  onSelected: onChanged == null
                      ? null
                      : (_) => onChanged!(name),
                  avatar: Icon(
                    Glyph.wallet,
                    size: 18,
                    color: name == value
                        ? context.colors.brand
                        : context.colors.inkSoft,
                  ),
                  label: Text(name),
                  selectedColor: context.colors.brandSoft,
                  side: BorderSide(
                    color: name == value
                        ? context.colors.brand
                        : context.colors.line,
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }
}
