part of 'journal_import_diarium.dart';

/// Diarium `.diary` 备份（SQLite 数据库）的解析，见 [parseDiariumExport]。

List<JournalImportEntry> _parseDatabase(
  String path,
  JournalMediaStager media,
  JournalKeyRegistry keys,
  JournalImportIssues issues,
) {
  final Database database;
  try {
    database = sqlite3.open(path, mode: OpenMode.readOnly);
  } on SqliteException {
    throw const JournalImportFormatException(JournalImportSource.diarium);
  }
  try {
    final tables = <String>{
      for (final row in database.select(
        "SELECT name FROM sqlite_master WHERE type = 'table'",
      ))
        row['name'] as String,
    };
    Set<String> columnsOf(String table) => tables.contains(table)
        ? {
            for (final row in database.select('PRAGMA table_info("$table")'))
              row['name'] as String,
          }
        : const <String>{};
    final entryColumns = columnsOf('Entries');
    if (!entryColumns.contains('DiaryEntryId')) {
      throw const JournalImportFormatException(JournalImportSource.diarium);
    }
    String column(String name) =>
        entryColumns.contains(name) ? '"$name"' : 'NULL AS "$name"';

    final tagNames = <int, String>{};
    final tagColumns = columnsOf('Tags');
    if (tagColumns.containsAll(const {'DiaryTagId', 'Value'})) {
      final type = tagColumns.contains('Type') ? 'Type' : '0';
      for (final row in database.select(
        'SELECT DiaryTagId, Value, $type AS Type FROM Tags',
      )) {
        // Type 2 为数值追踪项（如体重、步数），不是标签。
        final name = journalString(row['Value']);
        if (name != null && row['Type'] != 2) {
          tagNames[row['DiaryTagId'] as int] = name;
        }
      }
    }
    final entryTags = <int, List<String>>{};
    if (columnsOf(
      'EntryTags',
    ).containsAll(const {'DiaryEntryId', 'DiaryTagId'})) {
      for (final row in database.select(
        'SELECT DiaryEntryId, DiaryTagId FROM EntryTags',
      )) {
        final name = tagNames[row['DiaryTagId']];
        if (name != null) {
          (entryTags[row['DiaryEntryId'] as int] ??= []).add(name);
        }
      }
    }
    final weather = <int, String>{};
    if (columnsOf(
      'Events',
    ).containsAll(const {'DiaryEntryId', 'Type', 'Content'})) {
      for (final row in database.select(
        'SELECT DiaryEntryId, Content FROM Events WHERE Type = 0',
      )) {
        final text = _weather(row['Content']);
        if (text != null) weather[row['DiaryEntryId'] as int] = text;
      }
    }
    final mediaColumns = columnsOf('Media');
    final mediaQuery = mediaColumns.containsAll(const {'DiaryEntryId', 'Data'})
        ? database.prepare(
            'SELECT ${['Type', 'Name', 'FileEnding'].map((name) => mediaColumns.contains(name) ? '"$name"' : 'NULL AS "$name"').join(', ')}, Data '
            'FROM Media WHERE DiaryEntryId = ?'
            '${mediaColumns.contains('Index') ? ' ORDER BY "Index"' : ''}',
          )
        : null;

    final entries = <JournalImportEntry>[];
    try {
      for (final row in database.select(
        'SELECT DiaryEntryId, ${['Heading', 'Text', 'Rating', 'Latitude', 'Longitude'].map(column).join(', ')} '
        'FROM Entries ORDER BY DiaryEntryId',
      )) {
        final id = row['DiaryEntryId'];
        final createdAt = id is int ? _ticksToLocal(id) : null;
        if (id is! int || createdAt == null) {
          issues.skip(JournalSkipReason.unreadable);
          continue;
        }
        final writer = JournalDeltaWriter();
        _appendBody(writer, journalString(row['Text']));
        if (mediaQuery != null) {
          for (final item in mediaQuery.select([id])) {
            final data = item['Data'];
            if (data is! Uint8List || data.isEmpty) {
              media.missingCount++;
              continue;
            }
            writer.embed(
              media.embedBytes(
                data,
                name: _mediaName(item['Name'], item['FileEnding']),
                kind: _mediaKind(item['Type'], item['FileEnding']),
              ),
            );
          }
        }
        final content = writer.build();
        final latitude = row['Latitude'];
        final longitude = row['Longitude'];
        final hasCoordinate =
            latitude is num &&
            longitude is num &&
            isJournalCoordinate(latitude, longitude);
        entries.add(
          JournalImportEntry(
            sourceKey: keys.unique(
              journalWallClockKey(createdAt, seconds: true),
            ),
            title: _plainHeading(row['Heading']),
            contentJson: content.contentJson,
            contentText: content.contentText,
            createdAt: createdAt,
            tags: entryTags[id] ?? const <String>[],
            moodLevel: _moodLevel(row['Rating']),
            weather: weather[id],
            latitude: hasCoordinate ? latitude.toDouble() : null,
            longitude: hasCoordinate ? longitude.toDouble() : null,
          ),
        );
      }
    } finally {
      mediaQuery?.close();
    }
    return entries;
  } on SqliteException {
    // 加密或损坏的备份打开后查询才报错（file is not a database）。
    throw const JournalImportFormatException(JournalImportSource.diarium);
  } finally {
    database.close();
  }
}

/// .NET ticks（0001-01-01 起的 100 纳秒数，本地墙钟）→ 本地时间。
DateTime? _ticksToLocal(int ticks) {
  const unixEpochTicks = 621355968000000000;
  final micros = (ticks - unixEpochTicks) ~/ 10;
  // .NET DateTime 支持 0001~9999 年。历史日记也可能早于 Unix epoch，
  // 不能把负的 Unix 微秒误当成坏 ID。
  if (ticks < 0 || ticks > 3155378975999999999) return null;
  final wall = DateTime.fromMicrosecondsSinceEpoch(micros, isUtc: true);
  return DateTime(
    wall.year,
    wall.month,
    wall.day,
    wall.hour,
    wall.minute,
    wall.second,
    wall.millisecond,
    wall.microsecond,
  );
}

String _mediaName(Object? name, Object? ending) {
  final stem = journalString(name) ?? 'media';
  final extension = journalString(ending);
  if (extension == null || p.extension(stem).isNotEmpty) return stem;
  return extension.startsWith('.') ? '$stem$extension' : '$stem.$extension';
}

/// 有扩展名时按扩展名判断；否则按 Media.Type（0/3 图片、1 视频、2 录音）。
JournalMediaKind? _mediaKind(Object? type, Object? ending) {
  if (journalString(ending) != null) return null;
  return switch (type) {
    0 || 3 => JournalMediaKind.image,
    1 => JournalMediaKind.video,
    2 => JournalMediaKind.audio,
    _ => null,
  };
}
