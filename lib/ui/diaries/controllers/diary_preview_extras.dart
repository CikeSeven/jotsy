import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/database/app_database.dart';
import '../../../core/database/diary_blocks/diary_link_target.dart';
import '../../ai/models/ai_preference_parts.dart';
import '../../ai/pages/ai_chat_page.dart';
import '../../ai/providers/ai_providers.dart';
import '../../ai/providers/ai_records_providers.dart';
import '../providers/diary_comments_provider.dart';
import '../providers/diary_link_providers.dart';
import '../widgets/diary_comments/diary_comments_section.dart';
import '../widgets/diary_link/diary_backlinks_section.dart';
import 'diary_comment_flows.dart';

/// 阅读版式正文之后的几块（留言区、提到这篇的日记、AI 回应）的数据与动作。
///
/// 预览页（`DiaryPreviewView`）与阅读式编辑页共用：两处判断显隐的口径一致
/// （功能开关、回收站、私密日记、截长图期间），留言的写 / 改 / 复制 / 删除
/// 都经 `diary_comment_flows.dart`。全部在调用方的 build 里调用（内部
/// `ref.watch`），不持有状态。
abstract final class DiaryPreviewExtras {
  /// 留言区的数据与动作；留言功能关闭、日记在回收站或首次读取还没返回时为
  /// null（不显示留言区）。[suppressed]（截取分享长图期间）同样为 null：
  /// 分享不带留言，但仍然订阅，截完立刻原样回来、不必重新读取。
  ///
  /// [onWrite] 为留言区末尾“写留言…”的动作。
  static DiaryPreviewComments? comments(
    BuildContext context,
    WidgetRef ref, {
    required Diary diary,
    required GlobalKey sectionKey,
    required VoidCallback onWrite,
    bool suppressed = false,
  }) {
    if (!ref.watch(diaryCommentsEnabledProvider) || diary.isDeleted) {
      return null;
    }
    final rows = ref.watch(diaryCommentsProvider(diary.diaryId)).value;
    if (rows == null || suppressed) return null;
    return DiaryPreviewComments(
      diaryCreatedAt: diary.createdAt,
      comments: rows,
      sectionKey: sectionKey,
      actions: DiaryCommentActions(
        onWrite: onWrite,
        onEdit: (comment) =>
            unawaited(editDiaryComment(context, ref, comment: comment)),
        onCopy: (comment) => unawaited(copyDiaryComment(context, comment)),
        onDelete: (comment) =>
            unawaited(deleteDiaryComment(context, ref, comment: comment)),
      ),
    );
  }

  /// “AI 回应”区与阅读式编辑页“更多 → AI 回应”（打开日记时直接编辑时）
  /// 是否出现：AI 可用且回应模块开启、日记不在回收站、私密日记只在用户
  /// 允许时。
  static bool aiReplyAvailable(WidgetRef ref, Diary diary) {
    if (diary.isDeleted) return false;
    if (!ref.watch(aiModuleAvailableProvider(AiModule.reply))) return false;
    if (ref.watch(
      aiPreferencesProvider.select((p) => p.privacy.allowPrivate),
    )) {
      return true;
    }
    final private = ref.watch(aiPrivateDiaryIdsProvider).value;
    return private != null && !private.contains(diary.diaryId);
  }

  /// AI 回应区要显示的日记 id；不显示时为 null（见 [aiReplyAvailable]，
  /// [suppressed] 为截取分享长图期间）。
  static String? aiRepliesFor(
    WidgetRef ref,
    Diary diary, {
    bool suppressed = false,
  }) => aiReplyAvailable(ref, diary) && !suppressed ? diary.diaryId : null;

  /// 回应卡片上的“继续聊聊”：对话模块关闭时为 null。
  static ValueChanged<AiResultRow>? aiContinueChat(
    BuildContext context,
    WidgetRef ref,
  ) => ref.watch(aiModuleAvailableProvider(AiModule.chat))
      ? (AiResultRow reply) => unawaited(
          Navigator.of(context).push<void>(
            MaterialPageRoute<void>(
              builder: (_) => AiChatPage(seedReply: reply),
            ),
          ),
        )
      : null;

  /// “提到这篇的日记”；日记在回收站、[suppressed]（截取分享长图期间）或
  /// 没有日记提到它时为 null（不显示）。
  static DiaryPreviewBacklinks? backlinks(
    WidgetRef ref,
    Diary diary, {
    bool suppressed = false,
  }) {
    if (diary.isDeleted) return null;
    final target = DiaryLinkTarget.diary(diary.diaryId);
    final items = ref.watch(diaryPreviewBacklinksProvider(target)).value;
    if (items == null || items.isEmpty || suppressed) {
      return null;
    }
    return DiaryPreviewBacklinks(target: target, items: items);
  }
}
