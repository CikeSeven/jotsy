// 撤销智能体做过的改动（对话页回答里的“撤销”与“撤销本轮全部改动”）。
//
// - 从后往前撤（后做的改动可能依赖先做的）；
// - 每个调用交回产生它的工具（`AiTool.undo`）；工具发现数据在那之后又被
//   别处改过时抛 `AiUndoConflict`，这里问用户要不要覆盖，同意后这一批都
//   强制撤销；
// - 每撤完一个就把“已撤销”写回这条回答的步骤记录（中途失败也不丢已撤的）；
// - 结果用提示条告知。

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/database/app_database.dart';
import '../../../core/services/app_service.dart';
import '../../../l10n/app_localizations.dart';
import '../../home/widgets/home_hint_visibility_scope.dart';
import '../models/ai_agent_steps.dart';
import '../tools/ai_tool.dart';
import '../tools/ai_tool_registry.dart';
import '../widgets/ai_dialogs.dart';

/// 撤销 [message] 里 [callIds] 这些调用（没给时撤销全部可撤销的）。
Future<void> undoAiAgentCalls(
  BuildContext context,
  WidgetRef ref,
  AiMessageRow message, {
  Set<String>? callIds,
}) async {
  final l10n = context.l10n;
  final container = ProviderScope.containerOf(context, listen: false);
  final database = ref.read(appDatabaseProvider);
  var steps = AiAgentStepRecord.decodeList(message.steps);
  final targets = <AiAgentCallRecord>[
    for (final step in steps.reversed)
      for (final call in step.calls.reversed)
        if (call.canUndo && (callIds == null || callIds.contains(call.id)))
          call,
  ];
  if (targets.isEmpty) return;
  var force = false;
  var undone = 0;
  String? failure;
  for (final call in targets) {
    final tool = aiToolByName(call.tool);
    if (tool == null) continue;
    try {
      try {
        await tool.undo(container, call.undo!, force: force);
      } on AiUndoConflict {
        if (!context.mounted) return;
        final overwrite = await confirmAiAction(
          context,
          title: l10n.aiAgentUndoConflictTitle,
          content: l10n.aiAgentUndoConflictBody,
          action: l10n.aiAgentUndoConflictAction,
          destructive: true,
        );
        if (!overwrite) break;
        force = true;
        await tool.undo(container, call.undo!, force: true);
      }
    } catch (error) {
      failure = '$error';
      break;
    }
    undone++;
    // withCall 只替换同 id 的那个调用，其余步骤原样。
    steps = [
      for (final step in steps) step.withCall(call.copyWith(undone: true)),
    ];
    await database.updateAiMessage(
      message.messageId,
      stepsJson: AiAgentStepRecord.encodeList(steps),
    );
  }
  if (!context.mounted) return;
  final text = failure != null
      ? l10n.aiAgentUndoFailed(failure)
      : undone > 0
      ? l10n.aiAgentUndone(undone)
      : null;
  if (text == null) return;
  await HomeHintVisibilityScope.showTrackedSnackBar(
    context: context,
    snackBar: SnackBar(content: Text(text)),
  );
}
