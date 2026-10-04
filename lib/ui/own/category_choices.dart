import 'package:flutter/material.dart';

import '../../domain/records.dart';
import '../../l10n/l10n.dart';
import '../../own/own_controller.dart';
import '../icons.dart';
import 'look.dart';

/// The categories of an expense, or of an income when [income], as chips
/// to pick one, with a way to make a new one.
class CategoryChoices extends StatelessWidget {
  const CategoryChoices({
    super.key,
    required this.own,
    required this.income,
    required this.selected,
    required this.onChanged,
  });

  final OwnController own;
  final bool income;
  final String? selected;
  final ValueChanged<String?> onChanged;

  Future<void> _newCategory(BuildContext context) async {
    final AppLocalizations l = context.l10n;
    final TextEditingController name = TextEditingController();
    final String? typed = await showDialog<String>(
      context: context,
      builder: (BuildContext context) => AlertDialog(
        title: Text(l.newCategory),
        content: TextField(
          controller: name,
          autofocus: true,
          textCapitalization: TextCapitalization.sentences,
          decoration: InputDecoration(labelText: l.accountName),
          onSubmitted: (String v) => Navigator.of(context).pop(v),
        ),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text(l.cancel),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(name.text),
            child: Text(l.save),
          ),
        ],
      ),
    );
    name.dispose();
    if (typed == null || typed.trim().isEmpty) return;
    final CategoryItem created = await own.store.addCategory(
      typed,
      income: income,
    );
    onChanged(created.key);
  }

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l = context.l10n;
    final List<CategoryItem> categories = <CategoryItem>[
      for (final CategoryItem c in own.categories)
        if (!c.archived && c.income == income) c,
    ];
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: <Widget>[
        for (final CategoryItem c in categories)
          ChoiceChip(
            avatar: Icon(
              categoryIconFor(c.key),
              size: 18,
              color: categoryColorFor(context, c.key),
            ),
            label: Text(categoryNameFor(context, c.key, own.categories)),
            selected: selected == c.key,
            onSelected: (bool on) => onChanged(on ? c.key : null),
          ),
        ActionChip(
          avatar: const Icon(Glyph.plus, size: 18),
          label: Text(l.newCategory),
          onPressed: () => _newCategory(context),
        ),
      ],
    );
  }
}
