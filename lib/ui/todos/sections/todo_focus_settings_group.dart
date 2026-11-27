import 'dart:async';

import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:node_diary/l10n/app_localizations.dart';

import '../../settings/widgets/settings_card_group.dart';
import '../../settings/widgets/settings_nav_tile.dart';
import '../models/todo_settings.dart';
import '../widgets/todo_sheet.dart';

/// 待办设置里的“专注计时”分组：专注时长、短休息、长休息与长休息间隔，
/// 各自点开一个选项面板（与“稍后提醒”同一写法）。只在专注计时开着时出现。
class TodoFocusSettingsGroup extends StatelessWidget {
  const TodoFocusSettingsGroup({
    super.key,
    required this.settings,
    required this.onSave,
  });

  final TodoSettings settings;

  /// 设置服务还没就绪时为 null（各行不可点）。
  final Future<void> Function(TodoSettings next)? onSave;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final focus = settings.focus;
    final save = onSave;

    Future<void> pick({
      required String title,
      required FaIconData icon,
      required List<int> choices,
      required int current,
      required String Function(int value) label,
      required TodoFocusSettings Function(int value) apply,
    }) async {
      final value = await showTodoSheet<int>(
        context: context,
        builder: (BuildContext sheetContext) => TodoSheetBody(
          title: title,
          children: <Widget>[
            for (final choice in choices)
              TodoSheetOption(
                icon: icon,
                label: label(choice),
                selected: choice == current,
                onTap: () => Navigator.of(sheetContext).pop(choice),
              ),
          ],
        ),
      );
      if (value == null || save == null) return;
      await save(settings.copyWith(focus: apply(value)));
    }

    Widget row({
      required FaIconData icon,
      required String title,
      required List<int> choices,
      required int current,
      required String Function(int value) label,
      required TodoFocusSettings Function(int value) apply,
    }) => SettingsNavTile(
      icon: icon,
      title: title,
      value: label(current),
      onTap: save == null
          ? null
          : () => unawaited(
              pick(
                title: title,
                icon: icon,
                choices: choices,
                current: current,
                label: label,
                apply: apply,
              ),
            ),
    );

    return SettingsCardGroup(
      title: l10n.todoSettingsFocusGroup,
      children: <Widget>[
        row(
          icon: FontAwesomeIcons.stopwatch,
          title: l10n.todoSettingsFocusLength,
          choices: TodoFocusSettings.focusChoices,
          current: focus.focusMinutes,
          label: l10n.todoFocusMinutes,
          apply: (int v) => focus.copyWith(focusMinutes: v),
        ),
        row(
          icon: FontAwesomeIcons.mugHot,
          title: l10n.todoSettingsShortBreak,
          choices: TodoFocusSettings.shortBreakChoices,
          current: focus.shortBreakMinutes,
          label: l10n.todoFocusMinutes,
          apply: (int v) => focus.copyWith(shortBreakMinutes: v),
        ),
        row(
          icon: FontAwesomeIcons.couch,
          title: l10n.todoSettingsLongBreak,
          choices: TodoFocusSettings.longBreakChoices,
          current: focus.longBreakMinutes,
          label: l10n.todoFocusMinutes,
          apply: (int v) => focus.copyWith(longBreakMinutes: v),
        ),
        row(
          icon: FontAwesomeIcons.rotate,
          title: l10n.todoSettingsLongBreakEvery,
          choices: TodoFocusSettings.longBreakEveryChoices,
          current: focus.longBreakEvery,
          label: l10n.todoFocusRounds,
          apply: (int v) => focus.copyWith(longBreakEvery: v),
        ),
      ],
    );
  }
}
