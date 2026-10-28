import 'dart:convert';

import 'package:intl/intl.dart';

import 'diary_export_blocks.dart';
import 'diary_export_book.dart';
import 'diary_export_entry.dart';
import 'diary_export_format.dart';
import 'diary_export_plain_text.dart';

/// 纯文本写出器：所有日记依次写进一个 `.txt`，篇与篇之间用分隔线隔开。
///
/// 每篇：标题、日期行、（可选）信息行与标签行，空一行后是正文；图片与
/// 附件写成一行说明，保留“这里原本有张图”的上下文。有留言时正文之后是
/// 留言区：一行“——— 留言 ———”，每条留言为说明行加心情与文字，条与条之间
/// 空一行。
///
/// 导出成书（[book] 不为 null）时，开头依次是扉页（书名、简介、统计行与
/// 导出日期）与目录（章节名下缩进列出“日期  标题”），各自以 [bookRule]
/// 隔开；每章以“章节名 + 一行 [chapterRule]”开头，章内各篇仍以 [separator]
/// 隔开。纯文本没有页码，目录不写页码。
class DiaryTextWriter {
  const DiaryTextWriter._();

  static const String separator = '────────────────────';

  /// 扉页、目录与正文之间的粗分隔线。
  static const String bookRule = '════════════════════';

  /// 章节标题下的横线。
  static const String chapterRule = '━━━━━━━━━━━━━━━━━━━━';

  static DiaryExportOutput write(
    List<DiaryExportEntry> entries, {
    required DiaryExportOptions options,
    required DiaryExportLabels labels,
    DiaryExportBookLayout? book,
  }) {
    if (book != null) {
      return DiaryExportOutput.single(
        utf8.encode('${_book(book, options: options, labels: labels)}\n'),
      );
    }
    final parts = <String>[
      for (final entry in entries)
        _entry(entry, options: options, labels: labels),
    ];
    return DiaryExportOutput.single(
      utf8.encode('${parts.join('\n\n$separator\n\n')}\n'),
    );
  }

  static String _entry(
    DiaryExportEntry entry, {
    required DiaryExportOptions options,
    required DiaryExportLabels labels,
  }) {
    final header = <String>[
      labels.titleOf(entry),
      labels.formatDateTime(entry.createdAt.toLocal()),
      if (options.includeMeta) ...<String>[
        labels.metaLine(entry),
        entry.tagNames.map((String tag) => '#$tag').join(' '),
      ],
    ].where((String line) => line.isNotEmpty);
    final body = ExportPlainText.render(
      entry.blocks,
      embedLabel: labels.mediaLine,
    );
    return <String>[
      header.join('\n'),
      if (body.isNotEmpty) body,
      if (entry.comments.isNotEmpty) _comments(entry, labels),
    ].join('\n\n');
  }

  /// 留言区：标题夹在两段短横线之间，与正文里的分隔线同一写法，一眼能
  /// 看出正文到此为止。
  static String _comments(DiaryExportEntry entry, DiaryExportLabels labels) {
    const rule = ExportPlainText.dividerLine;
    return '$rule ${labels.commentsHeading} $rule\n'
        '${labels.commentsPlainText(entry)}';
  }

  static String _book(
    DiaryExportBookLayout book, {
    required DiaryExportOptions options,
    required DiaryExportLabels labels,
  }) {
    final titlePage = <String>[
      book.title,
      ?book.description,
      if (book.summaryLine.isNotEmpty) book.summaryLine,
      book.exportedLine,
    ].join('\n');

    final contents = <String>[book.contentsTitle, ''];
    final indent = book.hasChapterHeadings ? '  ' : '';
    for (final section in book.sections) {
      if (section.title != null) {
        contents.add(section.title!);
      }
      for (final entry in section.entries) {
        contents.add(
          '$indent${labels.formatDate(entry.createdAt.toLocal())}  '
          '${labels.titleOf(entry)}',
        );
      }
    }

    final chapters = <String>[];
    for (final section in book.sections) {
      final entries = <String>[
        for (final entry in section.entries)
          _entry(entry, options: options, labels: labels),
      ].join('\n\n$separator\n\n');
      chapters.add(
        section.title == null
            ? entries
            : '${section.title}\n$chapterRule\n\n$entries',
      );
    }
    return <String>[
      titlePage,
      contents.join('\n'),
      ...chapters,
    ].join('\n\n$bookRule\n\n');
  }
}

/// CSV 写出器：每篇一行，列为日期、时间、标题、正文、心情、精力、天气、
/// 地点、标签、字数与最后编辑时间；导出留言时（[write] 的 `includeComments`）
/// 末尾多一列留言，一篇的全部留言写在同一格里。
///
/// - 文件以 UTF-8 BOM 开头、行尾 CRLF（RFC 4180），Excel 直接双击打开不
///   乱码；
/// - 含逗号、引号、换行的字段加引号，引号翻倍；
/// - 以 `=`、`+`、`@` 开头的字段前加 `'`，防止表格软件把日记内容当公式
///   执行（CSV 注入）。
class DiaryCsvWriter {
  const DiaryCsvWriter._();

  static final DateFormat _date = DateFormat('yyyy-MM-dd');
  static final DateFormat _time = DateFormat('HH:mm');
  static final DateFormat _dateTime = DateFormat('yyyy-MM-dd HH:mm');

  /// [includeComments] 由导出控制器按留言功能、开关与格式决定，而不是看
  /// 有没有哪篇带留言：选了导出留言时，即使这几篇都没有留言也保留这一列，
  /// 表头不随所选日记变化；不导出时表格与没有留言功能时逐字节相同。
  static DiaryExportOutput write(
    List<DiaryExportEntry> entries, {
    required DiaryExportLabels labels,
    bool includeComments = false,
  }) {
    final rows = <List<String>>[
      <String>[
        labels.date,
        labels.time,
        labels.title,
        labels.content,
        labels.mood,
        labels.energy,
        labels.weather,
        labels.location,
        labels.tags,
        labels.wordCount,
        labels.updated,
        if (includeComments) labels.commentsHeading,
      ],
      for (final entry in entries)
        <String>[
          _date.format(entry.createdAt.toLocal()),
          _time.format(entry.createdAt.toLocal()),
          entry.title,
          ExportPlainText.render(
            entry.blocks,
            embedLabel: (ExportBlock block) => labels.mediaLine(block),
          ),
          entry.context.moodEmoji ?? '',
          entry.context.energyLevel?.toString() ?? '',
          entry.context.weather ?? '',
          entry.context.location ?? '',
          entry.tagNames.join(', '),
          '${entry.wordCount}',
          _dateTime.format(entry.updatedAt.toLocal()),
          if (includeComments) labels.commentsPlainText(entry),
        ],
    ];
    final csv = rows
        .map((List<String> row) => row.map(_cell).join(','))
        .join('\r\n');
    return DiaryExportOutput.single(utf8.encode('\uFEFF$csv\r\n'));
  }

  static String _cell(String raw) {
    var value = raw;
    if (value.startsWith(RegExp(r'[=+@\t\r]'))) {
      value = "'$value";
    }
    if (value.contains(RegExp(r'[",\r\n]'))) {
      return '"${value.replaceAll('"', '""')}"';
    }
    return value;
  }
}
