import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:node_diary/l10n/app_localizations.dart';

import '../../../app/theme/app_spacing.dart';
import '../../../app/theme/expressive_motion.dart';
import '../../widgets/empty_hint.dart';
import '../models/diary_template.dart';
import '../models/diary_template_selection.dart';
import '../providers/diary_template_providers.dart';
import '../viewmodels/diary_template_labels.dart';
import '../viewmodels/diary_template_library.dart';
import '../viewmodels/diary_template_search.dart';
import '../widgets/diary_template_search_field.dart';
import '../widgets/diary_template_tile.dart';
import 'diary_template_picker_preview.dart';

/// 完整的模板面板：按分类筛选、点一个先预览（变量已按 [diaryDate] 替换），
/// 再“使用这个模板”。只负责挑选，返回选定的模板（含“换一题”的偏移）；
/// 下滑或点遮罩关闭返回 null。套用由调用方（新建编辑页、新建入口流程）完成。
Future<DiaryTemplateSelection?> showDiaryTemplatePickerSheet(
  BuildContext context, {
  required DateTime diaryDate,
}) {
  return showModalBottomSheet<DiaryTemplateSelection>(
    context: context,
    useSafeArea: true,
    showDragHandle: true,
    isScrollControlled: true,
    // 底部面板默认滑入不读取系统“减少动态效果”；该模式下直接出现。
    sheetAnimationStyle: ExpressiveMotion.reduceMotion(context)
        ? AnimationStyle.noAnimation
        : null,
    builder: (BuildContext sheetContext) => DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.75,
      minChildSize: 0.45,
      builder: (BuildContext context, ScrollController scrollController) =>
          DiaryTemplatePicker(
            diaryDate: diaryDate,
            scrollController: scrollController,
          ),
    ),
  );
}

/// 面板的筛选项：全部、推荐、我的，或某个分类。
@immutable
class _PickerFilter {
  const _PickerFilter._(this.kind, [this.category]);

  static const _PickerFilter all = _PickerFilter._(_FilterKind.all);
  static const _PickerFilter recommended = _PickerFilter._(
    _FilterKind.recommended,
  );
  static const _PickerFilter mine = _PickerFilter._(_FilterKind.mine);

  final _FilterKind kind;
  final DiaryTemplateCategory? category;

  bool accepts(DiaryTemplateSuggestion item) => switch (kind) {
    _FilterKind.all => true,
    _FilterKind.recommended => item.recommended,
    _FilterKind.mine => !item.template.isBuiltIn,
    _FilterKind.category => item.template.category == category,
  };

  @override
  bool operator ==(Object other) =>
      other is _PickerFilter &&
      other.kind == kind &&
      other.category == category;

  @override
  int get hashCode => Object.hash(kind, category);
}

enum _FilterKind { all, recommended, mine, category }

/// 面板内容：列表与预览两步，经淡入淡出切换。
///
/// 列表步顶部有搜索框，与筛选胶囊取“且”。搜索词与输入框控制器放在本
/// State 而不是列表子树里：进入预览时列表子树被换掉，返回后搜索词与结果
/// 仍在。
class DiaryTemplatePicker extends ConsumerStatefulWidget {
  const DiaryTemplatePicker({
    super.key,
    required this.diaryDate,
    required this.scrollController,
  });

  final DateTime diaryDate;
  final ScrollController scrollController;

  @override
  ConsumerState<DiaryTemplatePicker> createState() =>
      _DiaryTemplatePickerState();
}

class _DiaryTemplatePickerState extends ConsumerState<DiaryTemplatePicker> {
  // 打开时定格“现在”：推荐顺序在面板打开期间不随时钟跳动。
  final DateTime _now = DateTime.now();
  _PickerFilter _filter = _PickerFilter.all;
  DiaryTemplate? _previewing;
  final TextEditingController _searchController = TextEditingController();
  final FocusNode _searchFocus = FocusNode();
  String _query = '';

  @override
  void dispose() {
    _searchController.dispose();
    _searchFocus.dispose();
    super.dispose();
  }

  void _openPreview(DiaryTemplate template) {
    // 先收起键盘：预览页没有输入框，键盘留着只会挡住底部的“使用”按钮。
    _searchFocus.unfocus();
    setState(() => _previewing = template);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final library = watchDiaryTemplateLibrary(ref, l10n).library;
    final ranked = library.ranked(now: _now, diaryDate: widget.diaryDate);
    final previewing = _previewing;
    return AnimatedSwitcher(
      duration: ExpressiveMotion.duration(context, ExpressiveMotion.medium),
      switchInCurve: ExpressiveMotion.effects,
      switchOutCurve: ExpressiveMotion.exit,
      child: previewing == null
          ? _buildList(context, ranked)
          : DiaryTemplatePickerPreview(
              key: ValueKey<String>('preview_${previewing.id}'),
              template: previewing,
              diaryDate: widget.diaryDate,
              onBack: () => setState(() => _previewing = null),
              onUse: (selection) => Navigator.of(context).pop(selection),
            ),
    );
  }

  Widget _buildList(
    BuildContext context,
    List<DiaryTemplateSuggestion> ranked,
  ) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    // 胶囊按完整列表计算而不是按搜索结果：打字时胶囊不会忽隐忽现。
    final filters = <(_PickerFilter, String)>[
      (_PickerFilter.all, l10n.diaryTemplateFilterAll),
      if (ranked.any((item) => item.recommended))
        (_PickerFilter.recommended, l10n.diaryTemplateFilterRecommended),
      if (ranked.any((item) => !item.template.isBuiltIn))
        (_PickerFilter.mine, l10n.diaryTemplateFilterMine),
      for (final category in DiaryTemplateCategory.values)
        if (ranked.any((item) => item.template.category == category))
          (
            _PickerFilter._(_FilterKind.category, category),
            diaryTemplateCategoryLabel(l10n, category),
          ),
    ];
    // 当前筛选项已经不存在（例如推荐时段过了）时回到“全部”。
    final filter = filters.any((entry) => entry.$1 == _filter)
        ? _filter
        : _PickerFilter.all;
    final items = ranked
        .where(
          (item) =>
              filter.accepts(item) &&
              diaryTemplateMatchesQuery(l10n, item.template, _query),
        )
        .toList(growable: false);
    final searching = diaryTemplateSearchTerms(_query).isNotEmpty;
    // 底部面板不会为软键盘让位，键盘盖在面板下半部分上；把键盘高度计入
    // 列表底部留白，搜索时结果仍能滚到键盘上方。键盘弹起时系统已把
    // padding.bottom 扣掉了键盘遮住的部分，两者相加不会重复计算。
    final bottomInset =
        MediaQuery.paddingOf(context).bottom +
        MediaQuery.viewInsetsOf(context).bottom;
    return CustomScrollView(
      key: const ValueKey<String>('list'),
      controller: widget.scrollController,
      slivers: <Widget>[
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.l + AppSpacing.xs,
            0,
            AppSpacing.l,
            AppSpacing.m,
          ),
          sliver: SliverToBoxAdapter(
            child: Semantics(
              header: true,
              child: Text(
                l10n.diaryTemplatePickerTitle,
                style: theme.textTheme.titleLarge?.copyWith(
                  fontSize: 20,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ),
        ),
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.l,
            0,
            AppSpacing.l,
            AppSpacing.s,
          ),
          sliver: SliverToBoxAdapter(
            child: DiaryTemplateSearchField(
              controller: _searchController,
              focusNode: _searchFocus,
              onChanged: (value) => setState(() => _query = value),
            ),
          ),
        ),
        SliverToBoxAdapter(
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.l),
            child: Row(
              children: <Widget>[
                for (final (value, label) in filters) ...<Widget>[
                  ChoiceChip(
                    label: Text(label),
                    selected: value == filter,
                    onSelected: (_) => setState(() => _filter = value),
                  ),
                  const SizedBox(width: AppSpacing.s),
                ],
              ],
            ),
          ),
        ),
        const SliverToBoxAdapter(child: SizedBox(height: AppSpacing.m)),
        if (items.isEmpty)
          SliverPadding(
            // 空态居中在键盘上方的可见区域里。
            padding: EdgeInsets.only(bottom: bottomInset),
            sliver: SliverFillRemaining(
              hasScrollBody: false,
              child: searching
                  ? EmptyHint(
                      icon: FontAwesomeIcons.magnifyingGlass,
                      message: l10n.diaryTemplatePickerSearchEmpty(
                        _query.trim(),
                      ),
                    )
                  : EmptyHint(
                      icon: FontAwesomeIcons.layerGroup,
                      message: l10n.diaryTemplatePickerEmpty,
                    ),
            ),
          )
        else
          SliverPadding(
            padding: EdgeInsets.fromLTRB(
              AppSpacing.l,
              0,
              AppSpacing.l,
              AppSpacing.l + bottomInset,
            ),
            sliver: SliverList.separated(
              itemCount: items.length,
              separatorBuilder: (_, _) => const SizedBox(height: AppSpacing.s),
              itemBuilder: (BuildContext context, int index) {
                final item = items[index];
                return DiaryTemplateTile(
                  key: ValueKey<String>('template_pick_${item.template.id}'),
                  template: item.template,
                  recommended: item.recommended,
                  onTap: () => _openPreview(item.template),
                );
              },
            ),
          ),
      ],
    );
  }
}
