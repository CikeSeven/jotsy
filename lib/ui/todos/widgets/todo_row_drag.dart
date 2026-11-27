import 'package:flutter/material.dart';

import '../../../app/theme/app_radii.dart';
import '../../../app/theme/app_spacing.dart';
import '../../widgets/expressive_state_blend.dart';
import '../models/todo_view.dart';

/// 桌面上把待办行拖到左栏（今天、收集箱、某个清单）上：拖起的是哪几条。
@immutable
class TodoDragPayload {
  const TodoDragPayload({required this.ids, required this.title});

  /// 拖起的待办（多选时为全部选中的，否则就是这一行）。
  final List<String> ids;

  /// 拖动时跟着指针的小卡片上写的标题（第一条）。
  final String title;
}

/// 桌面上可拖起的待办行：按住拖动即拿起，指针下跟着一张写着标题的小卡片
/// （多条时带“+N”），行本身留在原位；松开在 [TodoDropTarget] 以外的地方
/// 什么都不改。点按、右键与拖动手柄的排序照旧（拖动要先移过触摸溢出距离
/// 才开始）。只在 `AppPlatform.isDesktop` 时由调用方包上。
class TodoRowDraggable extends StatelessWidget {
  const TodoRowDraggable({
    super.key,
    required this.payload,
    required this.child,
  });

  final TodoDragPayload payload;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final extra = payload.ids.length - 1;
    return Draggable<TodoDragPayload>(
      data: payload,
      dragAnchorStrategy: pointerDragAnchorStrategy,
      feedback: Material(
        color: scheme.inverseSurface,
        elevation: 6,
        borderRadius: BorderRadius.circular(AppRadii.input),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 280),
          child: Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.m,
              vertical: AppSpacing.s,
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                Flexible(
                  child: Text(
                    payload.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: scheme.onInverseSurface,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                if (extra > 0) ...<Widget>[
                  const SizedBox(width: AppSpacing.s),
                  Text(
                    '+$extra',
                    style: theme.textTheme.labelLarge?.copyWith(
                      color: scheme.inversePrimary,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
      child: child,
    );
  }
}

/// 左栏上接住拖来的待办的一格：指针停在上面时描边与底色补间到 `primary`
/// （[ExpressiveStateBlend]），松开即交给 [onDrop]。[onDrop] 为 null 时原样
/// 返回 [child]（不接）。
class TodoDropTarget extends StatelessWidget {
  const TodoDropTarget({super.key, required this.onDrop, required this.child});

  final ValueChanged<TodoDragPayload>? onDrop;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final onDrop = this.onDrop;
    if (onDrop == null) return child;
    final scheme = Theme.of(context).colorScheme;
    return DragTarget<TodoDragPayload>(
      onAcceptWithDetails: (DragTargetDetails<TodoDragPayload> details) =>
          onDrop(details.data),
      builder:
          (
            BuildContext context,
            List<TodoDragPayload?> candidates,
            List<dynamic> _,
          ) => ExpressiveStateBlend(
            active: candidates.isNotEmpty,
            child: child,
            builder: (BuildContext context, double t, Widget? child) =>
                DecoratedBox(
                  position: DecorationPosition.foreground,
                  decoration: BoxDecoration(
                    color: scheme.primary.withValues(alpha: 0.08 * t),
                    borderRadius: BorderRadius.circular(AppRadii.input),
                    border: Border.all(
                      color: scheme.primary.withValues(alpha: t),
                      width: 2,
                    ),
                  ),
                  child: child,
                ),
          ),
    );
  }
}

/// 拖来的待办落在左栏的 [target] 上。
typedef TodoViewDrop = void Function(TodoView target, TodoDragPayload payload);

/// [target] 接得住拖来的待办时交给 [onDrop] 的回调，否则为 null（不接）。
ValueChanged<TodoDragPayload>? todoDropFor(
  TodoViewDrop? onDrop,
  TodoView target,
) => onDrop == null || !target.acceptsDrop
    ? null
    : (TodoDragPayload payload) => onDrop(target, payload);
