import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:node_diary/l10n/app_localizations.dart';

import '../../../core/database/app_database.dart';
import '../../../core/services/app_service.dart';
import '../../../core/services/app_platform.dart';
import '../../../core/services/todo_reminders/todo_notification_gateway_plugin.dart';
import '../../app_surface/models/app_surface_enums.dart';
import '../../app_surface/widgets/app_page_background.dart';
import '../../settings/widgets/settings_card_group.dart';
import '../../settings/widgets/settings_nav_tile.dart';
import '../../settings/widgets/settings_option_tiles.dart';
import '../../widgets/app_top_bar.dart';
import '../../widgets/form_width.dart';
import '../controllers/todo_navigation.dart';
import '../controllers/todo_reminder_scheduler.dart';
import '../models/todo_settings.dart';
import '../models/todo_view.dart';
import '../providers/todo_providers.dart';
import '../widgets/todo_labels.dart';
import '../widgets/todo_list_picker_sheet.dart';
import '../widgets/todo_sheet.dart';
import '../widgets/todo_view_switcher.dart';

/// 设置 → 待办：显示偏好、提醒与清单管理入口。
///
/// 每项改动立即经 [saveTodoSettings] 写入单个设置键 `app.settings.todos`
/// （随备份导出）；设置未就绪时各项禁用。通知权限与准时闹钟是系统状态，
/// 不存设置：页面打开与回到前台（可能刚从系统设置回来）时重新读取。
class TodoSettingsPage extends ConsumerStatefulWidget {
  const TodoSettingsPage({super.key});

  @override
  ConsumerState<TodoSettingsPage> createState() => _TodoSettingsPageState();
}

/// 系统通知权限与准时闹钟（不支持提醒的平台为 null）。
final _reminderStatusProvider =
    FutureProvider.autoDispose<({bool notifications, bool exact})?>((
      Ref ref,
    ) async {
      final gateway = ref.watch(todoNotificationGatewayProvider);
      if (gateway == null) return null;
      return (
        notifications: await gateway.notificationsEnabled(),
        exact: await gateway.exactAlarmsAllowed(),
      );
    });

class _TodoSettingsPageState extends ConsumerState<TodoSettingsPage> {
  late final AppLifecycleListener _lifecycle;

  @override
  void initState() {
    super.initState();
    _lifecycle = AppLifecycleListener(
      onResume: () => ref.invalidate(_reminderStatusProvider),
    );
  }

  @override
  void dispose() {
    _lifecycle.dispose();
    super.dispose();
  }

  Future<void> _fixPermission() async {
    final scheduler = ref.read(todoReminderSchedulerProvider);
    final allowed = await scheduler?.ensurePermission() ?? false;
    if (!allowed) await openTodoNotificationSettings();
    if (mounted) ref.invalidate(_reminderStatusProvider);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final settings = ref.watch(todoSettingsProvider);
    final service = ref.watch(settingsServiceProvider).asData?.value;
    final lists = ref.watch(todoListsProvider).value ?? const <TodoListRow>[];

    Future<void> save(TodoSettings next) async {
      if (service != null) await saveTodoSettings(service, next);
    }

    String viewName(TodoView view) {
      final listId = view.listId;
      if (listId == null) return TodoLabels.smartView(l10n, view.smart!);
      for (final list in lists) {
        if (list.listId == listId) return list.name;
      }
      return TodoLabels.smartView(l10n, TodoSmartView.today);
    }

    String? defaultListName() {
      final id = settings.defaultListId;
      if (id == null) return null;
      for (final list in lists) {
        if (list.listId == id) return list.name;
      }
      return null;
    }

    Future<void> pickDefaultView() async {
      final view = await showTodoSheet<TodoView>(
        context: context,
        builder: (BuildContext sheetContext) => TodoSheetBody(
          title: l10n.todoSettingsDefaultView,
          children: <Widget>[
            for (final smart in kTodoSmartViews)
              TodoSheetOption(
                icon: TodoLabels.smartViewIcon(smart),
                label: TodoLabels.smartView(l10n, smart),
                selected: settings.defaultView == TodoView.smart(smart),
                onTap: () =>
                    Navigator.of(sheetContext).pop(TodoView.smart(smart)),
              ),
            for (final list in lists)
              TodoSheetOption(
                icon: FontAwesomeIcons.listCheck,
                label: list.name,
                selected: settings.defaultView == TodoView.list(list.listId),
                onTap: () =>
                    Navigator.of(sheetContext).pop(TodoView.list(list.listId)),
              ),
          ],
        ),
      );
      if (view != null) await save(settings.copyWith(defaultViewKey: view.key));
    }

    Future<void> pickDefaultList() async {
      final choice = await showTodoListPickerSheet(
        context,
        current: defaultListName() == null ? null : settings.defaultListId,
      );
      if (choice == null) return;
      await save(
        choice.listId == null
            ? settings.copyWith(clearDefaultList: true)
            : settings.copyWith(defaultListId: choice.listId),
      );
    }

    return AppPageBackground(
      area: AppBackgroundArea.settings,
      child: Builder(
        builder: (BuildContext context) => Scaffold(
          backgroundColor: AppPageBackdrop.pageColorOf(context),
          appBar: AppTopBar(
            contentMaxWidth: FormWidth.maxWidth,
            title: Text(l10n.todoSettingsTitle),
            leading: IconButton(
              tooltip: l10n.commonBack,
              onPressed: () => Navigator.of(context).maybePop(),
              icon: const FaIcon(FontAwesomeIcons.angleLeft, size: 18),
            ),
          ),
          body: LayoutBuilder(
            builder: (BuildContext context, BoxConstraints constraints) {
              final side = FormWidth.extra(constraints.maxWidth);
              return ListView(
                padding: EdgeInsets.fromLTRB(side, 12, side, 24),
                children: <Widget>[
                  SettingsCardGroup(
                    title: l10n.todoSettingsDisplayGroup,
                    children: <Widget>[
                      SettingsSwitchTile(
                        title: l10n.todoShowCompleted,
                        subtitle: l10n.todoSettingsShowCompletedSubtitle,
                        value: settings.showCompleted,
                        onChanged: service == null
                            ? null
                            : (bool value) => unawaited(
                                save(settings.copyWith(showCompleted: value)),
                              ),
                      ),
                      SettingsNavTile(
                        icon: FontAwesomeIcons.solidSun,
                        title: l10n.todoSettingsDefaultView,
                        value: viewName(settings.defaultView),
                        onTap: service == null
                            ? null
                            : () => unawaited(pickDefaultView()),
                      ),
                      SettingsNavTile(
                        icon: FontAwesomeIcons.inbox,
                        title: l10n.todoSettingsDefaultList,
                        value: defaultListName() ?? l10n.todoViewInbox,
                        onTap: service == null
                            ? null
                            : () => unawaited(pickDefaultList()),
                      ),
                      SettingsSwitchTile(
                        title: l10n.todoSettingsSmartParse,
                        subtitle: l10n.todoSettingsSmartParseSubtitle,
                        value: settings.smartParse,
                        onChanged: service == null
                            ? null
                            : (bool value) => unawaited(
                                save(settings.copyWith(smartParse: value)),
                              ),
                      ),
                    ],
                  ),
                  if (AppPlatform.supportsReminders) ...<Widget>[
                    const SizedBox(height: 16),
                    _RemindersGroup(
                      settings: settings,
                      status: ref.watch(_reminderStatusProvider).value,
                      onSave: service == null ? null : save,
                      onFixPermission: () => unawaited(_fixPermission()),
                    ),
                  ],
                  const SizedBox(height: 16),
                  SettingsCardGroup(
                    title: l10n.todoListsSection,
                    children: <Widget>[
                      SettingsNavTile(
                        icon: FontAwesomeIcons.listCheck,
                        title: l10n.todoListManage,
                        value: lists.isEmpty ? null : '${lists.length}',
                        onTap: () => unawaited(openTodoListsManage(context)),
                      ),
                    ],
                  ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }
}

/// 提醒分组：通知权限（手机）、全天待办的提醒时刻、稍后提醒时长、锁屏隐藏
/// 内容（Android）与“提醒不准时？”（Android）；桌面组尾写明只在应用运行时
/// 提醒。
class _RemindersGroup extends StatelessWidget {
  const _RemindersGroup({
    required this.settings,
    required this.status,
    required this.onSave,
    required this.onFixPermission,
  });

  final TodoSettings settings;
  final ({bool notifications, bool exact})? status;
  final Future<void> Function(TodoSettings next)? onSave;
  final VoidCallback onFixPermission;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final scheme = Theme.of(context).colorScheme;
    final save = onSave;
    final status = this.status;
    final background = AppPlatform.supportsBackgroundReminders;

    Future<void> pickAllDayTime() async {
      final minute = settings.allDayReminderMinute;
      final picked = await showTimePicker(
        context: context,
        initialTime: TimeOfDay(hour: minute ~/ 60, minute: minute % 60),
      );
      if (picked == null || save == null) return;
      await save(
        settings.copyWith(
          allDayReminderMinute: picked.hour * 60 + picked.minute,
        ),
      );
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

    Future<void> showReliabilityTips() => showTodoSheet<void>(
      context: context,
      builder: (BuildContext sheetContext) => TodoSheetBody(
        title: l10n.todoSettingsReliability,
        children: <Widget>[
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Text(
              l10n.todoSettingsReliabilityBody,
              style: Theme.of(sheetContext).textTheme.bodyMedium,
            ),
          ),
        ],
      ),
    );

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
            onTap: status != null && status.notifications
                ? null
                : onFixPermission,
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
            onTap: () => unawaited(showReliabilityTips()),
          ),
      ],
    );
  }
}
