import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/database/app_database.dart';
import 'todo_focus_controller.dart';
import 'todo_navigation.dart';

/// 为 [row] 开始专注并打开专注页（详情“更多”、桌面快捷键共用）。
///
/// 已经在为别的待办计时时不打断它：直接打开专注页，看到的是正在进行的那
/// 一段（要换一条，先在那里结束）。走完、等下一步的那一段让位给新的这条。
Future<void> startTodoFocus(
  BuildContext context,
  WidgetRef ref,
  TodoRow row,
) async {
  final focus = ref.read(todoFocusProvider);
  if (focus.run == null) {
    await ref
        .read(todoFocusProvider.notifier)
        .start(todoId: row.todoId, title: row.title);
  }
  if (!context.mounted) return;
  unawaited(openTodoFocusPage(context));
}
