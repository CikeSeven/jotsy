import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:node_diary/l10n/app_localizations.dart';

import '../../../core/services/todo_reminders/todo_notification_gateway_plugin.dart';
import '../../home/widgets/home_hint_visibility_scope.dart';
import 'todo_reminder_scheduler.dart';

/// 给待办加上提醒后确认系统允许发通知：没有允许时请求一次（Android 13+ /
/// iOS 弹出系统对话框，每次运行只问一次）；仍不允许时给出提示，按钮跳到
/// 系统的通知设置。不支持提醒的平台什么都不做。
///
/// 只在用户自己加提醒时调用，不在启动时主动弹权限框。
Future<void> ensureTodoReminderPermission(
  BuildContext context,
  WidgetRef ref,
) async {
  final scheduler = ref.read(todoReminderSchedulerProvider);
  if (scheduler == null) return;
  final allowed = await scheduler.ensurePermission();
  if (allowed || !context.mounted) return;
  final l10n = context.l10n;
  unawaited(
    HomeHintVisibilityScope.showTrackedSnackBar(
      context: context,
      snackBar: SnackBar(
        content: Text(l10n.todoReminderPermissionDenied),
        persist: false,
        action: SnackBarAction(
          label: l10n.todoReminderPermissionAction,
          onPressed: () => unawaited(openTodoNotificationSettings()),
        ),
      ),
    ),
  );
}
