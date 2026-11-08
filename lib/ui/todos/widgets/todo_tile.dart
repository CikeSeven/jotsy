import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:node_diary/l10n/app_localizations.dart';

import '../../../app/theme/app_spacing.dart';
import '../../../app/theme/expressive_motion.dart';
import '../../../core/database/app_database.dart';
import '../../widgets/expressive_icon_swap.dart';
import '../../widgets/selectable_row_surface.dart';
import '../../widgets/todo_check_box.dart';
import 'todo_labels.dart';
import 'todo_tile_meta.dart';

/// 一条待办的列表行：方框、标题、备注预览与一排元信息胶囊。
///
/// 外观：卡片表面（[SelectableRowSurface]：16 圆角、0.8dp 微边框、无投影，
/// 多选时选中底色补间到 `secondaryContainer`）；左侧 48dp 触控格里 22dp 方框
/// 按优先级着色（高 error、中 tertiary、低 primary）；标题 `bodyLarge` w500 最
/// 多两行，有备注时下一行是备注的首行；再下一行是元信息胶囊
/// （[buildTodoMetaPills]）。已完成的标题变灰并加删除线。
///
/// 勾选动效（状态机：idle → checking → 交给 [onToggle]）：点未完成的方框时
/// 方框立即画成勾选、按 `spatial` 弹一下（1 → 1.15 → 1），删除线与灰字随
/// `medium` 进度显现，同时轻震一次；动效播完才调用 [onToggle]，由宿主写库
/// 或先收起再写库。取消勾选（已完成的行）不播动效、直接交出。行数据的完成
/// 状态变化（写库后、撤销、同步）时复位到数据所示的状态。减少动画时直接
/// 交出。
///
/// 多选态（[selectionMode]）：方框换成选择圆圈，点行与长按都交给 [onTap] /
/// [onLongPress]（由宿主切换选中），不再响应勾选。
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

  @override
  State<TodoTile> createState() => _TodoTileState();
}

class _TodoTileState extends State<TodoTile>
    with SingleTickerProviderStateMixin {
  /// 勾选动效的进度（0~1）：方框弹跳、删除线与灰字显现都取它。
  late final AnimationController _check = AnimationController(
    vsync: this,
    value: widget.row.completedAt != null ? 1 : 0,
  );

  /// 已点勾、动效还在播：方框先画成勾选，数据随后才变。
  bool _checking = false;

  bool get _done => widget.row.completedAt != null;

  @override
  void didUpdateWidget(TodoTile oldWidget) {
    super.didUpdateWidget(oldWidget);
    final wasDone = oldWidget.row.completedAt != null;
    if (wasDone != _done || oldWidget.row.todoId != widget.row.todoId) {
      // 数据说了算：写库完成、撤销或同步改了完成状态时复位动效。
      _checking = false;
      _check.value = _done ? 1 : 0;
    }
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
      ExpressiveMotion.medium,
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
    final priority = TodoPriority.of(row.priority);
    final meta = buildTodoMetaPills(
      context,
      row: row,
      today: widget.today,
      list: widget.list,
    );
    final note = _notePreview(row.note);

    final leading = widget.selectionMode
        ? _SelectionMark(selected: widget.selected)
        : _CheckButton(
            animation: _check,
            checked: checked,
            enabled: widget.onToggle != null,
            accent: TodoLabels.priorityColor(scheme, priority),
            onAccent: TodoLabels.priorityOnColor(scheme, priority),
            semanticsLabel: widget.onToggle == null
                ? widget.disabledHint
                : _done
                ? l10n.todoMarkUndone
                : l10n.todoMarkDone,
            onTap: () => unawaited(_toggle()),
          );

    return SelectableRowSurface(
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
          children: <Widget>[
            ExpressiveIconSwap(
              switchKey: widget.selectionMode,
              child: SizedBox(width: 48, height: 48, child: leading),
            ),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: AppSpacing.s),
                child: AnimatedBuilder(
                  animation: _check,
                  builder: (BuildContext context, Widget? _) {
                    // 灰字与删除线随勾选进度显现；已完成的行进度恒为 1。
                    final t = Curves.easeOutCubic.transform(_check.value);
                    final ink = Color.lerp(
                      scheme.onSurface,
                      scheme.onSurfaceVariant,
                      t,
                    );
                    return _TileText(
                      title: row.title,
                      note: note,
                      meta: meta,
                      titleStyle: theme.textTheme.bodyLarge?.copyWith(
                        fontWeight: FontWeight.w500,
                        color: ink,
                        decoration: t > 0 ? TextDecoration.lineThrough : null,
                        decorationColor: scheme.onSurfaceVariant.withValues(
                          alpha: t,
                        ),
                      ),
                    );
                  },
                ),
              ),
            ),
            if (!widget.selectionMode) ?widget.trailing,
          ],
        ),
      ),
    );
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

/// 标题、备注预览与元信息胶囊。
class _TileText extends StatelessWidget {
  const _TileText({
    required this.title,
    required this.note,
    required this.meta,
    required this.titleStyle,
  });

  final String title;
  final String? note;
  final List<Widget> meta;
  final TextStyle? titleStyle;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final note = this.note;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        Text(
          title,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: titleStyle,
        ),
        if (note != null)
          Padding(
            padding: const EdgeInsets.only(top: 2),
            child: Text(
              note,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ),
        if (meta.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(top: 6),
            child: Wrap(spacing: 6, runSpacing: 4, children: meta),
          ),
      ],
    );
  }
}

/// 左侧的勾选方框：48dp 触控格、22dp 方框，勾选动效里弹一下。
class _CheckButton extends StatelessWidget {
  const _CheckButton({
    required this.animation,
    required this.checked,
    required this.enabled,
    required this.accent,
    required this.onAccent,
    required this.semanticsLabel,
    required this.onTap,
  });

  final Animation<double> animation;
  final bool checked;
  final bool enabled;
  final Color? accent;
  final Color? onAccent;
  final String? semanticsLabel;
  final VoidCallback onTap;

  /// 弹跳：前 40% 放大到 1.15，其余按 spatial 回落。
  static final Animatable<double> _bounce =
      TweenSequence<double>(<TweenSequenceItem<double>>[
        TweenSequenceItem<double>(
          tween: Tween<double>(
            begin: 1,
            end: 1.15,
          ).chain(CurveTween(curve: ExpressiveMotion.effects)),
          weight: 40,
        ),
        TweenSequenceItem<double>(
          tween: Tween<double>(
            begin: 1.15,
            end: 1,
          ).chain(CurveTween(curve: ExpressiveMotion.spatial)),
          weight: 60,
        ),
      ]);

  @override
  Widget build(BuildContext context) {
    return Semantics(
      checked: checked,
      button: true,
      enabled: enabled,
      label: semanticsLabel,
      excludeSemantics: true,
      child: InkResponse(
        onTap: enabled ? onTap : null,
        radius: 22,
        child: Center(
          child: Opacity(
            opacity: enabled ? 1 : 0.38,
            child: ScaleTransition(
              scale: animation.drive(_bounce),
              child: TodoCheckBoxVisual(
                checked: checked,
                size: 22,
                accent: accent,
                onAccent: onAccent,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// 多选态的选择圆圈：选中为 `primary` 实心勾，未选为 `outline` 空心圆。
class _SelectionMark extends StatelessWidget {
  const _SelectionMark({required this.selected});

  final bool selected;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Center(
      child: ExpressiveIconSwap(
        switchKey: selected,
        child: FaIcon(
          selected
              ? FontAwesomeIcons.solidCircleCheck
              : FontAwesomeIcons.circle,
          size: 21,
          color: selected ? scheme.primary : scheme.outline,
        ),
      ),
    );
  }
}
