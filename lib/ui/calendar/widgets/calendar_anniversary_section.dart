import 'package:flutter/material.dart';
import 'package:node_diary/l10n/app_localizations.dart';

import '../../../app/theme/app_effects.dart';
import '../../../app/theme/app_spacing.dart';
import '../../../app/theme/expressive_surfaces.dart';
import '../../anniversaries/viewmodels/anniversary_calendar_index.dart';
import '../../anniversaries/widgets/anniversary_tile.dart';

/// 选中日的纪念日卡片：当天的每条纪念日一行，点按打开。
///
/// 卡片外观与“那年今日”的小卡片同一套（20dp 圆角、卡片表面、0.8dp 微边框、
/// 静止阴影），多条之间用极细分割线。出现与消失的过渡由页面负责。
class CalendarAnniversarySection extends StatelessWidget {
  const CalendarAnniversarySection({
    super.key,
    required this.marks,
    required this.today,
    required this.onOpen,
    this.trailingBuilder,
  });

  final List<AnniversaryDayMark> marks;
  final DateTime today;
  final ValueChanged<AnniversaryDayMark> onOpen;

  /// 每行行尾的附加操作（如打开关联的日记）。
  final Widget? Function(AnniversaryDayMark mark)? trailingBuilder;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Semantics(
      container: true,
      label: context.l10n.anniversarySectionTitle,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: AppSpacing.xs),
        decoration: BoxDecoration(
          color: ExpressiveSurfaces.cardColor(colorScheme),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: ExpressiveSurfaces.cardBorderColor(colorScheme),
            width: 0.8,
          ),
          boxShadow: AppEffects.restingCardShadow(colorScheme),
        ),
        child: Material(
          type: MaterialType.transparency,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              for (var i = 0; i < marks.length; i++) ...<Widget>[
                if (i > 0)
                  Divider(
                    height: 0.6,
                    thickness: 0.6,
                    indent: AppSpacing.m + 36 + AppSpacing.m,
                    endIndent: AppSpacing.m,
                    color: colorScheme.outlineVariant.withValues(alpha: 0.25),
                  ),
                Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.xs,
                  ),
                  child: AnniversaryTile(
                    mark: marks[i],
                    today: today,
                    onTap: () => onOpen(marks[i]),
                    trailing: trailingBuilder?.call(marks[i]),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
