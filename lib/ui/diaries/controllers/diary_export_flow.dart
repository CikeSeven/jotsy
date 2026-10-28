import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:node_diary/l10n/app_localizations.dart';

import '../../../core/database/app_database.dart';
import '../../../core/services/app_service.dart';
import '../../widgets/action_loading_overlay.dart';
import '../../widgets/backup_password_dialog.dart';
import '../export/diary_export_book.dart';
import '../export/diary_export_code.dart';
import '../export/diary_export_font.dart';
import '../export/diary_export_format.dart';
import '../providers/diary_code_block_style_provider.dart';
import '../providers/diary_comments_provider.dart';
import '../providers/diary_typography_provider.dart';
import '../sections/diary_export_sheet.dart';
import '../viewmodels/diary_export_messages.dart';
import 'diary_export_controller.dart';

/// 预览页、日记列表多选与“数据管理 → 导出日记”三个入口共用的导出流程。
///
/// 顺序：
/// 1. 读取上次的导出选项，打开导出面板（只负责挑选，改动即保存）；
/// 2. Jotsy 日记文件先询问可选密码，取消即结束；
/// 3. 在全屏等待遮罩下生成文件，遮罩撤下后再交给系统保存或分享——系统
///    对话框不能被遮罩盖住；
/// 4. 按结果提示：已保存 / 已取消 / 跳过的时间胶囊 / 失败原因。分享后
///    用户已在别的应用里，没有跳过的胶囊时不再弹提示。
///
/// 每一步之后检查 [context] 是否仍挂载；提示经调用方的 [showHint] 发出
/// （统一走 `HomeHintVisibilityScope`）。
///
/// 导出成书（日记本头部“导出成书”）时给出 [book]，[diaries] 按书中的先后：
/// 面板不再提供先后顺序、改为“书籍结构”开关（只对能写出结构的格式显示），
/// 控制器按书序导出（见 `DiaryExportController.build`）。
Future<void> runDiaryExportFlow(
  BuildContext context,
  WidgetRef ref, {
  required List<DiaryWithTags> diaries,
  required void Function(String message) showHint,
  DiaryExportBook? book,
  @visibleForTesting
  DiaryExportController Function(AppDatabase)? createController,
}) async {
  final l10n = context.l10n;
  if (diaries.isEmpty) {
    showHint(l10n.diaryExportNothing);
    return;
  }
  final settings = await ref.read(settingsServiceProvider.future);
  if (!context.mounted) {
    return;
  }
  // 留言功能关闭时面板不显示“包含留言”，生成时也不读留言。
  final commentsEnabled = ref.read(diaryCommentsEnabledProvider);
  final request = await showDiaryExportSheet(
    context,
    diaryCount: diaries.length,
    initialOptions: DiaryExportOptions.fromRaw(settings.diaryExportOptionsRaw),
    isBook: book != null,
    commentsEnabled: commentsEnabled,
    // 选项只是下次打开时的默认值，写入失败不打断本次导出。
    onOptionsChanged: (DiaryExportOptions options) => unawaited(
      settings
          .setDiaryExportOptionsRaw(options.toRaw())
          .catchError((Object _) {}),
    ),
  );
  if (request == null || !context.mounted) {
    return;
  }
  final options = request.options;
  String? password;
  if (options.format == DiaryExportFormat.diaryFile) {
    password = await showBackupPasswordDialog(
      context,
      purpose: BackupPasswordPurpose.export,
      confirmLabel: l10n.previewExportDiaryFileConfirm,
    );
    if (password == null || !context.mounted) {
      return;
    }
  }

  final database = ref.read(appDatabaseProvider);
  // 保存本次导出的正文排版快照；字体文件在生成时（等待遮罩下）才读取。
  final typography = ref.read(diaryTypographyProvider);
  final fontStorage = ref.read(diaryFontStorageServiceProvider);
  final controller =
      createController?.call(database) ??
      DiaryExportController(
        database: database,
        loadBodyFont: () => DiaryExportFont.load(typography, fontStorage),
      );
  final labels = buildDiaryExportLabels(l10n);
  final languageTag = Localizations.localeOf(context).toLanguageTag();
  final textDirection = Directionality.of(context);
  // 代码高亮跟随代码块样式；“跟随应用”主题按当前应用配色推出。
  final code = DiaryExportCodeTheme.resolve(
    ref.read(diaryCodeBlockStyleProvider),
    Theme.of(context).colorScheme,
  );

  void hint(String message) {
    if (context.mounted) {
      showHint(message);
    }
  }

  final DiaryExportArtifact artifact;
  try {
    artifact = await runWithActionLoadingOverlay(
      context,
      label: l10n.diaryExportInProgress,
      task: () => controller.build(
        diaries,
        options: options,
        labels: labels,
        languageTag: languageTag,
        textDirection: textDirection,
        password: password,
        book: book,
        bookStructure: request.bookStructure,
        code: code,
        typography: typography,
        commentsEnabled: commentsEnabled,
      ),
    );
  } on DiaryExportEmptyException catch (error) {
    hint(
      error.skippedCapsules > 0
          ? l10n.diaryExportOnlyCapsules
          : l10n.diaryExportNothing,
    );
    return;
  } on DiaryExportTooLargeException catch (error) {
    hint(l10n.diaryExportTooLarge((error.imageBytes / (1024 * 1024)).round()));
    return;
  } catch (error) {
    hint(l10n.previewExportFailed('$error'));
    return;
  }
  if (!context.mounted) {
    return;
  }

  try {
    bool? saved;
    if (request.action == DiaryExportAction.save) {
      saved = await controller.save(
        artifact,
        dialogTitle: l10n.previewExportSaveDialogTitle,
      );
    } else {
      await controller.share(artifact);
    }
    final message = diaryExportResultMessage(
      l10n,
      format: options.format,
      exportedCount: artifact.exportedCount,
      skippedCapsules: artifact.skippedCapsules,
      saved: saved,
    );
    if (message != null) {
      hint(message);
    }
  } catch (error) {
    hint(l10n.previewExportFailed('$error'));
  }
}
