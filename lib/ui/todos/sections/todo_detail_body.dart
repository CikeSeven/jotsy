import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:node_diary/l10n/app_localizations.dart';

import '../../../app/theme/app_spacing.dart';
import '../../../core/database/app_database.dart';
import '../../../core/services/app_service.dart';
import '../../home/widgets/home_hint_visibility_scope.dart';
import '../../widgets/delayed_loading_indicator.dart';
import '../../widgets/editing_session_blocker.dart';
import '../../widgets/empty_hint.dart';
import '../../widgets/text_selection_menu/app_text_context_menu.dart';
import '../controllers/todo_actions.dart';
import '../controllers/todo_debounced_writer.dart';
import '../controllers/todo_field_editors.dart';
import '../providers/todo_providers.dart';
import '../widgets/todo_detail_pills.dart';
import 'todo_detail_parts.dart';
import 'todo_steps_section.dart';
import '../widgets/todo_bare_input.dart';

/// 一条待办的详情内容（底部面板 [showTodoDetailSheet] 与宽窗口详情栏
/// `TodoDetailPane` 共用）：大方框 + 标题、属性胶囊、步骤卡、备注卡与
/// 创建 / 完成时间，改一项写一项。
///
/// 标题与备注是逐字输入，防抖后写库（[TodoDebouncedWriter]），卸载时（面板
/// 关闭、详情栏换到另一条）立即写掉还没写的；其余字段在各自的面板里选完即
/// 写。存在期间登记为局域网同步的阻塞者（[EditingSessionBlocker]）：输入框
/// 握着还没写库的文字，同步写进来再被防抖写回会盖掉对方的改动。
///
/// 删除交给宿主（[onDelete]：面板先关、详情栏先收起，再在下层页面弹可撤销
/// 提示）。这条待办在别处被删除（同步）时显示“已被删除”。
class TodoDetailBody extends ConsumerStatefulWidget {
  const TodoDetailBody({
    super.key,
    required this.todoId,
    required this.onDelete,
    this.scrollController,
    this.onEditingFocus,
    this.padding = const EdgeInsets.fromLTRB(
      AppSpacing.xl,
      0,
      AppSpacing.xl,
      AppSpacing.xxxl,
    ),
  });

  final String todoId;
  final VoidCallback onDelete;

  /// 底部面板的 [DraggableScrollableSheet] 交来的滚动控制器。
  final ScrollController? scrollController;

  /// 标题或备注获得焦点时（底部面板据此展开到全屏，给键盘让位）。
  final VoidCallback? onEditingFocus;
  final EdgeInsets padding;

  @override
  ConsumerState<TodoDetailBody> createState() => _TodoDetailBodyState();
}

class _TodoDetailBodyState extends ConsumerState<TodoDetailBody>
    with EditingSessionBlocker<TodoDetailBody> {
  @override
  String get editingSessionLabel => 'todo-detail';

  final TextEditingController _title = TextEditingController();
  final TextEditingController _note = TextEditingController();
  final FocusNode _titleFocus = FocusNode();
  final FocusNode _noteFocus = FocusNode();
  bool _loaded = false;
  late final AppDatabase _database = ref.read(appDatabaseProvider);

  /// 标题为空时不写（数据库要求非空），离开时保留原标题。
  late final TodoDebouncedWriter<String> _titleWriter =
      TodoDebouncedWriter<String>(
        onFire: (String text) {
          final title = text.trim();
          if (title.isNotEmpty) {
            unawaited(_database.setTodoTitle(widget.todoId, title));
          }
        },
      );
  late final TodoDebouncedWriter<String> _noteWriter =
      TodoDebouncedWriter<String>(
        onFire: (String text) =>
            unawaited(_database.setTodoNote(widget.todoId, text)),
      );

  @override
  void initState() {
    super.initState();
    ref.listenManual<AsyncValue<TodoRow?>>(todoProvider(widget.todoId), (
      AsyncValue<TodoRow?>? previous,
      AsyncValue<TodoRow?> next,
    ) {
      final row = next.value;
      if (row != null) _sync(row);
    }, fireImmediately: true);
    _titleFocus.addListener(_onFocus);
    _noteFocus.addListener(_onFocus);
  }

  @override
  void dispose() {
    _titleWriter.flush();
    _noteWriter.flush();
    _title.dispose();
    _note.dispose();
    _titleFocus.dispose();
    _noteFocus.dispose();
    super.dispose();
  }

  void _onFocus() {
    if (_titleFocus.hasFocus || _noteFocus.hasFocus) {
      widget.onEditingFocus?.call();
    }
  }

  /// 第一份数据到达时填进输入框；之后只在输入框没有焦点、也没有待写的
  /// 改动时跟上外部的变化（撤销完成、同步——同步期间本页阻塞，正常不会
  /// 发生，但覆盖恢复等整库替换后仍要跟上）。
  void _sync(TodoRow row) {
    if (!_loaded) {
      _loaded = true;
      _title.text = row.title;
      _note.text = row.note;
      return;
    }
    if (!_titleFocus.hasFocus &&
        !_titleWriter.pending &&
        _title.text != row.title) {
      _title.text = row.title;
    }
    if (!_noteFocus.hasFocus &&
        !_noteWriter.pending &&
        _note.text != row.note) {
      _note.text = row.note;
    }
  }

  void _delete() {
    _titleWriter.cancel();
    _noteWriter.cancel();
    widget.onDelete();
  }

  Future<void> _duplicate(TodoRow row, DateTime today) async {
    _titleWriter.flush();
    final l10n = context.l10n;
    final title = l10n.todoDuplicateTitle(row.title);
    await TodoFieldEditors(
      context: context,
      ref: ref,
      row: row,
      today: today,
    ).duplicate(title.length > 500 ? row.title : title);
    if (!mounted) return;
    unawaited(
      HomeHintVisibilityScope.showTrackedSnackBar(
        context: context,
        snackBar: SnackBar(content: Text(l10n.todoDuplicatedNotice)),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final async = ref.watch(todoProvider(widget.todoId));
    final row = async.value;
    if (row == null) {
      return async.isLoading
          ? const DelayedLoadingIndicator()
          : EmptyHint(
              icon: FontAwesomeIcons.trashCan,
              message: l10n.todoNotFound,
            );
    }
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final steps = decodeTodoSteps(row.steps);
    return ListView(
      controller: widget.scrollController,
      padding: widget.padding,
      children: <Widget>[
        TodoDetailHeader(
          row: row,
          controller: _title,
          focusNode: _titleFocus,
          onChanged: () => _titleWriter.schedule(_title.text),
          onToggle: () => unawaited(toggleTodoDone(context, _database, row)),
          onDelete: _delete,
          onDuplicate: () => unawaited(_duplicate(row, today)),
        ),
        const SizedBox(height: AppSpacing.m),
        TodoDetailPills(row: row, today: today),
        const SizedBox(height: AppSpacing.xl),
        TodoDetailSectionCard(
          title: steps.isEmpty
              ? l10n.todoStepsTitle
              : l10n.todoStepsTitleProgress(
                  steps.where((s) => s.done).length,
                  steps.length,
                ),
          progress: steps.isEmpty
              ? null
              : steps.where((s) => s.done).length / steps.length,
          child: TodoStepsSection(
            steps: steps,
            onChanged: (List<TodoStep> next) =>
                unawaited(_database.setTodoSteps(row.todoId, next)),
            onToggle: (String stepId, bool value) =>
                unawaited(_database.setTodoStepDone(row.todoId, stepId, value)),
          ),
        ),
        const SizedBox(height: AppSpacing.m),
        TodoDetailSectionCard(
          title: l10n.todoNoteTitle,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.l),
            child: TextField(
              controller: _note,
              focusNode: _noteFocus,
              onChanged: _noteWriter.schedule,
              minLines: 3,
              maxLines: null,
              keyboardType: TextInputType.multiline,
              contextMenuBuilder: appTextContextMenuBuilder,
              decoration: todoBareInputDecoration(hintText: l10n.todoNoteHint),
            ),
          ),
        ),
        const SizedBox(height: AppSpacing.l),
        TodoDetailFooter(row: row),
      ],
    );
  }
}
