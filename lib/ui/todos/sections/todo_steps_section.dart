import 'dart:async';

import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:node_diary/l10n/app_localizations.dart';

import '../../../app/theme/app_spacing.dart';
import '../../../app/theme/expressive_motion.dart';
import '../../../core/database/app_database.dart';
import '../../app_surface/widgets/app_glass_field.dart';
import '../../widgets/expressive_reorder_proxy.dart';
import '../../widgets/list_item_presence.dart';
import '../../widgets/text_selection_menu/app_text_context_menu.dart';
import '../widgets/todo_bare_input.dart';
import '../widgets/todo_step_row.dart';

/// 详情页的步骤（子任务）：每步一行（方框 + 可直接改的标题 + 菜单 + 拖动
/// 手柄），末尾一行“添加步骤”输入框；步骤全勾完、这条待办还没完成时，
/// 下面出现“顺便完成这条待办”（[onCompleteTodo]）。
///
/// - 改动经 [onChanged] 交出整份新列表（页面写库）；勾选经 [onToggle] 单独
///   写，不重写别的步骤；标题改动在失去焦点或回车时提交，不逐字写库；
/// - 新加的步骤从 0 展开进场；删除先原地收起（`medium`），收起后才交出
///   新列表（组件卸载时立即交出）；
/// - 拖手柄调整顺序（[ReorderHandle]，拖起态 [expressiveReorderProxyDecorator]）；
/// - 添加框可粘贴多行：每个非空行各成一步（不超过 [TodoStep.maxSteps]）；
///   桌面上回车同样提交；
/// - 菜单：转为独立待办（[onConvert]，同一事务里另建待办、去掉这一步）、删除。
class TodoStepsSection extends StatefulWidget {
  const TodoStepsSection({
    super.key,
    required this.steps,
    required this.onChanged,
    required this.onToggle,
    required this.onConvert,
    this.onCompleteTodo,
  });

  final List<TodoStep> steps;
  final ValueChanged<List<TodoStep>> onChanged;
  final void Function(String stepId, bool done) onToggle;
  final ValueChanged<String> onConvert;

  /// 步骤全勾完时“顺便完成这条待办”；null 时不出现（这条已完成）。
  final VoidCallback? onCompleteTodo;

  @override
  State<TodoStepsSection> createState() => _TodoStepsSectionState();
}

class _TodoStepsSectionState extends State<TodoStepsSection> {
  final TextEditingController _add = TextEditingController();
  final FocusNode _addFocus = FocusNode();

  /// 打开时就有的步骤（不演进场）；之后出现的从 0 展开。
  late final Set<String> _initial;

  /// 正在收起、收起后才删的步骤。
  final Map<String, Timer> _removing = <String, Timer>{};

  @override
  void initState() {
    super.initState();
    _initial = <String>{for (final step in widget.steps) step.id};
  }

  @override
  void dispose() {
    if (_removing.isNotEmpty) {
      for (final timer in _removing.values) {
        timer.cancel();
      }
      widget.onChanged(<TodoStep>[
        for (final step in widget.steps)
          if (!_removing.containsKey(step.id)) step,
      ]);
    }
    _add.dispose();
    _addFocus.dispose();
    super.dispose();
  }

  void _addTitles(Iterable<String> titles) {
    final next = <TodoStep>[...widget.steps];
    for (final raw in titles) {
      final title = raw.trim();
      if (title.isEmpty || next.length >= TodoStep.maxSteps) continue;
      next.add(
        TodoStep(
          id: TodoStep.nextId(next),
          title: title.length > TodoStep.maxTitleLength
              ? title.substring(0, TodoStep.maxTitleLength)
              : title,
        ),
      );
    }
    if (next.length == widget.steps.length) return;
    widget.onChanged(next);
  }

  void _submitNew() {
    _addTitles(<String>[_add.text]);
    _add.clear();
    _addFocus.requestFocus();
  }

  /// 输入里出现了换行：粘贴的多行各成一步；只是末尾一个换行（桌面上按
  /// 回车）就是提交这一步。
  void _onAddChanged(String text) {
    if (!text.contains('\n')) return;
    _addTitles(text.split('\n'));
    _add.clear();
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

  void _delete(TodoStep step) {
    if (_removing.containsKey(step.id)) return;
    final duration = ExpressiveMotion.duration(
      context,
      ExpressiveMotion.medium,
    );
    void commit() {
      _removing.remove(step.id);
      widget.onChanged(<TodoStep>[
        for (final item in widget.steps)
          if (item.id != step.id && !_removing.containsKey(item.id)) item,
      ]);
    }

    if (duration == Duration.zero) {
      commit();
      return;
    }
    setState(() => _removing[step.id] = Timer(duration, commit));
  }

  /// [newIndex] 已按移走 [oldIndex] 那一项修正过（`onReorderItem`）。
  void _reorder(int oldIndex, int newIndex) {
    final next = <TodoStep>[...widget.steps];
    next.insert(newIndex, next.removeAt(oldIndex));
    widget.onChanged(next);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final scheme = Theme.of(context).colorScheme;
    final steps = widget.steps;
    final duration = ExpressiveMotion.duration(
      context,
      ExpressiveMotion.medium,
    );
    final allDone =
        steps.isNotEmpty &&
        steps.every((TodoStep step) => step.done) &&
        _removing.isEmpty;
    final onCompleteTodo = widget.onCompleteTodo;
    final rows = ReorderableListView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      buildDefaultDragHandles: false,
      proxyDecorator: expressiveReorderProxyDecorator,
      itemCount: steps.length,
      onReorderItem: _reorder,
      itemBuilder: (BuildContext context, int index) {
        final step = steps[index];
        return ListItemPresence(
          key: ValueKey<String>('step_${step.id}'),
          visible: !_removing.containsKey(step.id),
          appearing: !_initial.contains(step.id),
          duration: duration,
          child: TodoStepRow(
            step: step,
            index: index,
            onToggle: () => widget.onToggle(step.id, !step.done),
            onRename: (String title) => _rename(step, title),
            onDelete: () => _delete(step),
            onConvert: () => widget.onConvert(step.id),
          ),
        );
      },
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        rows,
        if (steps.length < TodoStep.maxSteps)
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
                  // 多行：粘贴的多行文字原样进来，再按行拆成多步。
                  maxLines: null,
                  keyboardType: TextInputType.text,
                  textInputAction: TextInputAction.done,
                  onChanged: _onAddChanged,
                  onSubmitted: (_) => _submitNew(),
                  contextMenuBuilder: appTextContextMenuBuilder,
                  decoration: todoBareInputDecoration(
                    hintText: l10n.todoStepAdd,
                  ),
                ),
              ),
            ],
          ),
        if (onCompleteTodo != null)
          ListItemPresence(
            visible: allDone,
            appearing: allDone,
            duration: duration,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.l,
                AppSpacing.xs,
                AppSpacing.l,
                AppSpacing.s,
              ),
              child: FilledButton.tonalIcon(
                style: AppGlassField.tonalButtonStyle(context),
                onPressed: allDone ? onCompleteTodo : null,
                icon: const FaIcon(FontAwesomeIcons.check, size: 14),
                label: Text(l10n.todoStepsAllDoneComplete),
              ),
            ),
          ),
      ],
    );
  }
}
