import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:node_diary/l10n/app_localizations.dart';

import '../../../core/database/app_database.dart';
import '../../app_surface/widgets/app_page_backdrop.dart';
import '../../notebooks/sections/notebook_rule_sheets.dart';
import '../../widgets/empty_hint.dart';
import '../widgets/diary_search_chip.dart';

/// 搜索页没有条件时的内容（DESIGN.md §5.33）：最近搜索（点按即搜、行尾 ×
/// 删除一条、标题行“清空”）→ 常用标签（`#` 胶囊，点按加为条件）→ 一行
/// 多词搜索的说明。两组都没有时为居中的 [EmptyHint]。
///
/// 直接画在页面背景上：标题与说明文字经 [AppPageBackdrop.onBackgroundTextStyle]
/// 兜底，有背景图时同样读得清。拖动时收起键盘。
class DiarySearchSuggestions extends StatelessWidget {
  const DiarySearchSuggestions({
    super.key,
    required this.recent,
    required this.tags,
    required this.horizontalPadding,
    required this.onTapRecent,
    required this.onRemoveRecent,
    required this.onClearRecent,
    required this.onTapTag,
  });

  final List<String> recent;

  /// 常用标签（已排除选为条件的）。
  final List<Tag> tags;
  final double horizontalPadding;
  final ValueChanged<String> onTapRecent;
  final ValueChanged<String> onRemoveRecent;
  final VoidCallback onClearRecent;
  final ValueChanged<Tag> onTapTag;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    if (recent.isEmpty && tags.isEmpty) {
      return EmptyHint(
        icon: FontAwesomeIcons.magnifyingGlass,
        message: l10n.diarySearchEmptyTip,
      );
    }
    return ListView(
      keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
      padding: EdgeInsets.fromLTRB(horizontalPadding, 8, horizontalPadding, 24),
      children: <Widget>[
        if (recent.isNotEmpty) ...<Widget>[
          _SectionHeader(
            icon: FontAwesomeIcons.clockRotateLeft,
            label: l10n.diarySearchRecentTitle,
            trailing: TextButton(
              onPressed: onClearRecent,
              style: TextButton.styleFrom(
                foregroundColor: theme.colorScheme.onSurfaceVariant,
                visualDensity: VisualDensity.compact,
              ),
              child: Semantics(
                label: l10n.diarySearchClearRecent,
                excludeSemantics: true,
                child: Text(l10n.autoT0130),
              ),
            ),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: <Widget>[
              for (final query in recent)
                DiarySearchChip(
                  key: ValueKey<String>('search_recent_$query'),
                  label: query,
                  active: false,
                  onTap: () => onTapRecent(query),
                  onRemove: () => onRemoveRecent(query),
                  removeLabel: l10n.diarySearchRecentRemove(query),
                ),
            ],
          ),
          const SizedBox(height: 24),
        ],
        if (tags.isNotEmpty) ...<Widget>[
          _SectionHeader(
            icon: FontAwesomeIcons.tag,
            label: l10n.diarySearchSuggestedTags,
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: <Widget>[
              for (final tag in tags)
                notebookRuleTagChip(
                  theme,
                  name: tag.name,
                  color: Color(tag.color),
                  selected: false,
                  onTap: () => onTapTag(tag),
                ),
            ],
          ),
          const SizedBox(height: 24),
        ],
        Text(
          l10n.diarySearchEmptyTip,
          style: AppPageBackdrop.onBackgroundTextStyle(
            context,
            theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
              height: 1.4,
            ),
          ),
        ),
      ],
    );
  }
}

/// 分组标题：14px `primary` 图标 + `titleSmall` w700，行尾可放一个文本按钮。
/// 没有行尾按钮时保持同样的行高，两组标题的基线一致。
class _SectionHeader extends StatelessWidget {
  const _SectionHeader({
    required this.icon,
    required this.label,
    this.trailing,
  });

  final FaIconData icon;
  final String label;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final iconStyle = AppPageBackdrop.onBackgroundTextStyle(
      context,
      TextStyle(color: theme.colorScheme.primary),
    );
    return ConstrainedBox(
      constraints: const BoxConstraints(minHeight: 40),
      child: Row(
        children: <Widget>[
          FaIcon(
            icon,
            size: 14,
            color: iconStyle?.color,
            shadows: iconStyle?.shadows,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Semantics(
              header: true,
              child: Text(
                label,
                style: AppPageBackdrop.onBackgroundTextStyle(
                  context,
                  theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ),
          ),
          ?trailing,
        ],
      ),
    );
  }
}
