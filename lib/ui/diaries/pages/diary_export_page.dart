import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:intl/intl.dart';
import 'package:node_diary/l10n/app_localizations.dart';

import '../../../app/theme/app_spacing.dart';
import '../../../core/database/app_database.dart';
import '../../../core/services/app_service.dart';
import '../../home/widgets/home_hint_visibility_scope.dart';
import '../../widgets/app_top_bar.dart';
import '../../widgets/delayed_loading_indicator.dart';
import '../../widgets/expressive_choice_tile.dart';
import '../controllers/diary_export_flow.dart';
import '../models/diary_export_scope.dart';
import '../providers/diary_export_provider.dart';
import '../widgets/diary_sheet_controls.dart';

/// 设置 → 数据管理 → 导出日记：按日期范围与标签选出日记，再进入共用的
/// 导出面板选择格式。
///
/// 页面只做装配：候选来自 [diaryExportCandidatesProvider]，筛选规则在
/// [DiaryExportScope]，导出流程在 [runDiaryExportFlow]。筛选条件是本页的
/// 临时状态，不持久化（下次多半是另一段日期）。
class DiaryExportPage extends ConsumerStatefulWidget {
  const DiaryExportPage({super.key});

  @override
  ConsumerState<DiaryExportPage> createState() => _DiaryExportPageState();
}

class _DiaryExportPageState extends ConsumerState<DiaryExportPage> {
  DiaryExportScope _scope = const DiaryExportScope();

  Future<void> _selectRange(DiaryExportRange range) async {
    if (range != DiaryExportRange.custom) {
      setState(() => _scope = _scope.copyWith(range: range));
      return;
    }
    final now = DateTime.now();
    final picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(1970),
      lastDate: DateTime(now.year + 1, 12, 31),
      initialDateRange:
          _scope.customRange ??
          DateTimeRange(
            start: DateTime(now.year, now.month),
            end: DateTime(now.year, now.month, now.day),
          ),
    );
    // 取消选择时保持原来的范围，不切到一个空的“自定义”。
    if (!mounted || picked == null) {
      return;
    }
    setState(
      () => _scope = _scope.copyWith(
        range: DiaryExportRange.custom,
        customRange: picked,
      ),
    );
  }

  void _toggleTag(int tagId, bool selected) {
    final next = Set<int>.of(_scope.tagIds);
    selected ? next.add(tagId) : next.remove(tagId);
    setState(() => _scope = _scope.copyWith(tagIds: next));
  }

  void _showHint(String message) {
    unawaited(
      HomeHintVisibilityScope.showTrackedSnackBar(
        context: context,
        snackBar: SnackBar(content: Text(message)),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final candidates = ref.watch(diaryExportCandidatesProvider);
    final tags = ref.watch(tagListProvider).value ?? const <Tag>[];
    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.surface,
      appBar: AppTopBar(
        leading: IconButton(
          tooltip: l10n.commonBack,
          onPressed: () => Navigator.of(context).maybePop(),
          icon: const FaIcon(FontAwesomeIcons.angleLeft, size: 18),
        ),
        title: Text(l10n.diaryExportPageTitle),
      ),
      body: candidates.when(
        loading: () => const DelayedLoadingIndicator(),
        error: (Object error, StackTrace _) =>
            Center(child: Text(l10n.previewExportFailed('$error'))),
        data: (List<DiaryWithTags> diaries) {
          final matched = _scope.apply(diaries, DateTime.now());
          return Column(
            children: <Widget>[
              Expanded(child: _buildScope(l10n, tags)),
              _buildFooter(l10n, matched),
            ],
          );
        },
      ),
    );
  }

  Widget _buildScope(AppLocalizations l10n, List<Tag> tags) {
    final theme = Theme.of(context);
    final dateFormat = DateFormat.yMMMd(l10n.localeName);
    final custom = _scope.customRange;
    return ListView(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.l,
        AppSpacing.m,
        AppSpacing.l,
        AppSpacing.l,
      ),
      children: <Widget>[
        DiarySheetSectionHeader(
          icon: FontAwesomeIcons.calendarDays,
          label: l10n.diaryExportRangeSection,
        ),
        const SizedBox(height: AppSpacing.xs),
        for (final (range, label) in <(DiaryExportRange, String)>[
          (DiaryExportRange.all, l10n.diaryExportRangeAll),
          (DiaryExportRange.thisYear, l10n.diaryExportRangeThisYear),
          (DiaryExportRange.last30Days, l10n.diaryExportRangeLast30Days),
          (DiaryExportRange.custom, l10n.diaryExportRangeCustom),
        ])
          ExpressiveChoiceTile(
            label: label,
            description: range == DiaryExportRange.custom && custom != null
                ? l10n.diaryExportRangeCustomValue(
                    dateFormat.format(custom.start),
                    dateFormat.format(custom.end),
                  )
                : null,
            selected: _scope.range == range,
            onTap: () => unawaited(_selectRange(range)),
          ),
        if (tags.isNotEmpty) ...<Widget>[
          const SizedBox(height: AppSpacing.l),
          DiarySheetSectionHeader(
            icon: FontAwesomeIcons.tags,
            label: l10n.diaryExportTagsSection,
          ),
          const SizedBox(height: AppSpacing.s),
          Wrap(
            spacing: AppSpacing.s,
            runSpacing: AppSpacing.s,
            children: <Widget>[
              for (final tag in tags)
                FilterChip(
                  label: Text('# ${tag.name}'),
                  selected: _scope.tagIds.contains(tag.id),
                  onSelected: (bool selected) => _toggleTag(tag.id, selected),
                ),
            ],
          ),
          const SizedBox(height: AppSpacing.s),
          Text(
            l10n.diaryExportTagsHint,
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ],
        const SizedBox(height: AppSpacing.m),
        DiarySheetSwitch(
          label: l10n.diaryExportIncludeArchived,
          value: _scope.includeArchived,
          onChanged: (bool value) =>
              setState(() => _scope = _scope.copyWith(includeArchived: value)),
        ),
      ],
    );
  }

  Widget _buildFooter(AppLocalizations l10n, List<DiaryWithTags> matched) {
    final theme = Theme.of(context);
    return SafeArea(
      top: false,
      child: Padding(
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
            Text(
              l10n.diaryExportMatchCount(matched.length),
              style: theme.textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: AppSpacing.xs),
            Text(
              l10n.diaryExportCapsuleNote,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: AppSpacing.m),
            FilledButton.icon(
              onPressed: matched.isEmpty
                  ? null
                  : () => unawaited(
                      runDiaryExportFlow(
                        context,
                        ref,
                        diaries: matched,
                        showHint: _showHint,
                      ),
                    ),
              icon: const FaIcon(FontAwesomeIcons.fileExport, size: 16),
              label: Text(l10n.diaryExportNext),
            ),
          ],
        ),
      ),
    );
  }
}
