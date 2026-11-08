// 空白新对话的欢迎页（DESIGN §5.29“欢迎页”）：进入 AI 助手后先看到它。
//
// 自上而下：56dp 人设头像（emoji，`secondaryContainer` 圆底）+ `headlineSmall`
// w700 问候 + 一行灰字说明（智能体开着时提到能直接动手整理）；两列彩色
// 建议卡（16 圆角，左上 32dp 领域色徽标按序轮换三种容器色，点按即发送）；
// 回顾胶囊（回顾模块开启时：本周 / 本月 / 今年，“更多…”进回顾页）；最近
// 3 段对话与“全部对话”（打开历史抽屉）。各块以 `ExpressiveEntrance` 依次
// 淡入上移（时长递增，减少动画时直接显示）。

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';

import '../../../../app/theme/expressive_motion.dart';
import '../../../../core/database/app_database.dart';
import '../../../../l10n/app_localizations.dart';
import '../../../app_surface/widgets/app_glass_field.dart';
import '../../../widgets/expressive_entrance.dart';
import '../../models/ai_built_ins.dart';
import '../../models/ai_recap_range.dart';
import '../../providers/ai_records_providers.dart';
import '../../tools/ai_destinations.dart';
import '../../viewmodels/ai_labels.dart';
import '../../widgets/ai_tint_badge.dart';
import 'ai_chat_history_panel.dart';

class AiChatWelcome extends ConsumerWidget {
  const AiChatWelcome({
    super.key,
    required this.persona,
    required this.agent,
    required this.recapOn,
    required this.onAsk,
    required this.onOpenConversation,
    required this.onShowAll,
    required this.onRecap,
  });

  final AiPersonaInfo persona;

  /// 智能体开着（说明里提到能动手）。
  final bool agent;
  final bool recapOn;
  final ValueChanged<String> onAsk;
  final ValueChanged<String> onOpenConversation;

  /// 打开历史抽屉；宽窗口历史栏常驻时为 null（不放“全部对话”）。
  final VoidCallback? onShowAll;

  /// 打开回顾页：给了预设就直接生成。
  final ValueChanged<AiRecapPreset?> onRecap;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final recent =
        ref.watch(aiConversationsProvider('')).value?.take(3).toList() ??
        const <AiConversationRow>[];
    final prompts = <(String, FaIconData, AiTint)>[
      (l10n.aiHubQuickMonth, FontAwesomeIcons.calendarDays, AiTint.primary),
      (l10n.aiHubQuickWorry, FontAwesomeIcons.cloudRain, AiTint.secondary),
      (
        l10n.aiHubQuickLastYear,
        FontAwesomeIcons.clockRotateLeft,
        AiTint.tertiary,
      ),
      (l10n.aiHubQuickHappy, FontAwesomeIcons.solidFaceSmile, AiTint.primary),
      (l10n.aiHubQuickGrowth, FontAwesomeIcons.seedling, AiTint.secondary),
      (l10n.aiHubQuickHelp, FontAwesomeIcons.circleQuestion, AiTint.tertiary),
    ];
    final sectionStyle = theme.textTheme.titleSmall?.copyWith(
      fontWeight: FontWeight.w600,
      color: colors.onSurfaceVariant,
    );
    return Padding(
      padding: const EdgeInsets.only(top: 24, bottom: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          ExpressiveEntrance(
            child: Column(
              children: <Widget>[
                DecoratedBox(
                  decoration: BoxDecoration(
                    color: colors.secondaryContainer,
                    shape: BoxShape.circle,
                  ),
                  child: SizedBox.square(
                    dimension: 56,
                    child: Center(
                      child: Text(
                        persona.emoji,
                        style: const TextStyle(fontSize: 28),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 14),
                Text(
                  l10n.aiChatWelcomeTitle,
                  textAlign: TextAlign.center,
                  style: theme.textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  agent ? l10n.aiChatWelcomeAgent : l10n.aiChatWelcomeRetrieval,
                  textAlign: TextAlign.center,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: colors.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
          ExpressiveEntrance(
            duration: ExpressiveMotion.standard,
            child: LayoutBuilder(
              builder: (context, constraints) {
                final columns = constraints.maxWidth >= 560 ? 3 : 2;
                const gap = 10.0;
                final width =
                    (constraints.maxWidth - gap * (columns - 1)) / columns;
                return Wrap(
                  spacing: gap,
                  runSpacing: gap,
                  children: <Widget>[
                    for (final (text, icon, tint) in prompts)
                      SizedBox(
                        width: width,
                        child: _PromptCard(
                          text: text,
                          icon: icon,
                          tint: tint,
                          onTap: () => onAsk(text),
                        ),
                      ),
                  ],
                );
              },
            ),
          ),
          if (recapOn) ...<Widget>[
            const SizedBox(height: 24),
            ExpressiveEntrance(
              duration: ExpressiveMotion.long,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(l10n.aiChatWelcomeRecaps, style: sectionStyle),
                  const SizedBox(height: 10),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: <Widget>[
                      for (final preset in const <AiRecapPreset>[
                        AiRecapPreset.thisWeek,
                        AiRecapPreset.thisMonth,
                        AiRecapPreset.thisYear,
                      ])
                        ActionChip(
                          avatar: FaIcon(
                            FontAwesomeIcons.wandMagicSparkles,
                            size: 12,
                            color: colors.primary,
                          ),
                          label: Text(aiRecapPresetLabel(l10n, preset)),
                          onPressed: () => onRecap(preset),
                        ),
                      ActionChip(
                        label: Text(l10n.aiHubRecapMore),
                        onPressed: () => onRecap(null),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
          if (recent.isNotEmpty) ...<Widget>[
            const SizedBox(height: 24),
            ExpressiveEntrance(
              duration: ExpressiveMotion.long,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: <Widget>[
                  Row(
                    children: <Widget>[
                      Expanded(
                        child: Text(
                          l10n.aiChatWelcomeRecent,
                          style: sectionStyle,
                        ),
                      ),
                      if (onShowAll case final showAll?)
                        TextButton(
                          onPressed: showAll,
                          child: Text(l10n.aiChatWelcomeAllChats),
                        ),
                    ],
                  ),
                  for (final row in recent)
                    _RecentRow(
                      key: ValueKey<String>(row.conversationId),
                      row: row,
                      onTap: () => onOpenConversation(row.conversationId),
                    ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _PromptCard extends StatelessWidget {
  const _PromptCard({
    required this.text,
    required this.icon,
    required this.tint,
    required this.onTap,
  });

  final String text;
  final FaIconData icon;
  final AiTint tint;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final glass = AppGlassField.of(context);
    return Material(
      color: glass?.fill ?? colors.surfaceContainerLow,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side:
            glass?.border ??
            BorderSide(
              color: colors.outlineVariant.withValues(alpha: 0.6),
              width: 0.8,
            ),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 104),
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                AiTintBadge(icon: icon, tint: tint, size: 32),
                const SizedBox(height: 10),
                Text(
                  text,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.bodyMedium?.copyWith(height: 1.35),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _RecentRow extends StatelessWidget {
  const _RecentRow({super.key, required this.row, required this.onTap});

  final AiConversationRow row;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    return InkWell(
      borderRadius: BorderRadius.circular(14),
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 10),
        child: Row(
          children: <Widget>[
            FaIcon(
              row.pinned
                  ? FontAwesomeIcons.thumbtack
                  : FontAwesomeIcons.comments,
              size: 14,
              color: colors.primary,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                row.title.trim().isEmpty ? l10n.aiChatUntitled : row.title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.bodyLarge,
              ),
            ),
            const SizedBox(width: 8),
            Text(
              aiConversationTime(l10n, row.updatedAt),
              style: theme.textTheme.labelSmall?.copyWith(
                color: colors.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
