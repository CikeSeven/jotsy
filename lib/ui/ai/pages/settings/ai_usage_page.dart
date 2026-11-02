import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:intl/intl.dart';

import '../../../../core/services/ai/ai_usage_ledger.dart';
import '../../../../l10n/app_localizations.dart';
import '../../../settings/widgets/settings_card_group.dart';
import '../../providers/ai_providers.dart';
import '../../viewmodels/ai_labels.dart';
import '../../widgets/ai_dialogs.dart';
import '../../widgets/ai_page_scaffold.dart';

/// 设置 → AI 助手 → 用量：按月份（新 → 旧）列出各模型的请求数、失败数与
/// token，每行一条与当月最大值成比例的横条。只统计本机发出的请求。
class AiUsagePage extends ConsumerWidget {
  const AiUsagePage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final ledger = ref.watch(aiUsageProvider);
    final months = ledger.monthKeys;

    Future<void> clear() async {
      final confirmed = await confirmAiAction(
        context,
        title: l10n.aiUsageClearTitle,
        content: l10n.aiUsageClearBody,
        action: l10n.aiUsageClear,
        destructive: true,
      );
      if (!confirmed) return;
      final store = await ref.read(aiProviderStoreProvider.future);
      await store.clearUsage();
    }

    return AiPageScaffold(
      title: l10n.aiUsageTitle,
      actions: <Widget>[
        if (months.isNotEmpty)
          IconButton(
            tooltip: l10n.aiUsageClear,
            onPressed: clear,
            icon: const FaIcon(FontAwesomeIcons.trashCan, size: 16),
          ),
      ],
      children: <Widget>[
        if (months.isEmpty)
          Padding(
            padding: const EdgeInsets.all(48),
            child: Text(
              l10n.aiUsageEmpty,
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: colors.onSurfaceVariant,
              ),
            ),
          ),
        for (final month in months) ...<Widget>[
          _MonthGroup(month: month, entries: ledger.entriesOf(month)),
          const SizedBox(height: 16),
        ],
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 28),
          child: Text(
            l10n.aiUsageFooter,
            style: theme.textTheme.bodySmall?.copyWith(
              color: colors.onSurfaceVariant,
            ),
          ),
        ),
      ],
    );
  }
}

class _MonthGroup extends StatelessWidget {
  const _MonthGroup({required this.month, required this.entries});

  final String month;
  final List<AiUsageEntry> entries;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final parts = month.split('-');
    final date = DateTime(int.parse(parts[0]), int.parse(parts[1]));
    final title = DateFormat.yMMMM(l10n.localeName).format(date);
    final total = entries.fold<int>(0, (sum, e) => sum + e.totalTokens);
    final maxTokens = entries.fold<int>(
      1,
      (max, e) => e.totalTokens > max ? e.totalTokens : max,
    );
    return SettingsCardGroup(
      title: '$title · ${l10n.aiUsageMonthTotal(aiCompactCount(total))}',
      children: <Widget>[
        for (final entry in entries)
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  entry.model,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
                Text(
                  [
                    entry.providerName,
                    l10n.aiUsageRequests(entry.requests),
                    if (entry.failures > 0)
                      l10n.aiUsageFailures(entry.failures),
                  ].join(' · '),
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: colors.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: 8),
                ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: LinearProgressIndicator(
                    value: entry.totalTokens / maxTokens,
                    minHeight: 6,
                    backgroundColor: colors.primary.withValues(alpha: 0.12),
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  l10n.aiUsageTokens(
                    aiCompactCount(entry.inputTokens),
                    aiCompactCount(entry.outputTokens),
                  ),
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: colors.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }
}
