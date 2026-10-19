import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:node_diary/core/database/app_database.dart';
import 'package:node_diary/core/services/backup_constants.dart';
import 'package:node_diary/core/services/backup_payload.dart';
import 'package:node_diary/core/services/journal_import_models.dart';
import 'package:node_diary/core/services/journal_import_notebooks.dart';
import 'package:node_diary/core/services/journal_import_payload.dart';

/// 导入载荷中的来源日记本：三种落地方式、与本机日记本的复用规则、名称规整，
/// 以及载荷能通过备份解码的校验（id 唯一、关联行两端都在、只连手动本子）。
void main() {
  const source = JournalImportSource.diaro;
  final now = DateTime(2026, 10, 18, 9);

  JournalImportEntry entry(
    String key, {
    List<String> tags = const <String>[],
    List<String> notebooks = const <String>[],
  }) => JournalImportEntry(
    sourceKey: key,
    contentJson: '[{"insert":"$key\\n"}]',
    contentText: key,
    createdAt: DateTime(2024, 1, 1),
    tags: tags,
    notebooks: notebooks,
  );

  NotebookRow localNotebook({
    required int id,
    required String notebookId,
    required String name,
    String kind = 'manual',
    String payload = '{"icon":"plane","color":4278190335}',
  }) => NotebookRow(
    id: id,
    notebookId: notebookId,
    name: name,
    kind: kind,
    visibility: 'hidden',
    payload: payload,
    sortOrder: 7,
    isPinned: true,
    isClosed: false,
    createdAt: DateTime(2020),
    updatedAt: DateTime(2021),
  );

  /// 经备份 JSON 走一遍解码：会触发与真实导入相同的校验，并丢掉悬空或指向
  /// 非手动本子的关联行——数量不变说明载荷本身就是干净的。
  BackupPayload roundTrip(BackupPayload payload) {
    final decoded = BackupPayload.decode(
      jsonEncode({
        'formatVersion': backupFormatVersion,
        'database': {
          'diaries': payload.diaries.map((row) => row.toJson()).toList(),
          'tags': payload.tags.map((row) => row.toJson()).toList(),
          'diaryTags': payload.diaryTags.map((row) => row.toJson()).toList(),
          'notebooks': payload.notebooks.map((row) => row.toJson()).toList(),
          'diaryNotebooks': payload.diaryNotebooks
              .map((row) => row.toJson())
              .toList(),
        },
      }),
    );
    expect(decoded.notebooks, hasLength(payload.notebooks.length));
    expect(decoded.diaryNotebooks, hasLength(payload.diaryNotebooks.length));
    return decoded;
  }

  final entries = [
    entry('a', tags: ['Idea'], notebooks: ['Travel']),
    entry('b', notebooks: ['  Work   notes ']),
    entry('c', tags: ['Idea'], notebooks: ['Travel']),
    entry('d'),
  ];

  Map<String, List<String>> membersByName(BackupPayload payload) {
    final names = {for (final row in payload.notebooks) row.id: row.name};
    final keys = {for (final row in payload.diaries) row.id: row.contentText};
    final result = <String, List<String>>{};
    final rows = [...payload.diaryNotebooks]
      ..sort((a, b) => a.position.compareTo(b.position));
    for (final row in rows) {
      (result[names[row.notebookId]!] ??= <String>[]).add(keys[row.diaryId]!);
    }
    return result;
  }

  test('notebooks mode creates notebooks with members in parse order', () {
    final payload = buildJournalImportPayload(
      source,
      entries,
      tagColors: const [0xFF000001, 0xFF000002],
      now: now,
    );
    roundTrip(payload);

    expect(payload.tags.map((tag) => tag.name), ['Idea']);
    expect(payload.notebooks.map((row) => row.name), ['Travel', 'Work notes']);
    final travel = payload.notebooks.first;
    expect(travel.notebookId, journalImportNotebookId(source, 'Travel'));
    expect(travel.kind, 'manual');
    expect(travel.visibility, 'normal');
    expect(travel.createdAt, now);
    expect(jsonDecode(travel.payload), {'icon': 'book', 'color': 0xFF000001});
    expect(
      (jsonDecode(payload.notebooks.last.payload) as Map)['color'],
      0xFF000002,
    );
    expect(membersByName(payload), {
      'Travel': ['a', 'c'],
      'Work notes': ['b'],
    });
    expect(payload.diaryNotebooks.map((row) => row.addedAt), [now, now, now]);
    expect(payload.diaryNotebooks.map((row) => row.chapterId), [
      null,
      null,
      null,
    ]);
  });

  test('tags mode reproduces the folder-as-tag behaviour exactly', () {
    final payload = buildJournalImportPayload(
      source,
      entries,
      folderMode: JournalImportFolderMode.tags,
      now: now,
    );

    expect(payload.notebooks, isEmpty);
    expect(payload.diaryNotebooks, isEmpty);
    // 与旧版一致：文件夹名接在条目标签之后，同样规整空白。
    expect(payload.tags.map((tag) => tag.name), [
      'Idea',
      'Travel',
      'Work notes',
    ]);
    expect(payload.diaryTags, hasLength(5));
  });

  test('both mode creates the notebooks and the tags', () {
    final payload = buildJournalImportPayload(
      source,
      entries,
      folderMode: JournalImportFolderMode.both,
      now: now,
    );
    roundTrip(payload);

    expect(payload.tags.map((tag) => tag.name), [
      'Idea',
      'Travel',
      'Work notes',
    ]);
    expect(membersByName(payload), {
      'Travel': ['a', 'c'],
      'Work notes': ['b'],
    });
  });

  test('reuses the notebook created by an earlier import verbatim', () {
    // 上次导入建的本子被用户改了名、换了图标颜色，还设为隐藏与置顶。
    final previous = localNotebook(
      id: 42,
      notebookId: journalImportNotebookId(source, 'Travel'),
      name: 'Trips',
    );
    final payload = buildJournalImportPayload(
      source,
      entries,
      existingNotebooks: [previous],
      now: now,
    );
    roundTrip(payload);

    final reused = payload.notebooks.firstWhere(
      (row) => row.notebookId == previous.notebookId,
    );
    expect(reused, previous.copyWith(id: reused.id));
    expect(membersByName(payload)['Trips'], ['a', 'c']);
  });

  test('reuses a local manual notebook with the same name verbatim', () {
    final mine = localNotebook(
      id: 3,
      notebookId: 'local-travel',
      name: 'Travel',
    );
    final payload = buildJournalImportPayload(
      source,
      entries,
      existingNotebooks: [mine],
      now: now,
    );
    roundTrip(payload);

    expect(payload.notebooks.first, mine.copyWith(id: 1));
    expect(
      payload.notebooks.map((row) => row.notebookId),
      isNot(contains(journalImportNotebookId(source, 'Travel'))),
    );
  });

  test('two names landing on one local notebook share a single row', () {
    // 上次为 Travel 建的本子被改名成 Work notes，两个名字都指向它。
    final renamed = localNotebook(
      id: 5,
      notebookId: journalImportNotebookId(source, 'Travel'),
      name: 'Work notes',
    );
    final payload = buildJournalImportPayload(
      source,
      entries,
      existingNotebooks: [renamed],
      now: now,
    );
    roundTrip(payload);

    expect(payload.notebooks, [renamed.copyWith(id: 1)]);
    expect(membersByName(payload), {
      'Work notes': ['a', 'b', 'c'],
    });
  });

  test('never targets a local smart notebook', () {
    final smartByName = localNotebook(
      id: 1,
      notebookId: 'smart-travel',
      name: 'Travel',
      kind: 'smart',
    );
    // 上次导入建的 Work notes 已被转成智能日记本：确定性 id 被占用。
    final smartById = localNotebook(
      id: 2,
      notebookId: journalImportNotebookId(source, 'Work notes'),
      name: 'Converted',
      kind: 'smart',
    );
    final payload = buildJournalImportPayload(
      source,
      entries,
      existingNotebooks: [smartByName, smartById],
      now: now,
    );
    roundTrip(payload);

    expect(payload.notebooks.map((row) => (row.name, row.kind)), [
      ('Travel', 'manual'),
      ('Work notes', 'manual'),
    ]);
    final ids = payload.notebooks.map((row) => row.notebookId).toSet();
    expect(ids, isNot(contains(smartByName.notebookId)));
    expect(ids, isNot(contains(smartById.notebookId)));
    expect(ids, contains(journalImportNotebookId(source, 'Travel')));
    // 另取的 id 也是确定的，再次导入落回同一本。
    final again = buildJournalImportPayload(
      source,
      entries,
      existingNotebooks: [smartByName, smartById],
      now: now,
    );
    expect(again.notebooks.map((row) => row.notebookId).toSet(), ids);
  });

  test('skips blank names and clamps long ones to the column limit', () {
    final long = '日' * 70;
    final payload = buildJournalImportPayload(source, [
      entry('a', notebooks: ['   ', '']),
      entry('b', notebooks: [long, '$long tail', long]),
    ], now: now);
    roundTrip(payload);

    expect(payload.notebooks, hasLength(1));
    expect(payload.notebooks.single.name, '日' * 60);
    expect(payload.diaryNotebooks, hasLength(1));
    expect(normalizeJournalImportNotebookName('  a \n b  '), 'a b');
  });

  test('keeps the original folder names when landing shortens them', () {
    final long = '日' * 50;
    final named = [
      entry('long', notebooks: [long]),
      entry('spaced', notebooks: ['  Work   notes ']),
      entry('plain', notebooks: ['Travel']),
    ];
    Map<String, Object?> imported(BackupPayload payload, int index) =>
        (jsonDecode(payload.diaries[index].metadata) as Map)['import']
            as Map<String, Object?>;

    // 日记本名上限 60：50 字的名字原样落地，不必另存；空白规整过的要存。
    final asNotebooks = buildJournalImportPayload(source, named, now: now);
    expect(imported(asNotebooks, 0), isNot(contains('originalNotebooks')));
    expect(imported(asNotebooks, 1)['originalNotebooks'], ['  Work   notes ']);
    expect(imported(asNotebooks, 2), isNot(contains('originalNotebooks')));

    // 标签上限 40：同一个名字落成标签会被截断，原名留在 metadata 里。
    for (final mode in [
      JournalImportFolderMode.tags,
      JournalImportFolderMode.both,
    ]) {
      final payload = buildJournalImportPayload(
        source,
        named,
        folderMode: mode,
        now: now,
      );
      expect(imported(payload, 0)['originalNotebooks'], [long]);
      expect(imported(payload, 1)['originalNotebooks'], ['  Work   notes ']);
      expect(imported(payload, 2), isNot(contains('originalNotebooks')));
      // 来源标签本身没有被改动，不记 originalTags。
      expect(imported(payload, 0), isNot(contains('originalTags')));
    }
  });

  test('notebook ids do not collide with diary ids of the same key', () {
    expect(
      journalImportNotebookId(source, 'x'),
      isNot(journalImportDiaryId(source, 'x')),
    );
    expect(
      journalImportNotebookId(source, 'x'),
      journalImportNotebookId(source, 'x'),
    );
  });
}
