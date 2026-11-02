import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:node_diary/l10n/app_localizations.dart';

import '../../ai/models/ai_preference_parts.dart';
import '../../ai/models/ai_recap_range.dart';
import '../../ai/pages/ai_recap_page.dart';
import '../../ai/providers/ai_providers.dart';
import '../../ai/providers/ai_records_providers.dart';
import '../../ai/viewmodels/ai_labels.dart';
import '../controllers/explore_module_actions.dart';
import '../widgets/explore_shared_widgets.dart';

/// AI 洞察：最近一次回顾的摘录（点按打开），下面是“生成本周回顾”与
/// “问问我的日记”（各自的模块关闭时不出现）。
///
/// 渲染时不联网，只读已保存的回顾（[aiRecapsProvider]）；生成经回顾页
/// （进入即生成，仍经发送前确认）。AI 开关关闭时整张不显示（见
/// ExploreModuleSpec）；开着但还没配好服务时提示去设置。回顾模块关闭时
/// 不给“生成”按钮，已有的回顾照常显示。
class ExploreAiInsightCard extends ConsumerWidget {
  const ExploreAiInsightCard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final actions = ExploreActionsScope.of(context);
    final available = ref.watch(aiAvailableProvider);
    final recapOn = ref.watch(aiModuleAvailableProvider(AiModule.recap));
    final chatOn = ref.watch(aiModuleAvailableProvider(AiModule.chat));
    final recaps = ref.watch(aiRecapsProvider).value;
    final latest = recaps == null || recaps.isEmpty ? null : recaps.first;
    final children = <Widget>[
      ExploreCardHeader(
        icon: FontAwesomeIcons.wandMagicSparkles,
        title: l10n.exploreModuleAi,
      ),
    ];
    if (!available) {
      children.add(
        ExploreInlineHint(
          message: l10n.aiExploreNotConfigured,
          actionLabel: l10n.aiErrorOpenSettings,
          onAction: actions.openAiSettings,
        ),
      );
    } else {
      if (latest != null) {
        final decoded = AiRecapScope.decode(latest.scope);
        final preset = decoded.preset;
        final heading = [
          if (preset != null && preset != AiRecapPreset.custom)
            aiRecapPresetLabel(l10n, preset),
          latest.title,
          ?decoded.scope.notebookName,
        ].where((part) => part.trim().isNotEmpty).join(' · ');
        children.add(
          InkWell(
            borderRadius: BorderRadius.circular(12),
            onTap: () => actions.openAiRecap(resultId: latest.resultId),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 6),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(
                    heading,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.labelMedium?.copyWith(
                      color: colors.primary,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    aiRecapExcerpt(latest.content, max: 160),
                    maxLines: 4,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.bodyMedium?.copyWith(height: 1.5),
                  ),
                ],
              ),
            ),
          ),
        );
      } else if (recaps != null) {
        children.add(ExploreInlineHint(message: l10n.aiExploreNoRecap));
      }
      if (recapOn || chatOn) {
        children.add(
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Wrap(
              spacing: 4,
              runSpacing: 4,
              children: <Widget>[
                if (recapOn)
                  TextButton.icon(
                    onPressed: () => actions.openAiRecap(weekly: true),
                    icon: const FaIcon(FontAwesomeIcons.calendarWeek, size: 14),
                    label: Text(l10n.aiExploreWeekly),
                  ),
                if (chatOn)
                  TextButton.icon(
                    onPressed: actions.openAiHub,
                    icon: const FaIcon(FontAwesomeIcons.comments, size: 14),
                    label: Text(l10n.aiExploreAsk),
                  ),
              ],
            ),
          ),
        );
      }
    }
    return ExploreCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: children,
      ),
    );
  }
}
