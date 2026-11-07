import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:node_diary/l10n/app_localizations.dart';

import '../../../app/theme/expressive_motion.dart';
import '../../../app/theme/expressive_surfaces.dart';
import '../../../core/database/app_database.dart';
import '../../../core/services/app_platform.dart';
import '../../notebooks/viewmodels/notebook_rule_labels.dart';
import '../../widgets/desktop_horizontal_scroll.dart';
import '../../widgets/expressive_icon_swap.dart';
import '../../widgets/form_width.dart';
import '../../widgets/search_pill_field.dart';
import '../controllers/diary_search_controller.dart';
import '../models/diary_search_filters.dart';
import '../widgets/diary_search_chip.dart';

/// 搜索页顶部（实色顶栏里的内容，DESIGN.md §5.33）：
///
/// ```
///  <  ( 🔍 搜索标题或内容          ⊗ )  ✦
///  [📕 旅行 ×] [#旅行 #美食 ×] [日期 ▾] [心情 ▾] … [含归档]
/// ```
///
/// - 第一行：返回（48dp）+ 胶囊输入框（[SearchPillField]）+ 有条件时的
///   “存为智能日记本”；宽窗口按 [FormWidth.gutter] 与结果列对齐；
/// - 第二行：横向滚动的胶囊，先是日记本条件，再是固定顺序的筛选（标签、
///   各筛选槽位、含归档）。已选的标签不逐个列出，都写在“标签”胶囊上
///   （“#旅行 #美食”）；已生效的筛选显示取值，行尾 × 清除，点胶囊重新打开
///   选择器。
///
/// 键盘（输入框为空时）：退格依次移除最后一个标签、日记本条件；桌面上 Esc
/// 有字时清空、没字时退出。
///
/// 只负责排布与转发事件；条件状态在 [DiarySearchController]，选择面板的
/// 流程在 `diary_search_filter_flows.dart`。
class DiarySearchTopBar extends StatelessWidget {
  const DiarySearchTopBar({
    super.key,
    required this.session,
    required this.focusNode,
    required this.autofocus,
    required this.selectedTags,
    required this.scopeLabel,
    required this.scopeIcon,
    required this.onClose,
    required this.onSubmitted,
    required this.onPickTags,
    required this.onPickFilter,
    this.onSaveAsNotebook,
  });

  final DiarySearchController session;
  final FocusNode focusNode;
  final bool autofocus;

  /// 已选为条件的标签（按标签列表的顺序）。
  final List<Tag> selectedTags;

  /// 日记本条件的名称与图标；在全部日记中搜索（或已移除）时 [scopeLabel]
  /// 为 null。
  final String? scopeLabel;
  final FaIconData scopeIcon;

  final VoidCallback onClose;
  final VoidCallback onSubmitted;
  final VoidCallback onPickTags;
  final ValueChanged<DiarySearchFilterSlot> onPickFilter;

  /// 存为智能日记本；没有条件或日记本功能关闭时为 null（不显示）。
  final VoidCallback? onSaveAsNotebook;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final scheme = Theme.of(context).colorScheme;
    final isLight = scheme.brightness == Brightness.light;
    return LayoutBuilder(
      builder: (BuildContext context, BoxConstraints constraints) {
        final gutter = FormWidth.gutter(constraints.maxWidth);
        // 返回按钮与 ✦ 自带 48dp 点击区，视觉上的图标已有留白：两侧各收 4。
        final rowInset = gutter - 4;
        return Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            Padding(
              padding: EdgeInsets.fromLTRB(rowInset, 4, rowInset, 0),
              child: Row(
                children: <Widget>[
                  IconButton(
                    tooltip: l10n.autoT0128,
                    onPressed: onClose,
                    icon: const FaIcon(FontAwesomeIcons.angleLeft, size: 18),
                  ),
                  const SizedBox(width: 2),
                  Expanded(
                    child: Focus(
                      canRequestFocus: false,
                      skipTraversal: true,
                      onKeyEvent: _handleKey,
                      child: SearchPillField(
                        controller: session.text,
                        focusNode: focusNode,
                        autofocus: autofocus,
                        hintText: l10n.autoT0129,
                        onChanged: session.onInputChanged,
                        onSubmitted: (_) => onSubmitted(),
                        onClear: () {
                          session.clearKeyword();
                          focusNode.requestFocus();
                        },
                        // 与首页顶栏的搜索条同一底色与描边：点开后像是同一个
                        // 搜索框展开成了整页。
                        fill: isLight
                            ? ExpressiveSurfaces.cardColor(scheme)
                            : scheme.surfaceContainerHigh,
                        idleOutline: ExpressiveSurfaces.cardBorderColor(scheme),
                      ),
                    ),
                  ),
                  // 有了第一个条件才出现：缩放淡入，同时输入框宽度补间让位，
                  // 不在打字的那一帧硬跳。
                  AnimatedSize(
                    duration: ExpressiveMotion.duration(
                      context,
                      ExpressiveMotion.medium,
                    ),
                    curve: ExpressiveMotion.effects,
                    child: ExpressiveIconSwap(
                      switchKey: onSaveAsNotebook != null,
                      child: onSaveAsNotebook == null
                          ? const SizedBox.shrink()
                          : Padding(
                              padding: const EdgeInsetsDirectional.only(
                                start: 2,
                              ),
                              child: IconButton(
                                key: const ValueKey<String>(
                                  'search_save_as_notebook',
                                ),
                                tooltip: l10n.notebookSaveSearchAsSmart,
                                onPressed: onSaveAsNotebook,
                                icon: FaIcon(
                                  FontAwesomeIcons.wandMagicSparkles,
                                  size: 16,
                                  color: scheme.primary,
                                ),
                              ),
                            ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 8),
            DesktopHorizontalScroll(
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                padding: EdgeInsets.symmetric(horizontal: gutter),
                child: Row(children: _chips(context)),
              ),
            ),
            const SizedBox(height: 10),
          ],
        );
      },
    );
  }

  List<Widget> _chips(BuildContext context) {
    final l10n = context.l10n;
    final filters = session.filters;
    final now = DateTime.now();
    final chips = <Widget>[
      if (scopeLabel case final label?)
        DiarySearchChip(
          key: const ValueKey<String>('search_scope_chip'),
          label: label,
          active: true,
          leading: FaIcon(scopeIcon),
          onRemove: session.removeScope,
          removeLabel: l10n.notebookSearchRemoveScope(label),
        ),
      _tagChip(l10n),
      for (final slot in DiarySearchFilterSlot.values)
        _filterChip(context, slot, filters.ruleOf(slot), now),
      DiarySearchChip(
        key: const ValueKey<String>('search_filter_archived'),
        label: l10n.diarySearchIncludeArchived,
        active: filters.includeArchived,
        leading: const FaIcon(FontAwesomeIcons.boxArchive),
        onTap: () => session.setIncludeArchived(!filters.includeArchived),
      ),
    ];
    return <Widget>[
      for (var i = 0; i < chips.length; i++) ...<Widget>[
        if (i > 0) const SizedBox(width: 8),
        chips[i],
      ],
    ];
  }

  /// “标签”胶囊：没选时为普通筛选胶囊；选了以后胶囊上写所选标签
  /// （“#旅行 #美食”，过长省略），行尾 × 一次清掉全部标签条件。
  Widget _tagChip(AppLocalizations l10n) {
    final active = selectedTags.isNotEmpty;
    final label = active
        ? selectedTags.map((tag) => '#${tag.name}').join(' ')
        : notebookRuleTypeLabel(l10n, NotebookRuleType.tags);
    return DiarySearchChip(
      key: const ValueKey<String>('search_filter_tags'),
      label: label,
      active: active,
      leading: FaIcon(notebookRuleTypeIcon(NotebookRuleType.tags)),
      showCaret: !active,
      onTap: onPickTags,
      onRemove: active ? () => session.setTags(const <int>{}) : null,
      removeLabel: !active
          ? null
          : selectedTags.length == 1
          ? l10n.searchRemoveTagCondition(selectedTags.single.name)
          : l10n.diarySearchRemoveFilter(label),
    );
  }

  Widget _filterChip(
    BuildContext context,
    DiarySearchFilterSlot slot,
    NotebookRule? rule,
    DateTime now,
  ) {
    final l10n = context.l10n;
    final label = rule == null
        ? notebookRuleTypeLabel(l10n, slot.ruleType)
        : _activeLabel(l10n, rule, now);
    return DiarySearchChip(
      key: ValueKey<String>('search_filter_${slot.name}'),
      label: label,
      active: rule != null,
      leading: FaIcon(notebookRuleTypeIcon(slot.ruleType)),
      showCaret: rule == null,
      onTap: () => onPickFilter(slot),
      onRemove: rule == null ? null : () => session.setFilter(slot, null),
      removeLabel: rule == null ? null : l10n.diarySearchRemoveFilter(label),
    );
  }

  /// 已生效筛选的胶囊文字：只写取值（图标已经说明是哪一项）。
  static String _activeLabel(
    AppLocalizations l10n,
    NotebookRule rule,
    DateTime now,
  ) => switch (rule) {
    NotebookMoodRule(:final emojis) => emojis.join(' '),
    NotebookTextRule(:final text) => text,
    NotebookMediaRule(:final kind) => notebookMediaKindLabel(l10n, kind),
    _ => notebookRuleSummary(l10n, rule, now: now),
  };

  KeyEventResult _handleKey(FocusNode node, KeyEvent event) {
    if (event is! KeyDownEvent) {
      return KeyEventResult.ignored;
    }
    final empty = session.text.text.isEmpty;
    if (event.logicalKey == LogicalKeyboardKey.backspace && empty) {
      if (selectedTags.isNotEmpty) {
        session.removeTag(selectedTags.last.id);
        return KeyEventResult.handled;
      }
      if (scopeLabel != null) {
        session.removeScope();
        return KeyEventResult.handled;
      }
      return KeyEventResult.ignored;
    }
    if (event.logicalKey == LogicalKeyboardKey.escape &&
        AppPlatform.isDesktop) {
      if (!empty) {
        session.clearKeyword();
      } else {
        onClose();
      }
      return KeyEventResult.handled;
    }
    return KeyEventResult.ignored;
  }
}
