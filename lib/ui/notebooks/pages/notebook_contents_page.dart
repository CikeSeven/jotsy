import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:node_diary/l10n/app_localizations.dart';

import '../../../app/theme/app_spacing.dart';
import '../../../core/database/app_database.dart';
import '../../../core/services/app_service.dart';
import '../../diaries/controllers/diary_open_flow.dart';
import '../../diaries/pages/diary_preview_page.dart';
import '../../diaries/providers/diary_card_style_provider.dart';
import '../../settings/widgets/style_editor/style_editor_common.dart';
import '../../widgets/app_top_bar.dart';
import '../../widgets/delayed_loading_indicator.dart';
import '../../widgets/empty_hint.dart';
import '../controllers/notebook_contents_controller.dart';
import '../providers/notebook_providers.dart';
import '../sections/notebook_chapter_dialogs.dart';
import '../sections/notebook_contents_chapter_header.dart';
import '../sections/notebook_contents_list.dart';
import '../sections/notebook_contents_rows.dart';
import '../viewmodels/notebook_book_layout.dart';
import '../viewmodels/notebook_view.dart';
import '../widgets/notebook_page_title.dart';
import '../../widgets/form_width.dart';
import 'package:node_diary/ui/app_surface/models/app_surface_enums.dart';
import 'package:node_diary/ui/app_surface/widgets/app_page_background.dart';

/// 普通日记本的目录页（首页头部卡片“目录”）。
///
/// 一条扁平的可拖动列表：各章标题行（按章节顺序）后接它的日记，最后是
/// “未分章”。日记行与章节标题行（“未分章”除外）都按住右侧手柄即拖：
/// - 拖日记：松手时每篇归属它上方最近的标题行，整份顺序一次写回
///   （`reorderNotebookEntries`），数据库推送同样的顺序之前先按拖完的顺序
///   显示（[_pending]），松手时不会先跳回原位；落进收起着的章节时展开它。
/// - 拖章节：这一章的日记在拖动期间收进来，放下后按标题行的先后换算章节
///   顺序写回 payload（[_pendingChapters] 同理先按新顺序显示），日记在新
///   位置从 0 高度展开。
///
/// 点按章节名一带收起 / 展开这一章（`notebookContentsCollapsedProvider`，
/// 本次运行的内存）；收起的日记仍留在列表里、只收到 0 高度，拖动落点照旧
/// 按整份书序换算。
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
  List<String>? _pendingChapters;

  /// 这一帧从 0 高度展开的日记行 key（构建过一次就清掉，见 [_settleAppearing]）。
  final Set<String> _appearing = <String>{};
  bool _selecting = false;
  final Set<String> _selected = <String>{};
  bool _popScheduled = false;

  late final NotebookContentsController _controller;

  @override
  void initState() {
    super.initState();
    // 在 initState 建好：dispose 要结束拖动的阻塞登记，不能在那时才惰性
    // 创建（销毁期间不能再用 ref）。
    _controller = NotebookContentsController(
      ref.read(appDatabaseProvider),
      widget.notebookId,
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final notebookAsync = ref.watch(notebookProvider(widget.notebookId));
    final entriesAsync = ref.watch(notebookContentsProvider(widget.notebookId));
    final notebook = notebookAsync.value;
    if (notebookAsync.hasValue && notebook == null) {
      _popWhenGone();
    }
    final entries = entriesAsync.value;
    final hasEntries = entries != null && entries.isNotEmpty;
    // 正文在这里先建好：_buildBody 里有 ref.watch，不能挪进下面读页面底色
    // 的 Builder（那会在 Builder 自己重建时才订阅，订阅随之反复关开）。
    final body = notebook == null || entries == null
        ? const DelayedLoadingIndicator()
        : _buildBody(context, notebook, entries);
    return PopScope(
      canPop: !_selecting,
      onPopInvokedWithResult: (bool didPop, Object? _) {
        if (!didPop) _setSelecting(false);
      },
      child: AppPageBackground(
        area: AppBackgroundArea.other,
        child: Builder(
          builder: (BuildContext context) => Scaffold(
            backgroundColor: AppPageBackdrop.pageColorOf(context),
            appBar: AppTopBar(
              contentMaxWidth: FormWidth.maxWidth,
              title: NotebookPageTitle(
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
            body: body,
          ),
        ),
      ),
    );
  }

  Widget _buildBody(
    BuildContext context,
    NotebookView notebook,
    List<NotebookContentsEntry> entries,
  ) {
    final chapters = _orderedChapters(notebook.payload.chapters);
    final items = buildNotebookContents(
      chapters,
      entries,
      pending: _syncPending(chapters, entries),
    );
    final hint = chapters.isEmpty
        ? NotebookContentsChapterHint(onAddChapter: _addChapter)
        : null;
    if (items.isEmpty) {
      return FormWidthBar(
        sideInset: AppSpacing.l,
        child: Column(
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
        ),
      );
    }
    final dateMeta = ref.watch(diaryCardStyleProvider).meta;
    final collapsed = ref.watch(
      notebookContentsCollapsedProvider(widget.notebookId),
    );
    final hidden = notebookContentsHiddenRows(items, <String>{
      ...collapsed,
      ?_controller.dragFolded,
    });
    _settleAppearing();
    final now = DateTime.now();
    return LayoutBuilder(
      builder: (BuildContext context, BoxConstraints constraints) {
        final side = FormWidth.extra(constraints.maxWidth);
        return CustomScrollView(
          slivers: <Widget>[
            // 宽窗口：每段内容都补上居中留白（各段自带左右 16，手机上补 0）。
            for (final sliver in <Widget>[
              if (hint != null) SliverToBoxAdapter(child: hint),
              NotebookContentsListSliver(
                items: items,
                chapters: chapters,
                collapsed: collapsed,
                hidden: hidden,
                appearing: _appearing,
                selecting: _selecting,
                selected: _selected,
                dateMeta: dateMeta,
                now: now,
                onReorder: (int oldIndex, int newIndex) =>
                    _reorder(chapters, entries, items, oldIndex, newIndex),
                onReorderStart: (int index) {
                  if (_controller.startDrag(index, items[index])) {
                    setState(() {});
                  }
                },
                onReorderEnd: (int insertIndex) {
                  if (_controller.dropped(insertIndex)) {
                    _unfoldDrag(items, moved: false);
                  }
                },
                onToggleChapter: (header) => ref
                    .read(
                      notebookContentsCollapsedProvider(
                        widget.notebookId,
                      ).notifier,
                    )
                    .toggle(header.key),
                onChapterAction: (chapter, count, action) =>
                    unawaited(_chapterAction(chapter, count, action)),
                onEntryTap: (String diaryId) => _selecting
                    ? _toggle(diaryId)
                    : unawaited(_openPreview(diaryId, items)),
              ),
              SliverToBoxAdapter(
                child: SizedBox(
                  height: AppSpacing.xxl + MediaQuery.paddingOf(context).bottom,
                ),
              ),
            ])
              SliverPadding(
                padding: EdgeInsets.symmetric(horizontal: side),
                sliver: sliver,
              ),
          ],
        );
      },
    );
  }

  /// 拖动章节后的临时顺序：日记本推送的章节顺序已与它一致时交还（下一帧
  /// 清除），否则按它排列（其中没有的章节——拖动途中别处新加的——接在后面）。
  List<NotebookChapter> _orderedChapters(List<NotebookChapter> chapters) {
    final pending = _pendingChapters;
    if (pending == null) return chapters;
    if (listEquals(<String>[for (final c in chapters) c.id], pending)) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && identical(_pendingChapters, pending)) {
          setState(() => _pendingChapters = null);
        }
      });
      return chapters;
    }
    return orderNotebookChapters(chapters, pending);
  }

  /// 标成“出现”的行构建过一次就清掉：滚出再滚回不会重复播放展开。
  void _settleAppearing() {
    if (_appearing.isEmpty) return;
    final built = _appearing.toSet();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _appearing.removeAll(built);
    });
  }

  Set<String> get _collapsed =>
      ref.read(notebookContentsCollapsedProvider(widget.notebookId));

  /// 放出拖动章节时收进来的日记（见 [NotebookContentsController.unfoldDrag]）。
  /// [moved] 时这些日记在新位置重新挂载（列表按行号区分条目），标成“出现”
  /// 从 0 高度展开，而不是直接弹出来；这一章本来就收着的不必。
  void _unfoldDrag(List<NotebookContentsItem> items, {required bool moved}) {
    final folded = _controller.unfoldDrag();
    if (folded == null) return;
    setState(() {
      if (moved && !_collapsed.contains(folded)) {
        _appearing.addAll(notebookContentsRowsUnder(items, folded));
      }
    });
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
    final moved = items[oldIndex];
    switch (moved) {
      case NotebookContentsHeader():
        _reorderChapters(chapters, items, oldIndex, newIndex);
      case NotebookContentsRow():
        _reorderEntry(chapters, entries, items, moved, oldIndex, newIndex);
    }
  }

  /// 拖完一篇日记：按落点换章、整份顺序写库。落进收起着的章节时展开它
  /// （其余日记从 0 高度展开），看得见这一篇落在了哪里。
  void _reorderEntry(
    List<NotebookChapter> chapters,
    List<NotebookContentsEntry> entries,
    List<NotebookContentsItem> items,
    NotebookContentsRow moved,
    int oldIndex,
    int newIndex,
  ) {
    if (oldIndex == newIndex) return;
    final dropped = resolveNotebookContentsDrop(items, oldIndex, newIndex);
    // 按章节归组后的显示顺序写库：拖到最顶端（归第一章）的那篇排在第一章
    // 开头，与界面一致，数据库推送回来时也能与临时顺序比对上。
    final next = buildNotebookContents(chapters, entries, pending: dropped);
    final placements = <NotebookEntryPlacement>[
      for (final item in next)
        if (item is NotebookContentsRow)
          (diaryId: item.entry.diaryId, chapterId: item.chapterId),
    ];
    final movedId = moved.entry.diaryId;
    final target = NotebookContentsHeader.keyFor(
      placements.firstWhere((p) => p.diaryId == movedId).chapterId,
    );
    final reveal = _collapsed.contains(target);
    setState(() {
      _pending = placements;
      if (reveal) {
        _appearing.addAll(
          notebookContentsRowsUnder(
            next,
            target,
          ).where((key) => key != moved.key),
        );
      }
    });
    if (reveal) {
      ref
          .read(notebookContentsCollapsedProvider(widget.notebookId).notifier)
          .expand(<String>[target]);
    }
    unawaited(_run(() => _controller.reorder(placements), revertOrder: true));
  }

  /// 拖完一个章节：只按标题行的先后换算章节顺序（见
  /// [resolveNotebookChapterDrop]），顺序没变时不写库。
  void _reorderChapters(
    List<NotebookChapter> chapters,
    List<NotebookContentsItem> items,
    int oldIndex,
    int newIndex,
  ) {
    _unfoldDrag(items, moved: true);
    final order = resolveNotebookChapterDrop(items, oldIndex, newIndex);
    if (listEquals(order, <String>[for (final c in chapters) c.id])) {
      _controller.endDrag();
      return;
    }
    setState(() => _pendingChapters = order);
    unawaited(
      _run(() => _controller.reorderChapters(order), revertOrder: true),
    );
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
      if (revertOrder) {
        setState(() {
          _pending = null;
          _pendingChapters = null;
        });
      }
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

  /// 打开预览页（“打开日记时直接编辑”开启时为编辑页，见 [openDiaryPage]），
  /// 可按书序左右翻（序列在打开时冻结）。在里面删除日记时给 4 秒撤销。
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
    final result = await openDiaryPage(
      context,
      ref,
      diaryId: diaryId,
      sequence: sequence,
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
}
