import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:node_diary/l10n/app_localizations.dart';

import '../../../app/theme/app_spacing.dart';
import '../../../core/database/app_database.dart';
import '../../../core/services/app_service.dart';
import '../../app_surface/models/app_surface_enums.dart';
import '../../app_surface/widgets/app_card_surface.dart';
import '../../app_surface/widgets/app_page_background.dart';
import '../../widgets/app_top_bar.dart';
import '../../widgets/delayed_loading_indicator.dart';
import '../../widgets/editing_session_blocker.dart';
import '../../widgets/empty_hint.dart';
import '../../widgets/form_width.dart';
import '../../widgets/text_selection_menu/app_text_context_menu.dart';
import '../../widgets/todo_check_box.dart';
import '../controllers/todo_actions.dart';
import '../controllers/todo_debounced_writer.dart';
import '../providers/todo_providers.dart';
import '../sections/todo_detail_fields.dart';
import '../sections/todo_steps_section.dart';
import '../widgets/todo_labels.dart';

/// 待办详情：标题、步骤、各字段与备注，改一项写一项。
///
/// 标题与备注是逐字输入，防抖后写库（[TodoDebouncedWriter]），离开页面（含
/// 返回、被系统回收前的 dispose）立即写掉还没写的；其余字段在各自的面板里选完即写。
/// 页面期间登记为局域网同步的阻塞者（[EditingSessionBlocker]）：输入框握着
/// 还没写库的文字，同步写进来再被防抖写回会盖掉对方的改动。
///
/// 这条待办在别处被删除（另一台设备同步过来）时显示“已被删除”。
class TodoDetailPage extends ConsumerStatefulWidget {
  const TodoDetailPage({super.key, required this.todoId});

  final String todoId;

  @override
  ConsumerState<TodoDetailPage> createState() => _TodoDetailPageState();
}

class _TodoDetailPageState extends ConsumerState<TodoDetailPage>
    with EditingSessionBlocker<TodoDetailPage> {
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

  Future<void> _delete() async {
    _titleWriter.cancel();
    _noteWriter.cancel();
    final navigator = Navigator.of(context);
    // 提示弹在打开详情的那一页（本页随即出栈）。
    final previous = navigator.context;
    navigator.pop();
    await deleteTodoWithUndo(previous, _database, widget.todoId);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final async = ref.watch(todoProvider(widget.todoId));
    final row = async.value;
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final done = row?.completedAt != null;

    return AppPageBackground(
      area: AppBackgroundArea.other,
      child: Builder(
        builder: (BuildContext context) => Scaffold(
          backgroundColor: AppPageBackdrop.pageColorOf(context),
          appBar: AppTopBar(
            contentMaxWidth: FormWidth.maxWidth,
            leading: IconButton(
              tooltip: l10n.commonBack,
              onPressed: () => Navigator.of(context).maybePop(),
              icon: const FaIcon(FontAwesomeIcons.angleLeft, size: 18),
            ),
            title: Text(l10n.todoDetailTitle),
            actions: <Widget>[
              if (row != null)
                IconButton(
                  tooltip: l10n.todoDelete,
                  onPressed: () => unawaited(_delete()),
                  icon: const FaIcon(FontAwesomeIcons.trashCan, size: 16),
                ),
            ],
          ),
          body: row == null
              ? (async.isLoading
                    ? const DelayedLoadingIndicator()
                    : EmptyHint(
                        icon: FontAwesomeIcons.trashCan,
                        message: l10n.todoNotFound,
                      ))
              : LayoutBuilder(
                  builder: (BuildContext context, BoxConstraints constraints) {
                    final side = FormWidth.gutter(constraints.maxWidth);
                    return ListView(
                      padding: EdgeInsets.fromLTRB(
                        side,
                        AppSpacing.s,
                        side,
                        AppSpacing.xxxl,
                      ),
                      children: <Widget>[
                        _TitleCard(
                          row: row,
                          done: done,
                          controller: _title,
                          focusNode: _titleFocus,
                          onChanged: () => _titleWriter.schedule(_title.text),
                          onToggle: () => unawaited(
                            toggleTodoDone(context, _database, row),
                          ),
                          steps: TodoStepsSection(
                            steps: decodeTodoSteps(row.steps),
                            onChanged: (List<TodoStep> steps) => unawaited(
                              _database.setTodoSteps(row.todoId, steps),
                            ),
                            onToggle: (String stepId, bool value) => unawaited(
                              _database.setTodoStepDone(
                                row.todoId,
                                stepId,
                                value,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: AppSpacing.m),
                        TodoDetailFields(row: row, today: today),
                        const SizedBox(height: AppSpacing.m),
                        AppCardSurface(
                          shadow: false,
                          padding: const EdgeInsets.symmetric(
                            horizontal: AppSpacing.l,
                            vertical: AppSpacing.xs,
                          ),
                          child: TextField(
                            controller: _note,
                            focusNode: _noteFocus,
                            onChanged: _noteWriter.schedule,
                            minLines: 3,
                            maxLines: null,
                            keyboardType: TextInputType.multiline,
                            contextMenuBuilder: appTextContextMenuBuilder,
                            decoration: InputDecoration(
                              hintText: l10n.todoNoteHint,
                              border: InputBorder.none,
                            ),
                          ),
                        ),
                        const SizedBox(height: AppSpacing.l),
                        _Footer(row: row),
                      ],
                    );
                  },
                ),
        ),
      ),
    );
  }
}

/// 标题卡：大方框（勾选完成）+ 标题输入框，下方是步骤。
class _TitleCard extends StatelessWidget {
  const _TitleCard({
    required this.row,
    required this.done,
    required this.controller,
    required this.focusNode,
    required this.onChanged,
    required this.onToggle,
    required this.steps,
  });

  final TodoRow row;
  final bool done;
  final TextEditingController controller;
  final FocusNode focusNode;
  final VoidCallback onChanged;
  final VoidCallback onToggle;
  final Widget steps;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final priority = TodoPriority.of(row.priority);
    return AppCardSurface(
      shadow: false,
      padding: const EdgeInsets.only(
        top: AppSpacing.xs,
        bottom: AppSpacing.xs,
        right: AppSpacing.s,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Semantics(
                checked: done,
                button: true,
                label: done ? l10n.todoMarkUndone : l10n.todoMarkDone,
                excludeSemantics: true,
                child: InkResponse(
                  onTap: onToggle,
                  radius: 24,
                  child: SizedBox(
                    width: 52,
                    height: 52,
                    child: Center(
                      child: TodoCheckBoxVisual(
                        checked: done,
                        size: 24,
                        accent: TodoLabels.priorityColor(scheme, priority),
                        onAccent: switch (priority) {
                          TodoPriority.high => scheme.onError,
                          TodoPriority.medium => scheme.onTertiary,
                          TodoPriority.low => scheme.onPrimary,
                          TodoPriority.none => null,
                        },
                      ),
                    ),
                  ),
                ),
              ),
              Expanded(
                child: TextField(
                  controller: controller,
                  focusNode: focusNode,
                  onChanged: (_) => onChanged(),
                  maxLength: 500,
                  minLines: 1,
                  maxLines: null,
                  textInputAction: TextInputAction.done,
                  contextMenuBuilder: appTextContextMenuBuilder,
                  style: theme.textTheme.titleLarge?.copyWith(
                    color: done ? scheme.onSurfaceVariant : null,
                    decoration: done ? TextDecoration.lineThrough : null,
                    decorationColor: scheme.onSurfaceVariant,
                  ),
                  decoration: InputDecoration(
                    hintText: l10n.todoQuickAddHint,
                    border: InputBorder.none,
                    counterText: '',
                  ),
                ),
              ),
            ],
          ),
          steps,
        ],
      ),
    );
  }
}

/// 创建 / 完成时间。
class _Footer extends StatelessWidget {
  const _Footer({required this.row});

  final TodoRow row;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final style = AppPageBackdrop.onBackgroundTextStyle(
      context,
      theme.textTheme.bodySmall?.copyWith(
        color: theme.colorScheme.onSurfaceVariant,
      ),
    );
    final completedAt = row.completedAt;
    return Column(
      children: <Widget>[
        Text(
          l10n.todoCreatedAt(l10n.formatDateTimeMinute(row.createdAt)),
          style: style,
          textAlign: TextAlign.center,
        ),
        if (completedAt != null)
          Text(
            l10n.todoCompletedAt(l10n.formatDateTimeMinute(completedAt)),
            style: style,
            textAlign: TextAlign.center,
          ),
      ],
    );
  }
}
