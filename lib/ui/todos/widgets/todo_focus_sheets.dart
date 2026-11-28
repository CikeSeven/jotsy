import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:node_diary/l10n/app_localizations.dart';

import '../../../app/theme/app_spacing.dart';
import '../../../app/theme/expressive_motion.dart';
import '../../../core/database/app_database.dart';
import '../../../core/services/app_service.dart';
import '../../app_surface/widgets/app_glass_field.dart';
import '../models/todo_focus_settings.dart';
import '../providers/todo_providers.dart';
import '../viewmodels/todo_priority_colors.dart';
import 'todo_sheet.dart';

/// 专注页顶栏“专注节奏”快捷设置面板：胶囊选项即点即保存，不离开专注页。
Future<void> showTodoFocusRhythmSheet(BuildContext context) {
  return showTodoSheet<void>(
    context: context,
    builder: (BuildContext _) => const _FocusRhythmSheet(),
  );
}

class _FocusRhythmSheet extends ConsumerWidget {
  const _FocusRhythmSheet();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final settings = ref.watch(todoSettingsProvider);
    final service = ref.watch(settingsServiceProvider).asData?.value;
    final focus = settings.focus;

    void update(TodoFocusSettings next) {
      if (service == null || next == focus) return;
      unawaited(HapticFeedback.selectionClick());
      unawaited(saveTodoSettings(service, settings.copyWith(focus: next)));
    }

    return TodoSheetBody(
      title: l10n.todoFocusRhythm,
      children: <Widget>[
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.m),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              _RhythmSection(
                icon: FontAwesomeIcons.stopwatch,
                title: l10n.todoSettingsFocusLength,
                choices: TodoFocusSettings.focusChoices,
                current: focus.focusMinutes,
                labelOf: l10n.todoFocusMinutes,
                onSelect: (int v) => update(focus.copyWith(focusMinutes: v)),
              ),
              const SizedBox(height: AppSpacing.xl),
              _RhythmSection(
                icon: FontAwesomeIcons.mugHot,
                title: l10n.todoSettingsShortBreak,
                choices: TodoFocusSettings.shortBreakChoices,
                current: focus.shortBreakMinutes,
                labelOf: l10n.todoFocusMinutes,
                onSelect: (int v) =>
                    update(focus.copyWith(shortBreakMinutes: v)),
              ),
              const SizedBox(height: AppSpacing.xl),
              _RhythmSection(
                icon: FontAwesomeIcons.couch,
                title: l10n.todoSettingsLongBreak,
                choices: TodoFocusSettings.longBreakChoices,
                current: focus.longBreakMinutes,
                labelOf: l10n.todoFocusMinutes,
                onSelect: (int v) =>
                    update(focus.copyWith(longBreakMinutes: v)),
              ),
              const SizedBox(height: AppSpacing.xl),
              _RhythmSection(
                icon: FontAwesomeIcons.rotate,
                title: l10n.todoSettingsLongBreakEvery,
                choices: TodoFocusSettings.longBreakEveryChoices,
                current: focus.longBreakEvery,
                labelOf: l10n.todoFocusRounds,
                onSelect: (int v) => update(focus.copyWith(longBreakEvery: v)),
              ),
              const SizedBox(height: AppSpacing.s),
            ],
          ),
        ),
      ],
    );
  }
}

class _RhythmSection extends StatelessWidget {
  const _RhythmSection({
    required this.icon,
    required this.title,
    required this.choices,
    required this.current,
    required this.labelOf,
    required this.onSelect,
  });

  final FaIconData icon;
  final String title;
  final List<int> choices;
  final int current;
  final String Function(int value) labelOf;
  final ValueChanged<int> onSelect;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final glassField = AppGlassField.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        Row(
          children: <Widget>[
            FaIcon(icon, size: 13, color: scheme.primary),
            const SizedBox(width: AppSpacing.s),
            Text(
              title,
              style: theme.textTheme.labelLarge?.copyWith(
                color: scheme.onSurfaceVariant,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.s + 2),
        Wrap(
          spacing: AppSpacing.s,
          runSpacing: AppSpacing.s,
          children: <Widget>[
            for (final choice in choices)
              _ChoicePill(
                label: labelOf(choice),
                selected: choice == current,
                glassField: glassField,
                onTap: () => onSelect(choice),
              ),
          ],
        ),
      ],
    );
  }
}

class _ChoicePill extends StatelessWidget {
  const _ChoicePill({
    required this.label,
    required this.selected,
    required this.glassField,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final AppGlassField? glassField;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final bg = selected
        ? scheme.primary
        : glassField?.fill ?? scheme.surfaceContainerHigh;
    final fg = selected ? scheme.onPrimary : scheme.onSurface;
    final border = selected ? null : glassField?.border;
    return Semantics(
      selected: selected,
      button: true,
      label: label,
      excludeSemantics: true,
      child: AnimatedContainer(
        duration: ExpressiveMotion.duration(context, ExpressiveMotion.fast),
        curve: ExpressiveMotion.effects,
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(selected ? 999 : 14),
          border: border == null ? null : Border.fromBorderSide(border),
        ),
        child: Material(
          type: MaterialType.transparency,
          borderRadius: BorderRadius.circular(selected ? 999 : 14),
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            onTap: onTap,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
              child: Text(
                label,
                style: theme.textTheme.labelLarge?.copyWith(
                  color: fg,
                  fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                  fontFeatures: const <FontFeature>[
                    FontFeature.tabularFigures(),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// 空闲态选择待办面板的返回值：区分“选了自由专注”与“取消关闭”。
@immutable
class TodoFocusPickResult {
  const TodoFocusPickResult(this.todo);

  /// null 表示用户显式选择了“自由专注”。
  final TodoRow? todo;
}

/// 空闲准备态弹出：从当前未完成的待办里选一条开始专注，或切换为自由专注。
Future<TodoFocusPickResult?> showTodoFocusPickerSheet(
  BuildContext context, {
  required List<TodoRow> openTodos,
  required String? selectedTodoId,
}) {
  return showTodoSheet<TodoFocusPickResult>(
    context: context,
    builder: (BuildContext sheetContext) {
      final l10n = sheetContext.l10n;
      final theme = Theme.of(sheetContext);
      final scheme = theme.colorScheme;
      return TodoSheetBody(
        title: l10n.todoFocusPickTodo,
        children: <Widget>[
          TodoSheetOption(
            icon: FontAwesomeIcons.stopwatch,
            label: l10n.todoFocusFreeSession,
            selected: selectedTodoId == null,
            onTap: () =>
                Navigator.of(sheetContext).pop(const TodoFocusPickResult(null)),
          ),
          if (openTodos.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.l,
                vertical: AppSpacing.l,
              ),
              child: Text(
                l10n.todoFocusNoOpenTodos,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: scheme.onSurfaceVariant,
                ),
              ),
            )
          else
            for (final todo in openTodos.take(40))
              _TodoPickTile(
                todo: todo,
                selected: todo.todoId == selectedTodoId,
                onTap: () =>
                    Navigator.of(sheetContext).pop(TodoFocusPickResult(todo)),
              ),
        ],
      );
    },
  );
}

class _TodoPickTile extends StatelessWidget {
  const _TodoPickTile({
    required this.todo,
    required this.selected,
    required this.onTap,
  });

  final TodoRow todo;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final priority = TodoPriority.of(todo.priority);
    final priorityColors = TodoPriorityColors.of(scheme, priority);
    final steps = decodeTodoSteps(todo.steps);
    final done = steps.where((TodoStep s) => s.done).length;
    return ListTile(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      leading: Container(
        width: 28,
        height: 28,
        decoration: BoxDecoration(
          color:
              priorityColors?.tint ??
              scheme.surfaceContainerHighest.withValues(alpha: 0.8),
          borderRadius: BorderRadius.circular(10),
        ),
        alignment: Alignment.center,
        child: FaIcon(
          priority != TodoPriority.none
              ? FontAwesomeIcons.flag
              : FontAwesomeIcons.listCheck,
          size: 12,
          color: priorityColors?.accent ?? scheme.onSurfaceVariant,
        ),
      ),
      title: Text(todo.title, maxLines: 1, overflow: TextOverflow.ellipsis),
      subtitle: steps.isEmpty
          ? null
          : Text(l10n.todoStepsTitleProgress(done, steps.length)),
      selected: selected,
      trailing: selected
          ? FaIcon(FontAwesomeIcons.check, size: 16, color: scheme.primary)
          : null,
      onTap: onTap,
    );
  }
}
