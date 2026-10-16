import 'dart:convert';

import 'package:intl/intl.dart';

import 'diary_export_blocks.dart';
import 'diary_export_entry.dart';
import 'diary_export_format.dart';
import 'diary_export_plain_text.dart';

/// 纯文本写出器：所有日记依次写进一个 `.txt`，篇与篇之间用分隔线隔开。
///
/// 每篇：标题、日期行、（可选）信息行与标签行，空一行后是正文；图片与
/// 附件写成一行说明，保留“这里原本有张图”的上下文。
class DiaryTextWriter {
  const DiaryTextWriter._();

  static const String separator = '────────────────────';

  static DiaryExportOutput write(
    List<DiaryExportEntry> entries, {
    required DiaryExportOptions options,
    required DiaryExportLabels labels,
  }) {
    final parts = <String>[];
    for (final entry in entries) {
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
      parts.add(
        <String>[header.join('\n'), if (body.isNotEmpty) body].join('\n\n'),
      );
    }
    return DiaryExportOutput.single(
      utf8.encode('${parts.join('\n\n$separator\n\n')}\n'),
    );
  }
}

/// CSV 写出器：每篇一行，列为日期、时间、标题、正文、心情、精力、天气、
/// 地点、标签、字数与最后编辑时间。
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

  static DiaryExportOutput write(
    List<DiaryExportEntry> entries, {
    required DiaryExportLabels labels,
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
          '${entry.charCount}',
          _dateTime.format(entry.updatedAt.toLocal()),
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
