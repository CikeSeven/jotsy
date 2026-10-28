import 'dart:convert';

import 'package:path/path.dart' as p;
import 'package:sqlite3/sqlite3.dart';

import '../database/divider_embed_codec.dart';
import 'journal_import_block_writer.dart';
import 'journal_import_durian_body.dart';
import 'journal_import_durian_meta.dart';
import 'journal_import_media.dart';
import 'journal_import_models.dart';
import 'journal_import_support.dart';

/// 解析榴莲日记的备份（依据应用 0.14x 的逆向分析，数据库结构版本 30）：
///
/// - 「导入导出 › 导出榴莲日记压缩包」与早期本地备份的 `.lld`：ZIP，根目录
///   为 `app_database.db`（可能附带回滚日志 `app_database.db-journal`）、
///   `image/`、`attachment/`；
/// - 「导出榴莲日记文件夹」与新版「本地备份」：文件夹，数据库在
///   `database/app_database.db`；文件选择器选不了文件夹，需压缩成 ZIP。
///
/// 数据库是 Floor 生成的 SQLite。映射（日记表 `diary`）：
/// - `id` → 稳定键；`update_time`（UTC 毫秒）是用户选的日记日期 → 发表
///   时间；`create_time` 才是最后修改时间（每次保存、移进回收站都会改写）
///   → 更新时间；
/// - `title` → 标题；正文与媒体见 [DurianDiaryBody]；附件（录音与其他文件，
///   `attachment` 表按 `position` 排序）接在正文之后；
/// - `book_id` → 所在日记本（分属多本时才记，只有一本没有区分意义）；
///   `relation_diary_tag` → 标签（关联可能重复，去重）；
/// - `mood` / `mood_value` / `weather` / `weather_temp` / `location` /
///   `address` 见 journal_import_durian_meta.dart；`important` → 置顶；
/// - 评论（`comment` 表，带日期的追记，以及旧版的 `diary.comment` 列）是
///   用户写下的内容，接在正文末尾的分隔线之后，按评论时间排列；
/// - 回收站（`deleted = 1`）与模板（`template = 1`，模板也存在 diary 表里）
///   不导入；`lock` 只是界面验证、正文为明文，照常导入。
///
/// 旧版本的备份缺少后来加的列（心情指数、温度、收藏、日记本等），一律先
/// 探测列再读取，缺的按没有处理。
JournalImportParseResult parseDurianDiaryExport(
  JournalImportInput input,
  JournalMediaStager media,
) {
  final root = input.extractedPath;
  if (root == null) {
    throw const JournalImportFormatException(JournalImportSource.durianDiary);
  }
  final files = listJournalExportFiles(root);
  final databases =
      files.where((file) => p.basename(file.path) == _databaseName).toList()
        ..sort(
          (a, b) => p
              .split(p.relative(a.path, from: root))
              .length
              .compareTo(p.split(p.relative(b.path, from: root)).length),
        );
  if (databases.isEmpty) {
    throw const JournalImportFormatException(JournalImportSource.durianDiary);
  }
  final images = <String, String>{};
  final attachments = <String, String>{};
  for (final file in files) {
    final segments = p.split(p.relative(file.path, from: root));
    final name = segments.last.toLowerCase();
    // 恢复时应用只按文件名放回 image / attachment 目录，这里同样按文件名查找。
    if (segments.contains('image')) {
      images.putIfAbsent(name, () => file.path);
    } else if (segments.contains('attachment')) {
      attachments.putIfAbsent(name, () => file.path);
    }
  }

  final Database database;
  try {
    // 解压出的副本在导入暂存区里，以可写方式打开：备份时数据库仍在使用，
    // 若带着非空的回滚日志，SQLite 会先回滚未完成的事务，只读打开做不到。
    database = sqlite3.open(databases.first.path);
  } on SqliteException {
    throw const JournalImportFormatException(JournalImportSource.durianDiary);
  }
  try {
    return _parseDatabase(
      database,
      DurianDiaryBody(media: media, images: images, attachments: attachments),
      media,
    );
  } on SqliteException {
    throw const JournalImportFormatException(JournalImportSource.durianDiary);
  } finally {
    database.close();
  }
}

const String _databaseName = 'app_database.db';

JournalImportParseResult _parseDatabase(
  Database database,
  DurianDiaryBody body,
  JournalMediaStager media,
) {
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
  String select(Set<String> columns, List<String> names) => names
      .map((name) => columns.contains(name) ? '"$name"' : 'NULL AS "$name"')
      .join(', ');

  final diaryColumns = columnsOf('diary');
  if (!diaryColumns.containsAll(const {'id', 'content', 'update_time'})) {
    throw const JournalImportFormatException(JournalImportSource.durianDiary);
  }

  final books = <String, String>{
    if (columnsOf('book').containsAll(const {'id', 'name'}))
      for (final row in database.select('SELECT id, name FROM book'))
        if ((journalId(row['id']), journalString(row['name'])) case (
          final String id,
          final String name,
        ))
          id: name,
  };
  final tagNames = <String, String>{
    if (columnsOf('tag').containsAll(const {'id', 'name'}))
      for (final row in database.select('SELECT id, name FROM tag'))
        if ((journalId(row['id']), journalString(row['name'])) case (
          final String id,
          final String name,
        ))
          id: name,
  };
  final diaryTags = <String, List<String>>{};
  if (columnsOf(
    'relation_diary_tag',
  ).containsAll(const {'diary_id', 'tag_id'})) {
    for (final row in database.select(
      'SELECT diary_id, tag_id FROM relation_diary_tag ORDER BY rowid',
    )) {
      final name = tagNames[journalId(row['tag_id'])];
      final diary = journalId(row['diary_id']);
      if (name == null || diary == null) continue;
      final list = diaryTags[diary] ??= <String>[];
      if (!list.contains(name)) list.add(name);
    }
  }
  final attachmentPaths = <String, List<String>>{};
  final attachmentColumns = columnsOf('attachment');
  if (attachmentColumns.containsAll(const {'diary_id', 'path'})) {
    final order = [
      if (attachmentColumns.contains('position')) 'position',
      if (attachmentColumns.contains('create_time')) 'create_time',
      'rowid',
    ].join(', ');
    for (final row in database.select(
      'SELECT diary_id, path FROM attachment ORDER BY $order',
    )) {
      final diary = journalId(row['diary_id']);
      final path = journalString(row['path']);
      if (diary != null && path != null) {
        (attachmentPaths[diary] ??= <String>[]).add(path);
      }
    }
  }
  final comments = _readComments(database, columnsOf('comment'), select);

  final where = [
    if (diaryColumns.contains('deleted')) 'COALESCE(deleted, 0) = 0',
    if (diaryColumns.contains('template')) 'COALESCE(template, 0) = 0',
  ];
  final rows = database.select(
    'SELECT ${select(diaryColumns, _diaryColumns)} FROM diary'
    '${where.isEmpty ? '' : ' WHERE ${where.join(' AND ')}'}'
    ' ORDER BY update_time, id',
  );

  final issues = JournalImportIssues();
  final keys = JournalKeyRegistry();
  final parsed = <({JournalImportEntry entry, String? book})>[];
  for (final row in rows) {
    final createdAt = durianTime(row['update_time']);
    final id = journalId(row['id']);
    final content = row['content'];
    if (createdAt == null || id == null || content is! String) {
      issues.skip(JournalSkipReason.unreadable);
      continue;
    }
    final modified = durianTime(row['create_time']);
    final type = row['type'] is int ? row['type'] as int : 0;
    final writer = JournalBlockWriter(preserveWhitespace: type != 2);
    body.write(
      writer,
      type: type,
      content: content,
      quillJson: _text(row['quill_json']),
      imagesGrid: _text(row['images_grid']),
      attachmentPaths: attachmentPaths[id] ?? const [],
    );
    _writeComments(
      writer,
      body,
      legacy: _text(row['comment']),
      comments: comments[id] ?? const [],
    );
    final built = writer.build();
    final latLng = durianCoordinate(_text(row['location']));
    final book = journalId(row['book_id']);
    parsed.add((
      entry: JournalImportEntry(
        sourceKey: keys.unique(id),
        title: journalString(row['title']) ?? '',
        contentJson: built.contentJson,
        contentText: built.contentText,
        createdAt: createdAt,
        updatedAt: modified != null && modified.isAfter(createdAt)
            ? modified
            : createdAt,
        tags: diaryTags[id] ?? const [],
        moodLevel: durianMoodLevel(row['mood'], row['mood_value']),
        weather: durianWeather(row['weather'], row['weather_temp']),
        location: journalString(row['address']),
        latitude: latLng?.latitude,
        longitude: latLng?.longitude,
        pinned: journalNumber(row['important']) == 1,
        sourceMetadata: durianDetails(row),
      ),
      book: book == null ? null : books[book],
    ));
  }
  // 只有一本时全收在一本里，没有区分意义，不记日记本。
  // 指向已删除日记本的日记不算另一本。
  final keepBooks = parsed.map((item) => item.book).nonNulls.toSet().length > 1;
  return JournalImportParseResult(
    entries: [
      for (final item in parsed)
        keepBooks && item.book != null
            ? _withNotebook(item.entry, item.book!)
            : item.entry,
    ],
    missingMediaCount: media.missingCount,
    skippedNotes: issues.skipped,
  );
}

const List<String> _diaryColumns = [
  'id',
  'title',
  'type',
  'content',
  'quill_json',
  'images_grid',
  'book_id',
  'mood',
  'mood_value',
  'mood_emoji',
  'mood_desc',
  'weather',
  'weather_temp',
  'address',
  'location',
  'important',
  'favorite',
  'lock',
  'score',
  'comment',
  'create_time',
  'update_time',
];

typedef _Comment = ({String content, String images, DateTime? time});

/// 评论表：按评论时间排列。`comment_time` 是后来加的列（旧数据以
/// `update_time` 回填），缺失时依次退回 `update_time`、`create_time`。
Map<String, List<_Comment>> _readComments(
  Database database,
  Set<String> columns,
  String Function(Set<String> columns, List<String> names) select,
) {
  if (!columns.containsAll(const {'diary_id', 'content'})) return const {};
  final result = <String, List<_Comment>>{};
  for (final row in database.select(
    'SELECT ${select(columns, const ['diary_id', 'content', 'images', 'comment_time', 'update_time', 'create_time'])} '
    'FROM comment ORDER BY COALESCE(${[
      for (final name in const ['comment_time', 'update_time', 'create_time'])
        if (columns.contains(name)) name,
      '0',
    ].join(', ')}), rowid',
  )) {
    final diary = journalId(row['diary_id']);
    if (diary == null) continue;
    (result[diary] ??= <_Comment>[]).add((
      content: _text(row['content']),
      images: _text(row['images']),
      time:
          durianTime(row['comment_time']) ??
          durianTime(row['update_time']) ??
          durianTime(row['create_time']),
    ));
  }
  return result;
}

/// 评论接在正文末尾：分隔线之后先是旧版的单条评论（没有日期），再是每条
/// 评论的时间（加粗）、文字与图片。
void _writeComments(
  JournalBlockWriter writer,
  DurianDiaryBody body, {
  required String legacy,
  required List<_Comment> comments,
}) {
  final items = <_Comment>[
    if (legacy.trim().isNotEmpty) (content: legacy, images: '', time: null),
    for (final comment in comments)
      if (comment.content.trim().isNotEmpty || comment.images.trim().isNotEmpty)
        comment,
  ];
  if (items.isEmpty) return;
  writer.embed(diaryDividerEmbed);
  for (final item in items) {
    if (item.time case final time?) {
      writer
        ..text(journalWallClockKey(time).replaceFirst('T', ' '), const {
          'bold': true,
        })
        ..endLine();
    }
    if (item.content.trim().isNotEmpty) {
      appendJournalPlainText(writer, item.content);
    }
    body.writeMedia(writer, item.images);
  }
}

JournalImportEntry _withNotebook(JournalImportEntry entry, String book) =>
    JournalImportEntry(
      sourceKey: entry.sourceKey,
      title: entry.title,
      contentJson: entry.contentJson,
      contentText: entry.contentText,
      createdAt: entry.createdAt,
      updatedAt: entry.updatedAt,
      tags: entry.tags,
      notebooks: [book],
      moodLevel: entry.moodLevel,
      weather: entry.weather,
      location: entry.location,
      latitude: entry.latitude,
      longitude: entry.longitude,
      pinned: entry.pinned,
      sourceMetadata: entry.sourceMetadata,
    );

String _text(Object? value) => switch (value) {
  final String text => text,
  final List<int> bytes => utf8.decode(bytes, allowMalformed: true),
  _ => '',
};
