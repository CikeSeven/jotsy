import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:node_diary/l10n/app_localizations.dart';

import '../../../app/theme/app_breakpoints.dart';
import '../../../app/theme/app_spacing.dart';
import '../../../core/database/app_database.dart';
import '../../app_surface/widgets/app_glass_scope.dart';
import '../../diaries/controllers/diary_list_switch_motion.dart';
import '../../diaries/widgets/diary_list_switch_reveal.dart';
import '../../widgets/delayed_loading_indicator.dart';
import '../../widgets/empty_hint.dart';
import '../../widgets/expressive_entrance.dart';
import '../../widgets/list_make_room.dart';
import '../models/todo_view.dart';
import '../viewmodels/todo_groups.dart';
import '../viewmodels/todo_list_entries.dart';
import '../widgets/todo_inline_add_row.dart';
import '../widgets/todo_labels.dart';
import '../widgets/todo_quick_add_sheet.dart';
import '../widgets/todo_view_hero.dart';
import 'todo_list_callbacks.dart';
import 'todo_list_slivers.dart';

/// 待办页的列表列：页头留白 → 概览卡（[TodoViewHero]）→ 各组
/// （[TodoListSlivers]，内联新建插在未完成与已完成之间）→ 末尾给 FAB 与
/// 玻璃底栏的空位。还在加载时为延迟出现的加载指示；没有任何一组时，内联
/// 新建之后是空状态。
///
/// 每个视图有自己的滚动位置（按视图键存进 PageStorage，切回来时停在原
/// 处）。概览卡、各项与空状态都挂着视图切换的退场 / 错峰入场
/// （[switchMotion]，概览卡是第 0 项）。
///
/// 内联新建在输入时（[inlineEditing]）列表底部让出被键盘盖住的一段：首页
/// Scaffold 不随键盘缩小，不让的话列表末尾的输入框会被键盘盖住；让出后视口
/// 变矮，输入框由 EditableText 自己滚到可见处。
Widget buildTodosPageList({
  required BuildContext context,
  required TodoView view,
  required DateTime today,
  required List<TodoGroup>? groups,
  required List<TodoListEntry>? entries,
  required List<TodoRow>? open,
  required List<TodoRow>? completed,
  required Map<TodoSmartView, int> counts,
  required Map<String, TodoListRow> listsById,
  required Map<String?, TodoListProgress> progress,
  required bool wide,
  required double width,
  required double topInset,
  required double bottomInset,
  required bool inlineEditing,
  required bool reorderable,
  required Set<String> collapsed,
  required ValueChanged<String> onToggleCollapsed,
  required TodoListRowState rowState,
  required TodoListCallbacks callbacks,
  required TodoQuickAddPreset? inlinePreset,
  required Key inlineAddKey,
  required ValueChanged<bool> onInlineEditingChanged,
  required VoidCallback? onEditList,
  required MakeRoomController makeRoom,
  required DiaryListSwitchMotion switchMotion,
}) {
  final l10n = context.l10n;
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
          // 页面按视图给的 GlobalKey：列表从空到有、上面多出一组时换了位置
          // 也不重建；换视图时换一把，预填的清单 / 日期跟着视图走。
          key: inlineAddKey,
          preset: inlinePreset,
          onEditingChanged: onInlineEditingChanged,
        );
  Widget reveal(int index, Widget child, {bool glass = false}) =>
      DiaryListSwitchReveal(
        motion: switchMotion,
        index: index,
        glass: glass,
        child: child,
      );

  final slivers = <Widget>[
    SliverToBoxAdapter(child: SizedBox(height: topInset)),
    SliverPadding(
      padding: padding.copyWith(bottom: AppSpacing.xs),
      sliver: SliverToBoxAdapter(
        child: reveal(
          0,
          glass: AppGlass.of(context).isGlass(AppGlassComponent.cards),
          TodoViewHero(
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
    ),
    if (groups == null || entries == null)
      const SliverFillRemaining(
        hasScrollBody: false,
        child: DelayedLoadingIndicator(),
      )
    else ...<Widget>[
      TodoListSlivers(
        groups: groups,
        entries: entries,
        doneKind: switch (view.smart) {
          TodoSmartView.today => TodoGroupKind.completedToday,
          _ when view.isSingleList => TodoGroupKind.completed,
          _ => null,
        },
        reorderable: reorderable,
        listsById: listsById,
        showListOnRows: !view.isSingleList,
        today: today,
        collapsed: collapsed,
        onToggleCollapsed: onToggleCollapsed,
        callbacks: callbacks,
        state: rowState,
        makeRoom: makeRoom,
        switchMotion: switchMotion,
        horizontalPadding: gutter,
        firstRevealIndex: 1,
        inlineAdd: inlineAdd,
      ),
      if (groups.isEmpty)
        SliverFillRemaining(
          hasScrollBody: false,
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: AppSpacing.xxl),
            child: reveal(
              2,
              // 最后一条完成 / 移走后淡入上移，而不是硬切出现。
              ExpressiveEntrance(
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
          ),
        ),
    ],
    // FAB、玻璃底栏与多选操作栏下方留出空间，最后一条能完整滚出来。
    SliverToBoxAdapter(child: SizedBox(height: 112 + bottomInset)),
  ];
  return _KeyboardGap(
    enabled: inlineEditing,
    child: CustomScrollView(
      // 按视图存滚动位置：切回来时停在原处，换到别的视图从头开始。
      key: PageStorageKey<String>('todos_list_${view.key}'),
      slivers: slivers,
    ),
  );
}

/// 内联新建输入时在列表底部让出被软键盘盖住的那一段。
///
/// 键盘高度读窗口本身（`View.viewInsets`，经 [WidgetsBindingObserver] 在
/// 窗口尺寸变化时更新）：首页挂着 `KeyboardShield`，MediaQuery 里的键盘高度
/// 恒为打开首页时的值，读它既让不开键盘、也不会随键盘收起复原。只让出盖住
/// 列表的部分（键盘高度减去列表底边到屏幕底边的距离），不输入
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
