import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:intl/intl.dart';
import 'package:node_diary/l10n/app_localizations.dart';

import '../../../app/theme/app_spacing.dart';
import '../../../app/theme/expressive_motion.dart';

/// 长按日期后可执行的快捷操作。
enum CalendarDayAction {
  /// 选中这一天（长按不会改变选中日）。
  view,

  /// 以这一天为发表日期写日记。
  write,

  /// 写一封在这一天解封的时间胶囊（仅未来日期）。
  capsule,

  /// 以这一天为起点选择日期范围，统计这段时间。
  range,

  /// 以这一天新建纪念日（未来日期为倒数日）。
  anniversary,
}

/// 长按日期弹出的快捷操作面板：标题为日期，下方为可执行的操作；返回所选
/// 操作，取消返回 null。只负责选择，执行由页面控制器完成。
Future<CalendarDayAction?> showCalendarDayActionsSheet(
  BuildContext context, {
  required DateTime day,
  required DateTime now,
  required bool isSelected,
}) {
  final today = DateUtils.dateOnly(now);
  final isFuture = DateUtils.dateOnly(day).isAfter(today);
  return showModalBottomSheet<CalendarDayAction>(
    context: context,
    useSafeArea: true,
    showDragHandle: true,
    // 底部面板默认滑入不读取系统“减少动态效果”；该模式下直接出现。
    sheetAnimationStyle: ExpressiveMotion.reduceMotion(context)
        ? AnimationStyle.noAnimation
        : null,
    builder: (BuildContext sheetContext) {
      final l10n = sheetContext.l10n;
      final theme = Theme.of(sheetContext);
      Widget action(
        CalendarDayAction value,
        FaIconData icon,
        String label, {
        String? description,
      }) {
        return ListTile(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          leading: FaIcon(icon, size: 18, color: theme.colorScheme.primary),
          title: Text(label),
          subtitle: description == null ? null : Text(description),
          onTap: () => Navigator.of(sheetContext).pop(value),
        );
      }

      return SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.s,
            0,
            AppSpacing.s,
            AppSpacing.l,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              Padding(
                padding: const EdgeInsets.fromLTRB(
                  AppSpacing.l,
                  0,
                  AppSpacing.l,
                  AppSpacing.s,
                ),
                child: Semantics(
                  header: true,
                  child: Text(
                    DateFormat.MMMEd(l10n.localeName).format(day),
                    style: theme.textTheme.titleLarge?.copyWith(
                      fontSize: 20,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ),
              if (!isSelected)
                action(
                  CalendarDayAction.view,
                  FontAwesomeIcons.eye,
                  l10n.calendarDayActionView,
                ),
              action(
                CalendarDayAction.write,
                FontAwesomeIcons.penToSquare,
                l10n.calendarDayActionWrite,
              ),
              if (isFuture)
                action(
                  CalendarDayAction.capsule,
                  FontAwesomeIcons.hourglassHalf,
                  l10n.calendarDayActionCapsule,
                  description: l10n.calendarDayActionCapsuleDescription,
                ),
              action(
                CalendarDayAction.anniversary,
                FontAwesomeIcons.heart,
                l10n.calendarDayActionAnniversary,
                description: isFuture
                    ? l10n.calendarDayActionCountdownDescription
                    : l10n.calendarDayActionAnniversaryDescription,
              ),
              action(
                CalendarDayAction.range,
                FontAwesomeIcons.arrowsLeftRight,
                l10n.calendarDayActionRange,
                description: l10n.calendarDayActionRangeDescription,
              ),
            ],
          ),
        ),
      );
    },
  );
}
