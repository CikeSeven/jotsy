import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:node_diary/l10n/app_localizations.dart';

import '../providers/todo_reminder_providers.dart';
import 'todo_sheet.dart';

/// 展示 Android 后台提醒权限检查清单的底部面板：每项实时显示状态并支持一键跳转修复。
Future<void> showTodoReliabilitySheet(
  BuildContext context, {
  required Future<void> Function() onFixNotification,
  required Future<void> Function() onFixExactAlarm,
  required Future<void> Function() onFixBattery,
  required Future<void> Function() onOpenAutoStart,
}) => showTodoSheet<void>(
  context: context,
  builder: (BuildContext sheetContext) => _TodoReliabilitySheetBody(
    onFixNotification: onFixNotification,
    onFixExactAlarm: onFixExactAlarm,
    onFixBattery: onFixBattery,
    onOpenAutoStart: onOpenAutoStart,
  ),
);

class _TodoReliabilitySheetBody extends ConsumerStatefulWidget {
  const _TodoReliabilitySheetBody({
    required this.onFixNotification,
    required this.onFixExactAlarm,
    required this.onFixBattery,
    required this.onOpenAutoStart,
  });

  final Future<void> Function() onFixNotification;
  final Future<void> Function() onFixExactAlarm;
  final Future<void> Function() onFixBattery;
  final Future<void> Function() onOpenAutoStart;

  @override
  ConsumerState<_TodoReliabilitySheetBody> createState() =>
      _TodoReliabilitySheetBodyState();
}

class _TodoReliabilitySheetBodyState
    extends ConsumerState<_TodoReliabilitySheetBody> {
  late final AppLifecycleListener _lifecycle;

  @override
  void initState() {
    super.initState();
    _lifecycle = AppLifecycleListener(
      onResume: () => ref.invalidate(todoReminderSystemStatusProvider),
    );
  }

  @override
  void dispose() {
    _lifecycle.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final status = ref.watch(todoReminderSystemStatusProvider).value;

    return TodoSheetBody(
      title: l10n.todoSettingsReliability,
      children: <Widget>[
        _ChecklistTile(
          title: l10n.todoSettingsPermission,
          ready: status?.notifications,
          onTap: () => unawaited(widget.onFixNotification()),
        ),
        _ChecklistTile(
          title: l10n.todoSettingsExactPermission,
          ready: status?.exact,
          onTap: () => unawaited(widget.onFixExactAlarm()),
        ),
        _ChecklistTile(
          title: l10n.todoSettingsBattery,
          ready: status?.ignoringBattery,
          onTap: () => unawaited(widget.onFixBattery()),
        ),
        ListTile(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          leading: FaIcon(
            FontAwesomeIcons.sliders,
            size: 18,
            color: scheme.primary,
          ),
          title: Text(l10n.todoSettingsAutoStart),
          subtitle: Text(l10n.todoSettingsAutoStartSubtitle),
          trailing: FaIcon(
            FontAwesomeIcons.angleRight,
            size: 14,
            color: scheme.onSurfaceVariant,
          ),
          onTap: () => unawaited(widget.onOpenAutoStart()),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
          child: Text(
            l10n.todoSettingsReliabilityBody,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: scheme.onSurfaceVariant,
            ),
          ),
        ),
      ],
    );
  }
}

class _ChecklistTile extends StatelessWidget {
  const _ChecklistTile({
    required this.title,
    required this.ready,
    required this.onTap,
  });

  final String title;
  final bool? ready;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final scheme = Theme.of(context).colorScheme;
    final ok = ready == true;
    final iconColor = ready == null
        ? scheme.onSurfaceVariant
        : ok
        ? scheme.primary
        : scheme.error;
    final statusText = ready == null
        ? null
        : ok
        ? l10n.todoSettingsReliabilityReady
        : l10n.todoSettingsReliabilityAction;

    return ListTile(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      leading: FaIcon(
        ok ? FontAwesomeIcons.circleCheck : FontAwesomeIcons.circleExclamation,
        size: 18,
        color: iconColor,
      ),
      title: Text(title),
      subtitle: statusText == null
          ? null
          : Text(statusText, style: TextStyle(color: iconColor)),
      trailing: ok
          ? null
          : FaIcon(
              FontAwesomeIcons.angleRight,
              size: 14,
              color: scheme.onSurfaceVariant,
            ),
      onTap: ok ? null : onTap,
    );
  }
}
