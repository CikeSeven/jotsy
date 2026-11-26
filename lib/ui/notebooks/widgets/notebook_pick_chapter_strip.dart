import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:node_diary/core/database/app_database.dart';
import 'package:node_diary/l10n/app_localizations.dart';

import '../../app_surface/widgets/on_glass.dart';
import '../../diary_templates/viewmodels/diary_template_accent.dart';

/// 选择日记本行内展开的章节胶囊条（按章节顺序排列，末尾为“未分章”）。
///
/// 视觉沿用日记本的强调色（`notebookAccentColors`）：当前选中的胶囊以
/// `accent.onContainer` 为底配 `accent.container` 文字与对勾，明暗主题下
/// 对比度都有保证。点按只回调 [onSelect]，不冒泡到外层日记本勾选行。
class NotebookPickChapterStrip extends StatelessWidget {
  const NotebookPickChapterStrip({
    super.key,
    required this.notebookId,
    required this.accent,
    required this.chapters,
    required this.selectedChapterId,
    required this.onSelect,
    this.allowNoneSelected = false,
  });

  final String notebookId;
  final DiaryTemplateAccentColors accent;
  final List<NotebookChapter> chapters;

  /// 当前选中的章节 id；null 表示“未分章”（当 [allowNoneSelected] 为 true
  /// 且 [hasExplicitSelection] 为 false 时可不亮任何项，供单选目标本展示）。
  final String? selectedChapterId;
  final ValueChanged<String?> onSelect;

  /// 为 true 时不预先高亮“未分章”（例如“移动到…”单选模式，点具体章或
  /// “未分章”即选定返回）。
  final bool allowNoneSelected;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return Padding(
      padding: const EdgeInsetsDirectional.fromSTEB(56, 0, 12, 12),
      child: Wrap(
        spacing: 6,
        runSpacing: 6,
        children: <Widget>[
          for (final chapter in chapters)
            _ChapterPill(
              key: ValueKey<String>(
                'notebook_pick_chapter_${notebookId}_${chapter.id}',
              ),
              label: chapter.title,
              selected: selectedChapterId == chapter.id,
              accent: accent,
              onTap: () => onSelect(chapter.id),
            ),
          _ChapterPill(
            key: ValueKey<String>(
              'notebook_pick_chapter_${notebookId}_unassigned',
            ),
            label: l10n.notebookChapterUnassigned,
            selected: !allowNoneSelected && selectedChapterId == null,
            accent: accent,
            onTap: () => onSelect(null),
          ),
        ],
      ),
    );
  }
}

class _ChapterPill extends StatelessWidget {
  const _ChapterPill({
    super.key,
    required this.label,
    required this.selected,
    required this.accent,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final DiaryTemplateAccentColors accent;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final radius = BorderRadius.circular(8);
    final background = selected
        ? accent.onContainer
        : OnGlass.of(context)
        ? OnGlass.wellColor(scheme)
        : scheme.surface.withValues(alpha: 0.72);
    final foreground = selected ? accent.container : scheme.onSurface;
    return Semantics(
      button: true,
      selected: selected,
      child: Material(
        color: background,
        shape: RoundedRectangleBorder(
          borderRadius: radius,
          side: selected
              ? BorderSide.none
              : BorderSide(color: scheme.outlineVariant.withValues(alpha: 0.5)),
        ),
        child: InkWell(
          borderRadius: radius,
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                if (selected) ...<Widget>[
                  FaIcon(FontAwesomeIcons.check, size: 10, color: foreground),
                  const SizedBox(width: 5),
                ],
                Flexible(
                  child: Text(
                    label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.labelMedium?.copyWith(
                      fontWeight: selected ? FontWeight.w600 : FontWeight.w500,
                      color: foreground,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
