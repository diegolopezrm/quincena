import 'package:flutter/material.dart';

import '../../domain/categories.dart';
import '../../domain/records.dart';
import '../../l10n/l10n.dart';
import '../../own/own_controller.dart';
import '../../theme/tokens.dart';
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
    final (String, OwnCategoryLook)? typed =
        await showDialog<(String, OwnCategoryLook)>(
          context: context,
          builder: (BuildContext context) => const _NewCategoryDialog(),
        );
    if (typed == null || typed.$1.trim().isEmpty) return;
    final CategoryItem created = await own.store.addCategory(
      typed.$1.trim(),
      income: income,
    );
    await own.saveCategoryLook(created.key, typed.$2);
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

/// Asks the name of a new category, and its icon and color, so it reads
/// apart from the rest in every list. It keeps its own field: the field is
/// still on screen while the dialog closes, after its answer is back.
class _NewCategoryDialog extends StatefulWidget {
  const _NewCategoryDialog();

  @override
  State<_NewCategoryDialog> createState() => _NewCategoryDialogState();
}

class _NewCategoryDialogState extends State<_NewCategoryDialog> {
  final TextEditingController _name = TextEditingController();
  String _icon = 'tag';
  String? _color;

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  void _done() => Navigator.of(context).pop((
    _name.text,
    OwnCategoryLook(
      icon: _icon,
      color: _color ?? defaultCategoryColor(_name.text, context.colors),
    ),
  ));

  /// One choice in a row of them: a round button, ringed when chosen.
  Widget _choice({
    required bool chosen,
    required String label,
    required VoidCallback onTap,
    required Widget child,
    Color? fill,
  }) => Semantics(
    button: true,
    selected: chosen,
    label: label,
    child: InkWell(
      onTap: onTap,
      customBorder: const CircleBorder(),
      child: Container(
        width: 44,
        height: 44,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: fill ?? (chosen ? context.colors.brandSoft : null),
          border: Border.all(
            color: chosen ? context.colors.ink : context.colors.line,
            width: chosen ? 2.5 : 1,
          ),
        ),
        child: ExcludeSemantics(child: child),
      ),
    ),
  );

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l = context.l10n;
    final QuincenaColors c = context.colors;
    final String color = _color ?? defaultCategoryColor(_name.text, c);
    return AlertDialog(
      scrollable: true,
      title: Text(l.newCategory),
      content: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          TextField(
            controller: _name,
            autofocus: true,
            textCapitalization: TextCapitalization.sentences,
            decoration: InputDecoration(labelText: l.accountName),
            onChanged: (_) => setState(() {}),
            onSubmitted: (_) => _done(),
          ),
          const SizedBox(height: 16),
          Text(l.categoryIcon, style: context.type.labelMedium),
          const SizedBox(height: 8),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: <Widget>[
              for (final MapEntry<String, IconData> e
                  in categoryIconChoices.entries)
                _choice(
                  chosen: _icon == e.key,
                  label: l.categoryIconName(e.key),
                  onTap: () => setState(() => _icon = e.key),
                  child: Icon(e.value, size: 20, color: c.categories[color]),
                ),
            ],
          ),
          const SizedBox(height: 16),
          Text(l.categoryColor, style: context.type.labelMedium),
          const SizedBox(height: 8),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: <Widget>[
              for (final (int i, String key) in c.categories.keys.indexed)
                _choice(
                  chosen: color == key,
                  label: l.categoryColorNumber(i + 1),
                  onTap: () => setState(() => _color = key),
                  fill: c.categories[key],
                  child: const SizedBox.shrink(),
                ),
            ],
          ),
        ],
      ),
      actions: <Widget>[
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(l.cancel),
        ),
        TextButton(onPressed: _done, child: Text(l.save)),
      ],
    );
  }
}
