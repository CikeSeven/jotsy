import 'dart:async';

import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:node_diary/l10n/app_localizations.dart';

import '../../../core/services/app_platform.dart';
import '../../settings/widgets/settings_card_group.dart';
import '../../settings/widgets/settings_nav_tile.dart';
import '../../settings/widgets/settings_option_tiles.dart';
import '../../settings/widgets/settings_reveal.dart';
import '../models/todo_settings.dart';
import '../providers/todo_reminder_providers.dart';
import '../widgets/todo_labels.dart';
import '../widgets/todo_sheet.dart';

/// 待办设置里的“提醒”分组：通知权限（手机）、电池优化（Android）、全天
/// 待办的提醒时刻、稍后提醒时长、每日摘要（开关 + 时刻）、锁屏隐藏内容
/// （Android）与“提醒不准时？”（Android）；桌面组尾写明只在应用运行时
/// 提醒（每日摘要同样）。
///
/// 打开每日摘要时先经 [onRequestPermission] 请求一次发通知的权限（与第一次
/// 加提醒时一样，不在启动时问）；拒绝了照样存下开关，权限行会标出关着。
class TodoRemindersSettingsGroup extends StatelessWidget {
  const TodoRemindersSettingsGroup({
    super.key,
    required this.settings,
    required this.status,
    required this.onSave,
    required this.onRequestPermission,
    required this.onFixPermission,
    required this.onFixExactAlarm,
    required this.onFixBattery,
    required this.onShowReliability,
  });

  final TodoSettings settings;
  final TodoReminderSystemStatus? status;

  /// 设置服务还没就绪时为 null（各行不可点）。
  final Future<void> Function(TodoSettings next)? onSave;
  final Future<void> Function() onRequestPermission;
  final VoidCallback onFixPermission;
  final VoidCallback onFixExactAlarm;
  final VoidCallback onFixBattery;
  final VoidCallback onShowReliability;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final scheme = Theme.of(context).colorScheme;
    final save = onSave;
    final status = this.status;
    final background = AppPlatform.supportsBackgroundReminders;
    final digestMinute = settings.digestMinute;

    Future<int?> pickTime(int minute) async {
      final picked = await showTimePicker(
        context: context,
        initialTime: TimeOfDay(hour: minute ~/ 60, minute: minute % 60),
      );
      return picked == null ? null : picked.hour * 60 + picked.minute;
    }

    Future<void> pickAllDayTime() async {
      final minute = await pickTime(settings.allDayReminderMinute);
      if (minute == null || save == null) return;
      await save(settings.copyWith(allDayReminderMinute: minute));
    }

    Future<void> pickDigestTime() async {
      final minute = await pickTime(
        digestMinute ?? TodoSettings.defaultDigestMinute,
      );
      if (minute == null || save == null) return;
      await save(settings.copyWith(digestMinute: minute));
    }

    Future<void> toggleDigest(bool on) async {
      if (save == null) return;
      if (!on) {
        await save(settings.copyWith(clearDigest: true));
        return;
      }
      await save(
        settings.copyWith(digestMinute: TodoSettings.defaultDigestMinute),
      );
      await onRequestPermission();
    }

    Future<void> pickSnooze() async {
      final minutes = await showTodoSheet<int>(
        context: context,
        builder: (BuildContext sheetContext) => TodoSheetBody(
          title: l10n.todoSettingsSnooze,
          children: <Widget>[
            for (final value in TodoSettings.snoozeChoices)
              TodoSheetOption(
                icon: FontAwesomeIcons.clock,
                label: l10n.todoSettingsSnoozeMinutes(value),
                selected: value == settings.snoozeMinutes,
                onTap: () => Navigator.of(sheetContext).pop(value),
              ),
          ],
        ),
      );
      if (minutes == null || save == null) return;
      await save(settings.copyWith(snoozeMinutes: minutes));
    }

    return SettingsCardGroup(
      title: l10n.todoSettingsRemindersGroup,
      footer: background ? null : l10n.todoSettingsDesktopNote,
      children: <Widget>[
        if (background)
          SettingsNavTile(
            icon: FontAwesomeIcons.bell,
            title: l10n.todoSettingsPermission,
            value: status == null
                ? null
                : status.notifications
                ? l10n.todoSettingsPermissionOn
                : l10n.todoSettingsPermissionOff,
            subtitle: status != null && status.notifications && !status.exact
                ? l10n.todoSettingsExactOff
                : null,
            subtitleColor: scheme.error,
            onTap: status == null
                ? null
                : !status.notifications
                ? onFixPermission
                : !status.exact
                ? onFixExactAlarm
                : null,
          ),
        if (AppPlatform.isAndroid)
          SettingsNavTile(
            icon: FontAwesomeIcons.bolt,
            title: l10n.todoSettingsBattery,
            value: status == null
                ? null
                : status.ignoringBattery
                ? l10n.todoSettingsBatteryUnrestricted
                : l10n.todoSettingsBatteryRestricted,
            subtitle: status != null && !status.ignoringBattery
                ? l10n.todoSettingsBatterySubtitle
                : null,
            subtitleColor: scheme.error,
            onTap: onFixBattery,
          ),
        SettingsNavTile(
          icon: FontAwesomeIcons.clock,
          title: l10n.todoSettingsAllDayTime,
          value: TodoLabels.formatTodoTime(
            context,
            settings.allDayReminderMinute,
          ),
          onTap: save == null ? null : () => unawaited(pickAllDayTime()),
        ),
        SettingsNavTile(
          icon: FontAwesomeIcons.stopwatch,
          title: l10n.todoSettingsSnooze,
          value: l10n.todoSettingsSnoozeMinutes(settings.snoozeMinutes),
          onTap: save == null ? null : () => unawaited(pickSnooze()),
        ),
        // 开关与它下面的时刻合成分组里的同一项（见 SettingsReveal）。
        Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            SettingsSwitchTile(
              title: l10n.todoSettingsDigest,
              subtitle: l10n.todoSettingsDigestSubtitle,
              value: digestMinute != null,
              onChanged: save == null
                  ? null
                  : (bool on) => unawaited(toggleDigest(on)),
            ),
            SettingsReveal(
              visible: digestMinute != null,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  const SettingsCardGroupDivider(),
                  SettingsNavTile(
                    icon: FontAwesomeIcons.sun,
                    title: l10n.todoSettingsDigestTime,
                    value: TodoLabels.formatTodoTime(
                      context,
                      digestMinute ?? TodoSettings.defaultDigestMinute,
                    ),
                    onTap: save == null
                        ? null
                        : () => unawaited(pickDigestTime()),
                  ),
                ],
              ),
            ),
          ],
        ),
        if (AppPlatform.supportsNotificationVisibility)
          SettingsSwitchTile(
            title: l10n.todoSettingsHideContent,
            subtitle: l10n.todoSettingsHideContentSubtitle,
            value: settings.hideContentOnLockScreen,
            onChanged: save == null
                ? null
                : (bool value) => unawaited(
                    save(settings.copyWith(hideContentOnLockScreen: value)),
                  ),
          ),
        if (AppPlatform.isAndroid)
          SettingsNavTile(
            icon: FontAwesomeIcons.circleQuestion,
            title: l10n.todoSettingsReliability,
            onTap: onShowReliability,
          ),
      ],
    );
  }
}
