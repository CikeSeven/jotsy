import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:intl/intl.dart';
import 'package:node_diary/l10n/app_localizations.dart';

import '../../../app/theme/app_spacing.dart';
import '../../../app/theme/expressive_motion.dart';
import '../../../core/database/app_database.dart';
import '../../widgets/app_modal/app_modal_bottom_sheet.dart';
import 'day_mood_picker.dart';

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

/// 长按面板里的一次选择：执行某个快捷操作，或设定 / 清除这天的心情。
sealed class CalendarDayChoice {
  const CalendarDayChoice();
}

/// 执行快捷操作 [action]。
final class CalendarDayActionChoice extends CalendarDayChoice {
  const CalendarDayActionChoice(this.action);

  final CalendarDayAction action;
}

/// 把这天的心情设为 [mood]；null 为清除。
final class CalendarDayMoodChoice extends CalendarDayChoice {
  const CalendarDayMoodChoice(this.mood);

  final DayMood? mood;
}

/// 长按日期弹出的快捷操作面板：标题为日期，其下是这天的心情（五个心情格，
/// 已记心情时标题行尾可清除），再下方为可执行的操作；返回所选的一项，取消
/// 返回 null。只负责选择，执行由页面控制器完成。点一个心情即选定并收起
/// 面板，日期格随即换成这个心情的样子。
///
/// [showCapsule] / [showAnniversary] 为 false 时隐藏对应操作（时间胶囊、
/// 纪念日功能关闭时隐藏入口，数据保留）；[showDayMood] 为 false（显示选项
/// 关掉了这天的心情）时不提供心情一组。“写日记”与“范围”始终保留，面板
/// 不会为空。
Future<CalendarDayChoice?> showCalendarDayActionsSheet(
  BuildContext context, {
  required DateTime day,
  required DateTime now,
  required bool isSelected,
  DayMood? dayMood,
  bool showDayMood = true,
  bool showCapsule = true,
  bool showAnniversary = true,
}) {
  final today = DateUtils.dateOnly(now);
  final isFuture = DateUtils.dateOnly(day).isAfter(today);
  return showAppModalBottomSheet<CalendarDayChoice>(
    context: context,
    useSafeArea: true,
    showDragHandle: true,
    // 加上心情一组后，五项操作全开时会超过默认 9/16 屏高的上限：按内容
    // 高度展开，矮屏（横屏）上超出时在面板内滚动。
    isScrollControlled: true,
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
          onTap: () =>
              Navigator.of(sheetContext).pop(CalendarDayActionChoice(value)),
        );
      }

      return SafeArea(
        top: false,
        child: SingleChildScrollView(
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
              if (showDayMood) ...<Widget>[
                _DayMoodSection(
                  dayMood: dayMood,
                  onChanged: (DayMood? mood) => Navigator.of(
                    sheetContext,
                  ).pop(CalendarDayMoodChoice(mood)),
                ),
                const Divider(
                  height: AppSpacing.l,
                  indent: AppSpacing.l,
                  endIndent: AppSpacing.l,
                ),
              ],
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
              if (isFuture && showCapsule)
                action(
                  CalendarDayAction.capsule,
                  FontAwesomeIcons.hourglassHalf,
                  l10n.calendarDayActionCapsule,
                  description: l10n.calendarDayActionCapsuleDescription,
                ),
              if (showAnniversary)
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

/// 面板里的“这天的心情”：标题行（已记心情时行尾“清除”）+ 五个心情格。
class _DayMoodSection extends StatelessWidget {
  const _DayMoodSection({required this.dayMood, required this.onChanged});

  final DayMood? dayMood;

  /// 选定的心情；null 为清除。
  final ValueChanged<DayMood?> onChanged;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.m),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          SizedBox(
            height: 40,
            child: Row(
              children: <Widget>[
                const SizedBox(width: AppSpacing.xs),
                Expanded(
                  child: Text(
                    l10n.calendarDayMoodTitle,
                    style: theme.textTheme.titleSmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                if (dayMood != null)
                  TextButton(
                    style: TextButton.styleFrom(
                      foregroundColor: theme.colorScheme.onSurfaceVariant,
                    ),
                    onPressed: () => onChanged(null),
                    child: Text(l10n.calendarDayMoodClear),
                  ),
              ],
            ),
          ),
          DayMoodPicker(selected: dayMood, onSelected: onChanged),
        ],
      ),
    );
  }
}
