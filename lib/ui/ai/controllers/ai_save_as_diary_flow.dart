// 把 AI 写的文字另存为日记（回顾与对话共用）、复制与分享。
//
// 另存为日记不直接写日记表：带着内容（正文为 Markdown 转成的块文档）推入
// 新建编辑页（`EditDiaryPage(createSeed:)`），像套用模板一样填好。用户改过再
// 返回才进草稿箱（与其他新建入口同一口径）；原样未动直接返回什么都不留，
// 开着“返回时直接发表”也不会发表。
//
// 引用编号 `[Dn]` 离开这次回答就没有意义，复制、分享与另存时一律去掉。

import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:share_plus/share_plus.dart';

import '../../../core/database/app_database.dart';
import '../../../core/services/app_platform.dart';
import '../../../core/services/app_service.dart';
import '../../../l10n/app_localizations.dart';
import '../../diaries/controllers/diary_ai_editing.dart';
import '../../diaries/models/edit_diary_create_seed.dart';
import '../../diaries/pages/edit_diary_page.dart';
import '../../home/widgets/home_hint_visibility_scope.dart';
import '../../settings/providers/app_features_provider.dart';
import '../viewmodels/ai_citations.dart';

/// AI 输出的 Markdown 转成正文的块文档（去掉 `[Dn]` 引用；与粘贴 Markdown
/// 同一转换）。“另存为日记”与 AI 助手新建、追加日记共用。
Map<String, Object?> aiMarkdownDiaryDocument(String markdown) =>
    <String, Object?>{
      'document': <String, Object?>{
        'type': 'page',
        'children': [
          for (final node in diaryAiMarkdownNodes(aiStripCitations(markdown)))
            node.toJson(),
        ],
      },
    };

/// 另存为日记：带着内容打开新建编辑页。[notebookId] 给出、日记本功能开着且
/// 那本仍是可收录的手动本时，预先收进它。
Future<void> saveAiTextAsDiary(
  BuildContext context,
  WidgetRef ref, {
  required String title,
  required String markdown,
  String? notebookId,
}) async {
  final database = ref.read(appDatabaseProvider);
  final document = aiMarkdownDiaryDocument(markdown);
  String? notebook;
  if (notebookId != null && ref.read(appFeaturesProvider).notebooks) {
    final row = await database.getNotebook(notebookId);
    if (row != null && row.acceptsManualEntries) notebook = notebookId;
  }
  if (!context.mounted) return;
  await Navigator.of(context).push<Object?>(
    MaterialPageRoute<Object?>(
      builder: (_) => EditDiaryPage(
        entryMode: EditDiaryEntryMode.create,
        createSeed: EditDiaryCreateSeed(
          title: title,
          contentDocJson: jsonEncode(document),
        ),
        createNotebookId: notebook,
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
