// 导出对话的三种去处：保存到文件、系统分享、复制。
//
// 文件先写到缓存目录 `ai_chat_export/`（每次导出前清掉上次的暂存）：保存
// 经 `BackupFileSaveService.saveFile`（手机为系统“另存为”，只传路径；桌面为
// 保存对话框），保存完删掉暂存；分享交给系统分享面板，暂存留到下次导出
// 再清（分享面板读文件是异步的）。Linux 没有系统文件分享，页面不放分享。
// 结果都用提示条告知。

import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import '../../../core/services/backup_file_save_service.dart';
import '../../../l10n/app_localizations.dart';
import '../../home/widgets/home_hint_visibility_scope.dart';
import '../viewmodels/ai_chat_export.dart';

const String _stagingDirectory = 'ai_chat_export';

Future<File> _stage(String text, String fileName) async {
  final root = Directory(
    p.join((await getTemporaryDirectory()).path, _stagingDirectory),
  );
  if (await root.exists()) {
    try {
      await root.delete(recursive: true);
    } on FileSystemException {
      // 清不掉上次的暂存不影响这次导出。
    }
  }
  final file = File(
    p.join(root.path, '${DateTime.now().microsecondsSinceEpoch}', fileName),
  );
  await file.create(recursive: true);
  await file.writeAsString(text, flush: true);
  return file;
}

void _hint(BuildContext context, String message) {
  HomeHintVisibilityScope.showTrackedSnackBar(
    context: context,
    snackBar: SnackBar(content: Text(message)),
  );
}

/// 保存到文件（取消时什么都不提示）。
Future<void> saveAiChatExport(
  BuildContext context, {
  required String text,
  required String fileName,
  required AiChatExportFormat format,
}) async {
  final l10n = context.l10n;
  File? file;
  try {
    file = await _stage(text, fileName);
    final saved = await BackupFileSaveService.saveFile(
      file: file,
      fileName: fileName,
      dialogTitle: l10n.aiChatExport,
      mimeType: format.mimeType,
      extension: format.extension,
    );
    if (!context.mounted) return;
    if (saved != null && saved.trim().isNotEmpty) {
      _hint(context, l10n.aiChatExportSaved);
    }
  } catch (error) {
    debugPrint('AI chat export failed: $error');
    if (context.mounted) _hint(context, l10n.aiChatExportFailed);
  } finally {
    final parent = file?.parent;
    if (parent != null) {
      try {
        await parent.delete(recursive: true);
      } on FileSystemException {
        // 系统会回收缓存目录。
      }
    }
  }
}

/// 交给系统分享面板（以文件分享，聊天应用里收到的是一份文档）。
Future<void> shareAiChatExport(
  BuildContext context, {
  required String text,
  required String fileName,
  required AiChatExportFormat format,
}) async {
  try {
    final file = await _stage(text, fileName);
    await Share.shareXFiles(<XFile>[
      XFile(file.path, mimeType: format.mimeType),
    ]);
  } catch (error) {
    debugPrint('AI chat export share failed: $error');
    if (context.mounted) _hint(context, context.l10n.aiChatExportFailed);
  }
}

/// 复制全部导出内容。
Future<void> copyAiChatExport(BuildContext context, String text) async {
  await Clipboard.setData(ClipboardData(text: text));
  if (context.mounted) _hint(context, context.l10n.aiPanelCopied);
}
