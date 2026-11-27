import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:node_diary/l10n/app_localizations.dart';

import '../../../app/theme/app_spacing.dart';
import '../../../app/theme/expressive_motion.dart';
import '../../../core/database/app_database.dart';
import '../../ai/models/ai_preference_parts.dart';
import '../../ai/providers/ai_providers.dart';
import '../../widgets/list_item_presence.dart';
import '../controllers/todo_ai_drafts.dart';
import '../controllers/todo_ai_flow.dart';
import '../viewmodels/todo_ai_output.dart';
import '../widgets/todo_ai_preview.dart';
import 'todo_detail_parts.dart';
import 'todo_steps_section.dart';

/// 详情页的步骤卡：小标题（有步骤时写进度）+ 细进度条 + 步骤
/// （[TodoStepsSection]）。
///
/// AI 助手的待办模块可用时（配好服务且模块开启，见
/// `aiModuleAvailableProvider`），小标题行尾多一个“AI 拆解”：点了按隐私
/// 设置确认后流式生成，建议的步骤在步骤下面逐条长出，可以勾掉不要的，
/// 点“使用 N 步”一次写入（接在已有步骤后面，不超过 [TodoStep.maxSteps]）。
/// 生成中可随时停止；放弃不写任何东西。
class TodoStepsCard extends ConsumerStatefulWidget {
  const TodoStepsCard({
    super.key,
    required this.row,
    required this.steps,
    required this.onChanged,
    required this.onToggle,
    required this.onConvert,
    this.onCompleteTodo,
  });

  final TodoRow row;
  final List<TodoStep> steps;
  final ValueChanged<List<TodoStep>> onChanged;
  final void Function(String stepId, bool done) onToggle;
  final ValueChanged<String> onConvert;
  final VoidCallback? onCompleteTodo;

  @override
  ConsumerState<TodoStepsCard> createState() => _TodoStepsCardState();
}

class _TodoStepsCardState extends ConsumerState<TodoStepsCard> {
  /// 建议与已有步骤（打开时的、之后改的都算）去重，条数不超过还能加的。
  late final TodoAiDrafts<String> _ai = TodoAiDrafts<String>(
    (String text, {required bool complete}) => parseTodoAiSteps(
      text,
      complete: complete,
      existing: <String>[for (final step in widget.steps) step.title],
      max: math.max(0, TodoStep.maxSteps - widget.steps.length),
    ),
  )..addListener(_onAi);

  bool _aiActive = false;

  /// 预览自己听着逐条更新；这里只在出现 / 收起时重建（行尾按钮跟着变）。
  void _onAi() {
    if (_ai.active == _aiActive || !mounted) return;
    setState(() => _aiActive = _ai.active);
  }

  @override
  void dispose() {
    _ai
      ..removeListener(_onAi)
      ..dispose();
    super.dispose();
  }

  void _breakdown() => unawaited(
    startTodoAiBreakdown(
      context,
      ref,
      _ai,
      row: widget.row,
      steps: widget.steps,
    ),
  );

  void _use() {
    final next = <TodoStep>[...widget.steps];
    for (final title in _ai.chosen) {
      if (next.length >= TodoStep.maxSteps) break;
      next.add(TodoStep(id: TodoStep.nextId(next), title: title));
    }
    _ai.reset();
    if (next.length != widget.steps.length) widget.onChanged(next);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final steps = widget.steps;
    final done = steps.where((TodoStep step) => step.done).length;
    final available = ref.watch(aiModuleAvailableProvider(AiModule.todos));
    final canAdd = steps.length < TodoStep.maxSteps;
    return TodoDetailSectionCard(
      title: steps.isEmpty
          ? l10n.todoStepsTitle
          : l10n.todoStepsTitleProgress(done, steps.length),
      progress: steps.isEmpty ? null : done / steps.length,
      trailing: available
          ? TextButton.icon(
              style: TextButton.styleFrom(
                visualDensity: VisualDensity.compact,
                textStyle: theme.textTheme.labelLarge?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
              onPressed: canAdd && !_aiActive ? _breakdown : null,
              icon: const FaIcon(FontAwesomeIcons.wandMagicSparkles, size: 12),
              label: Text(l10n.todoAiBreakdown),
            )
          : null,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          TodoStepsSection(
            steps: steps,
            onChanged: widget.onChanged,
            onToggle: widget.onToggle,
            onConvert: widget.onConvert,
            onCompleteTodo: widget.onCompleteTodo,
          ),
          if (available)
            ListItemPresence(
              visible: _aiActive,
              appearing: _aiActive,
              duration: ExpressiveMotion.duration(
                context,
                ExpressiveMotion.medium,
              ),
              child: TodoAiPreview<String>(
                drafts: _ai,
                title: l10n.todoAiStepsTitle,
                useLabel: l10n.todoAiUseSteps,
                onUse: _use,
                onRetry: _breakdown,
                itemBuilder: (BuildContext context, int index, String title) =>
                    _StepSuggestion(
                      title: title,
                      on: _ai.isOn(index),
                      onToggle: () => _ai.toggle(index),
                    ),
              ),
            ),
        ],
      ),
    );
  }
}

/// 一条建议的步骤：勾选框 + 标题（勾掉后变灰），整行可点。
class _StepSuggestion extends StatelessWidget {
  const _StepSuggestion({
    required this.title,
    required this.on,
    required this.onToggle,
  });

  final String title;
  final bool on;
  final VoidCallback onToggle;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return InkWell(
      borderRadius: BorderRadius.circular(12),
      onTap: onToggle,
      child: Row(
        children: <Widget>[
          TodoAiKeepBox(title: title, value: on, onChanged: onToggle),
          const SizedBox(width: AppSpacing.xs),
          Expanded(
            child: AnimatedDefaultTextStyle(
              duration: ExpressiveMotion.duration(
                context,
                ExpressiveMotion.fast,
              ),
              curve: ExpressiveMotion.effects,
              style: (theme.textTheme.bodyLarge ?? const TextStyle()).copyWith(
                color: on ? scheme.onSurface : scheme.onSurfaceVariant,
              ),
              child: Text(title),
            ),
          ),
        ],
      ),
    );
  }
}
