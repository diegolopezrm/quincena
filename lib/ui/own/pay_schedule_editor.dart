import 'package:flutter/material.dart';

import '../../domain/pay_schedule.dart';
import '../../format/dates.dart';
import '../../l10n/l10n.dart';
import '../../theme/tokens.dart';
import '../icons.dart';
import '../kit.dart';

/// Picks how the person gets paid.
class PayScheduleEditor extends StatefulWidget {
  const PayScheduleEditor({
    super.key,
    required this.value,
    required this.onChanged,
    required this.today,
  });

  final PaySchedule value;
  final ValueChanged<PaySchedule> onChanged;
  final DateTime today;

  @override
  State<PayScheduleEditor> createState() => _PayScheduleEditorState();
}

enum _Kind { twice, monthly, biweekly, weekly }

class _PayScheduleEditorState extends State<PayScheduleEditor> {
  late TwiceMonthly _twice = widget.value is TwiceMonthly
      ? widget.value as TwiceMonthly
      : const TwiceMonthly();
  late Monthly _monthly = widget.value is Monthly
      ? widget.value as Monthly
      : const Monthly(30);
  late EveryTwoWeeks _biweekly = widget.value is EveryTwoWeeks
      ? widget.value as EveryTwoWeeks
      : EveryTwoWeeks(widget.today);
  late Weekly _weekly = widget.value is Weekly
      ? widget.value as Weekly
      : const Weekly(DateTime.friday);

  _Kind get _kind => switch (widget.value) {
    TwiceMonthly() => _Kind.twice,
    Monthly() => _Kind.monthly,
    EveryTwoWeeks() => _Kind.biweekly,
    Weekly() => _Kind.weekly,
  };

  PaySchedule _of(_Kind kind) => switch (kind) {
    _Kind.twice => _twice,
    _Kind.monthly => _monthly,
    _Kind.biweekly => _biweekly,
    _Kind.weekly => _weekly,
  };

  Widget _days(
    int value,
    int from,
    int to,
    ValueChanged<int> onChanged,
    String label,
  ) => DropdownButtonFormField<int>(
    icon: const Icon(Glyph.caretDown, size: 18),
    initialValue: value,
    // Within its half of the row, whatever the text size.
    isExpanded: true,
    decoration: InputDecoration(labelText: label),
    items: <DropdownMenuItem<int>>[
      for (var d = from; d <= to; d++)
        DropdownMenuItem<int>(
          value: d,
          child: Text(context.l10n.payDayOption(d)),
        ),
    ],
    onChanged: (int? d) {
      if (d != null) onChanged(d);
    },
  );

  Widget _option(_Kind kind, String title, String detail) {
    final bool selected = _kind == kind;
    // One choice to a screen reader: its radio says what it picks.
    return MergeSemantics(
      child: Material(
        color: selected ? context.colors.brandSoft : context.colors.surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(
            color: selected ? context.colors.brand : context.colors.line,
            width: selected ? 1.5 : 1,
          ),
        ),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: () => widget.onChanged(_of(kind)),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
            child: Row(
              children: <Widget>[
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Text(title, style: context.type.titleSmall),
                      const SizedBox(height: 2),
                      Text(detail, style: context.type.bodySmall),
                    ],
                  ),
                ),
                Radio<_Kind>(value: kind),
              ],
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l = context.l10n;
    final _Kind kind = _kind;
    final Widget firstDay = _days(_twice.first, 1, 27, (int d) {
      _twice = TwiceMonthly(
        first: d,
        second: d < _twice.second ? _twice.second : 30,
      );
      widget.onChanged(_twice);
    }, l.payFirstDay);
    final Widget secondDay = _days(_twice.second, _twice.first + 1, 31, (
      int d,
    ) {
      _twice = TwiceMonthly(first: _twice.first, second: d);
      widget.onChanged(_twice);
    }, l.paySecondDay);
    return RadioGroup<_Kind>(
      groupValue: kind,
      onChanged: (_Kind? k) {
        if (k != null) widget.onChanged(_of(k));
      },
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          _option(
            _Kind.twice,
            l.payTwiceMonthly,
            l.payTwiceMonthlyDetail(
              dayOfMonth(_twice.first),
              dayOfMonth(_twice.second),
            ),
          ),
          if (kind == _Kind.twice)
            Padding(
              padding: const EdgeInsets.fromLTRB(4, 12, 4, 4),
              // With large text one under the other, each label whole.
              child: largeText(context)
                  ? Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      spacing: 12,
                      children: <Widget>[firstDay, secondDay],
                    )
                  : Row(
                      children: <Widget>[
                        Expanded(child: firstDay),
                        const SizedBox(width: 12),
                        Expanded(child: secondDay),
                      ],
                    ),
            ),
          const SizedBox(height: 10),
          _option(
            _Kind.monthly,
            l.payMonthly,
            l.payMonthlyDetail(dayOfMonth(_monthly.day)),
          ),
          if (kind == _Kind.monthly)
            Padding(
              padding: const EdgeInsets.fromLTRB(4, 12, 4, 4),
              child: _days(_monthly.day, 1, 31, (int d) {
                _monthly = Monthly(d);
                widget.onChanged(_monthly);
              }, l.payDay),
            ),
          const SizedBox(height: 10),
          _option(
            _Kind.biweekly,
            l.payBiweekly,
            l.payBiweeklyDetail(shortDate(_biweekly.anchor)),
          ),
          if (kind == _Kind.biweekly)
            Padding(
              padding: const EdgeInsets.fromLTRB(4, 12, 4, 4),
              child: OutlinedButton(
                onPressed: () async {
                  final DateTime? picked = await showDatePicker(
                    context: context,
                    initialDate: _biweekly.anchor,
                    firstDate: widget.today.subtract(const Duration(days: 60)),
                    lastDate: widget.today.add(const Duration(days: 30)),
                    helpText: l.payLastPayday,
                  );
                  if (picked == null) return;
                  _biweekly = EveryTwoWeeks(picked);
                  widget.onChanged(_biweekly);
                },
                child: Text(
                  '${l.payLastPayday}: ${shortDate(_biweekly.anchor)}',
                ),
              ),
            ),
          const SizedBox(height: 10),
          _option(
            _Kind.weekly,
            l.payWeekly,
            l.payWeeklyDetail(weekdayName(_weekly.weekday)),
          ),
          if (kind == _Kind.weekly)
            Padding(
              padding: const EdgeInsets.fromLTRB(4, 12, 4, 4),
              child: DropdownButtonFormField<int>(
                icon: const Icon(Glyph.caretDown, size: 18),
                initialValue: _weekly.weekday,
                decoration: InputDecoration(labelText: l.payWeekday),
                items: <DropdownMenuItem<int>>[
                  for (var d = 1; d <= 7; d++)
                    DropdownMenuItem<int>(
                      value: d,
                      child: Text(weekdayName(d)),
                    ),
                ],
                onChanged: (int? d) {
                  if (d == null) return;
                  _weekly = Weekly(d);
                  widget.onChanged(_weekly);
                },
              ),
            ),
        ],
      ),
    );
  }
}
