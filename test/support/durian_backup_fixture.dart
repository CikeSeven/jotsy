import 'dart:io';

import 'package:archive/archive.dart';
import 'package:path/path.dart' as p;
import 'package:sqlite3/sqlite3.dart';

/// 榴莲日记本地备份（`.lld`）的测试夹具：表结构逐字取自应用的 Floor 实体
/// （`database.g.dart` 的 CREATE TABLE），按备份的打包方式放进 ZIP：
/// `app_database.db`、`image/<文件>`、`attachment/<文件>`。
class DurianBackupFixture {
  DurianBackupFixture(this.directory)
    : database = sqlite3.open(p.join(directory.path, 'app_database.db')) {
    for (final statement in schema) {
      database.execute(statement);
    }
  }

  final Directory directory;
  final Database database;
  final Map<String, List<int>> files = {};

  static const List<String> schema = [
    'CREATE TABLE IF NOT EXISTS `diary` (`title` TEXT NOT NULL, `type` INTEGER NOT NULL, `content` TEXT NOT NULL, `quill_json` TEXT NOT NULL, `deleted` INTEGER NOT NULL, `images_grid` TEXT NOT NULL, `book_id` TEXT NOT NULL, `mood` INTEGER NOT NULL, `mood_value` INTEGER, `mood_emoji` TEXT, `mood_desc` TEXT, `weather` INTEGER NOT NULL, `weather_temp` REAL, `address` TEXT NOT NULL, `location` TEXT NOT NULL, `important` INTEGER NOT NULL, `favorite` INTEGER, `lock` INTEGER NOT NULL, `score` REAL NOT NULL, `comment` TEXT NOT NULL, `template` INTEGER NOT NULL, `is_df_template` INTEGER, `share_count` INTEGER, `like_count` INTEGER, `id` TEXT NOT NULL, `create_time` INTEGER NOT NULL, `update_time` INTEGER NOT NULL, PRIMARY KEY (`id`))',
    'CREATE TABLE IF NOT EXISTS `book` (`name` TEXT NOT NULL, `remark` TEXT NOT NULL, `cover_type` INTEGER NOT NULL, `cover_value` TEXT NOT NULL, `weight` INTEGER NOT NULL, `is_default` INTEGER NOT NULL, `id` TEXT NOT NULL, `create_time` INTEGER NOT NULL, `update_time` INTEGER NOT NULL, PRIMARY KEY (`id`))',
    'CREATE TABLE IF NOT EXISTS `tag` (`book_id` TEXT NOT NULL, `name` TEXT NOT NULL, `weight` INTEGER NOT NULL, `color` TEXT NOT NULL, `icon` TEXT NOT NULL, `parent_id` TEXT, `id` TEXT NOT NULL, `create_time` INTEGER NOT NULL, `update_time` INTEGER NOT NULL, PRIMARY KEY (`id`))',
    'CREATE TABLE IF NOT EXISTS `relation_diary_tag` (`id` INTEGER PRIMARY KEY AUTOINCREMENT, `diary_id` TEXT NOT NULL, `tag_id` TEXT NOT NULL)',
    'CREATE TABLE IF NOT EXISTS `image` (`id` TEXT NOT NULL, `name` TEXT NOT NULL, `diary_id` TEXT NOT NULL, `comment_id` TEXT NOT NULL, `book_id` TEXT NOT NULL, `create_time` INTEGER NOT NULL, `update_time` INTEGER NOT NULL, PRIMARY KEY (`id`))',
    'CREATE TABLE IF NOT EXISTS `attachment` (`id` TEXT NOT NULL, `path` TEXT NOT NULL, `name` TEXT NOT NULL, `thumbnail` TEXT NOT NULL, `size` INTEGER NOT NULL, `duration` INTEGER NOT NULL, `position` INTEGER NOT NULL, `diary_id` TEXT NOT NULL, `book_id` TEXT NOT NULL, `create_time` INTEGER NOT NULL, `update_time` INTEGER NOT NULL, PRIMARY KEY (`id`))',
    'CREATE TABLE IF NOT EXISTS `comment` (`content` TEXT NOT NULL, `diary_id` TEXT NOT NULL, `images` TEXT NOT NULL, `comment_time` INTEGER NOT NULL, `id` TEXT NOT NULL, `create_time` INTEGER NOT NULL, `update_time` INTEGER NOT NULL, PRIMARY KEY (`id`))',
  ];

  void book(String id, String name, {bool isDefault = false}) =>
      database.execute(
        'INSERT INTO book VALUES (?, \'\', 0, \'\', 0, ?, ?, 0, 0)',
        [name, isDefault ? 1 : 0, id],
      );

  void tag(String id, String name, {String? parentId}) => database.execute(
    'INSERT INTO tag VALUES (\'\', ?, 0, \'\', \'\', ?, ?, 0, 0)',
    [name, parentId, id],
  );

  void tagDiary(String diaryId, String tagId) => database.execute(
    'INSERT INTO relation_diary_tag (diary_id, tag_id) VALUES (?, ?)',
    [diaryId, tagId],
  );

  void attachment(
    String id,
    String diaryId,
    String path, {
    String name = '',
    int position = 0,
    int createTime = 0,
  }) => database.execute(
    'INSERT INTO attachment VALUES (?, ?, ?, \'\', 0, 0, ?, ?, \'\', ?, 0)',
    [id, path, name, position, diaryId, createTime],
  );

  void comment(
    String id,
    String diaryId,
    String content, {
    String images = '',
    int commentTime = 0,
  }) => database.execute('INSERT INTO comment VALUES (?, ?, ?, ?, ?, ?, ?)', [
    content,
    diaryId,
    images,
    commentTime,
    id,
    commentTime,
    commentTime,
  ]);

  /// 插入一篇日记；没给的列取应用新建日记时的默认值。
  void diary(
    String id, {
    String title = '',
    int type = 0,
    String content = '',
    String quillJson = '',
    int deleted = 0,
    String imagesGrid = '',
    String bookId = '',
    int mood = -1,
    int? moodValue,
    String? moodEmoji,
    String? moodDesc,
    int weather = -1,
    double? weatherTemp,
    String address = '',
    String location = '',
    int important = 0,
    int? favorite = 0,
    int lock = 0,
    int template = 0,
    required int createTime,
    int? updateTime,
  }) => database.execute(
    'INSERT INTO diary VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, '
    '?, ?, ?, 0, \'\', ?, 0, 0, 0, ?, ?, ?)',
    [
      title,
      type,
      content,
      quillJson,
      deleted,
      imagesGrid,
      bookId,
      mood,
      moodValue,
      moodEmoji,
      moodDesc,
      weather,
      weatherTemp,
      address,
      location,
      important,
      favorite,
      lock,
      template,
      id,
      createTime,
      updateTime ?? createTime,
    ],
  );

  /// 关闭数据库并打包成 `.lld`。
  File pack([String name = 'durian_diary_2026_01_02_030405.lld']) {
    database.close();
    final archive = Archive();
    void add(String path, List<int> bytes) =>
        archive.addFile(ArchiveFile(path, bytes.length, bytes));
    add(
      'app_database.db',
      File(p.join(directory.path, 'app_database.db')).readAsBytesSync(),
    );
    files.forEach(add);
    return File(p.join(directory.path, name))
      ..writeAsBytesSync(ZipEncoder().encode(archive)!);
  }
}
