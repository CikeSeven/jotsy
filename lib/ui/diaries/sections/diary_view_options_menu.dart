import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:node_diary/l10n/app_localizations.dart';

import '../../../core/database/app_database.dart';
import '../../notebooks/viewmodels/notebook_labels.dart';
import '../../widgets/expressive_menu/expressive_menu.dart';
import 'diary_head_section.dart';

/// 首页顶栏“更多”菜单需要的当前值与回调，由页面控制器组装。
@immutable
class DiaryViewMenuOptions {
  const DiaryViewMenuOptions({
    required this.sortMode,
    required this.layoutMode,
    required this.onSortModeChanged,
    required this.onLayoutModeChanged,
    required this.onOpenCardStyle,
    this.notebookSort,
    this.allowBookOrder = false,
    this.onNotebookSortChanged,
    this.onOpenSettings,
  });

  final DiarySortMode sortMode;
  final DiaryLayoutMode layoutMode;
  final ValueChanged<DiarySortMode> onSortModeChanged;
  final ValueChanged<DiaryLayoutMode> onLayoutModeChanged;

  /// 进入卡片样式页（预览并编辑当前所用的布局）。
  final VoidCallback onOpenCardStyle;

  /// 在日记本里时为本子当前的排序：“排序方式”换成日记本排序，经
  /// [onNotebookSortChanged] 写回本子；null 为全部日记（全局排序偏好）。
  final NotebookSort? notebookSort;

  /// 本子排序是否提供“书序”（只有普通日记本有）。
  final bool allowBookOrder;
  final ValueChanged<NotebookSort>? onNotebookSortChanged;

  /// 切到设置 Tab；null 时不显示“设置”。
  final VoidCallback? onOpenSettings;
}

/// 首页顶栏的“更多”（⋮）：弹出菜单，“排序方式 ›”“显示布局 ›”两项在原地
/// 下钻到二级菜单，“设置”直接切到设置 Tab。
///
/// 二级菜单里的单选项点了不关菜单：排序依据与方向常常要连着调，列表在菜单
/// 后方淡出、换序、淡入，效果看得见；点外部或返回关闭。选中态由二级菜单页
/// 自己维护（初值取下钻时的页面状态）：二级菜单的内容在下钻时取定、不随页面
/// 重建刷新，打开期间排序与布局只能经由这个菜单修改，本地状态不会与页面分叉。
/// “卡片样式”“设置”是跳转，点按先关菜单。
class DiaryViewOptionsMenuButton extends StatelessWidget {
  const DiaryViewOptionsMenuButton({super.key, required this.options});

  final DiaryViewMenuOptions options;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return ExpressiveMenuButton(
      tooltip: l10n.autoT0125,
      icon: const FaIcon(FontAwesomeIcons.ellipsisVertical, size: 18),
      items: <Widget>[
        ExpressiveSubmenuItem(
          leadingIcon: const FaIcon(FontAwesomeIcons.arrowDownWideShort),
          menuChildren: <Widget>[_SortMenuPage(options: options)],
          child: Text(l10n.autoT0141),
        ),
        ExpressiveSubmenuItem(
          leadingIcon: const FaIcon(FontAwesomeIcons.tableCellsLarge),
          menuChildren: <Widget>[_LayoutMenuPage(options: options)],
          child: Text(l10n.autoT0145),
        ),
        if (options.onOpenSettings case final openSettings?)
          ExpressiveMenuItem(
            leadingIcon: const FaIcon(FontAwesomeIcons.gear),
            onPressed: openSettings,
            child: Text(l10n.navSettings),
          ),
      ],
    );
  }
}

/// “排序方式”二级菜单：全部日记为排序依据 + 方向两组；在日记本里为本子的
/// 排序（智能日记本没有“书序”）。
///
/// 方向不写“正序 / 倒序”：它对时间字段有歧义，直接写出当前依据下的实际效果
/// （如“最近更新的在前”），随依据切换。
class _SortMenuPage extends StatefulWidget {
  const _SortMenuPage({required this.options});

  final DiaryViewMenuOptions options;

  @override
  State<_SortMenuPage> createState() => _SortMenuPageState();
}

class _SortMenuPageState extends State<_SortMenuPage> {
  late DiarySortMode _sortMode = widget.options.sortMode;
  late NotebookSort? _notebookSort = widget.options.notebookSort;

  void _selectSortMode(DiarySortMode mode) {
    if (mode == _sortMode) return;
    setState(() => _sortMode = mode);
    widget.options.onSortModeChanged(mode);
  }

  void _selectNotebookSort(NotebookSort sort) {
    if (sort == _notebookSort) return;
    setState(() => _notebookSort = sort);
    widget.options.onNotebookSortChanged?.call(sort);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final notebookSort = _notebookSort;
    return ListBody(
      children: notebookSort != null
          ? <Widget>[
              for (final sort in NotebookSort.values)
                if (sort != NotebookSort.book || widget.options.allowBookOrder)
                  ExpressiveMenuItem(
                    closeOnActivate: false,
                    selected: notebookSort == sort,
                    onPressed: () => _selectNotebookSort(sort),
                    child: Text(notebookSortLabel(l10n, sort)),
                  ),
            ]
          : <Widget>[
              for (final field in DiarySortField.values)
                ExpressiveMenuItem(
                  closeOnActivate: false,
                  selected: _sortMode.field == field,
                  // 换排序依据时保留当前方向。
                  onPressed: () => _selectSortMode(_sortMode.withField(field)),
                  child: Text(_sortFieldLabel(l10n, field)),
                ),
              const ExpressiveMenuDivider(),
              for (final direction in const <DiarySortDirection>[
                DiarySortDirection.descending,
                DiarySortDirection.ascending,
              ])
                ExpressiveMenuItem(
                  closeOnActivate: false,
                  selected: _sortMode.direction == direction,
                  onPressed: () =>
                      _selectSortMode(_sortMode.withDirection(direction)),
                  child: Text(
                    _sortEffectLabel(l10n, _sortMode.withDirection(direction)),
                  ),
                ),
            ],
    );
  }
}

/// “显示布局”二级菜单：列表 / 瀑布流，分隔线下是卡片样式页入口。
class _LayoutMenuPage extends StatefulWidget {
  const _LayoutMenuPage({required this.options});

  final DiaryViewMenuOptions options;

  @override
  State<_LayoutMenuPage> createState() => _LayoutMenuPageState();
}

class _LayoutMenuPageState extends State<_LayoutMenuPage> {
  late DiaryLayoutMode _layoutMode = widget.options.layoutMode;

  void _select(DiaryLayoutMode mode) {
    if (mode == _layoutMode) return;
    setState(() => _layoutMode = mode);
    widget.options.onLayoutModeChanged(mode);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return ListBody(
      children: <Widget>[
        ExpressiveMenuItem(
          closeOnActivate: false,
          leadingIcon: const FaIcon(FontAwesomeIcons.list),
          selected: _layoutMode == DiaryLayoutMode.list,
          onPressed: () => _select(DiaryLayoutMode.list),
          child: Text(l10n.autoT0146),
        ),
        ExpressiveMenuItem(
          closeOnActivate: false,
          leadingIcon: const FaIcon(FontAwesomeIcons.tableColumns),
          selected: _layoutMode == DiaryLayoutMode.waterfall,
          onPressed: () => _select(DiaryLayoutMode.waterfall),
          child: Text(l10n.autoT0147),
        ),
        const ExpressiveMenuDivider(),
        ExpressiveMenuItem(
          leadingIcon: const FaIcon(FontAwesomeIcons.palette),
          onPressed: widget.options.onOpenCardStyle,
          child: Text(l10n.diaryCardStyleSheetSection),
        ),
      ],
    );
  }
}

String _sortFieldLabel(AppLocalizations l10n, DiarySortField field) {
  return switch (field) {
    DiarySortField.updatedAt => l10n.diarySortFieldUpdated,
    DiarySortField.createdAt => l10n.diarySortFieldPublished,
    DiarySortField.title => l10n.diarySortFieldTitle,
  };
}

/// 一种排序组合的实际效果，用作方向选项的文字。
String _sortEffectLabel(AppLocalizations l10n, DiarySortMode mode) {
  return switch (mode) {
    DiarySortMode.updatedDesc => l10n.diarySortHintUpdatedDesc,
    DiarySortMode.updatedAsc => l10n.diarySortHintUpdatedAsc,
    DiarySortMode.createdDesc => l10n.diarySortHintPublishedDesc,
    DiarySortMode.createdAsc => l10n.diarySortHintPublishedAsc,
    DiarySortMode.titleAsc => l10n.diarySortHintTitleAsc,
    DiarySortMode.titleDesc => l10n.diarySortHintTitleDesc,
  };
}
