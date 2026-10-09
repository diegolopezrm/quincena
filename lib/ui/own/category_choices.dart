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
    final String? typed = await showDialog<String>(
      context: context,
      builder: (BuildContext context) => const _NewCategoryDialog(),
    );
    if (typed == null || typed.trim().isEmpty) return;
    final CategoryItem created = await own.store.addCategory(
      typed.trim(),
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

/// Asks the name of a new category. It keeps its own field: the field is
/// still on screen while the dialog closes, after its answer is back.
class _NewCategoryDialog extends StatefulWidget {
  const _NewCategoryDialog();

  @override
  State<_NewCategoryDialog> createState() => _NewCategoryDialogState();
}

class _NewCategoryDialogState extends State<_NewCategoryDialog> {
  final TextEditingController _name = TextEditingController();

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l = context.l10n;
    return AlertDialog(
      scrollable: true,
      title: Text(l.newCategory),
      content: TextField(
        controller: _name,
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
          onPressed: () => Navigator.of(context).pop(_name.text),
          child: Text(l.save),
        ),
      ],
    );
  }
}
