import 'package:intl/intl.dart';
import 'package:node_diary/l10n/app_localizations.dart';

import '../export/diary_export_book.dart';
import '../export/diary_export_entry.dart';
import '../export/diary_export_format.dart';
import 'diary_comment_timeline.dart';

/// 写出器用的文案：按当前界面语言构造，日期带星期与时间。
DiaryExportLabels buildDiaryExportLabels(AppLocalizations l10n) {
  final dateTime = DateFormat.yMMMEd(l10n.localeName).add_Hm();
  final date = DateFormat.yMd(l10n.localeName);
  final month = DateFormat.yMMM(l10n.localeName);
  final day = DateFormat.yMMMd(l10n.localeName);
  return DiaryExportLabels(
    untitled: l10n.diaryExportLabelUntitled,
    mood: l10n.diaryExportLabelMood,
    energy: l10n.diaryExportLabelEnergy,
    weather: l10n.diaryExportLabelWeather,
    location: l10n.diaryExportLabelLocation,
    tags: l10n.diaryExportLabelTags,
    date: l10n.diaryExportLabelDate,
    time: l10n.diaryExportLabelTime,
    title: l10n.diaryExportLabelTitle,
    content: l10n.diaryExportLabelContent,
    wordCount: l10n.diaryExportLabelWordCount,
    updated: l10n.diaryExportLabelUpdated,
    image: l10n.diaryExportLabelImage,
    audio: l10n.diaryExportLabelAudio,
    video: l10n.diaryExportLabelVideo,
    attachment: l10n.diaryExportLabelAttachment,
    exportedBy: l10n.diaryExportLabelExportedBy,
    commentsHeading: l10n.diaryExportCommentsHeading,
    commentEdited: l10n.diaryCommentEdited,
    commentAge: (DateTime diaryCreatedAt, DateTime commentCreatedAt) =>
        diaryCommentRelativeLabel(l10n, diaryCreatedAt, commentCreatedAt),
    // 导出文件会在以后、在别处打开：留言时间总是写出完整日期，不像预览页
    // 那样按“今天 / 今年”省略。
    commentTime: l10n.formatDateTimeMinute,
    formatDateTime: dateTime.format,
    formatDate: date.format,
    book: DiaryExportBookLabels(
      contents: l10n.notebookContents,
      unassignedChapter: l10n.notebookChapterUnassigned,
      // 与日记本头部的时间跨度同一写法（按月），但书是导出那一刻的快照，
      // 不写“至今”。
      summary: (DateTime first, DateTime last, int count) {
        final sameMonth = first.year == last.year && first.month == last.month;
        final span = sameMonth
            ? month.format(first)
            : l10n.notebookMetaSpan(month.format(first), month.format(last));
        return '$span · ${l10n.notebookEntryCount(count)}';
      },
      exportedOn: (DateTime value) =>
          l10n.notebookBookExportedOn(day.format(value)),
    ),
  );
}

String diaryExportFormatName(AppLocalizations l10n, DiaryExportFormat format) {
  return switch (format) {
    DiaryExportFormat.pdf => l10n.diaryExportFormatPdf,
    DiaryExportFormat.word => l10n.diaryExportFormatWord,
    DiaryExportFormat.markdown => l10n.diaryExportFormatMarkdown,
    DiaryExportFormat.html => l10n.diaryExportFormatHtml,
    DiaryExportFormat.text => l10n.diaryExportFormatText,
    DiaryExportFormat.csv => l10n.diaryExportFormatCsv,
    DiaryExportFormat.diaryFile => l10n.diaryExportFormatDiaryFile,
  };
}

String diaryExportFormatDescription(
  AppLocalizations l10n,
  DiaryExportFormat format,
) {
  return switch (format) {
    DiaryExportFormat.pdf => l10n.diaryExportFormatPdfDescription,
    DiaryExportFormat.word => l10n.diaryExportFormatWordDescription,
    DiaryExportFormat.markdown => l10n.diaryExportFormatMarkdownDescription,
    DiaryExportFormat.html => l10n.diaryExportFormatHtmlDescription,
    DiaryExportFormat.text => l10n.diaryExportFormatTextDescription,
    DiaryExportFormat.csv => l10n.diaryExportFormatCsvDescription,
    DiaryExportFormat.diaryFile => l10n.diaryExportFormatDiaryFileDescription,
  };
}

/// 媒体开关的文案：Markdown 会把录音、视频与附件一起打包，其余格式只带图片。
String diaryExportMediaToggleLabel(
  AppLocalizations l10n,
  DiaryExportFormat format,
) {
  return format.media == DiaryExportMediaSupport.all
      ? l10n.diaryExportIncludeMedia
      : l10n.diaryExportIncludeImages;
}

/// 导出结束后的提示；[saved] 为 null 表示交给了分享面板（用户已离开本页，
/// 只在有跳过的胶囊时提示）。
String? diaryExportResultMessage(
  AppLocalizations l10n, {
  required DiaryExportFormat format,
  required int exportedCount,
  required int skippedCapsules,
  required bool? saved,
}) {
  final primary = switch (saved) {
    null => null,
    false => l10n.previewExportCanceled,
    true when format == DiaryExportFormat.diaryFile =>
      l10n.previewExportDiaryFileSuccess,
    true => l10n.diaryExportSaved(exportedCount),
  };
  final lines = <String>[
    ?primary,
    if (skippedCapsules > 0 && saved != false)
      l10n.diaryExportSkippedCapsules(skippedCapsules),
  ];
  return lines.isEmpty ? null : lines.join('\n');
}
