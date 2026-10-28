import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:node_diary/core/services/journal_import_durian.dart';
import 'package:node_diary/core/services/journal_import_durian_body.dart';
import 'package:node_diary/core/services/journal_import_durian_meta.dart';
import 'package:node_diary/core/services/journal_import_media.dart';
import 'package:node_diary/core/services/journal_import_models.dart';
import 'package:node_diary/core/services/journal_import_support.dart';
import 'package:path/path.dart' as p;
import 'package:sqlite3/sqlite3.dart';

import '../../support/diary_content_test_helpers.dart';
import '../../support/durian_backup_fixture.dart';

const _jpeg = [0xFF, 0xD8, 0xFF, 0xE0, 0, 0x10, 0x4A, 0x46];
const _mp4 = [0, 0, 0, 0x18, 0x66, 0x74, 0x79, 0x70, 0x6D, 0x70, 0x34, 0x32];

/// 2024-02-29 08:30（本地时间）的毫秒时间戳。
final int _date = DateTime(2024, 2, 29, 8, 30).millisecondsSinceEpoch;

/// 正文逐行：图片写作 `[图]`、视频 `[视频]`、录音 `[录音]`、分隔线 `[---]`，
/// 其他文件为 `[attachment]`。
List<String> _lines(JournalImportEntry entry) {
  final lines = <String>[];
  final current = StringBuffer();
  for (final op in diaryContentQuillOps(entry.contentJson)) {
    switch (op['insert']) {
      case final String text:
        final parts = text.split('\n');
        for (var i = 0; i < parts.length; i++) {
          if (i > 0) {
            lines.add('$current');
            current.clear();
          }
          current.write(parts[i]);
        }
      case final Map embed:
        current.write(switch (embed.keys.first) {
          'image' => '[图]',
          'video' => '[视频]',
          'audio' => '[录音]',
          'divider' => '[---]',
          final other => '[$other]',
        });
    }
  }
  if (current.isNotEmpty) lines.add('$current');
  return lines;
}

Map<String, Object?>? _attributesOf(JournalImportEntry entry, String text) =>
    diaryContentQuillOps(
          entry.contentJson,
        ).firstWhere((op) => op['insert'] == text)['attributes']
        as Map<String, Object?>?;

void main() {
  late Directory temp;
  late Directory export;
  late DurianBackupFixture backup;
  late JournalMediaStager media;

  setUp(() async {
    temp = await Directory.systemTemp.createTemp('durian_import_test_');
    export = await Directory(p.join(temp.path, 'export')).create();
    backup = DurianBackupFixture(export);
    media = JournalMediaStager(
      (await Directory(p.join(temp.path, 'staging')).create()).path,
    );
  });

  tearDown(() async {
    try {
      backup.database.close();
    } on StateError {
      // 已在 parse() 里关闭。
    }
    await temp.delete(recursive: true);
  });

  void file(String relative, List<int> bytes) {
    final target = File(p.join(export.path, relative));
    target.parent.createSync(recursive: true);
    target.writeAsBytesSync(bytes);
  }

  JournalImportParseResult parse() {
    backup.database.close();
    return parseDurianDiaryExport(
      JournalImportInput(filePath: export.path, extractedPath: export.path),
      media,
    );
  }

  group('body', () {
    test('rich text keeps formatting, inline media in place and only adds '
        'grid items the body does not use', () {
      file('image/20240229083000-a.jpg', _jpeg);
      file('image/20240229083000-still.jpg', _jpeg);
      file('image/20240229083000-motion.mp4', _mp4);
      file('image/20240229083000-extra.jpg', _jpeg);
      backup.diary(
        'rich',
        type: 1,
        // 富文本的 content 只是纯文本副本，不能用来生成正文。
        content: '副本\uFFFC\n',
        quillJson: jsonEncode([
          {'insert': '标题'},
          {
            'insert': '\n',
            'attributes': {'header': 1},
          },
          {'insert': '　　首行缩进，'},
          {
            'insert': '红字',
            'attributes': {'color': '#FFE91E63', 'bold': true},
          },
          {'retain': 3},
          {'insert': '\n'},
          {'insert': '已完成'},
          {
            'insert': '\n',
            'attributes': {'list': 'checked'},
          },
          {
            'insert': {'image': 'img:20240229083000-a.jpg'},
            'attributes': {'style': 'width: 200; dd-size-mode: fit'},
          },
          {
            'insert': '\n',
            'attributes': {'align': 'center'},
          },
          {
            'insert': {'divider': 'dashed'},
          },
          {'insert': '\n'},
          {
            'insert': {
              'image':
                  'live:20240229083000-still.jpg|20240229083000-motion.mp4',
            },
          },
          {'insert': '\n结尾\n'},
        ]),
        imagesGrid:
            'img:20240229083000-a.jpg,'
            'live:20240229083000-still.jpg|20240229083000-motion.mp4,'
            'img:20240229083000-extra.jpg',
        createTime: _date,
      );

      final result = parse();

      final entry = result.entries.single;
      expect(_lines(entry), [
        '标题',
        '　　首行缩进，红字',
        '已完成',
        '[图]',
        '[---]',
        '[图]',
        '[视频]',
        '结尾',
        '[图]',
      ]);
      expect(_attributesOf(entry, '红字'), {'bold': true, 'color': '#FFE91E63'});
      expect(result.missingMediaCount, 0);
    });

    test('rich text without a valid Delta falls back to the plain copy', () {
      file('image/a.jpg', _jpeg);
      backup.diary(
        'broken',
        type: 1,
        content: '纯文本副本\uFFFC\n第二行\n',
        // 最后一个 op 不以换行结尾：应用自己也改为显示 content。
        quillJson: jsonEncode([
          {'insert': '没有换行'},
        ]),
        imagesGrid: 'img:a.jpg',
        createTime: _date,
      );

      expect(_lines(parse().entries.single), ['纯文本副本', '第二行', '[图]']);
    });

    test('a photo-only plain diary does not start with a blank line', () {
      file('image/a.jpg', _jpeg);
      backup.diary('photo', imagesGrid: 'img:a.jpg', createTime: _date);

      expect(_lines(parse().entries.single), ['[图]']);
    });

    test('Markdown resolves bare and URL-encoded file names', () {
      file('image/2024 照片.jpg', _jpeg);
      file('image/b.jpg', _jpeg);
      backup.diary(
        'md',
        type: 2,
        content: '# 标题\n**粗体**\n\n![](2024%20%E7%85%A7%E7%89%87.jpg)',
        imagesGrid: 'img:2024 照片.jpg,img:b.jpg',
        createTime: _date,
      );

      final entry = parse().entries.single;
      expect(_lines(entry), ['标题', '粗体', '', '[图]', '[图]']);
      expect(_attributesOf(entry, '粗体'), {'bold': true});
    });

    test('plain text keeps its whitespace, then grid media and attachments '
        'in order', () {
      file('image/a.jpg', _jpeg);
      file('image/v.mp4', _mp4);
      file('attachment/Record_2024_02_29_083000.m4a', const [
        0,
        0,
        0,
        0x20,
        0x66,
        0x74,
        0x79,
        0x70,
        0x4D,
        0x34,
        0x41,
        0x20,
      ]);
      file('attachment/report.pdf', utf8.encode('%PDF-1.4'));
      backup
        ..diary(
          'plain',
          content: '　　第一段\n\n  第二段 **不是粗体**',
          imagesGrid: 'a.jpg,video:v.mp4,img:gone.jpg',
          createTime: _date,
        )
        ..attachment('x2', 'plain', 'report.pdf', position: 1)
        ..attachment(
          'x1',
          'plain',
          'Record_2024_02_29_083000.m4a',
          position: 0,
        );

      final result = parse();

      expect(_lines(result.entries.single), [
        '　　第一段',
        '',
        '  第二段 **不是粗体**',
        '[图]',
        '[视频]',
        '[录音]',
        '[attachment]',
      ]);
      expect(result.missingMediaCount, 1);
    });

    test('comments follow a divider in comment-time order', () {
      file('image/c.jpg', _jpeg);
      backup.diary('commented', content: '正文', createTime: _date);
      backup.database.execute(
        "UPDATE diary SET comment = '旧版评论' WHERE id = 'commented'",
      );
      backup
        ..comment(
          'late',
          'commented',
          '第二条',
          commentTime: DateTime(2024, 3, 2, 9, 5).millisecondsSinceEpoch,
        )
        ..comment(
          'early',
          'commented',
          '第一条',
          images: '["c.jpg"]',
          commentTime: DateTime(2024, 3, 1, 21, 0).millisecondsSinceEpoch,
        );

      final entry = parse().entries.single;
      expect(_lines(entry), [
        '正文',
        '[---]',
        '旧版评论',
        '2024-03-01 21:00',
        '第一条',
        '[图]',
        '2024-03-02 09:05',
        '第二条',
      ]);
      expect(_attributesOf(entry, '2024-03-01 21:00'), {'bold': true});
    });
  });

  group('metadata', () {
    test('update_time is the diary date and create_time the last edit', () {
      final edited = DateTime(2024, 3, 5, 12).millisecondsSinceEpoch;
      backup.diary(
        'dated',
        content: '补写的日记',
        createTime: edited,
        updateTime: _date,
      );

      final entry = parse().entries.single;
      expect(entry.createdAt, DateTime(2024, 2, 29, 8, 30));
      expect(entry.updatedAt, DateTime(2024, 3, 5, 12));
    });

    test('maps tags, books, mood, weather, place and pin', () {
      backup
        ..book('00000000000000000000000000000001', '默认本', isDefault: true)
        ..book('travel', '旅行')
        ..tag('t1', '生活')
        ..tag('t2', '城市', parentId: 't1')
        ..diary(
          'a',
          content: '甲',
          bookId: 'travel',
          mood: 22,
          weather: 0,
          weatherTemp: 25.7,
          address: '外滩',
          location: '31.2304,121.4737',
          important: 1,
          favorite: 1,
          lock: 1,
          createTime: _date,
        )
        ..diary(
          'b',
          content: '乙',
          bookId: '00000000000000000000000000000001',
          mood: -2,
          moodEmoji: '🦄',
          moodDesc: '自定义',
          weather: -1,
          weatherTemp: -3.5,
          // 早期数据经纬颠倒。
          location: '121.4737,31.2304',
          createTime: _date + 1,
        )
        ..diary(
          'c',
          content: '丙',
          bookId: 'gone',
          mood: 0,
          moodValue: 15,
          weather: 17,
          createTime: _date + 2,
        )
        ..tagDiary('a', 't1')
        ..tagDiary('a', 't2')
        ..tagDiary('a', 't1');

      final [a, b, c] = parse().entries;

      expect(a.tags, ['生活', '城市']);
      expect(a.notebooks, ['旅行']);
      expect(b.notebooks, ['默认本']);
      expect(c.notebooks, isEmpty);
      // 生气（默认指数 10）→ 最差；自定义心情没有指数无法定级；开心但指数 15。
      expect([a.moodLevel, b.moodLevel, c.moodLevel], [1, null, 1]);
      expect([a.weather, b.weather, c.weather], ['晴天 25℃', '-3℃', '雾霾']);
      expect(a.location, '外滩');
      expect((a.latitude, a.longitude), (31.2304, 121.4737));
      expect((b.latitude, b.longitude), (31.2304, 121.4737));
      expect(a.pinned, isTrue);
      expect(b.pinned, isFalse);
      expect(a.sourceMetadata, {
        'mood': '生气',
        'moodEmoji': '😡',
        'favorite': true,
        'locked': true,
      });
      expect(b.sourceMetadata, {'mood': '自定义', 'moodEmoji': '🦄'});
      expect(c.sourceMetadata, {
        'mood': '开心',
        'moodEmoji': '😄',
        'moodValue': 15,
      });
    });

    test('a book that no longer exists does not count as another book', () {
      backup
        ..book('00000000000000000000000000000001', '默认本', isDefault: true)
        ..diary(
          'a',
          content: '甲',
          bookId: '00000000000000000000000000000001',
          createTime: _date,
        )
        ..diary('b', content: '乙', bookId: 'deleted', createTime: _date);

      expect(parse().entries.map((entry) => entry.notebooks), [
        isEmpty,
        isEmpty,
      ]);
    });

    test('a single book is not recorded as a notebook', () {
      backup
        ..book('00000000000000000000000000000001', '默认本', isDefault: true)
        ..diary(
          'a',
          content: '甲',
          bookId: '00000000000000000000000000000001',
          createTime: _date,
        )
        ..diary(
          'b',
          content: '乙',
          bookId: '00000000000000000000000000000001',
          createTime: _date,
        );

      expect(parse().entries.map((entry) => entry.notebooks), [
        isEmpty,
        isEmpty,
      ]);
    });

    test('mood levels follow the app\'s own bands', () {
      expect(durianMoodLevel(-1, null), isNull);
      expect(durianMoodLevel(-1, 90), isNull);
      expect(durianMoodLevel(4, null), 5); // 幸福 95
      expect(durianMoodLevel(7, null), 4); // 平静 60
      expect(durianMoodLevel(11, null), 3); // 惊讶 55
      expect(durianMoodLevel(8, null), 2); // 纠结 35
      expect(durianMoodLevel(16, null), 1); // 恐惧 15
      // 心情指数只认 1~100，其他值退回默认指数。
      expect(durianMoodLevel(16, 0), 1);
      expect(durianMoodLevel(16, 101), 1);
      expect(durianMoodLevel(-2, 79), 4);
      expect(durianMoodLevel(-2, null), isNull);
    });
  });

  test('trash and templates are not imported, unreadable rows are counted', () {
    backup
      ..diary('kept', content: '正文', createTime: _date)
      ..diary('trash', content: '回收站', deleted: 1, createTime: _date)
      ..diary('template', content: '模板', template: 1, createTime: _date)
      ..diary('undated', content: '没有日期', createTime: 0);

    final result = parse();

    expect(result.entries.map((entry) => entry.sourceKey), ['kept']);
    expect(result.skippedNotes, {JournalSkipReason.unreadable: 1});
  });

  test('backups from old versions without later columns still import', () {
    backup.database.close();
    File(p.join(export.path, 'app_database.db')).deleteSync();
    final database = sqlite3.open(p.join(export.path, 'app_database.db'));
    database
      ..execute(
        'CREATE TABLE diary (id TEXT PRIMARY KEY, title TEXT, type INTEGER, '
        'content TEXT, quill_json TEXT, deleted INTEGER, images_grid TEXT, '
        'mood INTEGER, weather INTEGER, address TEXT, location TEXT, '
        'important INTEGER, lock INTEGER, template INTEGER, '
        'create_time INTEGER, update_time INTEGER)',
      )
      ..execute(
        "INSERT INTO diary VALUES ('old', '旧标题', 0, '旧正文', '', 0, '', 3, 2, "
        "'', '', 0, 0, 0, ?, ?)",
        [_date, _date],
      )
      ..close();

    final result = parseDurianDiaryExport(
      JournalImportInput(filePath: export.path, extractedPath: export.path),
      media,
    );

    final entry = result.entries.single;
    expect(entry.title, '旧标题');
    expect(entry.contentText, '旧正文');
    expect(entry.moodLevel, 5); // 甜蜜 85
    expect(entry.weather, '多云');
  });

  test('reads the zipped backup folder layout (database/ + image/)', () {
    backup
      ..diary('a', content: '文件夹备份', imagesGrid: 'img:a.jpg', createTime: _date)
      ..database.close();
    final folder = Directory(p.join(temp.path, 'folder', '榴莲日记备份'));
    Directory(p.join(folder.path, 'database')).createSync(recursive: true);
    File(
      p.join(export.path, 'app_database.db'),
    ).renameSync(p.join(folder.path, 'database', 'app_database.db'));
    File(p.join(folder.path, 'image', 'a.jpg'))
      ..parent.createSync()
      ..writeAsBytesSync(_jpeg);

    final result = parseDurianDiaryExport(
      JournalImportInput(
        filePath: folder.path,
        extractedPath: p.dirname(folder.path),
      ),
      media,
    );

    expect(_lines(result.entries.single), ['文件夹备份', '[图]']);
    expect(result.missingMediaCount, 0);
  });

  test('other files are rejected as the wrong format', () {
    backup.database.close();
    File(p.join(export.path, 'app_database.db')).deleteSync();
    File(p.join(export.path, 'notes.txt')).writeAsStringSync('not a backup');
    for (final input in [
      JournalImportInput(filePath: export.path, extractedPath: export.path),
      JournalImportInput(filePath: p.join(export.path, 'notes.txt')),
    ]) {
      expect(
        () => parseDurianDiaryExport(input, media),
        throwsA(isA<JournalImportFormatException>()),
      );
    }
    // 同名但不是 SQLite 数据库。
    File(p.join(export.path, 'app_database.db')).writeAsStringSync('junk');
    expect(
      () => parseDurianDiaryExport(
        JournalImportInput(filePath: export.path, extractedPath: export.path),
        media,
      ),
      throwsA(isA<JournalImportFormatException>()),
    );
  });

  test('parseDurianMediaItem understands every grid item form', () {
    String describe(DurianMediaItem? item) => item == null
        ? 'null'
        : [
            for (final (index, file) in item.files.indexed)
              '${item.kinds[index].name}:$file',
          ].join('+');
    expect(describe(parseDurianMediaItem('img:a.jpg')), 'image:a.jpg');
    expect(describe(parseDurianMediaItem('video:v.mp4')), 'video:v.mp4');
    expect(
      describe(parseDurianMediaItem('live:s.jpg|v.mp4')),
      'image:s.jpg+video:v.mp4',
    );
    // live 缺一段时与应用一致按整串当图片。
    expect(describe(parseDurianMediaItem('live:s.jpg|')), 'image:live:s.jpg|');
    expect(describe(parseDurianMediaItem(' a.jpg ')), 'image:a.jpg');
    expect(describe(parseDurianMediaItem('img:')), 'null');
    expect(describe(parseDurianMediaItem('')), 'null');
    expect(parseDurianCommentMedia('["a.jpg","video:v.mp4"]').length, 2);
    expect(parseDurianCommentMedia('img:a.jpg,b.jpg').length, 2);
  });

  test('decodeDurianQuill drops retain ops and rejects invalid documents', () {
    expect(decodeDurianQuill(''), isNull);
    expect(decodeDurianQuill('{"ops": []}'), isNull);
    expect(decodeDurianQuill('[{"insert": "no newline"}]'), isNull);
    expect(decodeDurianQuill('["text\\n"]'), isNull);
    expect(
      decodeDurianQuill('[{"insert":"a"},{"retain":1},{"insert":"\\n"}]'),
      [
        {'insert': 'a'},
        {'insert': '\n'},
      ],
    );
  });

  test('durianTime ignores empty and out-of-range timestamps', () {
    expect(durianTime(0), isNull);
    expect(durianTime(-5), isNull);
    expect(durianTime(1e300), isNull);
    expect(durianTime(_date), DateTime(2024, 2, 29, 8, 30));
    expect(journalWallClockKey(durianTime('$_date')!), '2024-02-29T08:30');
  });
}
