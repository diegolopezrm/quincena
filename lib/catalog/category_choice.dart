import 'package:flutter/material.dart';
import 'package:genui/genui.dart';
import 'package:genui_gen/genui_gen.dart';

import '../data/category.dart';
import '../theme/tokens.dart';
import '../ui/kit.dart';

part 'category_choice.genui.dart';

/// Which category a payment goes in.
@GenUiWidget(
  description:
      'Chips for choosing one spending category. Bind `value` to a data path '
      'and the choice is written there. Preselect the category you inferred '
      'from what the person said.',
)
class CategoryChoice extends StatelessWidget {
  const CategoryChoice({
    super.key,
    required this.label,
    required this.value,
    @GenUiWrites('value') this.onChanged,
  });

  /// The caption above the chips, such as "Categoría".
  final String label;

  /// The chosen category.
  final Category value;

  /// Called with the category the person picked.
  final ValueChanged<Category>? onChanged;

  static const List<Category> _offered = <Category>[
    Category.groceries,
    Category.restaurants,
    Category.transport,
    Category.shopping,
    Category.leisure,
    Category.health,
    Category.utilities,
    Category.other,
  ];

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
              for (final Category c in _offered)
                ChoiceChip(
                  selected: c == value,
                  onSelected: onChanged == null ? null : (_) => onChanged!(c),
                  avatar: Icon(
                    c.icon,
                    size: 18,
                    color: c == value
                        ? c.color(context)
                        : context.colors.inkSoft,
                  ),
                  label: Text(c.label),
                  selectedColor: c.color(context).withValues(alpha: 0.16),
                  side: BorderSide(
                    color: c == value ? c.color(context) : context.colors.line,
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }
}
