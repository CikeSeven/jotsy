import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:xml/xml.dart';

import 'journal_import_block_writer.dart';
import 'journal_import_files.dart';
import 'journal_import_media.dart';
import 'journal_import_models.dart';
import 'journal_import_support.dart';

/// 解析 Diaro 的备份：ZIP 根目录的 `DiaroBackup.xml` 与照片
/// `media/photo/<文件名>`，也接受单独的 `DiaroBackup.xml`。
///
/// XML 为 `<data version="2">` 下若干 `<table name="diaro_*">`，每行一个
/// `<r>`、每列一个子元素；除 `diaro_entries` 外的表都可能缺失（旧版没有
/// 心情表，没用到的表不导出），按名称查找。
///
/// 映射：uid → 稳定键；date（UTC 毫秒）加 tz_offset（`±HH:MM`，写日记时
/// 所在时区）→ 当时的墙钟时间；title/text（纯文本）→ 标题/正文；tags
/// （`,uid1,uid2,`）→ 标签；所在文件夹 → 所在日记本
/// （[JournalImportEntry.notebooks]）；mood → 心情（有心情表时取其
/// weight，5 最好；旧版按 1 最好、5 最差的固定刻度）；地点 → 位置与坐标；
/// 天气描述与温度（摄氏）→ 天气；照片按 position 放在正文之前（与 Diaro
/// 的版式一致）。加密备份（`DiaroBackup.denc`）的密钥不公开，无法导入。
JournalImportParseResult parseDiaroExport(
  JournalImportInput input,
  JournalMediaStager media,
) {
  final files = input.extractedPath == null
      ? [File(input.filePath)]
      : listJournalExportFiles(input.extractedPath!);
  final candidates = files.where(
    (file) => p.extension(file.path).toLowerCase() == '.xml',
  );
  // 根目录的 DiaroBackup.xml 优先，其次是任意位置的同名文件与其他 XML。
  final ordered = [
    ...candidates.where(
      (file) => p.basename(file.path).toLowerCase() == 'diarobackup.xml',
    ),
    ...candidates.where(
      (file) => p.basename(file.path).toLowerCase() != 'diarobackup.xml',
    ),
  ];
  final entries = <JournalImportEntry>[];
  final issues = JournalImportIssues();
  final keys = JournalKeyRegistry();
  final fileIndex = JournalImportFiles(
    input.extractedPath ?? p.dirname(input.filePath),
  );
  var recognized = false;
  for (final file in ordered) {
    final tables = _readTables(file);
    if (tables == null || !tables.containsKey('diaro_entries')) continue;
    recognized = true;
    entries.addAll(
      _parseEntries(tables, file.parent.path, media, fileIndex, keys, issues),
    );
  }
  if (recognized) {
    return JournalImportParseResult(
      entries: entries,
      missingMediaCount: media.missingCount,
      skippedNotes: issues.skipped,
    );
  }
  if (files.any((file) => p.extension(file.path).toLowerCase() == '.denc')) {
    throw const JournalImportFormatException(
      JournalImportSource.diaro,
      encrypted: true,
    );
  }
  throw const JournalImportFormatException(JournalImportSource.diaro);
}

typedef _Row = Map<String, String>;

/// 读取各表的行（列名 → 原样文本，不去首尾空白：正文末尾的空格也是内容）。
Map<String, List<_Row>>? _readTables(File file) {
  final XmlElement root;
  try {
    root = XmlDocument.parse(readJournalText(file)).rootElement;
  } on XmlException {
    return null;
  } on FileSystemException {
    return null;
  } on FormatException {
    return null;
  }
  if (root.name.local != 'data') return null;
  return {
    for (final table in root.findElements('table'))
      if (table.getAttribute('name') case final name?)
        name: [
          for (final row in table.findElements('r'))
            {
              for (final column in row.childElements)
                column.name.local: column.innerText,
            },
        ],
  };
}

List<JournalImportEntry> _parseEntries(
  Map<String, List<_Row>> tables,
  String root,
  JournalMediaStager media,
  JournalImportFiles files,
  JournalKeyRegistry keys,
  JournalImportIssues issues,
) {
  Map<String, _Row> byUid(String table) => {
    for (final row in tables[table] ?? const <_Row>[])
      if (row['uid']?.trim() case final uid? when uid.isNotEmpty) uid: row,
  };
  final folders = byUid('diaro_folders');
  final tags = byUid('diaro_tags');
  final moods = byUid('diaro_moods');
  final locations = byUid('diaro_locations');
  final attachments = <String, List<_Row>>{};
  for (final row in tables['diaro_attachments'] ?? const <_Row>[]) {
    final entry = row['entry_uid']?.trim();
    if (entry != null && entry.isNotEmpty) {
      (attachments[entry] ??= <_Row>[]).add(row);
    }
  }
  int position(_Row row) => int.tryParse(row['position']?.trim() ?? '') ?? 0;

  final entries = <JournalImportEntry>[];
  for (final row in tables['diaro_entries']!) {
    final createdAt = _wallClock(row['date'], row['tz_offset']);
    if (createdAt == null) {
      issues.skip(JournalSkipReason.unreadable);
      continue;
    }
    final uid = row['uid']?.trim() ?? '';

    final writer = JournalBlockWriter();
    for (final attachment
        in (attachments[uid] ?? const <_Row>[]).toList()
          ..sort((a, b) => position(a).compareTo(position(b)))) {
      final name = attachment['filename']?.trim() ?? '';
      if (name.isEmpty) {
        media.missingCount++;
        continue;
      }
      final type = attachment['type']?.trim();
      final path = files.resolve(
        p.posix.join(
          'media',
          type == null || type.isEmpty ? 'photo' : type,
          name.replaceAll('\\', '/'),
        ),
        from: root,
      );
      if (path == null) {
        media.missingCount++;
        continue;
      }
      final data = media.embedFile(path);
      if (data != null) writer.embed(data);
    }
    appendJournalPlainText(writer, row['text'] ?? '');
    final content = writer.build();

    final location = locations[row['location_uid']?.trim()];
    final latitude = double.tryParse(location?['lat']?.trim() ?? '');
    final longitude = double.tryParse(location?['lng']?.trim() ?? '');
    final hasCoordinate = isJournalCoordinate(latitude, longitude);
    final weatherDescription = journalString(row['weather_description']);
    final hasWeather =
        weatherDescription != null ||
        journalString(row['weather_icon']) != null;
    final folder = journalString(folders[row['folder_uid']?.trim()]?['title']);
    entries.add(
      JournalImportEntry(
        sourceKey: keys.unique(
          uid.isEmpty ? journalWallClockKey(createdAt, seconds: true) : uid,
        ),
        title: journalString(row['title']) ?? '',
        contentJson: content.contentJson,
        contentText: content.contentText,
        createdAt: createdAt,
        tags: [
          for (final tagUid in (row['tags'] ?? '').split(','))
            if (journalString(tags[tagUid.trim()]?['title']) case final name?)
              name,
        ],
        notebooks: [?folder],
        moodLevel: _moodLevel(row['mood'], moods),
        weather: hasWeather
            ? journalWeatherText(
                weatherDescription,
                num.tryParse(row['weather_temperature']?.trim() ?? ''),
              )
            : null,
        location:
            journalString(location?['title']) ??
            journalString(location?['address']),
        latitude: hasCoordinate ? latitude : null,
        longitude: hasCoordinate ? longitude : null,
      ),
    );
  }
  return entries;
}

/// `date`（UTC 毫秒）在 `tz_offset` 时区的墙钟时间；时区缺失或格式不对时
/// 按本机时区。用日历字段构造，不受本机夏令时影响。
DateTime? _wallClock(String? rawDate, String? rawOffset) {
  final millis = int.tryParse(rawDate?.trim() ?? '');
  if (millis == null) return null;
  final instant = journalEpochTime(millis);
  if (instant == null) return null;
  final offset = RegExp(
    r'^([+-])(\d{2}):(\d{2})$',
  ).firstMatch(rawOffset?.trim() ?? '');
  if (offset == null ||
      int.parse(offset.group(2)!) > 23 ||
      int.parse(offset.group(3)!) > 59) {
    return instant;
  }
  final minutes =
      int.parse(offset.group(2)!) * 60 + int.parse(offset.group(3)!);
  final shifted = instant.toUtc().add(
    Duration(minutes: offset.group(1) == '-' ? -minutes : minutes),
  );
  return DateTime(
    shifted.year,
    shifted.month,
    shifted.day,
    shifted.hour,
    shifted.minute,
    shifted.second,
    shifted.millisecond,
  );
}

/// Diaro 心情 → 1（最差）~ 5（最好）。
int? _moodLevel(String? raw, Map<String, _Row> moods) {
  final uid = raw?.trim() ?? '';
  if (uid.isEmpty || uid == '0') return null;
  final weight = int.tryParse(moods[uid]?['weight']?.trim() ?? '');
  if (weight != null) return weight >= 1 && weight <= 5 ? weight : null;
  final value = int.tryParse(uid);
  return value != null && value >= 1 && value <= 5 ? 6 - value : null;
}
