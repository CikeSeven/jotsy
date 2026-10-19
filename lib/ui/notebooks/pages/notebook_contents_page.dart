import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:node_diary/l10n/app_localizations.dart';

import '../../../app/theme/app_spacing.dart';
import '../../../app/theme/expressive_motion.dart';
import '../../../core/database/app_database.dart';
import '../../../core/services/app_service.dart';
import '../../diaries/models/time_capsule.dart';
import '../../diaries/pages/diary_preview_page.dart';
import '../../diaries/providers/diary_card_style_provider.dart';
import '../../diaries/viewmodels/diary_card_date_formatter.dart';
import '../../settings/widgets/style_editor/style_editor_common.dart';
import '../../widgets/app_top_bar.dart';
import '../../widgets/delayed_loading_indicator.dart';
import '../../widgets/empty_hint.dart';
import '../controllers/notebook_contents_controller.dart';
import '../providers/notebook_providers.dart';
import '../sections/notebook_chapter_dialogs.dart';
import '../sections/notebook_contents_rows.dart';
import '../viewmodels/notebook_book_layout.dart';
import '../viewmodels/notebook_view.dart';

/// 普通日记本的目录页（首页头部卡片“目录”）。
///
/// 一条扁平的可拖动列表：各章标题行（按章节顺序）后接它的日记，最后是
/// “未分章”。只有日记行能拖（右侧手柄）；松手时每篇归属它上方最近的标题行，
/// 整份顺序一次写回（`reorderNotebookEntries`），数据库推送同样的顺序之前先
/// 按拖完的顺序显示（[_pending]），松手时不会先跳回原位。
///
/// 章节的增删改与上下移经 [NotebookContentsController] 写回 payload；多选
/// 可把日记移到某章，或从本日记本移出（4 秒撤销）。点日记打开预览页，可按
/// 书序左右翻。
///
/// 只从已解锁的首页范围进入；上锁本子在后台重新上锁时由应用级遮罩盖住，
/// 首页范围被重置（“回到全部日记”）时首页会把它之上的页面全部关掉。日记本
/// 被删除（或并入别的本子）时本页自行返回。
class NotebookContentsPage extends ConsumerStatefulWidget {
  const NotebookContentsPage({super.key, required this.notebookId});

  final String notebookId;

  static Route<void> route({required String notebookId}) =>
      MaterialPageRoute<void>(
        builder: (_) => NotebookContentsPage(notebookId: notebookId),
      );

  @override
  ConsumerState<NotebookContentsPage> createState() =>
      _NotebookContentsPageState();
}

class _NotebookContentsPageState extends ConsumerState<NotebookContentsPage> {
  List<NotebookEntryPlacement>? _pending;
  bool _selecting = false;
  final Set<String> _selected = <String>{};
  bool _popScheduled = false;

  late final NotebookContentsController _controller =
      NotebookContentsController(
        ref.read(appDatabaseProvider),
        widget.notebookId,
      );

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final scheme = Theme.of(context).colorScheme;
    final notebookAsync = ref.watch(notebookProvider(widget.notebookId));
    final entriesAsync = ref.watch(notebookContentsProvider(widget.notebookId));
    final notebook = notebookAsync.value;
    if (notebookAsync.hasValue && notebook == null) {
      _popWhenGone();
    }
    final entries = entriesAsync.value;
    final hasEntries = entries != null && entries.isNotEmpty;
    return PopScope(
      canPop: !_selecting,
      onPopInvokedWithResult: (bool didPop, Object? _) {
        if (!didPop) _setSelecting(false);
      },
      child: Scaffold(
        backgroundColor: scheme.surface,
        appBar: AppTopBar(
          title: _TitleWithSubtitle(
            title: l10n.notebookContents,
            subtitle: notebook?.name,
          ),
          actions: <Widget>[
            IconButton(
              tooltip: l10n.notebookContentsNewChapter,
              onPressed: notebook == null ? null : _addChapter,
              icon: const FaIcon(FontAwesomeIcons.folderPlus, size: 16),
            ),
            IconButton(
              tooltip: _selecting
                  ? l10n.notebookContentsSelectDone
                  : l10n.notebookContentsSelect,
              isSelected: _selecting,
              onPressed: hasEntries || _selecting
                  ? () => _setSelecting(!_selecting)
                  : null,
              icon: FaIcon(
                _selecting
                    ? FontAwesomeIcons.xmark
                    : FontAwesomeIcons.listCheck,
                size: 16,
              ),
            ),
          ],
        ),
        bottomNavigationBar: _selecting && notebook != null
            ? NotebookContentsSelectionBar(
                count: _selected.length,
                onMoveToChapter: notebook.payload.chapters.isEmpty
                    ? null
                    : () => unawaited(_moveSelected(notebook)),
                onRemove: () => unawaited(_removeSelected(notebook)),
              )
            : null,
        body: notebook == null || entries == null
            ? const DelayedLoadingIndicator()
            : _buildBody(context, notebook, entries),
      ),
    );
  }

  Widget _buildBody(
    BuildContext context,
    NotebookView notebook,
    List<NotebookContentsEntry> entries,
  ) {
    final chapters = notebook.payload.chapters;
    final items = buildNotebookContents(
      chapters,
      entries,
      pending: _syncPending(chapters, entries),
    );
    final hint = chapters.isEmpty
        ? NotebookContentsChapterHint(onAddChapter: _addChapter)
        : null;
    if (items.isEmpty) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          ?hint,
          Expanded(
            child: EmptyHint(
              icon: FontAwesomeIcons.bookOpen,
              message: context.l10n.notebookContentsEmpty,
            ),
          ),
        ],
      );
    }
    final dateMeta = ref.watch(diaryCardStyleProvider).meta;
    final untitled = context.l10n.autoT0033;
    final now = DateTime.now();
    return CustomScrollView(
      slivers: <Widget>[
        if (hint != null) SliverToBoxAdapter(child: hint),
        SliverReorderableList(
          itemCount: items.length,
          onReorderItem: (int oldIndex, int newIndex) =>
              _reorder(chapters, entries, items, oldIndex, newIndex),
          // 拿起条目即生效的瞬间给一次触觉：手柄是立即拖动，不经过长按。
          onReorderStart: (_) => unawaited(HapticFeedback.mediumImpact()),
          proxyDecorator: _liftProxy,
          itemBuilder: (BuildContext context, int index) {
            final item = items[index];
            switch (item) {
              case NotebookContentsHeader(:final chapter, :final count):
                final chapterIndex = chapter == null
                    ? -1
                    : chapters.indexOf(chapter);
                return NotebookContentsChapterHeader(
                  key: ValueKey<String>(item.key),
                  chapter: chapter,
                  count: count,
                  isFirst: chapterIndex == 0,
                  isLast: chapterIndex == chapters.length - 1,
                  onAction: chapter == null
                      ? null
                      : (action) =>
                            unawaited(_chapterAction(chapter, count, action)),
                );
              case NotebookContentsRow(:final entry):
                final sealed = TimeCapsuleState.fromFields(
                  lockedAt: entry.capsuleLockedAt,
                  unlockAt: entry.capsuleUnlockAt,
                  now: now,
                ).isLocked;
                return NotebookContentsEntryTile(
                  key: ValueKey<String>(item.key),
                  dateLabel: DiaryCardDateFormatter.eyebrow(
                    l10n: context.l10n,
                    meta: dateMeta,
                    createdAt: entry.createdAt,
                    updatedAt: entry.updatedAt,
                    now: now,
                  ),
                  title: entry.title.trim().isEmpty ? untitled : entry.title,
                  archived: entry.isArchived,
                  sealed: sealed,
                  selecting: _selecting,
                  selected: _selected.contains(entry.diaryId),
                  onTap: _selecting
                      ? () => _toggle(entry.diaryId)
                      : () => unawaited(_openPreview(entry.diaryId, items)),
                  dragHandle: ReorderableDragStartListener(
                    index: index,
                    child: const NotebookContentsDragGrip(),
                  ),
                );
            }
          },
        ),
        SliverToBoxAdapter(
          child: SizedBox(
            height: AppSpacing.xxl + MediaQuery.paddingOf(context).bottom,
          ),
        ),
      ],
    );
  }

  /// 拖动后的临时顺序：数据库推送的成书顺序已与它一致时交还给数据库（下一
  /// 帧清除），否则继续按它显示。
  List<NotebookEntryPlacement>? _syncPending(
    List<NotebookChapter> chapters,
    List<NotebookContentsEntry> entries,
  ) {
    final pending = _pending;
    if (pending == null) return null;
    if (sameNotebookPlacements(
      notebookBookPlacements(chapters, entries),
      pending,
    )) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && identical(_pending, pending)) {
          setState(() => _pending = null);
        }
      });
    }
    return pending;
  }

  void _reorder(
    List<NotebookChapter> chapters,
    List<NotebookContentsEntry> entries,
    List<NotebookContentsItem> items,
    int oldIndex,
    int newIndex,
  ) {
    if (oldIndex == newIndex) return;
    final dropped = resolveNotebookContentsDrop(items, oldIndex, newIndex);
    // 按章节归组后的显示顺序写库：拖到最顶端（归第一章）的那篇排在第一章
    // 开头，与界面一致，数据库推送回来时也能与临时顺序比对上。
    final placements = <NotebookEntryPlacement>[
      for (final item in buildNotebookContents(
        chapters,
        entries,
        pending: dropped,
      ))
        if (item is NotebookContentsRow)
          (diaryId: item.entry.diaryId, chapterId: item.chapterId),
    ];
    setState(() => _pending = placements);
    unawaited(_run(() => _controller.reorder(placements), revertOrder: true));
  }

  /// 执行一次写入；失败时提示（拖动失败还要放弃临时顺序，回到数据库的顺序）。
  Future<bool> _run(
    Future<void> Function() action, {
    bool revertOrder = false,
  }) async {
    try {
      await action();
      return true;
    } catch (error) {
      debugPrint('Notebook contents update failed: $error');
      if (!mounted) return false;
      if (revertOrder) setState(() => _pending = null);
      showStyleEditorMessage(context, context.l10n.notebookActionFailed);
      return false;
    }
  }

  void _setSelecting(bool value) {
    if (_selecting == value) return;
    setState(() {
      _selecting = value;
      _selected.clear();
    });
  }

  void _toggle(String diaryId) {
    setState(() {
      if (!_selected.remove(diaryId)) _selected.add(diaryId);
    });
  }

  Future<void> _addChapter() async {
    final title = await showNotebookChapterTitleDialog(context);
    if (title == null || !mounted) return;
    await _run(() => _controller.addChapter(title));
  }

  Future<void> _chapterAction(
    NotebookChapter chapter,
    int count,
    NotebookChapterAction action,
  ) async {
    switch (action) {
      case NotebookChapterAction.rename:
        final title = await showNotebookChapterTitleDialog(
          context,
          initial: chapter.title,
        );
        if (title == null || title == chapter.title || !mounted) return;
        await _run(() => _controller.renameChapter(chapter.id, title));
      case NotebookChapterAction.moveUp:
        await _run(() => _controller.moveChapter(chapter.id, -1));
      case NotebookChapterAction.moveDown:
        await _run(() => _controller.moveChapter(chapter.id, 1));
      case NotebookChapterAction.delete:
        final confirmed = await showNotebookChapterDeleteDialog(
          context,
          title: chapter.title,
          count: count,
        );
        if (!confirmed || !mounted) return;
        await _run(() => _controller.deleteChapter(chapter.id));
    }
  }

  Future<void> _moveSelected(NotebookView notebook) async {
    final ids = _selected.toList();
    if (ids.isEmpty) return;
    final chapters = notebook.payload.chapters;
    final target = await showNotebookChapterPickerSheet(
      context,
      chapters: chapters,
    );
    if (target == null || !mounted) return;
    final chapterId = target.chapterId;
    final ok = await _run(() => _controller.moveToChapter(ids, chapterId));
    if (!ok || !mounted) return;
    final l10n = context.l10n;
    var title = l10n.notebookChapterUnassigned;
    for (final chapter in chapters) {
      if (chapter.id == chapterId) title = chapter.title;
    }
    _setSelecting(false);
    showStyleEditorMessage(
      context,
      l10n.notebookContentsMoved(title, ids.length),
    );
  }

  Future<void> _removeSelected(NotebookView notebook) async {
    final ids = _selected.toList();
    if (ids.isEmpty) return;
    List<DiaryNotebookRow> removed = const <DiaryNotebookRow>[];
    final ok = await _run(() async => removed = await _controller.remove(ids));
    if (!ok || !mounted) return;
    _setSelecting(false);
    unawaited(
      showStyleEditorUndoSnackBar(
        context,
        message: context.l10n.notebookRemovedFrom(notebook.name, ids.length),
        onUndo: () => unawaited(_run(() => _controller.restore(removed))),
      ),
    );
  }

  /// 打开预览页，可按书序左右翻（序列在打开时冻结）。在预览页删除日记时
  /// 给 4 秒撤销。
  Future<void> _openPreview(
    String diaryId,
    List<NotebookContentsItem> items,
  ) async {
    final sequence = DiaryPreviewSequence(
      ids: <String>[
        for (final item in items)
          if (item is NotebookContentsRow) item.entry.diaryId,
      ],
    );
    final result = await Navigator.of(context).push<DiaryPreviewResult?>(
      MaterialPageRoute<DiaryPreviewResult?>(
        builder: (_) => DiaryPreviewPage(diaryId: diaryId, sequence: sequence),
      ),
    );
    if (result == null || !mounted) return;
    final database = ref.read(appDatabaseProvider);
    unawaited(
      showStyleEditorUndoSnackBar(
        context,
        message: context.l10n.autoT0075,
        onUndo: () => unawaited(
          _run(
            () => database.restoreDiary(result.diaryId, touchUpdatedAt: false),
          ),
        ),
      ),
    );
  }

  void _popWhenGone() {
    if (_popScheduled) return;
    _popScheduled = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final route = ModalRoute.of(context);
      if (route != null && route.isCurrent) {
        Navigator.of(context).pop();
      }
    });
  }

  /// 拖起时只轻微放大（与模板管理页一致），衬一层页面底色免得透出下方行。
  static Widget _liftProxy(
    Widget child,
    int index,
    Animation<double> animation,
  ) {
    return AnimatedBuilder(
      animation: animation,
      child: child,
      builder: (BuildContext context, Widget? child) => Transform.scale(
        scale: 1 + 0.02 * ExpressiveMotion.effects.transform(animation.value),
        child: Material(
          color: Theme.of(context).colorScheme.surfaceContainerLow,
          borderRadius: BorderRadius.circular(16),
          child: child,
        ),
      ),
    );
  }
}

/// 顶栏标题：“目录” + 下方一行日记本名称。
class _TitleWithSubtitle extends StatelessWidget {
  const _TitleWithSubtitle({required this.title, this.subtitle});

  final String title;
  final String? subtitle;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final subtitle = this.subtitle;
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text(title, maxLines: 1, overflow: TextOverflow.ellipsis),
        if (subtitle != null)
          Text(
            subtitle,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
      ],
    );
  }
}
