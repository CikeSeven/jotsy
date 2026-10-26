import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:html/parser.dart' as html_parser;
import 'package:path/path.dart' as p;
import 'package:sqlite3/sqlite3.dart';

import 'journal_import_block_writer.dart';
import 'journal_import_html.dart';
import 'journal_import_media.dart';
import 'journal_import_models.dart';
import 'journal_import_support.dart';

part 'journal_import_diarium_backup.dart';

/// 解析 Diarium 的两种导出：
///
/// - JSON 导出：日记对象数组，字段为 `date`（ISO 时间）、`heading`、
///   `html`、`rating`（1~5 星）、`tags`、`people`、`location`（`[纬度, 经度]`）、
///   `weather`（如 `"23°C, Partly cloudy."`）。不含媒体文件。
/// - `.diary` 备份：SQLite 数据库。`Entries.DiaryEntryId` 是写日记时本地墙钟
///   时间的 .NET ticks；正文 `Text` 为 HTML；`Media` 表以 BLOB 存图片/视频/
///   录音；`Tags`/`EntryTags` 为标签（Type 2 是数值追踪项，不导入）；`Events`
///   中 Type 0 为天气。各列按存在与否读取，兼容不同版本的表结构。
///
/// 两种格式的稳定键都是精确到秒的本地墙钟时间，先后导入 JSON 与备份时能
/// 互相识别为“已存在”。people 一并作为标签导入；数值追踪项不导入。
JournalImportParseResult parseDiariumExport(
  JournalImportInput input,
  JournalMediaStager media,
) {
  final files = input.extractedPath == null
      ? [File(input.filePath)]
      : listJournalExportFiles(input.extractedPath!);
  final entries = <JournalImportEntry>[];
  final keys = JournalKeyRegistry();
  final issues = JournalImportIssues();
  var recognized = false;
  for (final file in files) {
    if (_isSqlite(file)) {
      entries.addAll(_parseDatabase(file.path, media, keys, issues));
      recognized = true;
      continue;
    }
    if (p.extension(file.path).toLowerCase() != '.json') continue;
    final items = _jsonEntries(file);
    if (items == null) continue;
    recognized = true;
    for (final item in items) {
      final entry = item is Map
          ? _parseJsonEntry(item.cast<String, Object?>(), keys)
          : null;
      if (entry != null) {
        entries.add(entry);
      } else {
        issues.skip(JournalSkipReason.unreadable);
      }
    }
  }
  if (!recognized) {
    throw const JournalImportFormatException(JournalImportSource.diarium);
  }
  return JournalImportParseResult(
    entries: entries,
    missingMediaCount: media.missingCount,
    skippedNotes: issues.skipped,
  );
}

bool _isSqlite(File file) {
  try {
    final handle = file.openSync();
    try {
      return utf8.decode(handle.readSync(15), allowMalformed: true) ==
          'SQLite format 3';
    } finally {
      handle.closeSync();
    }
  } on FileSystemException {
    return false;
  }
}

/// 读取 JSON 导出中的日记对象；不是 Diarium 格式时返回 null。
List<Object?>? _jsonEntries(File file) {
  Object? decoded;
  try {
    decoded = jsonDecode(readJournalText(file));
  } on FormatException {
    return null;
  } on FileSystemException {
    return null;
  }
  bool resemblesEntry(Object? item) =>
      item is Map &&
      item.containsKey('date') &&
      (item.containsKey('html') ||
          item.containsKey('heading') ||
          item.containsKey('text'));
  if (decoded is List) {
    return decoded.isEmpty || decoded.any(resemblesEntry) ? decoded : null;
  }
  if (decoded is Map) {
    // 容器可能先带 tags/people 等数组，不能把第一个数组误当成日记列表。
    for (final list in decoded.values.whereType<List>()) {
      if (list.any(resemblesEntry)) return list;
    }
    for (final key in const ['entries', 'diaries']) {
      if (decoded[key] is List && (decoded[key] as List).isEmpty) {
        return const [];
      }
    }
  }
  return null;
}

JournalImportEntry? _parseJsonEntry(
  Map<String, Object?> raw,
  JournalKeyRegistry keys,
) {
  final createdAt = parseJournalDateTime(raw['date']);
  if (createdAt == null) return null;
  final writer = JournalBlockWriter();
  _appendBody(writer, journalString(raw['html']) ?? journalString(raw['text']));
  final content = writer.build();
  final location = raw['location'];
  final hasCoordinate =
      location is List &&
      location.length >= 2 &&
      location[0] is num &&
      location[1] is num &&
      isJournalCoordinate(location[0] as num, location[1] as num);
  return JournalImportEntry(
    sourceKey: keys.unique(journalWallClockKey(createdAt, seconds: true)),
    title: _plainHeading(raw['heading']),
    contentJson: content.contentJson,
    contentText: content.contentText,
    createdAt: createdAt,
    updatedAt: parseJournalDateTime(raw['updated'] ?? raw['modified']),
    tags: [
      ...journalStringList(raw['tags']),
      ...journalStringList(raw['people']),
    ],
    moodLevel: _moodLevel(raw['rating']),
    weather: _weather(raw['weather']),
    latitude: hasCoordinate ? (location[0] as num).toDouble() : null,
    longitude: hasCoordinate ? (location[1] as num).toDouble() : null,
  );
}

void _appendBody(JournalBlockWriter writer, String? body) {
  if (body == null) return;
  if (looksLikeJournalHtml(body)) {
    JournalHtmlConverter(writer).appendHtml(body);
  } else {
    appendJournalPlainText(writer, body);
  }
}

/// 标题可能带 HTML 标签与实体，只取纯文本。
String _plainHeading(Object? raw) {
  final heading = journalString(raw);
  if (heading == null) return '';
  return html_parser
      .parseFragment(heading)
      .text!
      .replaceAll(RegExp(r'\s+'), ' ')
      .trim();
}

int? _moodLevel(Object? raw) {
  final rating = journalNumber(raw);
  return rating != null && rating >= 1 && rating <= 5 ? rating.round() : null;
}

String? _weather(Object? raw) {
  final text = journalString(raw);
  if (text == null) return null;
  return text.replaceAll(RegExp(r'[.。]+$'), '').trim();
}
