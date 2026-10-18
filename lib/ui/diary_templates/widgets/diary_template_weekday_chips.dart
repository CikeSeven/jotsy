import 'package:flutter/material.dart';
import 'package:node_diary/l10n/app_localizations.dart';

import '../../../app/theme/app_spacing.dart';
import '../viewmodels/diary_template_auto_labels.dart';

/// 周一到周日一排 `FilterChip`，可多选。模板编辑页的推荐星期与自动套用
/// 时间段的星期共用它，两处看起来、点起来一样。
class DiaryTemplateWeekdayChips extends StatelessWidget {
  const DiaryTemplateWeekdayChips({
    super.key,
    required this.selected,
    required this.onChanged,
  });

  /// 选中的星期（`DateTime.weekday`，1 = 周一 … 7 = 周日）。
  final Set<int> selected;
  final ValueChanged<Set<int>> onChanged;

  @override
  Widget build(BuildContext context) {
    final localeName = context.l10n.localeName;
    return Wrap(
      spacing: AppSpacing.s,
      runSpacing: AppSpacing.s,
      children: <Widget>[
        for (var weekday = 1; weekday <= 7; weekday++)
          FilterChip(
            label: Text(diaryTemplateWeekdayLabel(localeName, weekday)),
            selected: selected.contains(weekday),
            onSelected: (on) => onChanged(
              Set<int>.unmodifiable(
                on
                    ? <int>{...selected, weekday}
                    : selected.difference({weekday}),
              ),
            ),
          ),
      ],
    );
  }
}
