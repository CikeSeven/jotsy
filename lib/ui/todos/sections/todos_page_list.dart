import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:node_diary/l10n/app_localizations.dart';

import '../../../app/theme/app_breakpoints.dart';
import '../../../app/theme/app_spacing.dart';
import '../../../core/database/app_database.dart';
import '../../widgets/delayed_loading_indicator.dart';
import '../../widgets/empty_hint.dart';
import '../models/todo_settings.dart';
import '../models/todo_view.dart';
import '../viewmodels/todo_groups.dart';
import '../widgets/todo_inline_add_row.dart';
import '../widgets/todo_labels.dart';
import '../widgets/todo_quick_add_sheet.dart';
import '../widgets/todo_view_hero.dart';
import 'todo_list_slivers.dart';

/// 待办页的列表列：页头留白 → 概览卡（[TodoViewHero]）→ 各组（
/// [buildTodoListSlivers]，内联新建插在未完成与已完成之间）→ 末尾给 FAB 与
/// 玻璃底栏的空位。还在加载时为延迟出现的加载指示；没有任何一组时，内联
/// 新建之后是空状态。
///
/// 内联新建在输入时（[inlineEditing]）列表底部让出被键盘盖住的一段：首页
/// Scaffold 不随键盘缩小，不让的话列表末尾的输入框会被键盘盖住；让出后视口
/// 变矮，输入框由 EditableText 自己滚到可见处。
Widget buildTodosPageList({
  required BuildContext context,
  required TodoView view,
  required DateTime today,
  required List<TodoGroup>? groups,
  required List<TodoRow>? open,
  required List<TodoRow>? completed,
  required Map<TodoSmartView, int> counts,
  required Map<String, TodoListRow> listsById,
  required Map<String?, TodoListProgress> progress,
  required TodoSettings settings,
  required bool wide,
  required double width,
  required double topInset,
  required double bottomInset,
  required bool inlineEditing,
  required Set<String> collapsed,
  required ValueChanged<String> onToggleCollapsed,
  required TodoListRowState rowState,
  required TodoListCallbacks callbacks,
  required TodoQuickAddPreset? inlinePreset,
  required ValueChanged<bool> onInlineEditingChanged,
  required VoidCallback? onEditList,
}) {
  final l10n = context.l10n;
  final scheme = Theme.of(context).colorScheme;
  final gutter = wide
      ? AppSpacing.l
      : AppContentWidth.gutter(width, AppContentWidth.reading);
  final padding = EdgeInsets.symmetric(horizontal: gutter);
  final listId = view.listId;
  final summary = open == null || completed == null
      ? const TodoTodaySummary(remaining: 0, overdue: 0, doneToday: 0)
      : todoTodaySummary(open, completed, today);
  final heroCount = switch (view.smart) {
    TodoSmartView.completed => completed?.length ?? 0,
    final smart? => counts[smart] ?? 0,
    null => 0,
  };
  final inlineAdd = inlinePreset == null
      ? null
      : TodoInlineAddRow(
          // 换视图时换一个：预填的清单 / 日期跟着视图走，输入框也收起。
          key: ValueKey<String>('inline_add_${view.key}'),
          preset: inlinePreset,
          onEditingChanged: onInlineEditingChanged,
        );

  final slivers = <Widget>[
    SliverToBoxAdapter(child: SizedBox(height: topInset)),
    SliverPadding(
      padding: padding.copyWith(bottom: AppSpacing.xs),
      sliver: SliverToBoxAdapter(
        child: TodoViewHero(
          view: view,
          today: today,
          summary: summary,
          count: heroCount,
          list: listId == null ? null : listsById[listId],
          progress: view.isSingleList ? progress[listId] : null,
          onEditList: onEditList,
        ),
      ),
    ),
    if (groups == null)
      const SliverFillRemaining(
        hasScrollBody: false,
        child: DelayedLoadingIndicator(),
      )
    else if (groups.isEmpty) ...<Widget>[
      if (inlineAdd != null)
        SliverPadding(
          padding: padding.copyWith(top: AppSpacing.m),
          sliver: SliverToBoxAdapter(child: inlineAdd),
        ),
      SliverFillRemaining(
        hasScrollBody: false,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: AppSpacing.xxl),
          child: EmptyHint(
            icon: view.smart == null
                ? FontAwesomeIcons.listCheck
                : TodoLabels.smartViewIcon(view.smart!),
            message: switch (view.smart) {
              TodoSmartView.today => l10n.todoEmptyToday,
              TodoSmartView.completed => l10n.todoEmptyCompleted,
              _ => l10n.todoEmptyList,
            },
          ),
        ),
      ),
    ] else
      ...buildTodoListSlivers(
        groups: groups,
        listsById: listsById,
        showListOnRows: !view.isSingleList,
        reorderable: view.isSingleList && settings.sort == TodoSortMode.manual,
        today: today,
        collapsed: collapsed,
        onToggleCollapsed: onToggleCollapsed,
        horizontalPadding: gutter,
        scheme: scheme,
        state: rowState,
        callbacks: callbacks,
        inlineAdd: inlineAdd,
      ),
    // FAB、玻璃底栏与多选操作栏下方留出空间，最后一条能完整滚出来。
    SliverToBoxAdapter(child: SizedBox(height: 112 + bottomInset)),
  ];
  return _KeyboardGap(
    enabled: inlineEditing,
    child: CustomScrollView(slivers: slivers),
  );
}

/// 内联新建输入时在列表底部让出被软键盘盖住的那一段。
///
/// 键盘高度读窗口本身（`View.viewInsets`，经 [WidgetsBindingObserver] 在
/// 窗口尺寸变化时更新）：首页挂着 `KeyboardShield`，MediaQuery 里的键盘高度
/// 恒为打开首页时的值，读它既让不开键盘、也不会随键盘收起复原。只让出盖住
/// 列表的部分（键盘高度减去列表底边到屏幕底边的距离，如实色底栏），不输入
/// 时为 0、也不监听。结构恒定，切换时列表不重建。
class _KeyboardGap extends StatefulWidget {
  const _KeyboardGap({required this.enabled, required this.child});

  final bool enabled;
  final Widget child;

  @override
  State<_KeyboardGap> createState() => _KeyboardGapState();
}

class _KeyboardGapState extends State<_KeyboardGap>
    with WidgetsBindingObserver {
  double _gap = 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void didUpdateWidget(_KeyboardGap oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.enabled != widget.enabled) _measure();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeMetrics() => _measure();

  void _measure() {
    var gap = 0.0;
    final box = context.findRenderObject();
    if (widget.enabled && box is RenderBox && box.hasSize) {
      final view = View.of(context);
      final keyboard = view.viewInsets.bottom / view.devicePixelRatio;
      if (keyboard > 0) {
        final screenHeight = view.physicalSize.height / view.devicePixelRatio;
        final bottom = box.localToGlobal(Offset(0, box.size.height)).dy;
        gap = (keyboard - (screenHeight - bottom)).clamp(0.0, keyboard);
      }
    }
    if (gap != _gap && mounted) setState(() => _gap = gap);
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(bottom: _gap),
      child: widget.child,
    );
  }
}
