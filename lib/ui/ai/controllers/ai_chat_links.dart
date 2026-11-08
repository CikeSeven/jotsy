// 对话页里“点了就打开”的几种东西：前往卡片、对象胶囊与正文引用。都经现有
// 的统一入口打开（`AiDestination.open`、`openDiaryLinkTarget`、
// `openDiaryTagSearch`、`openTodoDetail`、`openAnniversaryList`），不另拼路由。
//
// 会关掉对话页的目标（`AiDestination.leavesChat`：首页的 Tab、日记本范围）
// 打开前先登记“回到对话”，打开后对话页还在栈里（例如上锁的日记本没验证
// 通过）就撤销登记——看的是路由还在不在，退场动画期间页面仍是 mounted。

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/database/diary_blocks/diary_link_target.dart';
import '../../../core/services/app_service.dart';
import '../../../l10n/app_localizations.dart';
import '../../anniversaries/controllers/anniversary_navigation.dart';
import '../../diaries/controllers/diary_link_open_flow.dart';
import '../../diaries/controllers/diary_tag_search_flow.dart';
import '../../home/widgets/home_hint_visibility_scope.dart';
import '../../settings/providers/app_features_provider.dart';
import '../../todos/controllers/todo_navigation.dart';
import '../models/ai_tool_subject.dart';
import '../providers/ai_chat_return_provider.dart';
import '../providers/ai_providers.dart';
import '../tools/ai_destinations.dart';
import '../tools/ai_tool.dart';
import '../viewmodels/ai_task_prompts.dart';

/// 正文引用 `[Dn]` 指向的那篇日记（与对象胶囊同一开法）。
AiToolSubject aiCitationSubject(AiCitation citation) => AiToolSubject.diary(
  citation.diaryId,
  title: citation.title.trim(),
  date: citation.date,
);

/// 打开一个“前往”目标；功能已关闭（或换了平台）时只提示不可用。
/// [conversationId] 为当前对话（离开对话的目标据此登记“回到对话”）。
Future<void> openAiNavigation(
  BuildContext context,
  WidgetRef ref,
  AiToolNavigation navigation, {
  required String? conversationId,
}) async {
  final destination = aiDestinationById(navigation.destination);
  final env = AiToolEnv(
    features: ref.read(appFeaturesProvider),
    prefs: ref.read(aiPreferencesProvider),
  );
  if (destination == null || !destination.isAvailable(env)) {
    await HomeHintVisibilityScope.showTrackedSnackBar(
      context: context,
      snackBar: SnackBar(content: Text(context.l10n.aiToolPageUnavailable)),
    );
    return;
  }
  final returns = ref.read(aiChatReturnProvider.notifier);
  final route = ModalRoute.of(context);
  final leaves = destination.leavesChat && conversationId != null;
  if (leaves) returns.arm(conversationId);
  await destination.open(context, ref, navigation.params);
  if (leaves && (route?.isActive ?? false)) returns.disarm();
}

/// 打开一个对象胶囊：日记打开预览，日记本与前往卡片同一开法，标签按标签
/// 搜索，待办打开详情，纪念日打开列表；某一天不可点。
Future<void> openAiSubject(
  BuildContext context,
  WidgetRef ref,
  AiToolSubject subject, {
  required String? conversationId,
}) async {
  switch (subject.kind) {
    case AiSubjectKind.diary:
      await openDiaryLinkTarget(
        context,
        ref,
        DiaryLinkTarget.diary(subject.id),
      );
    case AiSubjectKind.notebook:
      await openAiNavigation(
        context,
        ref,
        AiToolNavigation(
          destination: 'notebook',
          params: <String, Object?>{'notebook_id': subject.id},
        ),
        conversationId: conversationId,
      );
    case AiSubjectKind.tag:
      final tags = await ref.read(appDatabaseProvider).watchAllTags().first;
      final tag = tags.where((tag) => tag.name == subject.id).firstOrNull;
      if (tag == null || !context.mounted) return;
      await openDiaryTagSearch(context, tag.id);
    case AiSubjectKind.todo:
      await openTodoDetail(context, subject.id);
    case AiSubjectKind.anniversary:
      await openAnniversaryList(context);
    case AiSubjectKind.day:
      return;
  }
}
