import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:node_diary/l10n/app_localizations.dart';

import '../../../app/theme/app_spacing.dart';
import '../../../app/theme/expressive_motion.dart';
import '../../../core/database/app_database.dart';
import '../../widgets/app_modal/app_modal_bottom_sheet.dart';
import '../../widgets/delayed_loading_indicator.dart';
import '../models/notebook_pick_selection.dart';
import '../providers/notebook_providers.dart';
import '../viewmodels/notebook_book_layout.dart';
import '../viewmodels/notebook_tree.dart';
import '../viewmodels/notebook_tree_rows.dart';
import '../viewmodels/notebook_view.dart';
import '../widgets/notebook_foldable_rows.dart';
import '../widgets/notebook_pick_row.dart';
import 'notebook_quick_create_dialog.dart';

export '../models/notebook_pick_selection.dart';

/// 收录选择器的两种用法。
///
/// - [multi]：勾选框语义，可多选，底部“完成”提交；批量时每本为三态；
/// - [single]：“移动到…”，点一本即选定返回（当前日记本不列出）。
enum NotebookPickerMode { multi, single }

/// 选择器里列出的日记本：没合上的普通日记本，按树序（子本紧跟在上级下面、
/// 缩进随层级，见 [notebookTreeRows]）。智能日记本按规则收录、合上的日记本
/// 不再接收新的日记，都不提供；[excludedIds] 另外排除（“移动到…”排除当前
/// 这本）。上级没列出时子本往外提一级。
List<NotebookTreeRow> notebookPickCandidates(
  List<NotebookView> notebooks, {
  Set<String> excludedIds = const <String>{},
}) => notebookTreeRows(
  NotebookTree.fromViews(notebooks),
  include: (NotebookView notebook) =>
      notebook.isManual &&
      !notebook.isClosed &&
      !excludedIds.contains(notebook.id),
);

/// 收录选择器（含章节）的返回结果：[result] 为日记本增减，[chapterIds] 为
/// 本次指定或改动过的章节（日记本业务 id → 目标章节 id，null 表示未分章）。
@immutable
class NotebookMembershipPick {
  const NotebookMembershipPick({
    required this.result,
    this.chapterIds = const <String, String?>{},
  });

  final NotebookPickerResult result;
  final Map<String, String?> chapterIds;

  bool get isEmpty => result.isEmpty && chapterIds.isEmpty;
}

/// 打开收录选择器（底部面板，仅返回日记本增减结果）。
Future<NotebookPickerResult?> showNotebookPickerSheet(
  BuildContext context, {
  NotebookPickerMode mode = NotebookPickerMode.multi,
  Map<String, NotebookPickState> initial = const <String, NotebookPickState>{},
  String? title,
  Set<String> excludedIds = const <String>{},
}) async {
  final pick = await showNotebookMembershipPickerSheet(
    context,
    mode: mode,
    initial: initial,
    title: title,
    excludedIds: excludedIds,
  );
  if (pick == null || pick.result.isEmpty) return null;
  return pick.result;
}

/// 打开收录选择器（底部面板，支持同时挑选或更改章节）。
///
/// [initial] 为各本对这批日记的三态（见 [notebookPickStatesFor]），没列出的
/// 按“都不在”。[initialChapters] 为已知的初始章节（日记本业务 id → 章节 id，
/// 仅对 [initial] 为 `all` 的本子生效）。返回只含变化的
/// [NotebookMembershipPick]；关掉面板或没有任何改动时为 null。单选模式下
/// 结果的 `result.add` 恰好一本，选定有章节的本子时同时带上所选章节。
///
/// 面板只负责挑选，写库与提示由调用方完成（见 `NotebookMembershipOps`）。
Future<NotebookMembershipPick?> showNotebookMembershipPickerSheet(
  BuildContext context, {
  NotebookPickerMode mode = NotebookPickerMode.multi,
  Map<String, NotebookPickState> initial = const <String, NotebookPickState>{},
  Map<String, String?> initialChapters = const <String, String?>{},
  String? title,
  Set<String> excludedIds = const <String>{},
}) {
  return showAppModalBottomSheet<NotebookMembershipPick>(
    context: context,
    useSafeArea: true,
    showDragHandle: true,
    isScrollControlled: true,
    // 底部面板默认滑入不读取系统“减少动态效果”；该模式下直接出现。
    sheetAnimationStyle: ExpressiveMotion.reduceMotion(context)
        ? AnimationStyle.noAnimation
        : null,
    builder: (BuildContext sheetContext) => NotebookPickerSheet(
      mode: mode,
      initial: initial,
      initialChapters: initialChapters,
      title: title,
      excludedIds: excludedIds,
    ),
  );
}

/// 收进私密日记本后的提示：这些日记从此只在那本里显示（不在全部日记里）。
/// [added] 里没有隐藏或上锁的日记本时返回 null。看生效可见性：上级私密的
/// 子本同样算私密。
String? notebookPrivateAddedHint(
  AppLocalizations l10n,
  Iterable<String> added,
  List<NotebookView> notebooks,
) {
  for (final notebook in notebooks) {
    if (added.contains(notebook.id) &&
        notebook.effectiveVisibility != NotebookVisibility.normal) {
      return l10n.notebookPickerPrivateHint(notebook.name);
    }
  }
  return null;
}

/// 收录选择器面板的内容：标题、“＋ 新建日记本”、日记本列表与底部“完成”。
/// 高度随内容，最高约屏高的 75%，列表在其中滚动。
///
/// 有子本的行可收起 / 展开（[NotebookFoldableRows]，与管理页共用收起状态）；
/// 打开时已勾上（全部或部分收进）的本子所在的上级按展开排，新建后勾上的
/// 同样露出来。
class NotebookPickerSheet extends ConsumerStatefulWidget {
  const NotebookPickerSheet({
    super.key,
    required this.mode,
    this.initial = const <String, NotebookPickState>{},
    this.initialChapters = const <String, String?>{},
    this.title,
    this.excludedIds = const <String>{},
  });

  final NotebookPickerMode mode;
  final Map<String, NotebookPickState> initial;
  final Map<String, String?> initialChapters;
  final String? title;
  final Set<String> excludedIds;

  @override
  ConsumerState<NotebookPickerSheet> createState() =>
      _NotebookPickerSheetState();
}

class _NotebookPickerSheetState extends ConsumerState<NotebookPickerSheet> {
  late final NotebookPickSelection _selection = NotebookPickSelection(
    widget.initial,
  );
  late final Map<String, String?> _chapterSelections = <String, String?>{
    for (final entry in widget.initialChapters.entries)
      if (widget.initial[entry.key] == NotebookPickState.all)
        entry.key: entry.value,
  };
  final Set<String> _chapterDirty = <String>{};
  String? _singleExpandedNotebookId;

  /// 要露出来的本子：打开时已（部分）收进的，与在面板里新建后勾上的。
  late final Set<String> _reveal = <String>{
    for (final MapEntry(:key, :value) in widget.initial.entries)
      if (value != NotebookPickState.none) key,
  };

  bool get _single => widget.mode == NotebookPickerMode.single;

  void _tap(NotebookView notebook) {
    final notebookId = notebook.id;
    if (_single) {
      if (notebook.payload.chapters.isEmpty) {
        Navigator.of(context).pop(
          NotebookMembershipPick(
            result: NotebookPickerResult(add: <String>{notebookId}),
          ),
        );
        return;
      }
      setState(() {
        _singleExpandedNotebookId = _singleExpandedNotebookId == notebookId
            ? null
            : notebookId;
      });
      return;
    }
    setState(() {
      _selection.toggle(notebookId);
      final next = _selection.stateOf(notebookId);
      if (next != NotebookPickState.all) {
        _chapterSelections.remove(notebookId);
        _chapterDirty.remove(notebookId);
      } else if (widget.initial[notebookId] == NotebookPickState.all &&
          widget.initialChapters.containsKey(notebookId)) {
        _chapterSelections[notebookId] = widget.initialChapters[notebookId];
        _chapterDirty.remove(notebookId);
      }
    });
  }

  void _selectChapter(String notebookId, String? chapterId) {
    if (_single) {
      Navigator.of(context).pop(
        NotebookMembershipPick(
          result: NotebookPickerResult(add: <String>{notebookId}),
          chapterIds: chapterId == null
              ? const <String, String?>{}
              : <String, String?>{notebookId: chapterId},
        ),
      );
      return;
    }
    setState(() {
      _chapterSelections[notebookId] = chapterId;
      final initialState = widget.initial[notebookId] ?? NotebookPickState.none;
      final unchangedExisting =
          initialState == NotebookPickState.all &&
          widget.initialChapters.containsKey(notebookId) &&
          widget.initialChapters[notebookId] == chapterId;
      final defaultNewUnassigned =
          initialState == NotebookPickState.none && chapterId == null;
      if (unchangedExisting || defaultNewUnassigned) {
        _chapterDirty.remove(notebookId);
      } else {
        _chapterDirty.add(notebookId);
      }
    });
  }

  /// 新建后直接选中：多选时勾上（列表随数据库流出现这一行），单选时就是
  /// 选定的目标。
  Future<void> _create() async {
    final id = await showQuickCreateNotebookDialog(context);
    if (id == null || !mounted) return;
    if (_single) {
      Navigator.of(context).pop(
        NotebookMembershipPick(result: NotebookPickerResult(add: <String>{id})),
      );
      return;
    }
    setState(() {
      _selection.select(id);
      _reveal.add(id);
    });
  }

  void _done() {
    final result = _selection.result;
    final chapterChanges = <String, String?>{
      for (final id in _chapterDirty)
        if (!result.remove.contains(id) &&
            _selection.stateOf(id) == NotebookPickState.all)
          id: _chapterSelections[id],
    };
    final pick = NotebookMembershipPick(
      result: result,
      chapterIds: chapterChanges,
    );
    Navigator.of(context).pop(pick.isEmpty ? null : pick);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final media = MediaQuery.of(context);
    final notebooks = ref.watch(notebooksProvider).value;
    final counts =
        ref.watch(notebookEntryCountsProvider).value ?? const <String, int>{};
    final candidates = notebooks == null
        ? null
        : notebookPickCandidates(notebooks, excludedIds: widget.excludedIds);
    final bottomInset = media.padding.bottom + AppSpacing.l;

    final Widget list;
    if (candidates == null) {
      list = const SizedBox(height: 160, child: DelayedLoadingIndicator());
    } else {
      list = ListView(
        shrinkWrap: true,
        padding: EdgeInsets.fromLTRB(
          AppSpacing.l,
          0,
          AppSpacing.l,
          _single ? bottomInset : AppSpacing.s,
        ),
        children: <Widget>[
          NotebookPickCreateRow(onTap: () => unawaited(_create())),
          if (candidates.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.xs,
                vertical: AppSpacing.l,
              ),
              child: Text(
                l10n.notebookPickerEmpty,
                textAlign: TextAlign.center,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ),
          NotebookFoldableRows(
            rows: candidates,
            reveal: _reveal,
            itemBuilder: (context, row, toggle) {
              final notebook = row.notebook;
              final id = notebook.id;
              final chapters = notebook.payload.chapters;
              final state = _selection.stateOf(id);
              final showChapters =
                  chapters.isNotEmpty &&
                  (_single
                      ? _singleExpandedNotebookId == id
                      : state == NotebookPickState.all);
              final rawSelectedChapter = _chapterSelections.containsKey(id)
                  ? _chapterSelections[id]
                  : widget.initialChapters[id];
              return NotebookPickRow(
                key: ValueKey<String>('notebook_pick_$id'),
                notebook: notebook,
                indent: row.indent,
                count: counts[id] ?? 0,
                state: state,
                showCheck: !_single,
                toggle: toggle,
                chapters: chapters,
                selectedChapterId: _single
                    ? null
                    : validNotebookChapterId(chapters, rawSelectedChapter),
                showChapters: showChapters,
                allowNoChapterHighlight: _single,
                onSelectChapter: (chapterId) => _selectChapter(id, chapterId),
                onTap: () => _tap(notebook),
              );
            },
          ),
        ],
      );
    }

    return ConstrainedBox(
      constraints: BoxConstraints(maxHeight: media.size.height * 0.75),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Padding(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.xl,
              0,
              AppSpacing.xl,
              AppSpacing.m,
            ),
            child: Text(
              widget.title ?? l10n.notebookPickerTitle,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: theme.textTheme.titleLarge?.copyWith(
                fontSize: 20,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          Flexible(child: list),
          if (!_single)
            Padding(
              padding: EdgeInsets.fromLTRB(
                AppSpacing.l,
                AppSpacing.s,
                AppSpacing.l,
                bottomInset,
              ),
              child: FilledButton(
                onPressed: _done,
                child: Text(l10n.notebookPickerDone),
              ),
            ),
        ],
      ),
    );
  }
}
