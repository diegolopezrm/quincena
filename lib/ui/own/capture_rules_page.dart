import 'package:flutter/material.dart';

import '../../capture/inbox.dart';
import '../../domain/records.dart';
import '../../l10n/l10n.dart';
import '../../own/own_controller.dart';
import '../../theme/tokens.dart';
import '../icons.dart';
import '../kit.dart';
import 'capture_reasons.dart';
import 'look.dart';

/// What the app learned from what the person confirmed, as rules to read,
/// change, turn off or delete. A rule only shapes what arrives after it.
class CaptureRulesPage extends StatelessWidget {
  const CaptureRulesPage({super.key, required this.own});

  final OwnController own;

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: own,
    builder: (BuildContext context, _) {
      final AppLocalizations l = context.l10n;
      final List<CaptureRule> rules = own.captureSettings.rules;
      List<CaptureRule> of(RuleKind kind) => <CaptureRule>[
        for (final CaptureRule r in rules)
          if (r.kind == kind) r,
      ]..sort((CaptureRule a, CaptureRule b) => a.key.compareTo(b.key));
      return Scaffold(
        appBar: AppBar(
          backgroundColor: context.colors.canvas,
          surfaceTintColor: Colors.transparent,
          title: Text(l.rulesTitle, style: context.type.titleLarge),
        ),
        body: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 640),
            child: ListView(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
              children: <Widget>[
                Text(l.rulesBody, style: context.type.bodyMedium),
                const SizedBox(height: 20),
                // Someone with movements had rules, or will: the first
                // movements are not what is missing.
                if (rules.isEmpty)
                  Block(
                    child: Text(
                      (own.snapshot?.entries ?? const <Entry>[]).isEmpty
                          ? l.rulesEmpty
                          : l.rulesEmptyWithMovements,
                      style: context.type.bodyMedium,
                    ),
                  ),
                for (final (RuleKind kind, String label)
                    in <(RuleKind, String)>[
                      (RuleKind.merchant, l.rulesMerchants),
                      (RuleKind.card, l.rulesCards),
                      (RuleKind.institution, l.rulesInstitutions),
                    ])
                  if (of(kind).isNotEmpty) ...<Widget>[
                    SectionLabel(label),
                    Panel(
                      indent: 16,
                      children: <Widget>[
                        for (final CaptureRule r in of(kind))
                          _RuleRow(own: own, rule: r),
                      ],
                    ),
                    const SizedBox(height: 20),
                  ],
              ],
            ),
          ),
        ),
      );
    },
  );
}

class _RuleRow extends StatelessWidget {
  const _RuleRow({required this.own, required this.rule});

  final OwnController own;
  final CaptureRule rule;

  Future<void> _save(CaptureSettings s) => own.store.saveCaptureSettings(s);

  Future<void> _change(BuildContext context) async {
    final AppLocalizations l = context.l10n;
    final List<(String, String)> choices = rule.kind == RuleKind.merchant
        ? <(String, String)>[
            for (final CategoryItem c in own.categories)
              if (!c.archived)
                (c.key, categoryNameFor(context, c.key, own.categories)),
          ]
        : <(String, String)>[
            for (final Account a in own.accounts)
              if (!a.archived) (a.id, a.name),
          ];
    final String? picked = await showDialog<String>(
      context: context,
      builder: (BuildContext context) => SimpleDialog(
        title: Text(
          rule.kind == RuleKind.merchant
              ? l.ruleChooseCategory
              : l.ruleChooseAccount,
        ),
        children: <Widget>[
          for (final (String value, String name) in choices)
            SimpleDialogOption(
              onPressed: () => Navigator.of(context).pop(value),
              child: Row(
                children: <Widget>[
                  Expanded(child: Text(name)),
                  if (value == rule.target)
                    Icon(Glyph.check, size: 18, color: context.colors.brand),
                ],
              ),
            ),
        ],
      ),
    );
    if (picked == null || picked == rule.target) return;
    await _save(own.captureSettings.withRule(rule.copyWith(target: picked)));
  }

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l = context.l10n;
    final String target = ruleTarget(context, own, rule);
    return ListTile(
      contentPadding: const EdgeInsets.fromLTRB(16, 4, 4, 4),
      onTap: () => _change(context),
      title: Text(ruleSubject(context, rule), style: context.type.titleSmall),
      subtitle: Text(
        '→ $target',
        style: context.type.bodySmall?.copyWith(
          decoration: rule.enabled ? null : TextDecoration.lineThrough,
        ),
      ),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Semantics(
            label: '${l.ruleOn}: ${ruleSubject(context, rule)}',
            child: Switch(
              value: rule.enabled,
              onChanged: (bool on) => _save(
                own.captureSettings.withRule(rule.copyWith(enabled: on)),
              ),
            ),
          ),
          IconButton(
            tooltip: l.ruleDelete,
            onPressed: () => _save(own.captureSettings.withoutRule(rule)),
            icon: Icon(Glyph.trash, size: 18, color: context.colors.inkFaint),
          ),
        ],
      ),
    );
  }
}
