import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/theme/expressive_motion.dart';
import '../../../core/services/app_service.dart';
import '../../widgets/app_modal/app_modal_bottom_sheet.dart';
import '../../widgets/keyboard_visibility.dart';
import '../controllers/todo_actions.dart';
import 'todo_detail_body.dart';

/// 待办详情的可拖动底部面板：打开时占屏高 62%，上拉吸附到全屏，往下拖到
/// 底即关闭；标题或备注获得焦点时自动展开到全屏，给键盘让位。
///
/// 面板内有自己的 [ScaffoldMessenger]：勾选完成的撤销提示弹在面板里，不被
/// 面板盖住。删除时先关面板，再在打开它的那一页（Navigator 的 context）弹
/// 可撤销提示。
Future<void> showTodoDetailSheet(BuildContext context, String todoId) {
  final navigatorContext = Navigator.of(context).context;
  final database = ProviderScope.containerOf(
    context,
    listen: false,
  ).read(appDatabaseProvider);
  return showAppModalBottomSheet<void>(
    context: context,
    useSafeArea: true,
    showDragHandle: true,
    isScrollControlled: true,
    sheetAnimationStyle: ExpressiveMotion.reduceMotion(context)
        ? AnimationStyle.noAnimation
        : null,
    builder: (BuildContext sheetContext) => _TodoDetailSheet(
      todoId: todoId,
      onDeleteTodo: (String id) {
        Navigator.of(sheetContext).pop();
        if (navigatorContext.mounted) {
          unawaited(deleteTodoWithUndo(navigatorContext, database, id));
        }
      },
    ),
  );
}

class _TodoDetailSheet extends StatefulWidget {
  const _TodoDetailSheet({required this.todoId, required this.onDeleteTodo});

  final String todoId;
  final ValueChanged<String> onDeleteTodo;

  @override
  State<_TodoDetailSheet> createState() => _TodoDetailSheetState();
}

class _TodoDetailSheetState extends State<_TodoDetailSheet> {
  static const double _initialSize = 0.62;

  final DraggableScrollableController _sheet = DraggableScrollableController();
  late String _todoId = widget.todoId;

  @override
  void dispose() {
    _sheet.dispose();
    super.dispose();
  }

  /// 开始输入时展开到全屏：键盘升起后半屏的面板只剩一条缝。
  void _expand() {
    if (!_sheet.isAttached || _sheet.size >= 0.99) return;
    final duration = ExpressiveMotion.duration(
      context,
      ExpressiveMotion.medium,
    );
    if (duration == Duration.zero) {
      _sheet.jumpTo(1);
    } else {
      unawaited(
        _sheet.animateTo(
          1,
          duration: duration,
          curve: ExpressiveMotion.effects,
        ),
      );
    }
  }

  /// 在同一个面板内原地切换到另一条待办（如已完成副本跳到下一次循环、或取消
  /// 完成触发回滚后切到原待办），不叠加第二层底部面板；切换后把滚动归零，
  /// 新的 [TodoDetailBody] 按自己的错峰入场过渡。
  void _switchTodo(String id) {
    if (id == _todoId || !mounted) return;
    setState(() => _todoId = id);
  }

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      controller: _sheet,
      expand: false,
      initialChildSize: _initialSize,
      minChildSize: 0.3,
      snap: true,
      snapSizes: const <double>[_initialSize],
      builder: (BuildContext context, ScrollController scrollController) =>
          ScaffoldMessenger(
            child: Scaffold(
              backgroundColor: Colors.transparent,
              body: KeyboardInsetPadding(
                child: TodoDetailBody(
                  key: ValueKey<String>('todo_detail_$_todoId'),
                  todoId: _todoId,
                  scrollController: scrollController,
                  onDelete: () => widget.onDeleteTodo(_todoId),
                  onOpenTodo: _switchTodo,
                  onEditingFocus: _expand,
                ),
              ),
            ),
          ),
    );
  }
}
