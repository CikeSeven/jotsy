/// 预览页留言的写入流程：写、改、复制、删除（可撤销）。
///
/// 职责边界：输入为日记与留言行，读写经 [appDatabaseProvider]，反馈一律经
/// [HomeHintVisibilityScope.showTrackedSnackBar]（带撤销的提示
/// `persist: false`）；面板只负责挑选内容（`showDiaryCommentSheet`），不构建
/// 页面 UI。留言区由数据库流驱动，写入后自动刷新。
///
/// 数据库在打开面板之前取得：面板期间预览页可能被翻走或关闭，之后不再用
/// [WidgetRef]；每次 await 之后检查 `context.mounted` 再提示。
library;

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/database/app_database.dart';
import '../../../core/services/app_service.dart';
import '../../../l10n/app_localizations.dart';
import '../../home/widgets/home_hint_visibility_scope.dart';
import '../providers/diary_card_style_provider.dart';
import '../viewmodels/diary_comment_timeline.dart';
import '../widgets/diary_comments/diary_comment_sheet.dart';

/// 撤销提示的时长，与日记页、归档页一致。
const Duration _undoDuration = Duration(seconds: 4);
const Duration _hintDuration = Duration(seconds: 2);

/// 给 [diary] 写一条留言：打开面板，保存后写库并轻震（动作生效，DESIGN
/// §4.3）。返回是否写下了；取消或失败为 false（失败时提示）。
Future<bool> writeDiaryComment(
  BuildContext context,
  WidgetRef ref, {
  required Diary diary,
}) async {
  final l10n = context.l10n;
  final db = ref.read(appDatabaseProvider);
  final relative = diaryCommentRelativeLabel(
    l10n,
    diary.createdAt,
    DateTime.now(),
  );
  final draft = await showDiaryCommentSheet(
    context,
    title: '${l10n.diaryCommentSheetNew} · $relative',
    moodOptions: ref.read(diaryCardMoodOptionsProvider),
  );
  if (draft == null) return false;
  try {
    await db.addDiaryComment(
      diaryId: diary.diaryId,
      content: draft.content,
      mood: draft.mood,
    );
  } catch (_) {
    if (context.mounted) await _showHint(context, l10n.diaryCommentSaveFailed);
    return false;
  }
  unawaited(HapticFeedback.lightImpact());
  return true;
}

/// 编辑一条留言：面板里带入原来的文字与心情，有改动才写库（记下编辑时间）。
Future<void> editDiaryComment(
  BuildContext context,
  WidgetRef ref, {
  required DiaryCommentRow comment,
}) async {
  final l10n = context.l10n;
  final db = ref.read(appDatabaseProvider);
  final draft = await showDiaryCommentSheet(
    context,
    title: l10n.diaryCommentSheetEdit,
    moodOptions: ref.read(diaryCardMoodOptionsProvider),
    initial: comment,
  );
  if (draft == null) return;
  try {
    final changed = await db.updateDiaryComment(
      comment.commentId,
      content: draft.content,
      mood: draft.mood,
    );
    if (changed) unawaited(HapticFeedback.lightImpact());
  } catch (_) {
    if (context.mounted) await _showHint(context, l10n.diaryCommentSaveFailed);
  }
}

/// 把留言文字复制到剪贴板并提示。
Future<void> copyDiaryComment(
  BuildContext context,
  DiaryCommentRow comment,
) async {
  final message = context.l10n.diaryCommentCopied;
  await Clipboard.setData(ClipboardData(text: comment.content));
  if (context.mounted) await _showHint(context, message);
}

/// 删除一条留言，提示里可撤销（原样写回，包括写下与编辑时间）。
Future<void> deleteDiaryComment(
  BuildContext context,
  WidgetRef ref, {
  required DiaryCommentRow comment,
}) async {
  final db = ref.read(appDatabaseProvider);
  final message = context.l10n.diaryCommentDeleted;
  final removed = await db.deleteDiaryComment(comment.commentId);
  if (removed == null || !context.mounted) return;
  if (await _showUndo(context, message)) {
    await db.restoreDiaryComment(removed);
  }
}

Future<void> _showHint(BuildContext context, String message) =>
    HomeHintVisibilityScope.showTrackedSnackBar(
      context: context,
      snackBar: SnackBar(content: Text(message), duration: _hintDuration),
    );

/// 带撤销按钮的提示；返回用户是否点了撤销。`persist: false` 让它到时关闭。
Future<bool> _showUndo(BuildContext context, String message) async {
  var undoRequested = false;
  final reason = await HomeHintVisibilityScope.showTrackedSnackBar(
    context: context,
    snackBar: SnackBar(
      content: Text(message),
      duration: _undoDuration,
      persist: false,
      action: SnackBarAction(
        label: context.l10n.commonUndo,
        onPressed: () => undoRequested = true,
      ),
    ),
  );
  return undoRequested || reason == SnackBarClosedReason.action;
}
