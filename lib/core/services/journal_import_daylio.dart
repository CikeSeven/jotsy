import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as p;

import '../../utils/csv_rows.dart';
import 'journal_import_delta_writer.dart';
import 'journal_import_html.dart';
import 'journal_import_media.dart';
import 'journal_import_models.dart';
import 'journal_import_support.dart';

part 'journal_import_daylio_csv.dart';

/// 解析 Daylio 的两种导出：
///
/// - `.daylio` 备份：ZIP 内的 `backup.daylio` 是 base64 编码的 JSON，照片在
///   `assets/` 下以校验和命名（常无扩展名）。`dayEntries` 中 `year/month
///   （0 起）/day/hour/minute` 是本地墙钟时间；`mood` 指向 `customMoods`，
///   其 `mood_group_id` 1（rad）~ 5（awful）；`tags` 指向活动；`assets`
///   指向照片；`note` 可能是 HTML，`note_title` 为标题。
/// - CSV 导出：`full_date,date,weekday,time,mood,activities,note_title,note`
///   （新版本可能多 `scales` 列，旧版本用 `year` + `date`），按表头列名读取。
///   心情是名称，只能识别默认的英文名称（rad/good/meh/bad/awful）。
///
/// Daylio 的条目 ID 不跨备份稳定，两种格式都以精确到分钟的墙钟时间为键，
/// 先后导入备份与 CSV 时能互相识别为“已存在”。活动 → 标签。
JournalImportParseResult parseDaylioExport(
  JournalImportInput input,
  JournalMediaStager media,
) {
  final extracted = input.extractedPath;
  final candidates = extracted == null
      ? [File(input.filePath)]
      : listJournalExportFiles(extracted);
  for (final file in candidates) {
    if (p.basename(file.path).toLowerCase() == 'backup.daylio' ||
        extracted == null) {
      final backup = _decodeBackup(file);
      if (backup != null) {
        return _parseBackup(backup, file.parent.path, media);
      }
    }
  }
  for (final file in candidates) {
    if (extracted != null && p.extension(file.path).toLowerCase() != '.csv') {
      continue;
    }
    final String text;
    try {
      text = readJournalText(file);
    } on FormatException {
      continue;
    } on FileSystemException {
      continue;
    }
    final result = _parseCsv(text);
    if (result != null) {
      return result;
    }
  }
  throw const JournalImportFormatException(JournalImportSource.daylio);
}

Map<String, Object?>? _decodeBackup(File file) {
  try {
    final encoded = readJournalText(file).trim();
    final decoded = jsonDecode(
      encoded.startsWith('{')
          ? encoded
          : utf8.decode(base64.decode(encoded.replaceAll(RegExp(r'\s'), ''))),
    );
    return decoded is Map && decoded['dayEntries'] is List
        ? decoded.cast<String, Object?>()
        : null;
  } on FormatException {
    return null;
  } on FileSystemException {
    return null;
  }
}

JournalImportParseResult _parseBackup(
  Map<String, Object?> backup,
  String? root,
  JournalMediaStager media,
) {
  List<Map> listOf(String key) =>
      journalList(backup[key]).whereType<Map>().toList();
  final issues = JournalImportIssues();

  final moodGroups = <int, int>{
    for (final mood in listOf('customMoods'))
      if (mood['id'] is int && mood['mood_group_id'] is int)
        mood['id'] as int: mood['mood_group_id'] as int,
  };
  final tagNames = <int, String>{
    for (final tag in listOf('tags'))
      if (tag['id'] is int && journalString(tag['name']) != null)
        tag['id'] as int: journalString(tag['name'])!,
  };
  final assets = <int, Map>{
    for (final asset in listOf('assets'))
      if (asset['id'] is int) asset['id'] as int: asset,
  };
  // 照片文件名即校验和；不同版本的目录层级与扩展名不同，按主名建索引。
  final assetFiles = <String, String>{
    if (root != null)
      for (final file in listJournalExportFiles(p.join(root, 'assets')))
        p.basenameWithoutExtension(file.path).toLowerCase(): file.path,
  };

  final parsed = <({DateTime createdAt, String note, Map raw})>[];
  for (final value in journalList(backup['dayEntries'])) {
    if (value is! Map) {
      issues.skip(JournalSkipReason.unreadable);
      continue;
    }
    final raw = value;
    final createdAt = _backupTime(raw);
    if (createdAt == null) {
      issues.skip(JournalSkipReason.unreadable);
      continue;
    }
    parsed.add((createdAt: createdAt, note: '${raw['note'] ?? ''}', raw: raw));
  }
  // 同一分钟内的多篇按正文排序后再分配键，重复导入时键不变。
  parsed.sort(
    (a, b) => a.createdAt.compareTo(b.createdAt) != 0
        ? a.createdAt.compareTo(b.createdAt)
        : a.note.compareTo(b.note),
  );

  final keys = JournalKeyRegistry();
  final entries = <JournalImportEntry>[];
  for (final item in parsed) {
    final raw = item.raw;
    final writer = JournalDeltaWriter();
    _appendNote(writer, item.note);
    for (final id in journalList(raw['assets']).whereType<int>()) {
      final asset = assets[id];
      final checksum = journalString(asset?['checksum'])?.toLowerCase();
      final path = checksum == null ? null : assetFiles[checksum];
      if (path == null) {
        media.missingCount++;
        continue;
      }
      final data = media.embedFile(
        path,
        kind: asset?['type'] == 1 ? JournalMediaKind.image : null,
      );
      if (data != null) writer.embed(data);
    }
    final content = writer.build();
    final moodId = raw['mood'];
    final group = moodId is int
        ? moodGroups[moodId] ?? (moodId >= 1 && moodId <= 5 ? moodId : null)
        : null;
    entries.add(
      JournalImportEntry(
        sourceKey: keys.unique(journalWallClockKey(item.createdAt)),
        title: journalString(raw['note_title']) ?? '',
        contentJson: content.contentJson,
        contentText: content.contentText,
        createdAt: item.createdAt,
        tags: [
          for (final id in journalList(raw['tags']).whereType<int>())
            ?tagNames[id],
        ],
        moodLevel: group != null && group >= 1 && group <= 5 ? 6 - group : null,
      ),
    );
  }
  return JournalImportParseResult(
    entries: entries,
    missingMediaCount: media.missingCount,
    skippedNotes: issues.skipped,
  );
}

DateTime? _backupTime(Map raw) {
  final year = raw['year'];
  final month = raw['month'];
  final day = raw['day'];
  if (year is int && month is int && day is int) {
    final hour = raw['hour'];
    final minute = raw['minute'];
    if (!isJournalCalendarDate(year, month + 1, day) ||
        (hour is int && (hour < 0 || hour > 23)) ||
        (minute is int && (minute < 0 || minute > 59))) {
      return null;
    }
    return DateTime(
      year,
      month + 1,
      day,
      hour is int ? hour : 0,
      minute is int ? minute : 0,
    );
  }
  final millis = journalNumber(raw['datetime']);
  if (millis == null) return null;
  final offset = journalNumber(raw['timeZoneOffset']) ?? 0;
  final wall = journalEpochTime(millis + offset)?.toUtc();
  if (wall == null) return null;
  return DateTime(wall.year, wall.month, wall.day, wall.hour, wall.minute);
}

void _appendNote(JournalDeltaWriter writer, String note) {
  if (note.trim().isEmpty) return;
  if (looksLikeJournalHtml(note) || RegExp(r'&[a-z]+;').hasMatch(note)) {
    JournalHtmlConverter(writer).appendHtml(note);
  } else {
    appendJournalPlainText(writer, note);
  }
}
