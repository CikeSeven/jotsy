import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/database/app_database.dart';
import '../../../core/services/app_service.dart';

/// AI 记录的读取（实时查询）。AI 表不参与局域网同步，这些流也不必加进
/// `syncedDataRefreshProvider` 的失效清单。

/// 对话与结果的总条数（隐私页“清除全部 AI 记录”）。
final aiRecordCountProvider = StreamProvider<int>((Ref ref) {
  return ref.watch(appDatabaseProvider).watchAiRecordCount();
});

/// 对话列表；参数为检索词（空串为全部）。
final aiConversationsProvider =
    StreamProvider.family<List<AiConversationRow>, String>((
      Ref ref,
      String query,
    ) {
      return ref.watch(appDatabaseProvider).watchAiConversations(query: query);
    });

/// 一次对话。
final aiConversationProvider =
    StreamProvider.family<AiConversationRow?, String>((
      Ref ref,
      String conversationId,
    ) {
      return ref.watch(appDatabaseProvider).watchAiConversation(conversationId);
    });

/// 一次对话的消息。
final aiMessagesProvider = StreamProvider.family<List<AiMessageRow>, String>((
  Ref ref,
  String conversationId,
) {
  return ref.watch(appDatabaseProvider).watchAiMessages(conversationId);
});

/// 某篇日记的读后回应。
final aiRepliesProvider = StreamProvider.family<List<AiResultRow>, String>((
  Ref ref,
  String diaryId,
) {
  return ref.watch(appDatabaseProvider).watchAiRepliesForDiary(diaryId);
});

/// 最近的回顾（新 → 旧）。
final aiRecapsProvider = StreamProvider<List<AiResultRow>>((Ref ref) {
  return ref.watch(appDatabaseProvider).watchAiRecaps();
});

/// 一份结果（回顾详情页）。
final aiResultProvider = StreamProvider.family<AiResultRow?, String>((
  Ref ref,
  String resultId,
) {
  return ref.watch(appDatabaseProvider).watchAiResult(resultId);
});
