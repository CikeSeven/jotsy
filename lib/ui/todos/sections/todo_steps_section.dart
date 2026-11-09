import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:node_diary/l10n/app_localizations.dart';

import '../../../app/theme/app_spacing.dart';
import '../../../core/database/app_database.dart';
import '../../widgets/text_selection_menu/app_text_context_menu.dart';
import '../../widgets/todo_check_box.dart';
import '../widgets/todo_bare_input.dart';

/// 详情页的步骤（子任务）：每步一行方框 + 可直接改的标题 + 删除；末尾一行
/// “添加步骤”输入框，回车即加一步并留在输入框里接着加。
///
/// 改动经 [onChanged] 交出整份新列表（页面写库）；勾选经 [onToggle] 单独写，
/// 不重写别的步骤。标题改动在失去焦点或回车时提交，不逐字写库。
class TodoStepsSection extends StatefulWidget {
  const TodoStepsSection({
    super.key,
    required this.steps,
    required this.onChanged,
    required this.onToggle,
  });

  final List<TodoStep> steps;
  final ValueChanged<List<TodoStep>> onChanged;
  final void Function(String stepId, bool done) onToggle;

  @override
  State<TodoStepsSection> createState() => _TodoStepsSectionState();
}

class _TodoStepsSectionState extends State<TodoStepsSection> {
  final TextEditingController _add = TextEditingController();
  final FocusNode _addFocus = FocusNode();

  @override
  void dispose() {
    _add.dispose();
    _addFocus.dispose();
    super.dispose();
  }

  void _submitNew() {
    final title = _add.text.trim();
    if (title.isEmpty || widget.steps.length >= TodoStep.maxSteps) return;
    widget.onChanged(<TodoStep>[
      ...widget.steps,
      TodoStep(id: TodoStep.nextId(widget.steps), title: title),
    ]);
    _add.clear();
    _addFocus.requestFocus();
  }

  void _rename(TodoStep step, String raw) {
    final title = raw.trim();
    if (title == step.title) return;
    widget.onChanged(<TodoStep>[
      for (final item in widget.steps)
        if (item.id != step.id)
          item
        else if (title.isNotEmpty)
          item.copyWith(title: title),
    ]);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final scheme = Theme.of(context).colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        for (final step in widget.steps)
          _StepRow(
            key: ValueKey<String>('step_${step.id}'),
            step: step,
            onToggle: () => widget.onToggle(step.id, !step.done),
            onRename: (String title) => _rename(step, title),
            onDelete: () => widget.onChanged(<TodoStep>[
              for (final item in widget.steps)
                if (item.id != step.id) item,
            ]),
          ),
        if (widget.steps.length < TodoStep.maxSteps)
          Row(
            children: <Widget>[
              SizedBox(
                width: 48,
                height: 48,
                child: Center(
                  child: FaIcon(
                    FontAwesomeIcons.plus,
                    size: 14,
                    color: scheme.primary,
                  ),
                ),
              ),
              Expanded(
                child: TextField(
                  controller: _add,
                  focusNode: _addFocus,
                  maxLength: TodoStep.maxTitleLength,
                  textInputAction: TextInputAction.done,
                  onSubmitted: (_) => _submitNew(),
                  contextMenuBuilder: appTextContextMenuBuilder,
                  decoration: todoBareInputDecoration(
                    hintText: l10n.todoStepAdd,
                  ),
                ),
              ),
            ],
          ),
      ],
    );
  }
}

class _StepRow extends StatefulWidget {
  const _StepRow({
    super.key,
    required this.step,
    required this.onToggle,
    required this.onRename,
    required this.onDelete,
  });

  final TodoStep step;
  final VoidCallback onToggle;
  final ValueChanged<String> onRename;
  final VoidCallback onDelete;

  @override
  State<_StepRow> createState() => _StepRowState();
}

class _StepRowState extends State<_StepRow> {
  late final TextEditingController _controller = TextEditingController(
    text: widget.step.title,
  );
  final FocusNode _focus = FocusNode();

  @override
  void initState() {
    super.initState();
    _focus.addListener(() {
      if (!_focus.hasFocus) widget.onRename(_controller.text);
    });
  }

  @override
  void didUpdateWidget(covariant _StepRow oldWidget) {
    super.didUpdateWidget(oldWidget);
    // 别处（同步、撤销）改了标题且这里没在编辑时跟上。
    if (!_focus.hasFocus && widget.step.title != _controller.text) {
      _controller.text = widget.step.title;
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    _focus.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final scheme = Theme.of(context).colorScheme;
    final done = widget.step.done;
    return Row(
      children: <Widget>[
        Semantics(
          checked: done,
          button: true,
          label: done ? l10n.todoMarkUndone : l10n.todoMarkDone,
          excludeSemantics: true,
          child: InkResponse(
            onTap: widget.onToggle,
            radius: 20,
            child: SizedBox(
              width: 48,
              height: 48,
              child: Center(child: TodoCheckBoxVisual(checked: done, size: 18)),
            ),
          ),
        ),
        Expanded(
          child: TextField(
            controller: _controller,
            focusNode: _focus,
            maxLength: TodoStep.maxTitleLength,
            textInputAction: TextInputAction.done,
            onSubmitted: widget.onRename,
            contextMenuBuilder: appTextContextMenuBuilder,
            style: TextStyle(
              color: done ? scheme.onSurfaceVariant : null,
              decoration: done ? TextDecoration.lineThrough : null,
              decorationColor: scheme.onSurfaceVariant,
            ),
            decoration: todoBareInputDecoration(),
          ),
        ),
        IconButton(
          tooltip: l10n.todoStepDelete,
          onPressed: widget.onDelete,
          icon: const FaIcon(FontAwesomeIcons.xmark, size: 14),
        ),
        const SizedBox(width: AppSpacing.xs),
      ],
    );
  }
}
