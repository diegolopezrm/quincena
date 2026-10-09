import 'package:flutter/material.dart';

import '../domain/categories.dart';
import '../format/dates.dart';
import '../l10n/l10n.dart';
import '../session/session.dart';
import '../theme/tokens.dart';
import 'icons.dart';

/// What a computation worked out, the way a person would say it.
String computedLabel(BuildContext context, Computed c) {
  final AppLocalizations l = context.l10n;
  final String lang = Localizations.localeOf(context).languageCode;
  String month() {
    final List<String> parts = '${c.arguments['month'] ?? ''}'.split('-');
    final int? year = parts.isNotEmpty ? int.tryParse(parts.first) : null;
    final int? number = parts.length > 1 ? int.tryParse(parts[1]) : null;
    if (year == null || number == null) return '${c.arguments['month'] ?? ''}';
    return monthYear(DateTime(year, number));
  }

  return switch (c.tool) {
    'account_overview' => l.computedOverview,
    'month_spending' => l.computedMonth(month()),
    'category_payments' => l.computedCategory(
      categoryLabel('${c.arguments['category'] ?? ''}', lang),
      month(),
    ),
    'monthly_totals' => l.computedTotals,
    'subscriptions' => l.computedSubscriptions,
    'savings_goal' => l.computedGoal,
    'record_expense' => l.computedRecord,
    'expense_accounts' => l.computedExpenseAccounts,
    'save_goal_plan' => l.computedPlan,
    'accounts' => l.computedAccounts,
    'portfolio' => l.computedPortfolio,
    'can_i_buy' => l.computedBuy,
    'coming_days' => l.computedComing,
    'fortnight_close' => l.computedClose,
    'commitments' => l.computedCommitments,
    'owed_and_variable' => l.computedOwed,
    _ => c.tool,
  };
}

/// Shows what the phone worked out for an answer, and that every figure in
/// it came from there.
Future<void> showComputed(
  BuildContext context,
  List<Computed> computed, {
  VoidCallback? onExplainFree,
}) => showModalBottomSheet<void>(
  context: context,
  isScrollControlled: true,
  showDragHandle: true,
  useSafeArea: true,
  backgroundColor: context.colors.surface,
  constraints: const BoxConstraints(maxWidth: 640),
  builder: (BuildContext context) {
    final AppLocalizations l = context.l10n;
    // The same computation twice, as a model may ask again, shows once.
    final List<String> labels = <String>{
      for (final Computed c in computed) computedLabel(context, c),
    }.toList();
    final bool free = computed.any(
      (Computed c) => c.tool == 'account_overview',
    );
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(24, 0, 24, 32),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Text(l.computedTitle, style: context.type.headlineMedium),
          const SizedBox(height: 16),
          for (final String label in labels)
            Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Padding(
                    padding: const EdgeInsets.only(top: 2),
                    child: Icon(
                      Glyph.check,
                      size: 18,
                      color: context.colors.brand,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(child: Text(label, style: context.type.bodyMedium)),
                ],
              ),
            ),
          const SizedBox(height: 8),
          Text(
            l.computedFooter(dayAndTime(computed.first.at)),
            style: context.type.bodySmall,
          ),
          if (free && onExplainFree != null) ...<Widget>[
            const SizedBox(height: 16),
            OutlinedButton.icon(
              onPressed: () {
                Navigator.of(context).pop();
                onExplainFree();
              },
              icon: const Icon(Glyph.info, size: 18),
              label: Text(l.computedSeeFree),
            ),
          ],
        ],
      ),
    );
  },
);
