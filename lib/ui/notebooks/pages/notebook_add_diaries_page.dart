import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:node_diary/l10n/app_localizations.dart';

import '../../../app/theme/app_radii.dart';
import '../../../app/theme/app_spacing.dart';
import '../../../core/database/app_database.dart';
import '../../../core/services/app_service.dart';
import '../../diaries/pages/diary_search_page.dart' show diarySearchDebounce;
import '../../diaries/providers/diary_filters.dart';
import '../../home/widgets/home_hint_visibility_scope.dart';
import '../../widgets/app_top_bar.dart';
import '../../widgets/delayed_loading_indicator.dart';
import '../models/notebook_add_filter.dart';
import '../sections/notebook_add_diaries_parts.dart';
import '../viewmodels/notebook_view.dart';
import '../../widgets/form_width.dart';
import 'package:node_diary/ui/app_surface/models/app_surface_enums.dart';
import 'package:node_diary/ui/app_surface/widgets/app_page_background.dart';

/// 从已有日记里挑选、批量加进一本普通日记本（头部卡片“添加日记”与空日记本
/// 的“从已有日记挑选”）。
///
/// 输入：目标日记本。候选为全部日记（私密日记不在其中），可按关键词（200ms
/// 防抖）、时间与标签筛选，按发表时间倒序分页加载（每次 20 篇，触底加载）。
/// 已在这本里的日记停用并注明。输出：“完成”把勾选的日记接在本子最后
/// （`addDiariesToNotebook`），返回上一页并提示篇数；写入失败时留在本页提示。
/// 勾选只在本页内存里，换筛选不会丢。
class NotebookAddDiariesPage extends ConsumerStatefulWidget {
  const NotebookAddDiariesPage({super.key, required this.notebook});

  final NotebookView notebook;

  static Route<void> route({required NotebookView notebook}) =>
      MaterialPageRoute<void>(
        builder: (_) => NotebookAddDiariesPage(notebook: notebook),
      );

  @override
  ConsumerState<NotebookAddDiariesPage> createState() =>
      _NotebookAddDiariesPageState();
}

class _NotebookAddDiariesPageState
    extends ConsumerState<NotebookAddDiariesPage> {
  static const int _pageSize = 20;
  static const double _loadMoreTriggerExtent = 420;

  final TextEditingController _search = TextEditingController();
  Timer? _searchTimer;
  String _keyword = '';
  NotebookAddTimeFilter _timeFilter = NotebookAddTimeFilter.all;
  final Set<int> _tagIds = <int>{};
  int _limit = _pageSize;
  bool _hasMore = false;
  bool _saving = false;

  /// 打开时取一次“此刻”：时间筛选的下限在本页内保持不变（查询 key 稳定）。
  final DateTime _openedAt = DateTime.now();

  /// 勾选的日记，按勾选先后（加进本子的顺序）。
  final Set<String> _selected = <String>{};

  /// 已在这本里的日记；读出前为空集合（行先显示为可选，读出后停用）。
  Set<String> _members = const <String>{};

  @override
  void initState() {
    super.initState();
    unawaited(_loadMembers());
  }

  @override
  void dispose() {
    _searchTimer?.cancel();
    _search.dispose();
    super.dispose();
  }

  Future<void> _loadMembers() async {
    final ids = await ref
        .read(appDatabaseProvider)
        .getActiveDiaryIds(
          scope: DiaryNotebookScope(notebookId: widget.notebook.id),
        );
    if (!mounted) return;
    setState(() {
      _members = ids.toSet();
      _selected.removeAll(_members);
    });
  }

  void _onKeywordChanged(String value) {
    _searchTimer?.cancel();
    // 输入防抖与搜索页一致。
    _searchTimer = Timer(diarySearchDebounce, () {
      if (!mounted || value.trim() == _keyword) return;
      setState(() {
        _keyword = value.trim();
        _limit = _pageSize;
      });
    });
  }

  void _setTimeFilter(NotebookAddTimeFilter filter) {
    if (filter == _timeFilter) return;
    setState(() {
      _timeFilter = filter;
      _limit = _pageSize;
    });
  }

  void _toggleTag(int tagId) {
    setState(() {
      if (!_tagIds.remove(tagId)) _tagIds.add(tagId);
      _limit = _pageSize;
    });
  }

  void _toggle(String diaryId) {
    setState(() {
      if (!_selected.remove(diaryId)) _selected.add(diaryId);
    });
  }

  bool _handleScroll(ScrollNotification notification) {
    if (notification.depth == 0 &&
        _hasMore &&
        notification.metrics.extentAfter < _loadMoreTriggerExtent) {
      // 下一页返回前 hasMore 仍为 true：同一窗口只加一次。
      final next = _limit + _pageSize;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && _limit < next) setState(() => _limit = next);
      });
      _hasMore = false;
    }
    return false;
  }

  Future<void> _done() async {
    if (_selected.isEmpty || _saving) return;
    setState(() => _saving = true);
    final l10n = context.l10n;
    try {
      final added = await ref
          .read(appDatabaseProvider)
          .addDiariesToNotebook(widget.notebook.id, _selected.toList());
      if (!mounted) return;
      unawaited(
        HomeHintVisibilityScope.showTrackedSnackBar(
          context: context,
          snackBar: SnackBar(content: Text(l10n.notebookAddedCount(added))),
        ),
      );
      Navigator.of(context).pop();
    } catch (error) {
      debugPrint('Adding diaries to notebook failed: $error');
      if (!mounted) return;
      setState(() => _saving = false);
      unawaited(
        HomeHintVisibilityScope.showTrackedSnackBar(
          context: context,
          snackBar: SnackBar(content: Text(l10n.notebookActionFailed)),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final tags = ref.watch(tagListProvider).value ?? const <Tag>[];
    final query = DiaryPageQuery(
      keyword: _keyword,
      requiredTagIds: _tagIds.toList()..sort(),
      limit: _limit,
      sortMode: DiarySortMode.createdDesc,
      scope: notebookAddScope(
        _timeFilter,
        notebookId: widget.notebook.id,
        now: _openedAt,
      ),
    );
    final page = ref.watch(searchDiariesProvider(query));
    final result = page.value;
    if (result != null) _hasMore = result.hasMore;
    final count = _selected.length;

    final Widget body;
    if (result == null) {
      body = page.hasError
          ? Center(child: Text(l10n.notebookActionFailed))
          : const DelayedLoadingIndicator();
    } else if (result.items.isEmpty) {
      body = Center(
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.xxl),
          child: Text(
            l10n.notebookAddEmpty,
            textAlign: TextAlign.center,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: scheme.onSurfaceVariant,
            ),
          ),
        ),
      );
    } else {
      body = NotificationListener<ScrollNotification>(
        onNotification: _handleScroll,
        child: LayoutBuilder(
          builder: (BuildContext context, BoxConstraints constraints) {
            final side = FormWidth.gutter(constraints.maxWidth);
            return ListView.builder(
              padding: EdgeInsets.fromLTRB(
                side,
                AppSpacing.s,
                side,
                AppSpacing.xxl + MediaQuery.paddingOf(context).bottom,
              ),
              itemCount: result.items.length,
              itemBuilder: (BuildContext context, int index) {
                final diary = result.items[index].diary;
                return NotebookAddDiaryRow(
                  key: ValueKey<String>('notebook_add_${diary.diaryId}'),
                  diary: diary,
                  selected: _selected.contains(diary.diaryId),
                  alreadyIn: _members.contains(diary.diaryId),
                  onToggle: () => _toggle(diary.diaryId),
                );
              },
            );
          },
        ),
      );
    }

    return AppPageBackground(
      area: AppBackgroundArea.other,
      child: Builder(
        builder: (BuildContext context) => Scaffold(
          backgroundColor: AppPageBackdrop.pageColorOf(context),
          appBar: AppTopBar(
            contentMaxWidth: FormWidth.maxWidth,
            title: Text(
              l10n.notebookAddPageTitle(widget.notebook.name),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            actions: <Widget>[
              Padding(
                padding: const EdgeInsets.only(right: AppSpacing.s),
                child: TextButton(
                  onPressed: count == 0 || _saving ? null : _done,
                  style: TextButton.styleFrom(
                    textStyle: const TextStyle(fontWeight: FontWeight.w700),
                  ),
                  child: Text(l10n.notebookAddPageDone(count)),
                ),
              ),
            ],
          ),
          body: Column(
            children: <Widget>[
              // 宽窗口：搜索框与筛选条与列表同列居中。
              FormWidthBar(
                sideInset: AppSpacing.l,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(
                    AppSpacing.l,
                    AppSpacing.xs,
                    AppSpacing.l,
                    AppSpacing.s,
                  ),
                  child: TextField(
                    controller: _search,
                    onChanged: _onKeywordChanged,
                    textInputAction: TextInputAction.search,
                    decoration: InputDecoration(
                      hintText: l10n.notebookAddSearchHint,
                      isDense: true,
                      filled: true,
                      fillColor: scheme.surfaceContainerHigh,
                      prefixIcon: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 14),
                        child: FaIcon(
                          FontAwesomeIcons.magnifyingGlass,
                          size: 14,
                          color: scheme.onSurfaceVariant,
                        ),
                      ),
                      prefixIconConstraints: const BoxConstraints(minWidth: 40),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(AppRadii.nav),
                        borderSide: BorderSide.none,
                      ),
                    ),
                  ),
                ),
              ),
              FormWidthBar(
                sideInset: AppSpacing.l,
                child: NotebookAddFilterBar(
                  timeFilter: _timeFilter,
                  onTimeFilterChanged: _setTimeFilter,
                  tags: tags,
                  selectedTagIds: _tagIds,
                  onToggleTag: _toggleTag,
                ),
              ),
              const SizedBox(height: AppSpacing.xs),
              Expanded(child: body),
            ],
          ),
        ),
      ),
    );
  }
}
