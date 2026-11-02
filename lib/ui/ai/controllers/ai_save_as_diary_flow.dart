// 把 AI 写的文字另存为日记（回顾与对话共用）、复制与分享。
//
// 另存为日记不直接写日记表：先按草稿箱同一格式写一份草稿（`NewDiaryDraft`，
// 正文为 Markdown 转成的块文档），再像草稿箱那样推入新建编辑页
// （`EditDiaryPage(createDraftId:)`）。用户可以改完再发表，不想要直接返回
// 就留在草稿箱里，与其他新建入口同一口径（AGENTS.md 草稿规则）。
//
// 引用编号 `[Dn]` 离开这次回答就没有意义，复制、分享与另存时一律去掉。

import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:share_plus/share_plus.dart';

import '../../../core/database/app_database.dart';
import '../../../core/database/diary_blocks/diary_blocks_codec.dart';
import '../../../core/services/app_platform.dart';
import '../../../core/services/app_service.dart';
import '../../../l10n/app_localizations.dart';
import '../../diaries/controllers/diary_ai_editing.dart';
import '../../diaries/models/new_diary_draft.dart';
import '../../diaries/pages/edit_diary_page.dart';
import '../../home/widgets/home_hint_visibility_scope.dart';
import '../../settings/providers/app_features_provider.dart';
import '../viewmodels/ai_citations.dart';

/// 另存为日记：写一份草稿并打开新建编辑页。[notebookId] 给出、日记本功能
/// 开着且那本仍是可收录的手动本时，预先勾选它。
Future<void> saveAiTextAsDiary(
  BuildContext context,
  WidgetRef ref, {
  required String title,
  required String markdown,
  String? notebookId,
}) async {
  final database = ref.read(appDatabaseProvider);
  final text = aiStripCitations(markdown);
  final document = <String, Object?>{
    'document': <String, Object?>{
      'type': 'page',
      'children': [
        for (final node in diaryAiMarkdownNodes(text)) node.toJson(),
      ],
    },
  };
  var notebooks = const <String>[];
  if (notebookId != null && ref.read(appFeaturesProvider).notebooks) {
    final row = await database.getNotebook(notebookId);
    if (row != null && row.acceptsManualEntries) notebooks = [notebookId];
  }
  final draft = NewDiaryDraft(
    title: title,
    contentDocJson: jsonEncode(document),
    contentText: diaryBlocksPlainText(document),
    notebookIds: notebooks,
  ).toSnapshot();
  final draftId = await database.saveDiaryDraft(
    title: draft.title,
    contentText: draft.contentText,
    payload: draft.payload,
  );
  if (!context.mounted) return;
  await Navigator.of(context).push<Object?>(
    MaterialPageRoute<Object?>(
      builder: (_) => EditDiaryPage(
        entryMode: EditDiaryEntryMode.create,
        createDraftId: draftId,
      ),
    ),
  );
}

/// 复制（去掉引用编号）。
Future<void> copyAiText(BuildContext context, String markdown) async {
  await Clipboard.setData(ClipboardData(text: aiStripCitations(markdown)));
  if (context.mounted) _hint(context, context.l10n.aiPanelCopied);
}

/// 分享文字：有系统分享面板时交给它，没有（Linux）时改为复制并提示。
Future<void> shareAiText(BuildContext context, String markdown) async {
  final text = aiStripCitations(markdown).trim();
  if (text.isEmpty) return;
  if (!AppPlatform.supportsSystemFileShare) {
    await Clipboard.setData(ClipboardData(text: text));
    if (context.mounted) _hint(context, context.l10n.aiRecapShareUnavailable);
    return;
  }
  await Share.share(text);
}

void _hint(BuildContext context, String message) {
  unawaited(
    HomeHintVisibilityScope.showTrackedSnackBar(
      context: context,
      snackBar: SnackBar(content: Text(message)),
    ),
  );
}
