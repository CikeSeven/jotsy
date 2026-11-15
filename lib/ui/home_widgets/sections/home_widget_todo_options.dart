import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';

import '../../../core/database/app_database.dart';
import '../../../core/services/home_widgets/home_widget_content.dart';
import '../../../l10n/app_localizations.dart';
import '../../settings/widgets/settings_card_group.dart';
import '../../settings/widgets/settings_nav_tile.dart';
import '../../settings/widgets/settings_option_tiles.dart';
import '../../todos/providers/todo_providers.dart';
import '../../widgets/expressive_button_group.dart';
import 'home_widget_choice_sheet.dart';

/// 待办清单小组件的内容选项：显示哪些待办（今天 / 计划 / 全部 / 某个清单），
/// 是否把今天完成的划掉列在最后，是否显示截止日与时刻。
class HomeWidgetTodoOptions extends ConsumerWidget {
  const HomeWidgetTodoOptions({
    super.key,
    required this.content,
    required this.onChanged,
  });

  final TodoListContent content;
  final ValueChanged<TodoListContent> onChanged;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final lists = ref.watch(todoListsProvider).value ?? const <TodoListRow>[];
    final chosen = lists
        .where((list) => list.listId == content.listId)
        .firstOrNull;
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
      children: <Widget>[
        SettingsCardGroup(
          children: <Widget>[
            SettingsChoiceTile(
              title: l10n.homeWidgetTodoView,
              child: ExpressiveButtonGroup<TodoWidgetView>(
                minSegmentWidth: 72,
                segments: <ButtonSegment<TodoWidgetView>>[
                  ButtonSegment(
                    value: TodoWidgetView.today,
                    label: Text(l10n.todoViewToday),
                  ),
                  ButtonSegment(
                    value: TodoWidgetView.planned,
                    label: Text(l10n.todoViewPlanned),
                  ),
                  ButtonSegment(
                    value: TodoWidgetView.all,
                    label: Text(l10n.todoViewAll),
                  ),
                  // 没有清单时不提供“某个清单”。
                  if (lists.isNotEmpty)
                    ButtonSegment(
                      value: TodoWidgetView.list,
                      label: Text(l10n.homeWidgetTodoViewList),
                    ),
                ],
                selected: <TodoWidgetView>{
                  content.view == TodoWidgetView.list && lists.isEmpty
                      ? TodoWidgetView.all
                      : content.view,
                },
                onSelectionChanged: (Set<TodoWidgetView> value) {
                  final view = value.first;
                  onChanged(
                    content.copyWith(
                      view: view,
                      // 第一次选“某个清单”时先选上第一个，小组件立刻有内容。
                      listId: view == TodoWidgetView.list && chosen == null
                          ? () => lists.first.listId
                          : null,
                    ),
                  );
                },
              ),
            ),
            if (content.view == TodoWidgetView.list && lists.isNotEmpty)
              SettingsNavTile(
                icon: FontAwesomeIcons.listCheck,
                title: l10n.homeWidgetTodoList,
                value: chosen?.name ?? lists.first.name,
                onTap: () async {
                  final picked = await _pickList(context, lists, chosen);
                  if (picked != null) {
                    onChanged(content.copyWith(listId: () => picked));
                  }
                },
              ),
          ],
        ),
        const SizedBox(height: 16),
        SettingsCardGroup(
          children: <Widget>[
            SettingsSwitchTile(
              title: l10n.homeWidgetTodoShowCompleted,
              subtitle: l10n.homeWidgetTodoShowCompletedHint,
              value: content.showCompleted,
              onChanged: (bool value) =>
                  onChanged(content.copyWith(showCompleted: value)),
            ),
            SettingsSwitchTile(
              title: l10n.homeWidgetTodoShowDue,
              value: content.showDue,
              onChanged: (bool value) =>
                  onChanged(content.copyWith(showDue: value)),
            ),
          ],
        ),
      ],
    );
  }

  Future<String?> _pickList(
    BuildContext context,
    List<TodoListRow> lists,
    TodoListRow? current,
  ) => showHomeWidgetChoiceSheet<String>(
    context,
    title: context.l10n.homeWidgetTodoList,
    selected: current?.listId,
    choices: <HomeWidgetChoice<String>>[
      for (final list in lists)
        HomeWidgetChoice<String>(
          value: list.listId,
          label: list.name,
          icon: FontAwesomeIcons.listCheck,
        ),
    ],
  );
}
