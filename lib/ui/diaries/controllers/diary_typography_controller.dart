import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/services/app_service.dart';
import '../../../core/services/diary_font_storage_service.dart';
import '../../../core/services/diary_media_storage_service.dart';
import '../../../core/services/settings_service.dart';
import '../../../l10n/app_localizations.dart';
import '../../home/widgets/home_hint_visibility_scope.dart';
import '../providers/diary_typography_provider.dart';

/// 正文排版的修改入口，设置页与预览页快捷面板共用。
///
/// - [commit]：写入设置服务（落盘并通知编辑 / 预览 / 发布页重排）。滑块拖动
///   期间由界面只改本地草稿，松手或点按 ± 时才提交：长日记整篇重排开销
///   不小，逐帧提交会让拖动卡顿，也会频繁写盘。
/// - [importFont]：选择文件 → 校验并复制 → 设为当前字体 → 提示。取消选择
///   不提示；无论成功与否都删除文件选择器留在缓存里的副本。
/// - [deleteFont]：删除文件与清单条目；正在使用的字体被删时回到内置字体。
///   删除前的确认由调用页负责。
class DiaryTypographyController {
  DiaryTypographyController(this._ref);

  final WidgetRef _ref;

  Future<void> commit(DiaryTypography typography) async {
    final settings = await _ref.read(settingsServiceProvider.future);
    if (settings.diaryTypography == typography) {
      return;
    }
    await settings.setDiaryTypography(typography);
  }

  /// [onBusyChanged] 在复制字体期间置为 true，供页面显示等待遮罩（中文
  /// 字体常有十几 MB，复制需要可感知的时间）。
  Future<void> importFont(
    BuildContext context, {
    required ValueChanged<bool> onBusyChanged,
  }) async {
    final l10n = context.l10n;
    final languageCode = Localizations.localeOf(context).languageCode;
    final picked = await FilePicker.platform.pickFiles(
      dialogTitle: l10n.diaryTypographyImportFont,
      // ttf/otf/ttc 在部分 Android 版本没有对应 MIME，按扩展名过滤会让文件
      // 无法选中；不限制类型，由文件头识别格式。
      type: FileType.any,
    );
    final path = picked?.files.firstOrNull?.path;
    if (path == null) {
      return;
    }
    if (!context.mounted) {
      await DiaryMediaStorageService.discardPickerCopy(path);
      return;
    }
    onBusyChanged(true);
    try {
      final font = await _ref
          .read(diaryFontStorageServiceProvider)
          .importFont(path, languageCode: languageCode);
      _ref.invalidate(diaryImportedFontsProvider);
      await commit(
        _ref.read(diaryTypographyProvider).copyWith(fontId: font.id),
      );
      if (context.mounted) {
        await _showHint(context, l10n.diaryTypographyImported(font.name));
      }
    } on DiaryFontImportException catch (error) {
      if (context.mounted) {
        await _showHint(context, switch (error.failure) {
          DiaryFontImportFailure.unsupportedFormat =>
            l10n.diaryTypographyImportUnsupported,
          DiaryFontImportFailure.unreadable =>
            l10n.diaryTypographyImportUnreadable,
        });
      }
    } on FileSystemException {
      // 读取成功但写入应用目录失败（如存储空间不足）。
      if (context.mounted) {
        await _showHint(context, l10n.diaryTypographyImportFailed);
      }
    } finally {
      onBusyChanged(false);
      await DiaryMediaStorageService.discardPickerCopy(path);
    }
  }

  Future<void> deleteFont(DiaryImportedFont font) async {
    await _ref.read(diaryFontStorageServiceProvider).deleteFont(font.id);
    final current = _ref.read(diaryTypographyProvider);
    if (current.fontId == font.id) {
      await commit(current.copyWith(fontId: DiaryTypography.bundledFontId));
    }
    _ref.invalidate(diaryImportedFontsProvider);
  }

  Future<void> _showHint(BuildContext context, String message) async {
    await HomeHintVisibilityScope.showTrackedSnackBar(
      context: context,
      snackBar: SnackBar(content: Text(message)),
    );
  }
}
