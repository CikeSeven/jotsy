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
import '../../settings/providers/app_features_provider.dart';
import '../../settings/widgets/settings_card_group.dart';
import '../../settings/widgets/settings_nav_tile.dart';
import '../../settings/widgets/settings_option_tiles.dart';
import '../../widgets/app_top_bar.dart';
import '../../widgets/form_width.dart';
import '../controllers/todo_navigation.dart';
import '../models/todo_settings.dart';
import '../models/todo_view.dart';
import '../providers/todo_providers.dart';
import '../providers/todo_reminder_providers.dart';
import '../sections/todo_focus_settings_group.dart';
import '../sections/todo_reminders_settings_group.dart';
import '../widgets/todo_labels.dart';
import '../widgets/todo_list_picker_sheet.dart';
import '../widgets/todo_reliability_sheet.dart';
import '../widgets/todo_sheet.dart';
import '../widgets/todo_swipe_action_sheet.dart';

/// 设置 → 待办：显示偏好、提醒与清单管理入口。
///
/// 每项改动立即经 [saveTodoSettings] 写入单个设置键 `app.settings.todos`
/// （随备份导出）；设置未就绪时各项禁用。通知权限、准时闹钟与电池优化是系统
/// 状态，不存设置：页面打开与回到前台（可能刚从系统设置回来）时重新读取。
class TodoSettingsPage extends ConsumerStatefulWidget {
  const TodoSettingsPage({super.key});

  @override
  ConsumerState<TodoSettingsPage> createState() => _TodoSettingsPageState();
}

class _TodoSettingsPageState extends ConsumerState<TodoSettingsPage> {
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

  /// 打开每日摘要时请求一次权限（每次运行只问一次），然后刷新权限行。
  Future<void> _requestPermission() async {
    await ref.read(todoReminderSchedulerProvider)?.ensurePermission();
    if (mounted) ref.invalidate(todoReminderSystemStatusProvider);
  }

  Future<void> _fixPermission() async {
    final scheduler = ref.read(todoReminderSchedulerProvider);
    final allowed = await scheduler?.ensurePermission() ?? false;
    if (!allowed) await openTodoNotificationSettings();
    if (mounted) ref.invalidate(todoReminderSystemStatusProvider);
  }

  Future<void> _fixExactAlarm() async {
    await requestTodoExactAlarmPermission();
    if (mounted) ref.invalidate(todoReminderSystemStatusProvider);
  }

  Future<void> _fixBatteryOptimization() async {
    await requestIgnoreTodoBatteryOptimizations();
    if (mounted) ref.invalidate(todoReminderSystemStatusProvider);
  }

  Future<void> _openAutoStart() async {
    await openTodoAutoStartSettings();
    if (mounted) ref.invalidate(todoReminderSystemStatusProvider);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final settings = ref.watch(todoSettingsProvider);
    final service = ref.watch(settingsServiceProvider).asData?.value;
    final lists = ref.watch(todoListsProvider).value ?? const <TodoListRow>[];
    final focusOn = ref.watch(
      appFeaturesProvider.select((features) => features.todoFocusEnabled),
    );

    Future<void> save(TodoSettings next) async {
      if (service != null) await saveTodoSettings(service, next);
    }

    String viewName(TodoView view) => TodoLabels.viewName(
      l10n,
      view,
      lists,
      missing: TodoLabels.smartView(l10n, TodoSmartView.today),
    );
    final tags = ref.watch(todoTagsProvider).value ?? const <TodoTagUsage>[];

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
            for (final tag in tags)
              TodoSheetOption(
                icon: FontAwesomeIcons.tag,
                label: tag.name,
                selected: settings.defaultView == TodoView.tag(tag.name),
                onTap: () =>
                    Navigator.of(sheetContext).pop(TodoView.tag(tag.name)),
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
                      // 滑动只在手机上有；桌面用右键菜单。
                      if (!AppPlatform.isDesktop)
                        SettingsNavTile(
                          icon: FontAwesomeIcons.leftLong,
                          title: l10n.todoSettingsSwipeLeft,
                          value: todoSwipeActionLabel(l10n, settings.swipeLeft),
                          onTap: service == null
                              ? null
                              : () => unawaited(() async {
                                  final action = await showTodoSwipeActionSheet(
                                    context,
                                    current: settings.swipeLeft,
                                  );
                                  if (action != null) {
                                    await save(
                                      settings.copyWith(swipeLeft: action),
                                    );
                                  }
                                }()),
                        ),
                    ],
                  ),
                  if (AppPlatform.supportsReminders) ...<Widget>[
                    const SizedBox(height: 16),
                    TodoRemindersSettingsGroup(
                      settings: settings,
                      status: ref.watch(todoReminderSystemStatusProvider).value,
                      onSave: service == null ? null : save,
                      onRequestPermission: _requestPermission,
                      onFixPermission: () => unawaited(_fixPermission()),
                      onFixExactAlarm: () => unawaited(_fixExactAlarm()),
                      onFixBattery: () => unawaited(_fixBatteryOptimization()),
                      onShowReliability: () => unawaited(
                        showTodoReliabilitySheet(
                          context,
                          onFixNotification: _fixPermission,
                          onFixExactAlarm: _fixExactAlarm,
                          onFixBattery: _fixBatteryOptimization,
                          onOpenAutoStart: _openAutoStart,
                        ),
                      ),
                    ),
                  ],
                  if (focusOn) ...<Widget>[
                    const SizedBox(height: 16),
                    TodoFocusSettingsGroup(
                      settings: settings,
                      onSave: service == null ? null : save,
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
