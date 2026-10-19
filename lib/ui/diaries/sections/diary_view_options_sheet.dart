import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:node_diary/l10n/app_localizations.dart';

import '../../../app/theme/app_spacing.dart';
import '../../../app/theme/expressive_motion.dart';
import '../../../core/database/app_database.dart';
import '../../widgets/expressive_button_group.dart';
import '../../notebooks/viewmodels/notebook_labels.dart';
import '../../widgets/expressive_choice_tile.dart';
import 'diary_head_section.dart';

/// 打开日记列表的视图选项面板：排序依据、正/倒序与布局，以及（传入
/// [onOpenCardStyle] 时）进入卡片样式页的入口、（传入 [onOpenNotebookShelf]
/// 时）打开书架的入口。
///
/// 首页在日记本里时传 [notebookSort]：排序分组换成“本日记本的排序”，选项为
/// 日记本排序（[allowBookOrder] 为 false 时没有“书序”），经
/// [onNotebookSortChanged] 写回本子；布局仍是全局的。
///
/// 选项即点即生效且面板保持打开：排序依据与方向常常要连着调，点一项就关闭
/// 会让用户反复打开面板。生效由页面经回调完成，列表在面板后方淡出、换序、
/// 淡入；下拉或点遮罩关闭面板。点卡片样式入口时先关闭面板再跳转。
Future<void> showDiaryViewOptionsSheet(
  BuildContext context, {
  required DiarySortMode sortMode,
  required DiaryLayoutMode layoutMode,
  required ValueChanged<DiarySortMode> onSortModeChanged,
  required ValueChanged<DiaryLayoutMode> onLayoutModeChanged,
  VoidCallback? onOpenCardStyle,
  VoidCallback? onOpenNotebookShelf,
  NotebookSort? notebookSort,
  bool allowBookOrder = false,
  ValueChanged<NotebookSort>? onNotebookSortChanged,
}) {
  return showModalBottomSheet<void>(
    context: context,
    useSafeArea: true,
    showDragHandle: true,
    // 内容高度接近默认的 9/16 屏高上限，大字号或矮屏会超出：放开上限按内容
    // 撑高，仍超出屏幕时由内部滚动兜底。
    isScrollControlled: true,
    // 底部面板默认滑入不读取系统“减少动态效果”；该模式下直接出现。
    sheetAnimationStyle: ExpressiveMotion.reduceMotion(context)
        ? AnimationStyle.noAnimation
        : null,
    builder: (BuildContext sheetContext) => DiaryViewOptionsSheet(
      initialSortMode: sortMode,
      initialLayoutMode: layoutMode,
      onSortModeChanged: onSortModeChanged,
      onLayoutModeChanged: onLayoutModeChanged,
      onOpenCardStyle: onOpenCardStyle,
      onOpenNotebookShelf: onOpenNotebookShelf,
      initialNotebookSort: notebookSort,
      allowBookOrder: allowBookOrder,
      onNotebookSortChanged: onNotebookSortChanged,
    ),
  );
}

/// 视图选项面板内容。
///
/// 选中态由面板自己维护（初值取打开时的页面状态）：面板是独立路由，不随
/// 页面重建；打开期间排序与布局只能经由面板修改，本地状态不会与页面分叉。
class DiaryViewOptionsSheet extends StatefulWidget {
  const DiaryViewOptionsSheet({
    super.key,
    required this.initialSortMode,
    required this.initialLayoutMode,
    required this.onSortModeChanged,
    required this.onLayoutModeChanged,
    this.onOpenCardStyle,
    this.onOpenNotebookShelf,
    this.initialNotebookSort,
    this.allowBookOrder = false,
    this.onNotebookSortChanged,
  });

  final DiarySortMode initialSortMode;
  final DiaryLayoutMode initialLayoutMode;
  final ValueChanged<DiarySortMode> onSortModeChanged;
  final ValueChanged<DiaryLayoutMode> onLayoutModeChanged;

  /// 进入卡片样式页；null 时不显示该入口。
  final VoidCallback? onOpenCardStyle;

  /// 打开书架（切换日记本）；null 时不显示该入口。
  final VoidCallback? onOpenNotebookShelf;

  /// 在日记本里时为本子当前的排序；null 为全部日记（全局排序偏好）。
  final NotebookSort? initialNotebookSort;
  final bool allowBookOrder;
  final ValueChanged<NotebookSort>? onNotebookSortChanged;

  @override
  State<DiaryViewOptionsSheet> createState() => _DiaryViewOptionsSheetState();
}

class _DiaryViewOptionsSheetState extends State<DiaryViewOptionsSheet> {
  late DiarySortMode _sortMode = widget.initialSortMode;
  late DiaryLayoutMode _layoutMode = widget.initialLayoutMode;
  late NotebookSort? _notebookSort = widget.initialNotebookSort;

  void _selectNotebookSort(NotebookSort sort) {
    if (sort == _notebookSort) {
      return;
    }
    setState(() => _notebookSort = sort);
    widget.onNotebookSortChanged?.call(sort);
  }

  /// 日记本里的排序分组：日记本排序选项（智能日记本没有“书序”）。
  List<Widget> _buildNotebookSortSection(
    AppLocalizations l10n,
    NotebookSort current,
  ) {
    return <Widget>[
      _SectionHeader(
        icon: FontAwesomeIcons.sort,
        label: l10n.notebookViewSortSection,
      ),
      const SizedBox(height: AppSpacing.xs),
      for (final sort in NotebookSort.values)
        if (sort != NotebookSort.book || widget.allowBookOrder)
          ExpressiveChoiceTile(
            label: notebookSortLabel(l10n, sort),
            description: notebookSortDescription(l10n, sort),
            selected: current == sort,
            onTap: () => _selectNotebookSort(sort),
          ),
    ];
  }

  void _selectSortMode(DiarySortMode mode) {
    if (mode == _sortMode) {
      return;
    }
    setState(() => _sortMode = mode);
    widget.onSortModeChanged(mode);
  }

  void _selectLayoutMode(DiaryLayoutMode mode) {
    if (mode == _layoutMode) {
      return;
    }
    setState(() => _layoutMode = mode);
    widget.onLayoutModeChanged(mode);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return SafeArea(
      top: false,
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.l,
          AppSpacing.s,
          AppSpacing.l,
          AppSpacing.l,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            if (_notebookSort case final notebookSort?)
              ..._buildNotebookSortSection(l10n, notebookSort)
            else ...<Widget>[
              _SectionHeader(
                icon: FontAwesomeIcons.sort,
                label: l10n.autoT0141,
              ),
              const SizedBox(height: AppSpacing.xs),
              for (final field in DiarySortField.values)
                ExpressiveChoiceTile(
                  label: _sortFieldLabel(l10n, field),
                  selected: _sortMode.field == field,
                  // 换排序依据时保留当前正/倒序。
                  onTap: () => _selectSortMode(_sortMode.withField(field)),
                ),
              const SizedBox(height: AppSpacing.s),
              ExpressiveButtonGroup<DiarySortDirection>(
                segments: <ButtonSegment<DiarySortDirection>>[
                  ButtonSegment<DiarySortDirection>(
                    value: DiarySortDirection.descending,
                    icon: const FaIcon(
                      FontAwesomeIcons.arrowDownWideShort,
                      size: 16,
                    ),
                    label: Text(l10n.diarySortDescending),
                  ),
                  ButtonSegment<DiarySortDirection>(
                    value: DiarySortDirection.ascending,
                    icon: const FaIcon(
                      FontAwesomeIcons.arrowUpWideShort,
                      size: 16,
                    ),
                    label: Text(l10n.diarySortAscending),
                  ),
                ],
                selected: <DiarySortDirection>{_sortMode.direction},
                onSelectionChanged: (Set<DiarySortDirection> selection) =>
                    _selectSortMode(_sortMode.withDirection(selection.single)),
              ),
              const SizedBox(height: AppSpacing.s),
              _SortEffectHint(text: _sortEffectHint(l10n, _sortMode)),
            ],
            const SizedBox(height: AppSpacing.l),
            _SectionHeader(
              icon: FontAwesomeIcons.tableCellsLarge,
              label: l10n.autoT0145,
            ),
            const SizedBox(height: AppSpacing.xs),
            ExpressiveChoiceTile(
              label: l10n.autoT0146,
              selected: _layoutMode == DiaryLayoutMode.list,
              onTap: () => _selectLayoutMode(DiaryLayoutMode.list),
            ),
            ExpressiveChoiceTile(
              label: l10n.autoT0147,
              selected: _layoutMode == DiaryLayoutMode.waterfall,
              onTap: () => _selectLayoutMode(DiaryLayoutMode.waterfall),
            ),
            if (widget.onOpenNotebookShelf case final openShelf?) ...<Widget>[
              const SizedBox(height: AppSpacing.l),
              _SectionHeader(
                icon: FontAwesomeIcons.book,
                label: l10n.notebookTitle,
              ),
              const SizedBox(height: AppSpacing.xs),
              ListTile(
                dense: true,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
                titleAlignment: ListTileTitleAlignment.center,
                title: Text(l10n.notebookViewOptionsEntry),
                subtitle: Text(l10n.notebookViewOptionsEntrySubtitle),
                trailing: const FaIcon(FontAwesomeIcons.angleRight, size: 14),
                onTap: () {
                  Navigator.of(context).pop();
                  openShelf();
                },
              ),
            ],
            if (widget.onOpenCardStyle case final openCardStyle?) ...<Widget>[
              const SizedBox(height: AppSpacing.l),
              _SectionHeader(
                icon: FontAwesomeIcons.palette,
                label: l10n.diaryCardStyleSheetSection,
              ),
              const SizedBox(height: AppSpacing.xs),
              ListTile(
                dense: true,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
                title: Text(l10n.diaryCardStyleSheetEntry),
                subtitle: Text(l10n.diaryCardStyleSheetEntrySubtitle),
                trailing: const FaIcon(FontAwesomeIcons.angleRight, size: 14),
                onTap: () {
                  Navigator.of(context).pop();
                  openCardStyle();
                },
              ),
            ],
          ],
        ),
      ),
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

/// “正序/倒序”对时间字段有歧义，用一句话写明当前组合的实际效果。
String _sortEffectHint(AppLocalizations l10n, DiarySortMode mode) {
  return switch (mode) {
    DiarySortMode.updatedDesc => l10n.diarySortHintUpdatedDesc,
    DiarySortMode.updatedAsc => l10n.diarySortHintUpdatedAsc,
    DiarySortMode.createdDesc => l10n.diarySortHintPublishedDesc,
    DiarySortMode.createdAsc => l10n.diarySortHintPublishedAsc,
    DiarySortMode.titleAsc => l10n.diarySortHintTitleAsc,
    DiarySortMode.titleDesc => l10n.diarySortHintTitleDesc,
  };
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({required this.icon, required this.label});

  final FaIconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Semantics(
      header: true,
      child: Row(
        children: <Widget>[
          FaIcon(icon, size: 16, color: theme.colorScheme.primary),
          const SizedBox(width: AppSpacing.s),
          Text(
            label,
            style: theme.textTheme.titleSmall?.copyWith(
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

/// 排序效果说明：随排序依据与方向变化短交叉淡入，不在一帧内换字。
class _SortEffectHint extends StatelessWidget {
  const _SortEffectHint({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.l),
      child: AnimatedSwitcher(
        duration: ExpressiveMotion.duration(context, ExpressiveMotion.fast),
        switchInCurve: ExpressiveMotion.effects,
        switchOutCurve: ExpressiveMotion.exit,
        layoutBuilder: (currentChild, previousChildren) => Stack(
          alignment: AlignmentDirectional.centerStart,
          children: <Widget>[...previousChildren, ?currentChild],
        ),
        child: Text(
          text,
          key: ValueKey<String>(text),
          style: theme.textTheme.bodySmall?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
      ),
    );
  }
}
