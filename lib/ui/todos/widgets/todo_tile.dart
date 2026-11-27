import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter/services.dart';
import 'package:node_diary/l10n/app_localizations.dart';

import '../../../app/theme/app_spacing.dart';
import '../../../app/theme/expressive_motion.dart';
import '../../../core/database/app_database.dart';
import '../../diaries/viewmodels/search_highlight.dart';
import '../../widgets/expressive_icon_swap.dart';
import '../../widgets/list_item_presence.dart';
import '../../widgets/selectable_row_surface.dart';
import '../viewmodels/todo_priority_colors.dart';
import 'todo_complete_motion.dart';
import 'todo_tile_check.dart';
import 'todo_tile_meta.dart';
import 'todo_tile_steps.dart';
import 'todo_tile_text.dart';

/// 一条待办的列表行：方框、标题、备注预览与一排元信息胶囊。
///
/// 外观：卡片表面（[SelectableRowSurface]：16 圆角、0.8dp 微边框、无投影，
/// 多选时选中底色补间到 `secondaryContainer`）；左侧 48dp 触控格里 22dp 方框
/// 按优先级着色（[TodoPriorityColors]：高红、中橙、低蓝，2dp 描边 + 淡底；
/// 无优先级为 `outline` 细描边）；标题 `bodyLarge` w500 最多两行，有备注时
/// 下一行是备注的首行；再下一行是元信息胶囊（[buildTodoMetaPills]）。已完成
/// 的标题变灰并按行划上删除线（[TodoTileText]）。
///
/// 勾选动效（“勾选三拍”，时序见 [TodoCompleteMotion]；状态机：idle →
/// checking → 交给 [onToggle]）：按下方框压小、松手弹起（[TodoTileCheckButton]），
/// 方框立即画成勾选、对勾描出，删除线逐行划过、标题变灰，同时轻震一次；
/// 停一拍后才调用 [onToggle]，由宿主写库或先收起再写库。取消勾选（已完成的
/// 行）不播动效、直接交出。行数据的完成状态变化（写库后、撤销、同步）时
/// 复位到数据所示的状态。减少动画时直接交出。
///
/// 步骤：给了 [onToggleSteps] 时步骤胶囊可点，[stepsExpanded] 为 true 时在
/// 胶囊下就地展开各步（[TodoTileSteps]，经 [onToggleStep] 勾选），展开 /
/// 收起按高度补间。
///
/// 多选态（[selectionMode]）：方框换成选择圆圈，点行与长按都交给 [onTap] /
/// [onLongPress]（由宿主切换选中），不再响应勾选与步骤。
///
/// 读屏：[semanticActions] 挂在整行上（完成、改期、删除等，与滑动 / 右键
/// 菜单等价），不必找到方框或会滑动才能操作。
///
/// [onToggle] 为 null 时方框淡化、不能勾选（如日历上重复待办以后的某一次，
/// 读屏念 [disabledHint]）；拖动手柄 [trailing] 由调用方在可手动排序的视图
/// 里给出。
class TodoTile extends StatefulWidget {
  const TodoTile({
    super.key,
    required this.row,
    required this.today,
    required this.onToggle,
    required this.onTap,
    this.list,
    this.trailing,
    this.disabledHint,
    this.onLongPress,
    this.selectionMode = false,
    this.selected = false,
    this.stepsExpanded = false,
    this.onToggleSteps,
    this.onToggleStep,
    this.semanticActions,
    this.highlights = const <String>[],
  });

  final TodoRow row;

  /// 本地零点的“今天”（截止日的相对说法与是否逾期）。
  final DateTime today;
  final VoidCallback? onToggle;
  final VoidCallback onTap;
  final VoidCallback? onLongPress;

  /// [onToggle] 为 null 时方框的读屏说明。
  final String? disabledHint;

  /// 所在清单；给出时在元信息里显示清单名。
  final TodoListRow? list;
  final Widget? trailing;

  /// 是否处于多选态（方框换成选择圆圈）。
  final bool selectionMode;

  /// 多选态下是否选中；非多选时用于宽窗口里标出详情栏正在看的一条。
  final bool selected;

  /// 步骤是否就地展开。
  final bool stepsExpanded;

  /// 点步骤胶囊（展开 / 收起）；null 时胶囊不可点。
  final VoidCallback? onToggleSteps;

  /// 勾选展开后的某一步。
  final ValueChanged<TodoStep>? onToggleStep;

  /// 读屏的自定义动作。
  final Map<CustomSemanticsAction, VoidCallback>? semanticActions;

  /// 搜索词（经 `splitSearchTerms` 拆好）：标题与备注里命中的地方高亮，
  /// 备注改为从第一个命中处摘录。
  final List<String> highlights;

  @override
  State<TodoTile> createState() => _TodoTileState();
}

class _TodoTileState extends State<TodoTile>
    with SingleTickerProviderStateMixin {
  /// 勾选动效的进度（0~1，含停的一拍）：方框弹跳、删除线与灰字都取它。
  late final AnimationController _check = AnimationController(
    vsync: this,
    value: widget.row.completedAt != null ? 1 : 0,
  );

  /// 删除线与灰字的进度（[TodoCompleteMotion.strike] 区间）。
  late final Animation<double> _strike = _check.drive(
    CurveTween(curve: TodoCompleteMotion.strike),
  );

  /// 已点勾、动效还在播：方框先画成勾选，数据随后才变。
  bool _checking = false;

  /// 展开过步骤（之后收起也留着，好演收起；没展开过的行不建步骤）。
  bool _stepsBuilt = false;

  bool get _done => widget.row.completedAt != null;

  @override
  void initState() {
    super.initState();
    _stepsBuilt = widget.stepsExpanded;
  }

  @override
  void didUpdateWidget(TodoTile oldWidget) {
    super.didUpdateWidget(oldWidget);
    final wasDone = oldWidget.row.completedAt != null;
    if (wasDone != _done || oldWidget.row.todoId != widget.row.todoId) {
      // 数据说了算：写库完成、撤销或同步改了完成状态时复位动效。
      _checking = false;
      _check.value = _done ? 1 : 0;
    }
    if (widget.stepsExpanded) _stepsBuilt = true;
  }

  @override
  void dispose() {
    _check.dispose();
    super.dispose();
  }

  Future<void> _toggle() async {
    final onToggle = widget.onToggle;
    if (onToggle == null || _checking) return;
    if (_done) {
      onToggle();
      return;
    }
    final duration = ExpressiveMotion.duration(
      context,
      TodoCompleteMotion.check,
    );
    unawaited(HapticFeedback.lightImpact());
    if (duration == Duration.zero) {
      onToggle();
      return;
    }
    setState(() => _checking = true);
    await _check.animateTo(1, duration: duration, curve: Curves.linear);
    if (!mounted || !_checking) return;
    onToggle();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final row = widget.row;
    final checked = _done || _checking;
    final priority = TodoPriorityColors.of(
      scheme,
      TodoPriority.of(row.priority),
    );
    final interactive = !widget.selectionMode;
    final onToggleSteps = interactive ? widget.onToggleSteps : null;
    final expanded = widget.stepsExpanded && onToggleSteps != null;
    final meta = buildTodoMetaPills(
      context,
      row: row,
      today: widget.today,
      list: widget.list,
      stepsExpanded: expanded,
      onStepsTap: onToggleSteps,
    );
    final highlights = widget.highlights;
    final note = highlights.isEmpty
        ? _notePreview(row.note)
        : searchExcerpt(row.note, highlights, maxLength: 120) ??
              _notePreview(row.note);
    final onToggleStep = widget.onToggleStep;
    final steps = _stepsBuilt && onToggleStep != null
        ? decodeTodoSteps(row.steps)
        : const <TodoStep>[];
    final below = steps.isEmpty
        ? null
        : ListItemPresence(
            visible: expanded,
            appearing: expanded,
            duration: ExpressiveMotion.duration(
              context,
              ExpressiveMotion.medium,
            ),
            child: TodoTileSteps(steps: steps, onToggle: onToggleStep!),
          );

    final leading = widget.selectionMode
        ? TodoTileSelectionMark(selected: widget.selected)
        : TodoTileCheckButton(
            check: _check,
            checked: checked,
            enabled: widget.onToggle != null,
            accent: priority?.accent,
            onAccent: priority?.onAccent,
            tint: priority?.tint,
            semanticsLabel: widget.onToggle == null
                ? widget.disabledHint
                : _done
                ? l10n.todoMarkUndone
                : l10n.todoMarkDone,
            onTap: () => unawaited(_toggle()),
          );

    Widget tile = SelectableRowSurface(
      selected: widget.selected,
      selectionMode: widget.selectionMode,
      onTap: widget.onTap,
      onLongPress: widget.onLongPress,
      child: Padding(
        padding: const EdgeInsetsDirectional.only(
          end: AppSpacing.m,
          top: AppSpacing.xs,
          bottom: AppSpacing.xs,
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            ExpressiveIconSwap(
              switchKey: widget.selectionMode,
              child: SizedBox(width: 48, height: 48, child: leading),
            ),
            Expanded(
              child: Padding(
                // 顶部多留 4：标题首行（24 高）的中线与 48dp 方框格的中线
                // 对齐；行与胶囊、展开的步骤一起往下长，方框停在首行旁。
                padding: const EdgeInsets.only(
                  top: AppSpacing.s + AppSpacing.xs,
                  bottom: AppSpacing.s,
                ),
                child: AnimatedBuilder(
                  animation: _strike,
                  builder: (BuildContext context, Widget? _) {
                    // 灰字与删除线随勾选进度显现；已完成的行进度恒为 1。
                    final t = _strike.value;
                    return TodoTileText(
                      title: row.title,
                      note: note,
                      highlights: highlights,
                      meta: meta,
                      strike: t,
                      strikeColor: scheme.onSurfaceVariant,
                      below: below,
                      titleStyle: theme.textTheme.bodyLarge?.copyWith(
                        fontWeight: FontWeight.w500,
                        color: Color.lerp(
                          scheme.onSurface,
                          scheme.onSurfaceVariant,
                          t,
                        ),
                      ),
                    );
                  },
                ),
              ),
            ),
            if (interactive)
              if (widget.trailing case final trailing?)
                SizedBox(height: 48, child: Center(child: trailing)),
          ],
        ),
      ),
    );
    final actions = widget.semanticActions;
    if (interactive && actions != null && actions.isNotEmpty) {
      tile = Semantics(customSemanticsActions: actions, child: tile);
    }
    // 勾选动效逐帧只重绘这一行。
    return RepaintBoundary(child: tile);
  }

  /// 备注的第一行非空文字（行上只显示一行）。
  static String? _notePreview(String note) {
    if (note.isEmpty) return null;
    for (final line in note.split('\n')) {
      final text = line.trim();
      if (text.isNotEmpty) return text;
    }
    return null;
  }
}
