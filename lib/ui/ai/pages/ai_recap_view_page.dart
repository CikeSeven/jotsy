// 已保存的一份回顾：标题为预设名（自定义范围时为日期）与日记本，正文与
// 生成时一样（统计胶囊、引用胶囊、人设与模型），可复制、分享、另存为日记
// 与删除（返回上一页并给撤销）。回顾已被删除（例如在别处清除了 AI 记录）
// 时直接返回。

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';

import '../../../core/database/app_database.dart';
import '../../../core/database/diary_blocks/diary_link_target.dart';
import '../../../core/services/app_service.dart';
import '../../../l10n/app_localizations.dart';
import '../../app_surface/models/app_surface_enums.dart';
import '../../diaries/controllers/diary_link_open_flow.dart';
import '../../home/widgets/home_hint_visibility_scope.dart';
import '../controllers/ai_recap_controller.dart';
import '../controllers/ai_save_as_diary_flow.dart';
import '../models/ai_recap_range.dart';
import '../providers/ai_providers.dart';
import '../providers/ai_records_providers.dart';
import '../sections/ai_recap_result_view.dart';
import '../viewmodels/ai_labels.dart';
import '../widgets/ai_dialogs.dart';
import '../widgets/ai_page_scaffold.dart';

class AiRecapViewPage extends ConsumerWidget {
  const AiRecapViewPage({super.key, required this.resultId});

  final String resultId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final async = ref.watch(aiResultProvider(resultId));
    final row = async.value;
    if (async.hasValue && row == null) {
      // 在别处被删掉了：没有可看的内容。
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (context.mounted) Navigator.of(context).maybePop();
      });
    }
    final decoded = row == null ? null : AiRecapScope.decode(row.scope);
    final preset = decoded?.preset;
    final title = row == null
        ? l10n.aiRecapTitle
        : (preset != null && preset != AiRecapPreset.custom
              ? aiRecapPresetLabel(l10n, preset)
              : row.title);
    final meta = row == null ? null : AiRecapMeta.decode(row.meta);
    final showReasoning = ref.watch(aiPreferencesProvider).showReasoning;
    return AiPageScaffold(
      title: title,
      area: AppBackgroundArea.other,
      children: <Widget>[
        if (row != null && meta != null) ...<Widget>[
          Padding(
            padding: const EdgeInsets.fromLTRB(4, 0, 4, 12),
            child: Text(
              [
                row.title,
                ?decoded?.scope.notebookName,
              ].where((part) => part.trim().isNotEmpty).join(' · '),
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
          ),
          AiRecapResultView(
            markdown: row.content,
            stats: meta.stats,
            personaName: meta.personaName,
            personaEmoji: meta.personaEmoji,
            modelName: meta.model,
            reasoning: showReasoning ? meta.reasoning : '',
            onCitation: (String citation) =>
                openAiRecapCitation(context, ref, meta, citation),
            actions: <Widget>[
              AiRecapAction(
                icon: FontAwesomeIcons.copy,
                label: l10n.aiPanelCopy,
                onPressed: () => unawaited(copyAiText(context, row.content)),
              ),
              AiRecapAction(
                icon: FontAwesomeIcons.shareNodes,
                label: l10n.aiRecapShare,
                onPressed: () => unawaited(shareAiText(context, row.content)),
              ),
              AiRecapAction(
                icon: FontAwesomeIcons.filePen,
                label: l10n.aiRecapSaveAsDiary,
                onPressed: () => unawaited(
                  saveAiTextAsDiary(
                    context,
                    ref,
                    title: l10n.aiRecapDiaryTitle(row.title),
                    markdown: row.content,
                    notebookId: ref.read(aiPreferencesProvider).recapNotebookId,
                  ),
                ),
              ),
              AiRecapAction(
                icon: FontAwesomeIcons.trashCan,
                label: l10n.commonDelete,
                destructive: true,
                onPressed: () => unawaited(_delete(context, ref, row)),
              ),
            ],
          ),
        ],
      ],
    );
  }

  Future<void> _delete(
    BuildContext context,
    WidgetRef ref,
    AiResultRow row,
  ) async {
    final l10n = context.l10n;
    final ok = await confirmAiAction(
      context,
      title: l10n.aiRecapDeleteTitle,
      action: l10n.commonDelete,
      destructive: true,
    );
    if (!ok || !context.mounted) return;
    final database = ref.read(appDatabaseProvider);
    final removed = await database.deleteAiResult(row.resultId);
    if (removed == null || !context.mounted) return;
    // 提示条在应用级的 ScaffoldMessenger 上，返回上一页后仍在。
    unawaited(
      HomeHintVisibilityScope.showTrackedSnackBar(
        context: context,
        snackBar: SnackBar(
          persist: false,
          content: Text(l10n.aiRecapDeleted),
          action: SnackBarAction(
            label: l10n.commonUndo,
            onPressed: () => unawaited(database.restoreAiResult(removed)),
          ),
        ),
      ),
    );
    if (context.mounted) Navigator.of(context).maybePop();
  }
}

/// 打开回顾里引用的日记（按保存时的编号快照找日记业务 id）。
void openAiRecapCitation(
  BuildContext context,
  WidgetRef ref,
  AiRecapMeta meta,
  String citation,
) {
  for (final item in meta.citations) {
    if (item.ref == citation) {
      unawaited(
        openDiaryLinkTarget(context, ref, DiaryLinkTarget.diary(item.diaryId)),
      );
      return;
    }
  }
}
