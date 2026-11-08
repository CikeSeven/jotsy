import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:node_diary/l10n/app_localizations.dart';

import '../../../core/database/app_database.dart';
import '../../../core/services/app_service.dart';
import '../../app_surface/models/app_surface_enums.dart';
import '../../app_surface/widgets/app_page_background.dart';
import '../../settings/widgets/settings_card_group.dart';
import '../../settings/widgets/settings_nav_tile.dart';
import '../../settings/widgets/settings_option_tiles.dart';
import '../../widgets/app_top_bar.dart';
import '../../widgets/form_width.dart';
import '../controllers/todo_navigation.dart';
import '../models/todo_settings.dart';
import '../models/todo_view.dart';
import '../providers/todo_providers.dart';
import '../widgets/todo_labels.dart';
import '../widgets/todo_list_picker_sheet.dart';
import '../widgets/todo_sheet.dart';
import '../widgets/todo_view_switcher.dart';

/// 设置 → 待办：显示偏好与清单管理入口（提醒相关的设置也在这里）。
///
/// 每项改动立即经 [saveTodoSettings] 写入单个设置键 `app.settings.todos`
/// （随备份导出）；设置未就绪时各项禁用。
class TodoSettingsPage extends ConsumerWidget {
  const TodoSettingsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
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
                    ],
                  ),
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
