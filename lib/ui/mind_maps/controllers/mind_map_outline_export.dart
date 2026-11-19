import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/database/mind_map/mind_map_document.dart';
import '../../../core/database/mind_map/mind_map_text.dart';
import '../../../core/services/app_service.dart';
import '../../../l10n/app_localizations.dart';
import '../../../utils/text_stats.dart';
import '../../diaries/controllers/diary_export_controller.dart';
import '../../diaries/export/diary_export_blocks.dart';
import '../../diaries/export/diary_export_entry.dart';
import '../../diaries/export/diary_export_font.dart';
import '../../diaries/export/diary_export_format.dart';
import '../../diaries/providers/diary_typography_provider.dart';
import '../../diaries/viewmodels/diary_export_messages.dart';
import '../viewmodels/mind_map_labels.dart';

/// 把导图的大纲导出成文档（PDF、Word、网页），由 `mind_map_io_flow.dart`
/// 的导出流程调用。
///
/// 为什么借日记导出的写出器而不另写：大纲就是一份带样式的缩进列表，日记
/// 正文里的导图本来就按同一种大纲导出（见 [ExportBlockParser]），分页、
/// 字体嵌入、颜色与高亮在纸面上的叠色、Word 的列表编号都已经处理过；另写
/// 一份既重复也会与日记导出里的导图不一致。
///
/// 输入：导图文档与目标格式；正文排版（字体与字号，PDF 嵌入导入字体，
/// Word 与网页按字族名引用）读当前设置。输出：文件字节。副作用：日记导出的
/// 暂存目录里写一次、读回后删掉。
Future<Uint8List> buildMindMapOutlineDocument(
  BuildContext context,
  MindMapDocument document,
  DiaryExportFormat format,
) async {
  assert(
    format == DiaryExportFormat.pdf ||
        format == DiaryExportFormat.word ||
        format == DiaryExportFormat.html,
  );
  final l10n = context.l10n;
  final container = ProviderScope.containerOf(context, listen: false);
  final typography = container.read(diaryTypographyProvider);
  final fontStorage = container.read(diaryFontStorageServiceProvider);
  final controller = DiaryExportController(
    database: container.read(appDatabaseProvider),
    loadBodyFont: () => DiaryExportFont.load(typography, fontStorage),
  );
  final title = mindMapTitle(l10n, document.root.text);
  final artifact = await controller.buildEntries(
    <DiaryExportEntry>[
      mindMapOutlineExportEntry(document, title: title, now: DateTime.now()),
    ],
    title: title,
    options: DiaryExportOptions(
      format: format,
      includeMedia: false,
      includeMeta: false,
      includeComments: false,
    ),
    labels: buildDiaryExportLabels(l10n),
    languageTag: Localizations.localeOf(context).toLanguageTag(),
    textDirection: Directionality.of(context),
    typography: typography,
  );
  try {
    return await artifact.file.readAsBytes();
  } finally {
    try {
      await artifact.file.parent.delete(recursive: true);
    } on FileSystemException {
      // 下次导出前会清掉整个暂存目录。
    }
  }
}

/// 大纲导出的那一篇：标题是中心主题（没写时为“未命名导图”），正文是其余
/// 主题的缩进列表（带文字样式与主题字号），不写日期（[DiaryExportEntry.dated]）。
DiaryExportEntry mindMapOutlineExportEntry(
  MindMapDocument document, {
  required String title,
  required DateTime now,
}) => DiaryExportEntry(
  diaryId: '',
  title: title,
  createdAt: now,
  updatedAt: now,
  blocks: ExportBlockParser.parseMindMapOutline(document),
  wordCount: TextStats.countWords(mindMapPlainText(document)),
  dated: false,
);
