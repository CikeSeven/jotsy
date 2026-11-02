// 一份回顾的正文（回顾页生成中 / 生成后、已保存的回顾页共用）：顶部本地
// 统计胶囊（篇数与字数、常用心情、常用标签），Markdown 正文（`[Dn]` 引用
// 为可点的胶囊），末尾一行人设与模型，再下面是操作按钮。

import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';

import '../../../l10n/app_localizations.dart';
import '../../app_surface/widgets/app_card_surface.dart';
import '../viewmodels/ai_citations.dart';
import '../viewmodels/ai_recap_material.dart';
import '../widgets/ai_markdown_view.dart';
import '../widgets/ai_persona_avatar.dart';

class AiRecapResultView extends StatelessWidget {
  const AiRecapResultView({
    super.key,
    required this.markdown,
    this.stats,
    this.personaName,
    this.personaEmoji,
    this.modelName,
    this.reasoning = '',
    this.onCitation,
    this.actions = const <Widget>[],
  });

  final String markdown;
  final AiRecapStats? stats;
  final String? personaName;
  final String? personaEmoji;
  final String? modelName;
  final String reasoning;
  final ValueChanged<String>? onCitation;
  final List<Widget> actions;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final stats = this.stats;
    final metaStyle = theme.textTheme.bodySmall?.copyWith(
      color: colors.onSurfaceVariant,
    );
    return AppCardSurface(
      padding: const EdgeInsets.fromLTRB(18, 16, 18, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          if (stats != null) ...<Widget>[
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: <Widget>[
                _StatChip(
                  icon: FontAwesomeIcons.bookOpen,
                  label: l10n.aiRecapStats(stats.entries, stats.words),
                ),
                for (final (mood, count) in stats.moods.take(4))
                  _StatChip(label: '$mood ×$count'),
                for (final (tag, _) in stats.tags.take(4))
                  _StatChip(icon: FontAwesomeIcons.hashtag, label: tag),
              ],
            ),
            const SizedBox(height: 12),
          ],
          if (reasoning.trim().isNotEmpty) ...<Widget>[
            AiReasoningFold(reasoning: reasoning),
            const SizedBox(height: 8),
          ],
          AiMarkdownView(
            markdown: aiNormalizeCitations(markdown),
            onCitation: onCitation,
          ),
          if (personaName != null || modelName != null) ...<Widget>[
            const SizedBox(height: 12),
            Row(
              children: <Widget>[
                if (personaEmoji != null) ...<Widget>[
                  AiPersonaAvatar(emoji: personaEmoji!, size: 22),
                  const SizedBox(width: 6),
                ],
                Expanded(
                  child: Text(
                    [
                      ?personaName,
                      if (modelName != null) l10n.aiRecapModel(modelName!),
                    ].join(' · '),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: metaStyle,
                  ),
                ),
              ],
            ),
          ],
          if (actions.isNotEmpty) ...<Widget>[
            const SizedBox(height: 4),
            Wrap(alignment: WrapAlignment.end, spacing: 4, children: actions),
          ],
        ],
      ),
    );
  }
}

class _StatChip extends StatelessWidget {
  const _StatChip({required this.label, this.icon});

  final String label;
  final FaIconData? icon;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: colors.secondaryContainer,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            if (icon != null) ...<Widget>[
              FaIcon(icon, size: 11, color: colors.onSecondaryContainer),
              const SizedBox(width: 6),
            ],
            Text(
              label,
              style: theme.textTheme.labelMedium?.copyWith(
                color: colors.onSecondaryContainer,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// 回顾操作按钮（文字按钮 + 图标）。
class AiRecapAction extends StatelessWidget {
  const AiRecapAction({
    super.key,
    required this.icon,
    required this.label,
    required this.onPressed,
    this.destructive = false,
  });

  final FaIconData icon;
  final String label;
  final VoidCallback? onPressed;
  final bool destructive;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return TextButton.icon(
      style: destructive
          ? TextButton.styleFrom(foregroundColor: colors.error)
          : null,
      onPressed: onPressed,
      icon: FaIcon(icon, size: 14),
      label: Text(label),
    );
  }
}
