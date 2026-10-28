import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/database/app_database.dart';
import '../../../l10n/app_localizations.dart';
import '../../notebooks/viewmodels/notebook_view.dart';
import '../../widgets/fast_scroller/fast_scroller.dart';
import '../providers/diary_filters.dart';
import '../providers/diary_timeline_provider.dart';
import '../viewmodels/diary_timeline_index.dart';

/// 日记页列表的快速滚动条：把首页的分页列表接到 [FastScroller]。
///
/// 输入：当前分页查询 [query]、已显示的日记 [items] 与是否还有下一页
/// [hasMore]、列表 sliver 外层的 [listKey]、成书顺序的章节名
/// [chapterTitles]（见 [chapterTitlesFor]）；输出：包住滚动视图 [child] 的
/// 滚动条，跳到还没加载的部分时经 [onNeedItems] 请求放大分页窗口。
///
/// 完整时间轴 [diaryTimelineProvider] 只在需要时订阅：列表还有没加载的
/// 部分（要总篇数与后段的日期）或成书顺序要章节，并且用户已经滚动过这个
/// 列表——启动与只看首屏时不多一条查询；之后筛选、排序变化照常换查询。
/// 短列表直接用已加载的日记。标签与分段（[DiaryTimelineIndex]）在输入不变
/// 时复用，不随页面每次重建重算。
class DiariesFastScroller extends ConsumerStatefulWidget {
  const DiariesFastScroller({
    super.key,
    required this.query,
    required this.items,
    required this.hasMore,
    required this.listKey,
    required this.onNeedItems,
    required this.child,
    this.chapterTitles = const <String>[],
    this.pinnedExtent = 0,
    this.padding = EdgeInsets.zero,
    this.enabled = true,
  });

  final DiaryPageQuery query;
  final List<DiaryWithTags> items;
  final bool hasMore;
  final GlobalKey listKey;
  final ValueChanged<int> onNeedItems;
  final Widget child;
  final List<String> chapterTitles;

  /// 列表上方始终固定的栏的高度（见 [FastScroller.pinnedExtent]）。
  final double pinnedExtent;
  final EdgeInsets padding;
  final bool enabled;

  /// 成书顺序时 [scope] 各章（按 `chapterOrder`）的标题；不是成书顺序或
  /// 本子没有章节时为空。
  static List<String> chapterTitlesFor(
    DiaryListScope scope,
    NotebookView? notebook,
  ) {
    if (scope is! DiaryNotebookScope || !scope.bookOrder || notebook == null) {
      return const <String>[];
    }
    final titles = <String, String>{
      for (final chapter in notebook.payload.chapters)
        chapter.id: chapter.title,
    };
    return <String>[for (final id in scope.chapterOrder) titles[id] ?? ''];
  }

  @override
  ConsumerState<DiariesFastScroller> createState() =>
      _DiariesFastScrollerState();
}

class _DiariesFastScrollerState extends ConsumerState<DiariesFastScroller> {
  DiaryTimelineIndex? _index;
  List<DiaryWithTags>? _indexItems;
  List<DiaryTimelineEntry>? _indexTimeline;
  bool? _indexHasMore;
  DiarySortMode? _indexSort;
  bool? _indexBookOrder;
  List<String> _indexChapters = const <String>[];
  String? _indexLocale;

  /// 用户滚动过列表：此后才订阅完整时间轴（见类注释）。
  bool _scrolled = false;

  bool _handleScroll(ScrollUpdateNotification notification) {
    if (!_scrolled && notification.depth == 0) {
      setState(() => _scrolled = true);
    }
    return false;
  }

  @override
  Widget build(BuildContext context) {
    final query = widget.query;
    final scope = query.scope;
    final bookOrder = scope is DiaryNotebookScope && scope.bookOrder;
    final needsTimeline =
        _scrolled &&
        (widget.hasMore || (bookOrder && widget.chapterTitles.isNotEmpty));
    final timeline = needsTimeline
        ? ref.watch(diaryTimelineProvider(query.timelineKey)).value
        : null;
    final index = _resolveIndex(
      timeline: timeline,
      bookOrder: bookOrder,
      l10n: context.l10n,
    );
    return NotificationListener<ScrollUpdateNotification>(
      onNotification: _handleScroll,
      child: FastScroller(
        listKey: widget.listKey,
        itemCount: index.length,
        loadedCount: widget.items.length,
        labelBuilder: index.labelAt,
        sections: index.sections,
        onNeedItems: widget.onNeedItems,
        listIdentity: query.timelineKey,
        pinnedExtent: widget.pinnedExtent,
        padding: widget.padding,
        enabled: widget.enabled,
        child: widget.child,
      ),
    );
  }

  DiaryTimelineIndex _resolveIndex({
    required List<DiaryTimelineEntry>? timeline,
    required bool bookOrder,
    required AppLocalizations l10n,
  }) {
    final cached = _index;
    if (cached != null &&
        identical(_indexItems, widget.items) &&
        identical(_indexTimeline, timeline) &&
        _indexHasMore == widget.hasMore &&
        _indexSort == widget.query.sortMode &&
        _indexBookOrder == bookOrder &&
        listEquals(_indexChapters, widget.chapterTitles) &&
        _indexLocale == l10n.localeName) {
      return cached;
    }
    _indexItems = widget.items;
    _indexTimeline = timeline;
    _indexHasMore = widget.hasMore;
    _indexSort = widget.query.sortMode;
    _indexBookOrder = bookOrder;
    _indexChapters = widget.chapterTitles;
    _indexLocale = l10n.localeName;
    return _index = DiaryTimelineIndex(
      loaded: widget.items,
      timeline: timeline,
      hasMore: widget.hasMore,
      sortMode: widget.query.sortMode,
      bookOrder: bookOrder,
      chapterTitles: widget.chapterTitles,
      l10n: l10n,
    );
  }
}
