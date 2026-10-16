import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:node_diary/l10n/app_localizations.dart';

import '../../../app/theme/app_spacing.dart';
import '../viewmodels/anniversary_calendar_index.dart';
import 'anniversary_labels.dart';

/// 选中日纪念日卡片里的一行：圆底图标 + 名称 + 这一次是什么。
///
/// 当天就是纪念日时副标题用 tertiary 加粗（与日历“今天”同一色相），其余
/// 日子弱化。天数不在这里重复写：选中日标题已有“N 天后/前”。
class AnniversaryTile extends StatelessWidget {
  const AnniversaryTile({
    super.key,
    required this.mark,
    required this.today,
    this.onTap,
    this.trailing,
  });

  final AnniversaryDayMark mark;
  final DateTime today;
  final VoidCallback? onTap;

  /// 行尾附加操作（如打开关联的日记），在箭头之前。
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final isToday = DateUtils.isSameDay(mark.occurrence.date, today);
    final trailing = this.trailing;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.m,
          vertical: AppSpacing.s,
        ),
        child: Row(
          children: <Widget>[
            Container(
              width: 36,
              height: 36,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: colorScheme.tertiaryContainer,
                shape: BoxShape.circle,
              ),
              child: FaIcon(
                AnniversaryLabels.iconFor(mark.rule),
                size: 15,
                color: colorScheme.onTertiaryContainer,
              ),
            ),
            const SizedBox(width: AppSpacing.m),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  Text(
                    mark.row.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    AnniversaryLabels.dayLine(l10n, mark, today),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: isToday
                          ? colorScheme.tertiary
                          : colorScheme.onSurfaceVariant,
                      fontWeight: isToday ? FontWeight.w600 : null,
                    ),
                  ),
                ],
              ),
            ),
            ?trailing,
            const SizedBox(width: AppSpacing.xs),
            FaIcon(
              FontAwesomeIcons.angleRight,
              size: 14,
              color: colorScheme.onSurfaceVariant,
            ),
          ],
        ),
      ),
    );
  }
}
